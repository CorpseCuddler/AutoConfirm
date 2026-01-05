
local function GetLootSlotSafe(dlg)
    if not dlg then return nil end
    local data = dlg.data
    if type(data) == "table" then data = data.slot end
    if type(data) ~= "number" or data <= 0 then return nil end
    return data
end


local function GetPopupText(dlg)
    if not dlg then return nil end

    -- dlg.text is typically a FontString on 3.3.5a StaticPopup frames
    if dlg.text and dlg.text.GetText then
        local t = dlg.text:GetText()
        if type(t) == "string" and t ~= "" then
            return t
        end
    elseif type(dlg.text) == "string" and dlg.text ~= "" then
        return dlg.text
    end

    local fs = _G[dlg:GetName() .. "Text"]
    if fs and fs.GetText then
        return fs:GetText()
    end
    return nil
end

local function ExtractConfirmToken(popupText)
    if type(popupText) ~= "string" then return nil end
    -- Common patterns like: Type "DELETE" into the field to confirm.
    local token = popupText:match('Type%s+"([^"]+)"')
    if token then return token end
    token = popupText:match("Type%s+'([^']+)'")
    if token then return token end
    token = popupText:match('Type%s+“([^”]+)”')
    return token
end

local function FindPopupEditBox(dlg)
    if not dlg then return nil end

    local eb = dlg.editBox
    if eb and eb.SetText then
        return eb
    end

    eb = _G[dlg:GetName() .. "EditBox"]
    if eb and eb.SetText then
        return eb
    end

    if dlg.GetChildren then
        local kids = { dlg:GetChildren() }
        for _, child in ipairs(kids) do
            if child and child.GetObjectType and child:GetObjectType() == "EditBox" then
                return child
            end
            -- Some templates don't report object type; fall back to method presence
            if child and child.SetText and child.GetText and child.HighlightText then
                return child
            end
        end
    end

    return nil
end


local function AutoFillDeleteConfirmText(dlg, rawWhich, noQueue)
    if not settings or not settings.autoDeleteGoodItems then
        return true
    end
    if not dlg then return end
    local editBox = FindPopupEditBox(dlg)
    if not (editBox and editBox.SetText) then
        return false
    end

    -- Only fill if it's currently empty (avoid clobbering user input)
    local current = (editBox.GetText and editBox:GetText()) or ""
    if current and current:gsub("%s+", "") ~= "" then
        return true
    end

    local token = nil
    if rawWhich == "DELETE_GOOD_ITEM" then
        token = _G.DELETE_ITEM_CONFIRM_STRING or "DELETE"
    end
    if not token then
        token = ExtractConfirmToken(GetPopupText(dlg))
    end
    if not token or token == "" then
        if not noQueue and dlg and dlg.IsShown and dlg:IsShown() then
            pendingDeleteFills[dlg] = { which = rawWhich, wait = 0, delay = 0.05, timeout = 2.0 }
            pendingClickTicker:Show()
        end
        return false
    end

if token and token ~= "" then
        editBox:SetText(token)
        if editBox.HighlightText then
            editBox:HighlightText()
        end
        return true
    end
    return false
end



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
    if AutoConfirmDB.autoDeleteGoodItems == nil then
        AutoConfirmDB.autoDeleteGoodItems = false
    end
    settings = AutoConfirmDB
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("GOSSIP_SHOW")
frame:RegisterEvent("QUEST_GREETING")
frame:RegisterEvent("QUEST_DETAIL")
frame:RegisterEvent("QUEST_PROGRESS")
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

local pendingPopupClicks = pendingPopupClicks or {}
local pendingDeleteFills = pendingDeleteFills or {}
local pendingClickTicker = pendingClickTicker or CreateFrame("Frame")
pendingClickTicker:Hide()
pendingClickTicker:SetScript("OnUpdate", function(_, elapsed)
    -- Process any queued popup clicks. This is mainly needed for CONFIRM_LOOT_SLOT,
    -- where dlg.data (the slot index) can be populated slightly after StaticPopup_Show.
    local any = false

    -- Process pending delete-confirm autofills (wait until popup text is populated)
    for dlg, info in pairs(pendingDeleteFills) do
        any = true
        if not dlg or not dlg.IsShown or not dlg:IsShown() then
            pendingDeleteFills[dlg] = nil
        else
            info.wait = info.wait + elapsed
            if info.wait >= info.delay then
                info.wait = 0
                info.timeout = (info.timeout or 2.0) - info.delay
                local ok = AutoFillDeleteConfirmText(dlg, info.which, true)
                if ok or (info.timeout <= 0) then
                    pendingDeleteFills[dlg] = nil
                end
            end
        end
    end

    for dlg, info in pairs(pendingPopupClicks) do
        any = true
        if not dlg or not dlg.IsShown or not dlg:IsShown() then
            pendingPopupClicks[dlg] = nil
        else
            info.wait = info.wait + elapsed
            if info.wait >= info.delay then
                -- For loot-slot confirmation popups, only click once dlg.data (slot) is available.
                if not info.needsSlot or GetLootSlotSafe(dlg) then
                    pendingPopupClicks[dlg] = nil
                    local button = _G[dlg:GetName() .. "Button" .. info.buttonIndex]
                    if button and button:IsEnabled() then
                        button:Click()
                    end
                end
            end
        end
    end
    if not any then
        pendingClickTicker:Hide()
    end
end)

