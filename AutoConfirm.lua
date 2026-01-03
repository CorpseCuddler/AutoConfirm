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
    if AutoConfirmDB.autoAcceptQuests == nil then
        AutoConfirmDB.autoAcceptQuests = false
    end
    if AutoConfirmDB.autoTurnInQuests == nil then
        AutoConfirmDB.autoTurnInQuests = false
    end
    settings = AutoConfirmDB
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("GOSSIP_SHOW")
frame:RegisterEvent("QUEST_GREETING")
frame:RegisterEvent("QUEST_DETAIL")
frame:RegisterEvent("QUEST_COMPLETE")

local function FindPopupByWhich(which)
    for i = 1, 4 do
        local dlg = _G["StaticPopup" .. i]
        if dlg and dlg:IsShown() and dlg.which == which then
            return dlg
        end
    end
    return nil
end

local function IsLootPopup(popupWhich)
    if popupWhich == "CONFIRM_LOOT_SLOT" or popupWhich == "LOOT_BIND" then
        return true
    end
    local dialog = StaticPopupDialogs and StaticPopupDialogs[popupWhich]
    if not dialog then
        return false
    end
    if dialog.OnAccept == ConfirmLootSlot then
        return true
    end
    local confirmDialog = StaticPopupDialogs.CONFIRM_LOOT_SLOT
    local lootBindDialog = StaticPopupDialogs.LOOT_BIND
    if confirmDialog and dialog.OnAccept == confirmDialog.OnAccept then
        return true
    end
    if lootBindDialog and dialog.OnAccept == lootBindDialog.OnAccept then
        return true
    end
    return false
end

local function NormalizePopupWhich(which, dlg)
    if IsLootPopup(which) then
        return "LOOT_BIND_ANY"
    end
    return which
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
        return
    end

    if not settings then
        return
    end

    if (event == "GOSSIP_SHOW" or event == "QUEST_GREETING" or event == "QUEST_DETAIL" or event == "QUEST_COMPLETE") and IsShiftKeyDown() then
        return
    end

    local autoAccept = settings.autoAcceptQuests == true
    local autoTurnIn = settings.autoTurnInQuests == true

    if event == "GOSSIP_SHOW" then
        if autoTurnIn then
            for i = 1, GetNumGossipActiveQuests() do
                SelectGossipActiveQuest(i)
            end
        end
        if autoAccept then
            for i = 1, GetNumGossipAvailableQuests() do
                SelectGossipAvailableQuest(i)
            end
        end
        return
    end

    if event == "QUEST_GREETING" then
        if autoTurnIn then
            for i = 1, GetNumActiveQuests() do
                SelectActiveQuest(i)
            end
        end
        if autoAccept then
            for i = 1, GetNumAvailableQuests() do
                SelectAvailableQuest(i)
            end
        end
        return
    end

    if event == "QUEST_DETAIL" then
        if autoAccept then
            AcceptQuest()
        end
        return
    end

    if event == "QUEST_COMPLETE" then
        if autoTurnIn and GetNumQuestChoices() == 0 then
            GetQuestReward(1)
        end
        return
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

    local function GetLootSlot(dialogFrame)
        if not dialogFrame then
            return nil
        end
        local data = dialogFrame.data
        if type(data) == "table" then
            data = data.slot
        end
        if type(data) ~= "number" or data <= 0 then
            return nil
        end
        return data
    end

    if IsLootPopup(which) and not GetLootSlot(dlg) then
        return
    end

    local normalizedWhich = NormalizePopupWhich(which, dlg)

    if ShouldAutoConfirm(normalizedWhich) then
        ClickPopupButton(dlg, 1)
        return
    end

    if ShouldAutoDeny(normalizedWhich) then
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

    local normalizedWhich = NormalizePopupWhich(dlg.which, dlg)

    if self == _G[dlg:GetName() .. "Button1"] then
        SaveSelection(normalizedWhich, settings.alwaysConfirm, settings.alwaysDeny)
        AutoConfirmUI_Refresh()
        print(addonName .. ": Always confirm saved for " .. normalizedWhich)
        return
    end

    if self == _G[dlg:GetName() .. "Button2"] then
        SaveSelection(normalizedWhich, settings.alwaysDeny, settings.alwaysConfirm)
        AutoConfirmUI_Refresh()
        print(addonName .. ": Always deny saved for " .. normalizedWhich)
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

