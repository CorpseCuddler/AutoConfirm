-- AutoConfirm.lua
local addonName = "AutoConfirm"
local frame = CreateFrame("Frame")

-- Settings
local defaultSettings = {
    autoLoot = true,
    autoAbandonQuest = false,
    autoQuestComplete = false,
    autoDelete = true,
    autoDeleteQuestItems = true,
    autoEquipConfirm = true,
    autoEnchantReplace = true,
    autoPartyInvite = false,
    partyInviteFriendsOnly = true,
    requireShiftAutoLoot = false,
    requireShiftAutoAbandonQuest = false,
    requireShiftAutoQuestComplete = false,
    requireShiftAutoDelete = false,
    requireShiftAutoDeleteQuestItems = false,
    requireShiftAutoEquipConfirm = false,
    requireShiftAutoEnchantReplace = false,
    requireShiftAutoPartyInvite = false
}

local settings

local function InitializeSavedVariables()
    if type(AutoConfirmDB) ~= "table" then
        AutoConfirmDB = {}
    end

    for key, value in pairs(defaultSettings) do
        if AutoConfirmDB[key] == nil then
            AutoConfirmDB[key] = value
        end
    end

    if AutoConfirmDB.autoEquipConfirm == nil and AutoConfirmDB.autoConfirmEquip ~= nil then
        AutoConfirmDB.autoEquipConfirm = AutoConfirmDB.autoConfirmEquip
    end

    if AutoConfirmDB.autoEnchantReplace == nil and AutoConfirmDB.autoConfirmEnchant ~= nil then
        AutoConfirmDB.autoEnchantReplace = AutoConfirmDB.autoConfirmEnchant
    end

    settings = AutoConfirmDB
end

-- Auto-confirm soulbound item loots
frame:RegisterEvent("LOOT_BIND_CONFIRM")
frame:RegisterEvent("CONFIRM_ENCHANT_REPLACE")
frame:RegisterEvent("EQUIP_BIND_CONFIRM")
frame:RegisterEvent("AUTOEQUIP_BIND_CONFIRM")
frame:RegisterEvent("ADDON_LOADED")

local questDeletePopups = {
    DELETE_QUEST_ITEM = true,
    DELETE_QUEST_ITEM_CONFIRM = true
}

local function IsShiftConditionMet(requireShift)
    return not requireShift or IsShiftKeyDown()
end

-- Auto-fill DELETE confirmation and click accept
local function AutoFillDelete(which, isEnabled, requireShift, confirmText)
    if not isEnabled then
        return
    end

    if not IsShiftConditionMet(requireShift) then
        return
    end

    if StaticPopup1EditBox and StaticPopup1EditBox:IsVisible() then
        local dialog = StaticPopup1
        if dialog and dialog.which == which then
            StaticPopup1EditBox:SetText(confirmText)
            -- Small delay to ensure the text is set before clicking
            C_Timer.After(0.1, function()
                if StaticPopup1Button1:IsEnabled() then
                    StaticPopup1Button1:Click()
                end
            end)
        end
    end
end

local function IsFriendByName(name)
    if not name then
        return false
    end

    if C_FriendList and C_FriendList.IsFriend then
        return C_FriendList.IsFriend(name)
    end

    if GetNumFriends and GetFriendInfo then
        local totalFriends = GetNumFriends()
        for i = 1, totalFriends do
            local friendName = GetFriendInfo(i)
            if friendName == name then
                return true
            end
        end
    end

    return false
end