local function QueuePopupClick(dlg, buttonIndex)
    if not dlg then return false end
    local needsSlot = IsLootPopup and IsLootPopup(dlg.which)
    if needsSlot and not GetLootSlotSafe(dlg) then
        pendingPopupClicks[dlg] = { buttonIndex = buttonIndex, wait = 0, delay = 0.05, needsSlot = true }
        pendingClickTicker:Show()
        return true
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

-- Some popups (notably loot binding) can vary across clients/servers. We treat
-- certain popups as equivalent by checking both the raw and normalized keys.
local function ListHas(list, which, normalizedWhich)
    if not list or not which then
        return false
    end
    if list[which] then
        return true
    end
    if normalizedWhich and list[normalizedWhich] then
        return true
    end
    return false
end

local function ShouldAutoConfirm(which, normalizedWhich)
    return ListHas(settings.alwaysConfirm, which, normalizedWhich)
end

local function ShouldAutoDeny(which, normalizedWhich)
    return ListHas(settings.alwaysDeny, which, normalizedWhich)
end

-- (legacy single-key helpers removed; use the normalized-aware variants above)

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


    if event == "QUEST_PROGRESS" then
        if autoTurnIn and IsQuestCompletable() then
            CompleteQuest()
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


    AutoFillDeleteConfirmText(dlg, which)

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

    local normalizedWhich = NormalizePopupWhich(which, dlg)
    if IsLootPopup(which) and not GetLootSlot(dlg) then
        if not (ShouldAutoConfirm(which, normalizedWhich) or ShouldAutoDeny(which, normalizedWhich)) then
            return
        end
    end

    if ShouldAutoConfirm(which, normalizedWhich) then
        QueuePopupClick(dlg, 1)
        return
    end

    if ShouldAutoDeny(which, normalizedWhich) then
        QueuePopupClick(dlg, 2)
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

    local rawWhich = dlg.which
    local normalizedWhich = NormalizePopupWhich(rawWhich, dlg)
    -- Auto-fill handled on popup show (StaticPopup_Show hook)


    if self == _G[dlg:GetName() .. "Button1"] then
        -- Store loot confirmations under a single normalized key to avoid duplicate UI entries.
        SaveSelection(normalizedWhich, settings.alwaysConfirm, settings.alwaysDeny)
        if normalizedWhich ~= rawWhich then
            RemoveFromList(settings.alwaysConfirm, rawWhich)
            RemoveFromList(settings.alwaysDeny, rawWhich)
        end
        AutoConfirmUI_Refresh()
        print(addonName .. ": Always confirm saved for " .. normalizedWhich)
        return
    end

    if self == _G[dlg:GetName() .. "Button2"] then
        SaveSelection(normalizedWhich, settings.alwaysDeny, settings.alwaysConfirm)
        if normalizedWhich ~= rawWhich then
            RemoveFromList(settings.alwaysConfirm, rawWhich)
            RemoveFromList(settings.alwaysDeny, rawWhich)
        end
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

    -- Common fields across clients/templates
    local icon = button.icon or button.Icon or button.IconTexture
    if icon then
        return icon
    end

    -- 3.3.5a QuestInfoItemTemplate commonly uses a named region: <ButtonName>IconTexture
    if button.GetName then
        local name = button:GetName()
        if name then
            icon = _G[name .. "IconTexture"] or _G[name .. "Icon"] or _G[name .. "IconTex"]
            if icon then
                return icon
            end
        end
    end

    -- Last fallback: sometimes the normal texture is the icon
    if button.GetNormalTexture then
        icon = button:GetNormalTexture()
        if icon then
            return icon
        end
    end

    return nil
end


