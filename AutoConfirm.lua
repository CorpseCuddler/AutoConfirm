-- AutoConfirm.lua
local addonName = "AutoConfirm"
local frame = CreateFrame("Frame")

local settings

local function InitializeSavedVariables()
    if type(AutoConfirmDB) ~= "table" then
        AutoConfirmDB = {}
    end
    AutoConfirmDB.alwaysConfirm = AutoConfirmDB.alwaysConfirm or {}
    AutoConfirmDB.alwaysDeny = AutoConfirmDB.alwaysDeny or {}
    settings = AutoConfirmDB
end

frame:RegisterEvent("ADDON_LOADED")

local function FindPopupByWhich(which)
    for i = 1, 4 do
        local dlg = _G["StaticPopup" .. i]
        if dlg and dlg:IsShown() and dlg.which == which then
            return dlg
        end
    end
    return nil
end

local function ClickPopupButton(dlg, buttonIndex)
    if not dlg then
        return false
    end
    local button = _G[dlg:GetName() .. "Button" .. buttonIndex]
    if button and button:IsEnabled() then
        button:Click()
        return true
    end
    return false
end

local function RemoveFromList(list, which)
    if list[which] then
        list[which] = nil
        return true
    end
    return false
end

local function SaveSelection(which, listToAdd, listToRemove)
    if not which then
        return
    end
    listToAdd[which] = true
    RemoveFromList(listToRemove, which)
end

local function ShouldAutoConfirm(which)
    return settings.alwaysConfirm[which]
end

local function ShouldAutoDeny(which)
    return settings.alwaysDeny[which]
end

frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            InitializeSavedVariables()
        end
    end
end)

hooksecurefunc("StaticPopup_Show", function(which)
    if not settings then
        return
    end

    if not which then
        return
    end

    local dlg = FindPopupByWhich(which)
    if not dlg then
        return
    end

    if ShouldAutoConfirm(which) then
        ClickPopupButton(dlg, 1)
        return
    end

    if ShouldAutoDeny(which) then
        ClickPopupButton(dlg, 2)
    end
end)

local function OnPopupButtonClick(self, button)
    if button ~= "RightButton" then
        return
    end

    if not settings then
        return
    end

    local dlg = self:GetParent()
    if not dlg or not dlg.which then
        return
    end

    if self == _G[dlg:GetName() .. "Button1"] then
        SaveSelection(dlg.which, settings.alwaysConfirm, settings.alwaysDeny)
        AutoConfirmUI_Refresh()
        print(addonName .. ": Always confirm saved for " .. dlg.which)
        return
    end

    if self == _G[dlg:GetName() .. "Button2"] then
        SaveSelection(dlg.which, settings.alwaysDeny, settings.alwaysConfirm)
        AutoConfirmUI_Refresh()
        print(addonName .. ": Always deny saved for " .. dlg.which)
    end
end

local function HookPopupButtons()
    for i = 1, 4 do
        local dlg = _G["StaticPopup" .. i]
        if dlg then
            local btn1 = _G[dlg:GetName() .. "Button1"]
            local btn2 = _G[dlg:GetName() .. "Button2"]
            if btn1 then
                btn1:RegisterForClicks("AnyUp")
                btn1:HookScript("OnClick", OnPopupButtonClick)
            end
            if btn2 then
                btn2:RegisterForClicks("AnyUp")
                btn2:HookScript("OnClick", OnPopupButtonClick)
            end
        end
    end
end

HookPopupButtons()

-- UI
local optionsPanel = CreateFrame("Frame", "AutoConfirmOptions", UIParent)
optionsPanel.name = "AutoConfirm"

local title = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("AutoConfirm")

local description = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
description:SetText("Right-click popup buttons to save always-confirm or always-deny rules.")

local function CreateListPanel(name, label, anchor, offsetX)
    local panel = CreateFrame("Frame", name, optionsPanel)
    panel:SetSize(260, 380)
    panel:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", offsetX, -12)

    local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetPoint("TOPLEFT", 8, -8)
    header:SetText(label)

    panel.entries = {}

    return panel
end

local confirmPanel = CreateListPanel("AutoConfirmConfirmPanel", "Always Confirm", description, 0)
local denyPanel = CreateListPanel("AutoConfirmDenyPanel", "Always Deny", description, 280)

local function ClearPanelEntries(panel)
    for _, entry in ipairs(panel.entries) do
        entry:Hide()
        entry:SetParent(nil)
    end
    panel.entries = {}
end

local function CreateEntry(panel, which, yOffset, onDelete)
    local entry = CreateFrame("Frame", nil, panel)
    entry:SetSize(240, 20)
    entry:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, yOffset)

    local label = entry:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", entry, "LEFT", 0, 0)
    label:SetText(which)

    local deleteButton = CreateFrame("Button", nil, entry, "UIPanelCloseButton")
    deleteButton:SetSize(18, 18)
    deleteButton:SetPoint("RIGHT", entry, "RIGHT", 0, 0)
    deleteButton:SetScript("OnClick", function()
        onDelete(which)
    end)

    table.insert(panel.entries, entry)
end

local function SortedKeys(list)
    local keys = {}
    for key in pairs(list) do
        table.insert(keys, key)
    end
    table.sort(keys)
    return keys
end

function AutoConfirmUI_Refresh()
    if not settings then
        return
    end

    ClearPanelEntries(confirmPanel)
    ClearPanelEntries(denyPanel)

    local confirmKeys = SortedKeys(settings.alwaysConfirm)
    local denyKeys = SortedKeys(settings.alwaysDeny)

    local y = -32
    for _, which in ipairs(confirmKeys) do
        CreateEntry(confirmPanel, which, y, function(entryWhich)
            settings.alwaysConfirm[entryWhich] = nil
            AutoConfirmUI_Refresh()
        end)
        y = y - 22
    end

    y = -32
    for _, which in ipairs(denyKeys) do
        CreateEntry(denyPanel, which, y, function(entryWhich)
            settings.alwaysDeny[entryWhich] = nil
            AutoConfirmUI_Refresh()
        end)
        y = y - 22
    end
end

optionsPanel:SetScript("OnShow", AutoConfirmUI_Refresh)
InterfaceOptions_AddCategory(optionsPanel)

local function ToggleOptions()
    InterfaceOptionsFrame_OpenToCategory(optionsPanel)
    InterfaceOptionsFrame_OpenToCategory(optionsPanel)
end

SLASH_AUTOCONFIRM1 = "/autoconfirm"
SLASH_AUTOCONFIRM2 = "/ac"
SlashCmdList["AUTOCONFIRM"] = function()
    ToggleOptions()
end

print(addonName .. " loaded - Right-click popup buttons to save rules. /ac to manage.")