local function AutoConfirmStaticPopup(which)
    if which == "LOOT_BIND" or which == "LOOT_BIND_CONFIRM" then
        if settings.autoLoot and IsShiftConditionMet(settings.requireShiftAutoLoot) and StaticPopup1Button1 and StaticPopup1Button1:IsEnabled() then
            StaticPopup1Button1:Click()
        end
        return
    end

    if which == "EQUIP_BIND" or which == "EQUIP_BIND_CONFIRM" or which == "AUTOEQUIP_BIND_CONFIRM" then
        if settings.autoEquipConfirm and IsShiftConditionMet(settings.requireShiftAutoEquipConfirm) and StaticPopup1Button1 and StaticPopup1Button1:IsEnabled() then
            StaticPopup1Button1:Click()
        end
        return
    end

    if which == "REPLACE_ENCHANT" or which == "CONFIRM_ENCHANT_REPLACE" then
        if settings.autoEnchantReplace and IsShiftConditionMet(settings.requireShiftAutoEnchantReplace) and StaticPopup1Button1 and StaticPopup1Button1:IsEnabled() then
            StaticPopup1Button1:Click()
        end
        return
    end

    if which == "ABANDON_QUEST" then
        if settings.autoAbandonQuest and IsShiftConditionMet(settings.requireShiftAutoAbandonQuest) and StaticPopup1Button1 and StaticPopup1Button1:IsEnabled() then
            StaticPopup1Button1:Click()
        end
        return
    end

    if which == "QUEST_COMPLETE" then
        if settings.autoQuestComplete and IsShiftConditionMet(settings.requireShiftAutoQuestComplete) and StaticPopup1Button1 and StaticPopup1Button1:IsEnabled() then
            StaticPopup1Button1:Click()
        end
        return
    end

    if which == "PARTY_INVITE" then
        if not settings.autoPartyInvite then
            return
        end

        if not IsShiftConditionMet(settings.requireShiftAutoPartyInvite) then
            return
        end

        if settings.partyInviteFriendsOnly then
            local dialog = StaticPopup1
            local inviterName = dialog and (dialog.data or dialog.data2)
            if not IsFriendByName(inviterName) then
                return
            end
        end

        if StaticPopup1Button1 and StaticPopup1Button1:IsEnabled() then
            StaticPopup1Button1:Click()
        end
    end
end

local function AutoConfirmEnchantReplace()
    if not settings.autoEnchantReplace then
        return
    end

    if not IsShiftConditionMet(settings.requireShiftAutoEnchantReplace) then
        return
    end

    if ConfirmEnchantReplace then
        ConfirmEnchantReplace()
        return
    end

    if StaticPopup1Button1 and StaticPopup1Button1:IsEnabled() then
        StaticPopup1Button1:Click()
    end
end

local function AutoConfirmEquipBind(...)
    if not settings.autoEquipConfirm then
        return
    end

    if not IsShiftConditionMet(settings.requireShiftAutoEquipConfirm) then
        return
    end

    if ConfirmEquipBind then
        ConfirmEquipBind(...)
        return
    end

    if ConfirmBindOnUse then
        ConfirmBindOnUse(...)
        return
    end

    if StaticPopup1Button1 and StaticPopup1Button1:IsEnabled() then
        StaticPopup1Button1:Click()
    end
end

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            InitializeSavedVariables()
        end
        return
    end

    if event == "LOOT_BIND_CONFIRM" then
        if settings.autoLoot and IsShiftConditionMet(settings.requireShiftAutoLoot) then
            local slot = ...
            ConfirmLootSlot(slot)
        end
    elseif event == "CONFIRM_ENCHANT_REPLACE" then
        AutoConfirmEnchantReplace()
    elseif event == "EQUIP_BIND_CONFIRM" then
        AutoConfirmEquipBind(...)
    elseif event == "AUTOEQUIP_BIND_CONFIRM" then
        AutoConfirmEquipBind(...)
    end
end)

-- Hook into StaticPopup to auto-fill delete text and click
hooksecurefunc("StaticPopup_Show", function(which)
    if which == "DELETE_GOOD_ITEM" then
        AutoFillDelete(which, settings.autoDelete, settings.requireShiftAutoDelete, DELETE_ITEM_CONFIRM_STRING)
    elseif questDeletePopups[which] then
        local confirmText = _G.DELETE_QUEST_ITEM_CONFIRM_STRING or _G.DELETE_ITEM_CONFIRM_STRING or "DELETE"
        AutoFillDelete(which, settings.autoDeleteQuestItems, settings.requireShiftAutoDeleteQuestItems, confirmText)
    else
        AutoConfirmStaticPopup(which)
    end
end)