local function EnsureBestVendorIcon(button, itemIcon)
    if not button then
        return nil
    end

    if not button.AutoConfirmBestVendorIcon then
        local icon = button:CreateTexture(nil, "OVERLAY")
        icon:SetTexture([[Interface\Buttons\UI-GroupLoot-Coin-Up]])
        icon:SetSize(18, 18)
        icon:SetDrawLayer("OVERLAY", 7)

        -- Prefer anchoring to the actual item icon region, otherwise anchor to the button.
        if itemIcon and icon.SetPoint then
            icon:SetPoint("TOPRIGHT", itemIcon, "TOPRIGHT", -2, -2)
        else
            icon:SetPoint("TOPRIGHT", button, "TOPRIGHT", -4, -4)
        end

        button.AutoConfirmBestVendorIcon = icon
    else
        -- If we created it before without an icon region, and we now have one, re-anchor.
        if itemIcon and button.AutoConfirmBestVendorIcon.ClearAllPoints then
            button.AutoConfirmBestVendorIcon:ClearAllPoints()
            button.AutoConfirmBestVendorIcon:SetPoint("TOPRIGHT", itemIcon, "TOPRIGHT", -2, -2)
        end
    end

    return button.AutoConfirmBestVendorIcon
end


-- 3.3.5a compatibility: some clients don't provide QuestInfo_GetRewardButton
local function AutoConfirm_GetRewardButton(rewardType, index)
    -- Prefer Blizzard's helper if available
    if type(QuestInfo_GetRewardButton) == "function" then
        return QuestInfo_GetRewardButton(rewardType, index)
    end

    -- Newer templates often store buttons here
    if QuestInfoRewardsFrame and QuestInfoRewardsFrame.RewardButtons then
        return QuestInfoRewardsFrame.RewardButtons[index]
    end

    -- Fallback globals (varies by client/template)
    local candidates = {
        _G["QuestInfoReward" .. index],
        _G["QuestInfoRewardsFrameReward" .. index],
        _G["QuestInfoItem" .. index],
    }
    for _, btn in ipairs(candidates) do
        if btn then
            return btn
        end
    end

    -- Last resort: scan children for matching ID (3.3.5a-safe)
    if QuestInfoRewardsFrame and QuestInfoRewardsFrame.GetChildren then
        local kids = { QuestInfoRewardsFrame:GetChildren() }
        for _, child in ipairs(kids) do
            if child and child.GetID and child:GetID() == index then
                return child
            end
        end
    end

    return nil
end

local function ClearBestVendorIcons()
    local numChoices = GetNumQuestChoices() or 0
    local maxButtons = numChoices

    if QuestInfoRewardsFrame and QuestInfoRewardsFrame.RewardButtons then
        maxButtons = math.max(maxButtons, #QuestInfoRewardsFrame.RewardButtons)
    end

    for i = 1, maxButtons do
        local button = AutoConfirm_GetRewardButton("choice", i)
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
        local _, _, numItems = GetQuestItemInfo("choice", i)

        -- 3.3.5a compatibility: GetQuestItemInfo doesn't always return itemID.
        local itemID = select(6, GetQuestItemInfo("choice", i))
        if not itemID then
            local link = GetQuestItemLink("choice", i)
            if link then
                itemID = tonumber(string.match(link, "item:(%d+)"))
            end
        end

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
        local button = AutoConfirm_GetRewardButton("choice", i)
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
    settings.autoAcceptQuests = not not self:GetChecked()
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
    settings.autoTurnInQuests = not not self:GetChecked()
end)


local autoDeleteGoodItemsCheckbox = CreateFrame("CheckButton", "AutoConfirmAutoDeleteGoodItems", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
autoDeleteGoodItemsCheckbox:SetPoint("TOPLEFT", autoTurnInCheckbox, "BOTTOMLEFT", 0, -6)
local autoDeleteGoodItemsLabel = autoDeleteGoodItemsCheckbox.Text or _G[autoDeleteGoodItemsCheckbox:GetName() .. "Text"]
if not autoDeleteGoodItemsLabel and autoDeleteGoodItemsCheckbox.text then
    autoDeleteGoodItemsLabel = autoDeleteGoodItemsCheckbox.text
end
if autoDeleteGoodItemsLabel and autoDeleteGoodItemsLabel.SetText then
    autoDeleteGoodItemsLabel:SetText("Auto-fill DELETE when deleting high-quality items")
end
autoDeleteGoodItemsCheckbox.tooltipText = "When enabled, the addon will auto-fill the confirmation text (e.g. DELETE) for the 'This item is high quality' delete confirmation popup. It will NOT auto-click."
autoDeleteGoodItemsCheckbox:SetScript("OnClick", function(self)
    if not settings then
        return
    end
    settings.autoDeleteGoodItems = not not self:GetChecked()
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
    if which == "LOOT_BIND" then
        return "Loot Bind"
    end
    return which
end

function AutoConfirmUI_Refresh()
    if not settings then
        return
    end

    autoAcceptCheckbox:SetChecked(settings.autoAcceptQuests)
    autoTurnInCheckbox:SetChecked(settings.autoTurnInQuests)

    if autoDeleteGoodItemsCheckbox then
        autoDeleteGoodItemsCheckbox:SetChecked(settings.autoDeleteGoodItems)
    end
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