-- Quest reward vendor value indicator
local vendorOverlayFrame = CreateFrame("Frame")
vendorOverlayFrame:RegisterEvent("QUEST_COMPLETE")
vendorOverlayFrame:RegisterEvent("QUEST_FINISHED")

local pendingVendorUpdate = false
local UpdateBestVendorChoice

local function GetRewardButtonIcon(button)
    if not button then
        return nil
    end
    return button.icon or button.Icon or button.IconTexture
end

local function EnsureBestVendorIcon(button, itemIcon)
    if not button or not itemIcon then
        return nil
    end

    if not button.AutoConfirmBestVendorIcon then
        local icon = button:CreateTexture(nil, "OVERLAY")
        icon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
        icon:SetSize(16, 16)
        icon:SetPoint("BOTTOMLEFT", itemIcon, "BOTTOMLEFT", 0, 0)
        button.AutoConfirmBestVendorIcon = icon
    end

    return button.AutoConfirmBestVendorIcon
end

local function ClearBestVendorIcons()
    local numChoices = GetNumQuestChoices() or 0
    local maxButtons = numChoices

    if QuestInfoRewardsFrame and QuestInfoRewardsFrame.RewardButtons then
        maxButtons = math.max(maxButtons, #QuestInfoRewardsFrame.RewardButtons)
    end

    for i = 1, maxButtons do
        local button = QuestInfo_GetRewardButton("choice", i)
        if button and button.AutoConfirmBestVendorIcon then
            button.AutoConfirmBestVendorIcon:Hide()
        end
    end
end

local function ScheduleVendorRetry()
    if pendingVendorUpdate then
        return
    end
    pendingVendorUpdate = true
    C_Timer.After(0.2, function()
        pendingVendorUpdate = false
        UpdateBestVendorChoice()
    end)
end

function UpdateBestVendorChoice()
    local numChoices = GetNumQuestChoices() or 0
    if numChoices <= 1 then
        ClearBestVendorIcons()
        return
    end

    local bestIndex
    local bestValue

    for i = 1, numChoices do
        local _, _, numItems, _, _, itemID = GetQuestItemInfo("choice", i)
        if not itemID then
            ScheduleVendorRetry()
            return
        end

        local _, _, _, _, _, _, _, _, _, _, sellPrice = GetItemInfo(itemID)
        if not sellPrice then
            ScheduleVendorRetry()
            return
        end

        local totalValue = sellPrice * (numItems or 1)
        if not bestValue or totalValue > bestValue then
            bestValue = totalValue
            bestIndex = i
        end
    end

    if not bestIndex then
        ClearBestVendorIcons()
        return
    end

    for i = 1, numChoices do
        local button = QuestInfo_GetRewardButton("choice", i)
        if button then
            local itemIcon = GetRewardButtonIcon(button)
            local coinIcon = EnsureBestVendorIcon(button, itemIcon)
            if coinIcon then
                if i == bestIndex then
                    coinIcon:Show()
                else
                    coinIcon:Hide()
                end
            end
        end
    end
end

vendorOverlayFrame:SetScript("OnEvent", function(_, event)
    if event == "QUEST_COMPLETE" then
        UpdateBestVendorChoice()
    elseif event == "QUEST_FINISHED" then
        ClearBestVendorIcons()
    end
end)

if QuestInfoRewardsFrame then
    QuestInfoRewardsFrame:HookScript("OnHide", ClearBestVendorIcons)
end

-- UI
local optionsPanel = CreateFrame("Frame", "AutoConfirmOptions", UIParent)
optionsPanel.name = "AutoConfirm"

local title = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("AutoConfirm")

local description = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
description:SetText("Right-click popup buttons to save always-confirm or always-deny rules.")

local shiftOverride = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
shiftOverride:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -6)
shiftOverride:SetText("Hold Shift while opening quest dialogs to bypass auto-accept and auto turn-in.")