local optionsPanel = CreateFrame("Frame", "AutoConfirmOptions", UIParent)
optionsPanel.name = "AutoConfirm"

local function CreateOptionCheckbox(name, label, settingKey, anchor, offsetY)
    local checkbox = CreateFrame("CheckButton", name, optionsPanel, "InterfaceOptionsCheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY)
    local labelRegion = _G[name .. "Text"] or checkbox.Text or checkbox.text
    if not labelRegion then
        labelRegion = checkbox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        labelRegion:SetPoint("LEFT", checkbox, "RIGHT", 0, 0)
    end
    labelRegion:SetText(label)

    checkbox:SetScript("OnClick", function(self)
        settings[settingKey] = self:GetChecked() and true or false
    end)

    return checkbox
end

local title = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("AutoConfirm")

local description = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
description:SetText("Configure automatic confirmations and deletions.")

local lootCheckbox = CreateOptionCheckbox("AutoConfirmLootCheckbox", "Auto-confirm soulbound loot", "autoLoot", description, -12)
local lootShiftCheckbox = CreateOptionCheckbox("AutoConfirmLootShiftCheckbox", "Require Shift for soulbound loot", "requireShiftAutoLoot", lootCheckbox, -8)
local abandonQuestCheckbox = CreateOptionCheckbox("AutoConfirmAbandonQuestCheckbox", "Auto-confirm abandon quest", "autoAbandonQuest", lootShiftCheckbox, -8)
local abandonQuestShiftCheckbox = CreateOptionCheckbox("AutoConfirmAbandonQuestShiftCheckbox", "Require Shift for abandon quest", "requireShiftAutoAbandonQuest", abandonQuestCheckbox, -8)
local questCompleteCheckbox = CreateOptionCheckbox("AutoConfirmQuestCompleteCheckbox", "Auto-confirm quest complete", "autoQuestComplete", abandonQuestShiftCheckbox, -8)
local questCompleteShiftCheckbox = CreateOptionCheckbox("AutoConfirmQuestCompleteShiftCheckbox", "Require Shift for quest complete", "requireShiftAutoQuestComplete", questCompleteCheckbox, -8)
local deleteCheckbox = CreateOptionCheckbox("AutoConfirmDeleteCheckbox", "Auto-fill DELETE confirmation", "autoDelete", questCompleteShiftCheckbox, -8)
local deleteShiftCheckbox = CreateOptionCheckbox("AutoConfirmDeleteShiftCheckbox", "Require Shift for delete confirmation", "requireShiftAutoDelete", deleteCheckbox, -8)
local questDeleteCheckbox = CreateOptionCheckbox("AutoConfirmQuestDeleteCheckbox", "Auto-delete quest items", "autoDeleteQuestItems", deleteShiftCheckbox, -8)
local questDeleteShiftCheckbox = CreateOptionCheckbox("AutoConfirmQuestDeleteShiftCheckbox", "Require Shift for quest item delete", "requireShiftAutoDeleteQuestItems", questDeleteCheckbox, -8)
local equipCheckbox = CreateOptionCheckbox("AutoConfirmEquipCheckbox", "Auto-confirm equipment binding", "autoEquipConfirm", questDeleteShiftCheckbox, -8)
local equipShiftCheckbox = CreateOptionCheckbox("AutoConfirmEquipShiftCheckbox", "Require Shift for equipment binding", "requireShiftAutoEquipConfirm", equipCheckbox, -8)
local enchantCheckbox = CreateOptionCheckbox("AutoConfirmEnchantCheckbox", "Auto-confirm enchant replacement", "autoEnchantReplace", equipShiftCheckbox, -8)
local enchantShiftCheckbox = CreateOptionCheckbox("AutoConfirmEnchantShiftCheckbox", "Require Shift for enchant replacement", "requireShiftAutoEnchantReplace", enchantCheckbox, -8)
local partyInviteCheckbox = CreateOptionCheckbox("AutoConfirmPartyInviteCheckbox", "Auto-accept party invites", "autoPartyInvite", enchantShiftCheckbox, -8)
local partyInviteFriendsCheckbox = CreateOptionCheckbox("AutoConfirmPartyInviteFriendsCheckbox", "Party invites: friends only", "partyInviteFriendsOnly", partyInviteCheckbox, -8)
local partyInviteShiftCheckbox = CreateOptionCheckbox("AutoConfirmPartyInviteShiftCheckbox", "Require Shift for party invites", "requireShiftAutoPartyInvite", partyInviteFriendsCheckbox, -8)

local function RefreshOptionsPanel()
    if not settings then
        return
    end

    lootCheckbox:SetChecked(settings.autoLoot)
    lootShiftCheckbox:SetChecked(settings.requireShiftAutoLoot)
    abandonQuestCheckbox:SetChecked(settings.autoAbandonQuest)
    abandonQuestShiftCheckbox:SetChecked(settings.requireShiftAutoAbandonQuest)
    questCompleteCheckbox:SetChecked(settings.autoQuestComplete)
    questCompleteShiftCheckbox:SetChecked(settings.requireShiftAutoQuestComplete)
    deleteCheckbox:SetChecked(settings.autoDelete)
    deleteShiftCheckbox:SetChecked(settings.requireShiftAutoDelete)
    questDeleteCheckbox:SetChecked(settings.autoDeleteQuestItems)
    questDeleteShiftCheckbox:SetChecked(settings.requireShiftAutoDeleteQuestItems)
    equipCheckbox:SetChecked(settings.autoEquipConfirm)
    equipShiftCheckbox:SetChecked(settings.requireShiftAutoEquipConfirm)
    enchantCheckbox:SetChecked(settings.autoEnchantReplace)
    enchantShiftCheckbox:SetChecked(settings.requireShiftAutoEnchantReplace)
    partyInviteCheckbox:SetChecked(settings.autoPartyInvite)
    partyInviteFriendsCheckbox:SetChecked(settings.partyInviteFriendsOnly)
    partyInviteShiftCheckbox:SetChecked(settings.requireShiftAutoPartyInvite)
end

optionsPanel:SetScript("OnShow", RefreshOptionsPanel)
InterfaceOptions_AddCategory(optionsPanel)

-- Standalone UI (movable frame)
local uiFrame
local uiCheckboxes = {}

local function CreateUICheckbox(name, label, settingKey, parent, anchor, offsetY)
    local checkbox = CreateFrame("CheckButton", name, parent, "InterfaceOptionsCheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY)
    local labelRegion = _G[name .. "Text"] or checkbox.Text or checkbox.text
    if not labelRegion then
        labelRegion = checkbox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        labelRegion:SetPoint("LEFT", checkbox, "RIGHT", 0, 0)
    end
    labelRegion:SetText(label)

    checkbox:SetScript("OnClick", function(self)
        settings[settingKey] = self:GetChecked() and true or false
    end)

    uiCheckboxes[settingKey] = checkbox
    return checkbox
end

local function RefreshStandaloneUI()
    if not uiFrame then return end
    for key, cb in pairs(uiCheckboxes) do
        cb:SetChecked(settings[key] and true or false)
    end
end

local function BuildStandaloneUI()
    if uiFrame then return end

    uiFrame = CreateFrame("Frame", "AutoConfirmStandaloneUI", UIParent)
    uiFrame:SetSize(440, 520)
    uiFrame:SetPoint("CENTER")
    uiFrame:SetMovable(true)
    uiFrame:EnableMouse(true)
    uiFrame:RegisterForDrag("LeftButton")
    uiFrame:SetScript("OnDragStart", uiFrame.StartMoving)
    uiFrame:SetScript("OnDragStop", uiFrame.StopMovingOrSizing)
    uiFrame:SetClampedToScreen(true)

-- WotLK/3.3.5a compatibility: BasicFrameTemplateWithInset does not exist.
-- Build a simple dialog-style frame manually.
uiFrame:SetFrameStrata("DIALOG")
uiFrame:SetToplevel(true)
uiFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
})

