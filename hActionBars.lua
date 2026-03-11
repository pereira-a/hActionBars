-- hActionBars
-- Hides / shows a user-selected group of action bars via a single keybind.
--
-- Configuration : /hab  (or /hactionbars)

local ADDON_NAME = ...

-- ============================================================
-- KEYBIND DISPLAY STRINGS
-- Must be globals so WoW reads them when registering bindings.
-- ============================================================

BINDING_HEADER_HACTIONBARS      = "hActionBars"
BINDING_NAME_HACTIONBARS_TOGGLE = "Toggle Selected Bars"

-- ============================================================
-- BAR DEFINITIONS
-- ============================================================

local BARS = {
    -- Action bars
    { name = "MainActionBar",           label = "Main Action Bar"            },
    { name = "MultiBarBottomLeft",      label = "Extra Bar"                  },
    { name = "MultiBarBottomRight",     label = "Extra Bar 3"                },
    { name = "MultiBarRight",           label = "Extra Bar 4"                },
    { name = "MultiBarLeft",            label = "Extra Bar 5"               },
    { name = "MultiBar5",               label = "Extra Bar 6"                },
    { name = "MultiBar6",               label = "Extra Bar 7"                },
    { name = "MultiBar7",               label = "Extra Bar 8"                },
    -- Special bars 
    { name = "ShapeshiftBarFrame",      label = "Stance / Shapeshift Bar"    },
    { name = "PetActionBarFrame",       label = "Pet Bar"                    },
    { name = "ExtraActionBarFrame",     label = "Extra Action Bar"           },
    { name = "ZoneAbilityFrame",        label = "Zone Ability Bar"           },
    { name = "OverrideActionBar",       label = "Override / Vehicle Bar"     },
    { name = "MicroButtonAndBagsBar",   label = "Micro Menu & Bags"          },
}

-- ============================================================
-- SAVED VARIABLES
-- hActionBarsDB = {
--   selected = { [frameName] = true },   -- bars in the toggle group
--   hidden   = false,                    -- current toggle state
-- }
-- ============================================================

local function InitDB()
    if type(hActionBarsDB) ~= "table"          then hActionBarsDB          = {} end
    if type(hActionBarsDB.selected) ~= "table" then hActionBarsDB.selected = {} end
    if hActionBarsDB.hidden == nil             then hActionBarsDB.hidden   = false end
end

local function IsSelected(name) return hActionBarsDB.selected[name] == true end
local function SetSelected(name, v) hActionBarsDB.selected[name] = v or nil end
local function AreHidden() return hActionBarsDB.hidden == true end

local uiPanel = nil

-- ============================================================
-- BAR CONTROL
-- ============================================================

local function ApplyBar(name)
    if not IsSelected(name) then return end  -- never touch bars outside the toggle group
    local f = _G[name]
    if not f then return end
    if AreHidden() then
        f:SetAlpha(0)  -- works even on Edit Mode protected frames (e.g. MainMenuBar)
        f:Hide()       -- also hide when possible; silently ignored if frame is protected
    else
        f:SetAlpha(1)
        f:Show()       -- no-op if still shown; SetAlpha(1) handles the protected case
    end
end

local function ApplyAll()
    for _, bar in ipairs(BARS) do ApplyBar(bar.name) end
end

-- ============================================================
-- BINDING STATUS
-- The actual keybind is defined in Bindings.xml via <ButtonArray>.
-- We only read binding state to update the /hab panel hint.
-- ============================================================

local function RefreshBindingHintUI()
    if uiPanel and uiPanel.RefreshBindingHint then
        uiPanel:RefreshBindingHint()
    end
end

-- ============================================================
-- TOGGLE  -- called by the virtual button's OnClick and /hab toggle
-- Global so the virtual button's OnClick can reach it.
-- ============================================================