local autoAcceptCheckbox = CreateFrame("CheckButton", "AutoConfirmAutoAcceptQuests", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
autoAcceptCheckbox:SetPoint("TOPLEFT", shiftOverride, "BOTTOMLEFT", 0, -8)
local autoAcceptLabel = autoAcceptCheckbox.Text or _G[autoAcceptCheckbox:GetName() .. "Text"]
if not autoAcceptLabel and autoAcceptCheckbox.text then
    autoAcceptLabel = autoAcceptCheckbox.text
end
if autoAcceptLabel and autoAcceptLabel.SetText then
    autoAcceptLabel:SetText("Auto-accept available quests")
end
autoAcceptCheckbox:SetScript("OnClick", function(self)
    if not settings then
        return
    end
    settings.autoAcceptQuests = self:GetChecked() == true
end)

local autoTurnInCheckbox = CreateFrame("CheckButton", "AutoConfirmAutoTurnInQuests", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
autoTurnInCheckbox:SetPoint("TOPLEFT", autoAcceptCheckbox, "BOTTOMLEFT", 0, -6)
local autoTurnInLabel = autoTurnInCheckbox.Text or _G[autoTurnInCheckbox:GetName() .. "Text"]
if not autoTurnInLabel and autoTurnInCheckbox.text then
    autoTurnInLabel = autoTurnInCheckbox.text
end
if autoTurnInLabel and autoTurnInLabel.SetText then
    autoTurnInLabel:SetText("Auto turn-in completed quests")
end
autoTurnInCheckbox:SetScript("OnClick", function(self)
    if not settings then
        return
    end
    settings.autoTurnInQuests = self:GetChecked() == true
end)

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

local confirmPanel = CreateListPanel("AutoConfirmConfirmPanel", "Always Confirm", autoTurnInCheckbox, 0)
local denyPanel = CreateListPanel("AutoConfirmDenyPanel", "Always Deny", autoTurnInCheckbox, 280)

local function ClearPanelEntries(panel)
    for _, entry in ipairs(panel.entries) do
        entry:Hide()
        entry:SetParent(nil)
    end
    panel.entries = {}
end

local function CreateEntry(panel, which, labelText, yOffset, onDelete)
    local entry = CreateFrame("Frame", nil, panel)
    entry:SetSize(240, 20)
    entry:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, yOffset)

    local label = entry:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", entry, "LEFT", 0, 0)
    label:SetText(labelText or which)

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

local function GetDisplayLabel(which)
    if which == "LOOT_BIND_ANY" then
        return "Loot Bind (all)"
    end
    return which
end

function AutoConfirmUI_Refresh()
    if not settings then
        return
    end

    autoAcceptCheckbox:SetChecked(settings.autoAcceptQuests)
    autoTurnInCheckbox:SetChecked(settings.autoTurnInQuests)

    ClearPanelEntries(confirmPanel)
    ClearPanelEntries(denyPanel)

    local confirmKeys = SortedKeys(settings.alwaysConfirm)
    local denyKeys = SortedKeys(settings.alwaysDeny)

    local y = -32
    for _, which in ipairs(confirmKeys) do
        CreateEntry(confirmPanel, which, GetDisplayLabel(which), y, function(entryWhich)
            settings.alwaysConfirm[entryWhich] = nil
            AutoConfirmUI_Refresh()
        end)
        y = y - 22
    end

    y = -32
    for _, which in ipairs(denyKeys) do
        CreateEntry(denyPanel, which, GetDisplayLabel(which), y, function(entryWhich)
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