uiFrame.titleBg = uiFrame:CreateTexture(nil, "ARTWORK")
uiFrame.titleBg:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
uiFrame.titleBg:SetPoint("TOP", uiFrame, "TOP", 0, 0)
uiFrame.titleBg:SetSize(320, 64)

uiFrame.closeButton = CreateFrame("Button", nil, uiFrame, "UIPanelCloseButton")
uiFrame.closeButton:SetPoint("TOPRIGHT", -6, -6)

uiFrame.inset = CreateFrame("Frame", nil, uiFrame)
uiFrame.inset:SetPoint("TOPLEFT", 14, -54)
uiFrame.inset:SetPoint("BOTTOMRIGHT", -14, 36)
uiFrame.inset:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
})
uiFrame.inset:SetBackdropColor(0, 0, 0, 0.35)

    uiFrame.title = uiFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    uiFrame.title:SetPoint("CENTER", uiFrame.titleBg, "CENTER", 0, -12)
    uiFrame.title:SetText("AutoConfirm")


    local scrollFrame = CreateFrame("ScrollFrame", "AutoConfirmStandaloneScroll", uiFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", uiFrame.inset, "TOPLEFT", 6, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", uiFrame.inset, "BOTTOMRIGHT", -26, 8)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 1) -- will be expanded after widgets are created
    scrollFrame:SetScrollChild(content)

    local header = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetPoint("TOPLEFT", 8, -8)
    header:SetText("Configure automatic confirmations and deletions.")

    local function CreateRowCheckbox(name, label, settingKey, x, y)
        local cb = CreateFrame("CheckButton", name, content, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", content, "TOPLEFT", x, y)
        local labelRegion = _G[name .. "Text"] or cb.Text or cb.text
        if labelRegion then labelRegion:SetText(label) end
        cb:SetScript("OnClick", function(self)
            settings[settingKey] = self:GetChecked() and true or false
            RefreshOptionsPanel()
        end)
        uiCheckboxes[settingKey] = cb
        return cb
    end

    local y = -34
    local leftX = 8
    local shiftX = 250
    local rowStep = 28

    -- Loot
    CreateRowCheckbox("AutoConfirmUI_AutoLoot", "Auto-confirm soulbound loot", "autoLoot", leftX, y)
    CreateRowCheckbox("AutoConfirmUI_ShiftLoot", "Shift", "requireShiftAutoLoot", shiftX, y)
    y = y - rowStep

    -- Quest abandon
    CreateRowCheckbox("AutoConfirmUI_AutoAbandon", "Auto-confirm abandon quest", "autoAbandonQuest", leftX, y)
    CreateRowCheckbox("AutoConfirmUI_ShiftAbandon", "Shift", "requireShiftAutoAbandonQuest", shiftX, y)
    y = y - rowStep

    -- Quest complete
    CreateRowCheckbox("AutoConfirmUI_AutoComplete", "Auto-confirm quest complete", "autoQuestComplete", leftX, y)
    CreateRowCheckbox("AutoConfirmUI_ShiftComplete", "Shift", "requireShiftAutoQuestComplete", shiftX, y)
    y = y - rowStep

    -- DELETE confirm
    CreateRowCheckbox("AutoConfirmUI_AutoDeleteConfirm", "Auto-fill DELETE confirmation", "autoDeleteConfirm", leftX, y)
    CreateRowCheckbox("AutoConfirmUI_ShiftDeleteConfirm", "Shift", "requireShiftAutoDeleteConfirm", shiftX, y)
    y = y - rowStep

    -- Quest item delete
    CreateRowCheckbox("AutoConfirmUI_AutoDeleteQuestItems", "Auto-delete quest items", "autoDeleteQuestItems", leftX, y)
    CreateRowCheckbox("AutoConfirmUI_ShiftDeleteQuestItems", "Shift", "requireShiftAutoDeleteQuestItems", shiftX, y)
    y = y - rowStep

    -- Bind on equip
    CreateRowCheckbox("AutoConfirmUI_AutoEquipConfirm", "Auto-confirm bind on equip", "autoEquipConfirm", leftX, y)
    CreateRowCheckbox("AutoConfirmUI_ShiftEquipConfirm", "Shift", "requireShiftAutoEquipConfirm", shiftX, y)
    y = y - rowStep

    -- Enchant replacement
    CreateRowCheckbox("AutoConfirmUI_AutoEnchantReplace", "Auto-confirm enchant replacement", "autoEnchantReplace", leftX, y)
    CreateRowCheckbox("AutoConfirmUI_ShiftEnchantReplace", "Shift", "requireShiftAutoEnchantReplace", shiftX, y)
    y = y - rowStep

    -- Party invites
    CreateRowCheckbox("AutoConfirmUI_AutoPartyInvite", "Auto-accept party invites", "autoPartyInvite", leftX, y)
    CreateRowCheckbox("AutoConfirmUI_ShiftPartyInvite", "Shift", "requireShiftAutoPartyInvite", shiftX, y)
    y = y - rowStep

    CreateRowCheckbox("AutoConfirmUI_PartyFriendsOnly", "Friends/guild only", "partyInviteFriendsOnly", leftX + 18, y)
    y = y - rowStep

    -- Expand content height so the scroll frame knows how far it can scroll.
    content:SetHeight((-y) + 40)
    local helpTip = uiFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    helpTip:SetPoint("BOTTOMRIGHT", uiFrame, "BOTTOMRIGHT", -14, 14)
    helpTip:SetText("Tip: /ac status for settings")

    -- Expand content height so the scroll frame knows how far it can scroll.

    uiFrame:SetScript("OnShow", function()
        RefreshStandaloneUI()
    end)

    uiFrame:Hide()
end

local function ToggleStandaloneUI()
    BuildStandaloneUI()
    if uiFrame:IsShown() then
        uiFrame:Hide()
    else
        uiFrame:Show()
        uiFrame:Raise()
    end
end


-- Slash command handler
SLASH_AUTOCONFIRM1 = "/autoconfirm"
SLASH_AUTOCONFIRM2 = "/ac"

SlashCmdList["AUTOCONFIRM"] = function(msg)
    msg = msg or ""
    msg = strlower(strtrim(msg))
    if msg == "" or msg == "ui" or msg == "options" then
        ToggleStandaloneUI()
        return
    end

    if msg == "loot" then
        settings.autoLoot = not settings.autoLoot
        print("|cff00ff00AutoConfirm:|r Auto-loot BoP: " .. (settings.autoLoot and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
    elseif msg == "delete" then
        settings.autoDelete = not settings.autoDelete
        print("|cff00ff00AutoConfirm:|r Auto-delete: " .. (settings.autoDelete and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
    elseif msg == "equip" then
        settings.autoEquipConfirm = not settings.autoEquipConfirm
        print("|cff00ff00AutoConfirm:|r Auto-confirm equip: " .. (settings.autoEquipConfirm and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
    elseif msg == "enchant" then
        settings.autoEnchantReplace = not settings.autoEnchantReplace
        print("|cff00ff00AutoConfirm:|r Auto-confirm enchant replace: " .. (settings.autoEnchantReplace and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
    elseif msg == "abandon" then
        settings.autoAbandonQuest = not settings.autoAbandonQuest
        print("|cff00ff00AutoConfirm:|r Auto-confirm abandon quest: " .. (settings.autoAbandonQuest and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
    elseif msg == "complete" then
        settings.autoQuestComplete = not settings.autoQuestComplete
        print("|cff00ff00AutoConfirm:|r Auto-confirm quest complete: " .. (settings.autoQuestComplete and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
    elseif msg == "party" then
        settings.autoPartyInvite = not settings.autoPartyInvite
        print("|cff00ff00AutoConfirm:|r Auto-accept party invites: " .. (settings.autoPartyInvite and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
    elseif msg == "partyfriends" then
        settings.partyInviteFriendsOnly = not settings.partyInviteFriendsOnly
        print("|cff00ff00AutoConfirm:|r Party invites friends only: " .. (settings.partyInviteFriendsOnly and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
    elseif msg == "status" then
        print("|cff00ff00AutoConfirm Status:|r")
        print("  Auto-loot BoP: " .. (settings.autoLoot and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        print("  Require Shift for auto-loot: " .. (settings.requireShiftAutoLoot and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        print("  Auto-confirm abandon quest: " .. (settings.autoAbandonQuest and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        print("  Require Shift for abandon quest: " .. (settings.requireShiftAutoAbandonQuest and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        print("  Auto-confirm quest complete: " .. (settings.autoQuestComplete and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        print("  Require Shift for quest complete: " .. (settings.requireShiftAutoQuestComplete and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        print("  Auto-delete: " .. (settings.autoDelete and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        print("  Require Shift for auto-delete: " .. (settings.requireShiftAutoDelete and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        print("  Auto-delete quest items: " .. (settings.autoDeleteQuestItems and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        print("  Require Shift for quest item delete: " .. (settings.requireShiftAutoDeleteQuestItems and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        print("  Auto-confirm equip: " .. (settings.autoEquipConfirm and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        print("  Require Shift for equip confirm: " .. (settings.requireShiftAutoEquipConfirm and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        print("  Auto-confirm enchant replace: " .. (settings.autoEnchantReplace and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        print("  Require Shift for enchant replace: " .. (settings.requireShiftAutoEnchantReplace and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        print("  Auto-accept party invites: " .. (settings.autoPartyInvite and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        print("  Party invites friends only: " .. (settings.partyInviteFriendsOnly and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        print("  Require Shift for party invites: " .. (settings.requireShiftAutoPartyInvite and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        print("  Supported delete popups: DELETE_GOOD_ITEM, DELETE_QUEST_ITEM, DELETE_QUEST_ITEM_CONFIRM")
        print("  Supported equip popups: EQUIP_BIND, EQUIP_BIND_CONFIRM, AUTOEQUIP_BIND_CONFIRM")
        print("  Supported enchant popups: REPLACE_ENCHANT, CONFIRM_ENCHANT_REPLACE")
        print("  Supported quest popups: ABANDON_QUEST, QUEST_COMPLETE")
        print("  Supported party popups: PARTY_INVITE")
    else
        print("|cff00ff00AutoConfirm Commands:|r")
        print("  /ac loot - Toggle auto-confirm BoP loot")
        print("  /ac abandon - Toggle auto-confirm abandon quest")
        print("  /ac complete - Toggle auto-confirm quest complete")
        print("  /ac delete - Toggle auto-delete items")
        print("  /ac equip - Toggle auto-confirm equipment binding")
        print("  /ac enchant - Toggle auto-confirm enchant replacement")
        print("  /ac party - Toggle auto-accept party invites")
        print("  /ac partyfriends - Toggle party invites friends only")
        print("  /ac status - Show current settings")
    end

    RefreshOptionsPanel()
end

print(addonName .. " loaded - Type /ac for commands")