function hActionBars_Toggle()

    if not hActionBarsDB then
        print("hActionBars: ERROR - DB is nil (ADDON_LOADED may not have fired yet)")
        return
    end

    hActionBarsDB.hidden = not AreHidden()

    -- Collect which bars are actually selected so we can report them.
    local sel, missing = {}, {}
    for _, bar in ipairs(BARS) do
        if IsSelected(bar.name) then
            if _G[bar.name] then
                sel[#sel + 1] = bar.name
            else
                missing[#missing + 1] = bar.name   -- selected but frame does not exist
            end
        end
    end

    if #sel == 0 and #missing == 0 then
        print("hActionBars: no bars selected (open /hab and check some action bars to toggle)")
    else
        if #missing > 0 then
            print("hActionBars: WARNING - selected but frame not found: " .. table.concat(missing, ", "))
        end
    end

    ApplyAll()

    if uiPanel and uiPanel.RefreshStatus then
        uiPanel:RefreshStatus()
    end
end

-- ============================================================
-- UI  (configuration panel — /hab)
-- ============================================================

local cbMap = {}

local PANEL_W  = 300
local PANEL_H  = 460 
local TITLE_H  = 34
local BOTTOM_H = 54 
local PAD      = 8
local SCROLL_W = 22 
local ROW_H    = 24

local function StatusColor()
    return AreHidden() and "|cFFFF6600" or "|cFF44FF44"
end

local function GetToggleBindingKeys()
    return GetBindingKey("HACTIONBARS_TOGGLE")
end

local function FormatBindingHint(key1, key2)
    if key1 or key2 then
        local keys = {}
        if key1 then keys[#keys + 1] = key1 end
        if key2 then keys[#keys + 1] = key2 end
        return "|cFF888888Keybind: " .. table.concat(keys, " / ") .. "|r"
    end

    return "|cFFFF6600No keybind set. Use Key Bindings > AddOns > hActionBars.|r"
end

local function BuildUI()
    local f = CreateFrame("Frame", "hActionBarsPanel", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(PANEL_W, PANEL_H)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:Hide()

    f.TitleText:SetText("hActionBars")

    -- Status label (below title)
    local statusLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusLabel:SetPoint("TOP", f, "TOP", 0, -TITLE_H + 4)
    f.RefreshStatus = function(self)
        statusLabel:SetText(StatusColor() .. (AreHidden() and "HIDDEN|r" or "SHOWN|r"))
    end
    f:RefreshStatus()

    -- Scroll frame (fills space between title and buttons)
    local scrollFrame = CreateFrame("ScrollFrame", "hActionBarsScroll", f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     f, "TOPLEFT",     PAD,              -TITLE_H - PAD)
    scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(PAD + SCROLL_W), BOTTOM_H)

    -- Content frame inside the scroll frame
    local contentW = PANEL_W - 2 * PAD - SCROLL_W
    local contentH = 4 + #BARS * ROW_H
    local content = CreateFrame("Frame", "hActionBarsContent", scrollFrame)
    content:SetSize(contentW, contentH)
    scrollFrame:SetScrollChild(content)

    -- Checkbox rows
    for i, bar in ipairs(BARS) do
        local yOff = -(4 + (i - 1) * ROW_H)

        local cb = CreateFrame("CheckButton", "hABcb_" .. bar.name, content, "UICheckButtonTemplate")
        cb:SetSize(20, 20)
        cb:SetPoint("TOPLEFT", content, "TOPLEFT", 4, yOff - 2)
        cb:SetChecked(IsSelected(bar.name))

        local lbl = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lbl:SetPoint("LEFT", cb, "RIGHT", 4, 0)

        lbl:SetText(bar.label)
        local barName = bar.name
        cb:SetScript("OnClick", function(self)
            SetSelected(barName, self:GetChecked())
            ApplyBar(barName)
        end)

        cbMap[bar.name] = cb
    end

    -- Buttons (anchored to panel bottom, outside the scroll frame)
    local btnY = PAD + 14 + 6   -- above hint text

    local btnAll = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnAll:SetSize(86, 22)
    btnAll:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, btnY)
    btnAll:SetText("Select All")
    btnAll:SetScript("OnClick", function()
        for _, bar in ipairs(BARS) do SetSelected(bar.name, true) end
        for _, bar in ipairs(BARS) do
            if cbMap[bar.name] then cbMap[bar.name]:SetChecked(true) end
        end
        ApplyAll()
    end)

    local btnNone = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnNone:SetSize(86, 22)
    btnNone:SetPoint("LEFT", btnAll, "RIGHT", 6, 0)
    btnNone:SetText("Clear All")
    btnNone:SetScript("OnClick", function()
        for _, bar in ipairs(BARS) do SetSelected(bar.name, false) end
        for _, bar in ipairs(BARS) do
            if cbMap[bar.name] then cbMap[bar.name]:SetChecked(false) end
        end
        ApplyAll()
    end)

    local btnToggle = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnToggle:SetSize(86, 22)
    btnToggle:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, btnY)
    btnToggle:SetText("Toggle Now")
    btnToggle:SetScript("OnClick", function()
        hActionBars_Toggle()
    end)

    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("BOTTOM", f, "BOTTOM", 0, PAD)
    f.RefreshBindingHint = function(self)
        local key1, key2 = GetToggleBindingKeys()
        hint:SetText(FormatBindingHint(key1, key2))
    end
    f:RefreshBindingHint()

    return f
end

local function ToggleUI()
    if not uiPanel then uiPanel = BuildUI() end

    if uiPanel:IsShown() then
        uiPanel:Hide()
    else
        for _, bar in ipairs(BARS) do
            if cbMap[bar.name] then
                cbMap[bar.name]:SetChecked(IsSelected(bar.name))
            end
        end
        uiPanel:RefreshStatus()
        if uiPanel.RefreshBindingHint then uiPanel:RefreshBindingHint() end
        uiPanel:Show()
    end
end

-- ============================================================
-- EVENTS
-- ============================================================

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("UPDATE_BINDINGS")

ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        InitDB()
        print("hActionBars: initialized (addon name matched: " .. tostring(ADDON_NAME) .. ")")
       
    elseif event == "PLAYER_ENTERING_WORLD" then
        RefreshBindingHintUI()
        ApplyAll()

    elseif event == "PLAYER_REGEN_ENABLED" then
        ApplyAll()

    elseif event == "UPDATE_BINDINGS" then
        RefreshBindingHintUI()
    end
end)

-- ============================================================
-- SLASH COMMANDS
-- ============================================================

SLASH_HACTIONBARS1 = "/hab"
SLASH_HACTIONBARS2 = "/hactionbars"

SlashCmdList["HACTIONBARS"] = function(msg)
    msg = strtrim(msg):lower()

    if msg == "" then
        ToggleUI()

    elseif msg == "toggle" then
        hActionBars_Toggle()

    elseif msg == "show" then
        hActionBarsDB.hidden = false
        ApplyAll()
        if uiPanel and uiPanel.RefreshStatus then uiPanel:RefreshStatus() end
        print("|cFF44FF44hActionBars:|r Bars shown.")

    elseif msg == "hide" then
        hActionBarsDB.hidden = true
        ApplyAll()
        if uiPanel and uiPanel.RefreshStatus then uiPanel:RefreshStatus() end
        print("|cFF44FF44hActionBars:|r Bars hidden.")

    elseif msg == "reset" then
        hActionBarsDB = { selected = {}, hidden = false }
        InitDB()
        ApplyAll()
        if uiPanel and uiPanel.RefreshStatus then uiPanel:RefreshStatus() end
        print("|cFF44FF44hActionBars:|r Settings reset.")
        
    else
        print("|cFF44FF44hActionBars|r commands:")
        print("  |cFFFFFF00/hab|r            Open config panel")
        print("  |cFFFFFF00/hab toggle|r      Toggle bars on/off")
        print("  |cFFFFFF00/hab show|r        Force show selected bars")
        print("  |cFFFFFF00/hab hide|r        Force hide selected bars")
        print("  |cFFFFFF00/hab reset|r       Reset all settings")
    end
end
