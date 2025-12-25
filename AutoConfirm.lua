-- AutoConfirm.lua
local addonName = "AutoConfirm"
local frame = CreateFrame("Frame")
local _autoLootInProgress = false

-- Settings
local defaultSettings = {
    autoLoot = false,
    autoQuestAccept = false,
    autoQuestTurnIn = false,
    autoAbandonQuest = false,
    autoDelete = false,
    autoDeleteQuestItems = false,
    autoEquipConfirm = false,
    autoEnchantReplace = false,
    autoPartyInvite = false,
    partyInviteFriendsOnly = false,
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
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("QUEST_DETAIL")
frame:RegisterEvent("QUEST_PROGRESS")
frame:RegisterEvent("QUEST_COMPLETE")
frame:RegisterEvent("GOSSIP_SHOW")



local questDeletePopups = {
    DELETE_QUEST_ITEM = true,
    DELETE_QUEST_ITEM_CONFIRM = true
}

local function FindPopupByWhich(which)
    for i = 1, 4 do
        local dlg = _G["StaticPopup"..i]
        if dlg and dlg:IsShown() and dlg.which == which then
            return dlg
        end
    end
    return nil
end

local function ClickPopupAccept(which)
    local dlg = FindPopupByWhich(which)
    if not dlg then return false end

    local btn1 = _G[dlg:GetName() .. "Button1"]
    if btn1 and btn1:IsEnabled() then
        btn1:Click()
        return true
    end
    return false
end

-- Auto-fill DELETE confirmation and click accept
local function AutoFillDelete(which, isEnabled, confirmText)
    if not isEnabled then
        return
    end
    if StaticPopup1EditBox and StaticPopup1EditBox:IsVisible() then
        local dialog = StaticPopup1
        if dialog and dialog.which == which then
            StaticPopup1EditBox:SetText(confirmText)
            local elapsed = 0
			local f = CreateFrame("Frame")
			f:SetScript("OnUpdate", function(self, dt)
				elapsed = elapsed + dt
				if elapsed >= 0.1 then
					self:SetScript("OnUpdate", nil)
					self:Hide()
					if StaticPopup1Button1 and StaticPopup1Button1:IsEnabled() then
						StaticPopup1Button1:Click()
					end
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
local function FindPopupByWhich(which)
    for i = 1, 4 do
        local dlg = _G["StaticPopup" .. i]
        if dlg and dlg:IsShown() and dlg.which == which then
            return dlg, i
        end
    end
    return nil, nil
end

local function ClickPopupAccept(which)
    local dlg = FindPopupByWhich(which)
    if not dlg then return false end
    local btn1 = _G[dlg:GetName() .. "Button1"]
    if btn1 and btn1:IsEnabled() then
        btn1:Click()
        return true
    end
    return false
end

local function GetPartyInviterName()
    local dlg = FindPopupByWhich("PARTY_INVITE")
    if not dlg then return nil end

    -- Best case: server stores it here
    if type(dlg.data) == "string" and dlg.data ~= "" then return dlg.data end
    if type(dlg.data2) == "string" and dlg.data2 ~= "" then return dlg.data2 end

    -- Fallback: parse from the visible text "X invites you to a group."
    local textRegion = _G[dlg:GetName() .. "Text"]
    local text = textRegion and textRegion:GetText()
    if type(text) == "string" then
        local name = text:match("^([^ ]+) invites you to")
        return name
    end

    return nil
end


local function AutoConfirmStaticPopup(which)
    if which == "EQUIP_BIND" or which == "EQUIP_BIND_CONFIRM" or which == "AUTOEQUIP_BIND_CONFIRM" then
        if settings.autoEquipConfirm then
            ClickPopupAccept(which)
        end
        return
    end

    if which == "REPLACE_ENCHANT" or which == "CONFIRM_ENCHANT_REPLACE" then
        if settings.autoEnchantReplace then
            ClickPopupAccept(which)
        end
        return
    end

    if which == "ABANDON_QUEST" then
        if settings.autoAbandonQuest then
            ClickPopupAccept(which)
        end
        return
    end

    if which == "PARTY_INVITE" then
    if not settings.autoPartyInvite then
        return
    end

    if settings.partyInviteFriendsOnly then
        local inviterName = GetPartyInviterName()
        if not inviterName or not IsFriendByName(inviterName) then
            return
        end
    end

    ClickPopupAccept("PARTY_INVITE")
    return
	end

end

local function AutoConfirmEnchantReplace()
    if not settings.autoEnchantReplace then
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

local function AutoQuest_Accept()
    if not settings.autoQuestAccept then return end
    if AcceptQuest then AcceptQuest() end
end

local function AutoQuest_Progress()
    if not settings.autoQuestTurnIn then return end
    if IsQuestCompletable and IsQuestCompletable() then
        if CompleteQuest then CompleteQuest() end
    end
end

local function AutoQuest_Complete()
    if not settings.autoQuestTurnIn then return end

    local choices = (GetNumQuestChoices and GetNumQuestChoices()) or 0
    if choices > 1 then
        return -- don't auto-select among multiple rewards
    end

    if GetQuestReward then
        GetQuestReward(1)
    end
end

-- Gossip-based accept/turn-in (common on private servers)
local function AutoQuest_Gossip()
    -- Turn-in (active quests) first
    if settings.autoQuestTurnIn and GetNumGossipActiveQuests and SelectGossipActiveQuest then
        local n = GetNumGossipActiveQuests()
        if n == 1 then
            -- WotLK returns: title, level, isTrivial, isComplete, isLegendary, isIgnored
            local _, _, _, isComplete = GetGossipActiveQuests()
            if isComplete == 1 then
                SelectGossipActiveQuest(1)
                return
            end
        end
    end

    -- Accept (available quests)
    if settings.autoQuestAccept and GetNumGossipAvailableQuests and SelectGossipAvailableQuest then
        local n = GetNumGossipAvailableQuests()
        if n == 1 then
            SelectGossipAvailableQuest(1)
            return
        end
    end
end




frame:SetScript("OnEvent", function(self, event, arg1, arg2, arg3, arg4)
    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            InitializeSavedVariables()
        end
        return
    end

    if not settings then
        return
    end

    if event == "QUEST_DETAIL" then
        AutoQuest_Accept()
        return
    elseif event == "QUEST_PROGRESS" then
        AutoQuest_Progress()
        return
    elseif event == "QUEST_COMPLETE" then
        AutoQuest_Complete()
        return
    elseif event == "GOSSIP_SHOW" then
        AutoQuest_Gossip()
        return
    end

	if event == "LOOT_BIND_CONFIRM" then
		if settings and settings.autoLoot then
			local slot = arg1
			if ConfirmLootSlot and slot then
				ConfirmLootSlot(slot)
			end
		end
		return
	end


        return
    elseif event == "CONFIRM_ENCHANT_REPLACE" then
        AutoConfirmEnchantReplace()
        return
    elseif event == "EQUIP_BIND_CONFIRM" then
        AutoConfirmEquipBind(arg1, arg2, arg3, arg4)
        return
    elseif event == "AUTOEQUIP_BIND_CONFIRM" then
        AutoConfirmEquipBind(arg1, arg2, arg3, arg4)
        return
    end
end)



-- Hook into StaticPopup to auto-fill delete text and click
local lastPartyInviter

hooksecurefunc("StaticPopup_Show", function(which, text_arg1, text_arg2, data)
    if which == "LOOT_BIND" then
		if settings and settings.autoLoot then
			-- data is often the loot slot
			if type(data) == "number" and ConfirmLootSlot then
				ConfirmLootSlot(data)
			end
		end
		return
	end




    if which == "DELETE_GOOD_ITEM" then
        AutoFillDelete(which, settings.autoDelete, DELETE_ITEM_CONFIRM_STRING)
        return
    end

    if questDeletePopups[which] then
        local confirmText = _G.DELETE_QUEST_ITEM_CONFIRM_STRING or _G.DELETE_ITEM_CONFIRM_STRING or "DELETE"
        AutoFillDelete(which, settings.autoDeleteQuestItems, confirmText)
        return
    end

    if which == "PARTY_INVITE" then
        AutoConfirmStaticPopup(which)
        return
    end

    AutoConfirmStaticPopup(which)
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
local abandonQuestCheckbox = CreateOptionCheckbox("AutoConfirmAbandonQuestCheckbox", "Auto-confirm abandon quest", "autoAbandonQuest", lootCheckbox, -8)
local questAcceptCheckbox = CreateOptionCheckbox("AutoConfirmQuestAcceptCheckbox", "Auto-accept quests", "autoQuestAccept", abandonQuestCheckbox, -8)
local questTurnInCheckbox = CreateOptionCheckbox("AutoConfirmQuestTurnInCheckbox", "Auto-complete/turn-in quests", "autoQuestTurnIn", questAcceptCheckbox, -8)

local deleteCheckbox = CreateOptionCheckbox("AutoConfirmDeleteCheckbox", "Auto-fill DELETE confirmation", "autoDelete", questCompleteCheckbox, -8)
local questDeleteCheckbox = CreateOptionCheckbox("AutoConfirmQuestDeleteCheckbox", "Auto-delete quest items", "autoDeleteQuestItems", deleteCheckbox, -8)
local equipCheckbox = CreateOptionCheckbox("AutoConfirmEquipCheckbox", "Auto-confirm equipment binding", "autoEquipConfirm", questDeleteCheckbox, -8)
local enchantCheckbox = CreateOptionCheckbox("AutoConfirmEnchantCheckbox", "Auto-confirm enchant replacement", "autoEnchantReplace", equipCheckbox, -8)
local partyInviteCheckbox = CreateOptionCheckbox("AutoConfirmPartyInviteCheckbox", "Auto-accept party invites", "autoPartyInvite", enchantCheckbox, -8)
local partyInviteFriendsCheckbox = CreateOptionCheckbox("AutoConfirmPartyInviteFriendsCheckbox", "Party invites: friends only", "partyInviteFriendsOnly", partyInviteCheckbox, -8)
local function RefreshOptionsPanel()
    if not settings then
        return
    end
    lootCheckbox:SetChecked(settings.autoLoot)
    abandonQuestCheckbox:SetChecked(settings.autoAbandonQuest)
	questAcceptCheckbox:SetChecked(settings.autoQuestAccept)
	questTurnInCheckbox:SetChecked(settings.autoQuestTurnIn)

    deleteCheckbox:SetChecked(settings.autoDelete)
    questDeleteCheckbox:SetChecked(settings.autoDeleteQuestItems)
    equipCheckbox:SetChecked(settings.autoEquipConfirm)
    enchantCheckbox:SetChecked(settings.autoEnchantReplace)
    partyInviteCheckbox:SetChecked(settings.autoPartyInvite)
    partyInviteFriendsCheckbox:SetChecked(settings.partyInviteFriendsOnly)
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
	uiFrame.title:SetPoint("CENTER", uiFrame.titleBg, "CENTER", 0, 12)
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
    local rowStep = 28
		-- Loot
		CreateRowCheckbox("AutoConfirmUI_AutoLoot", "Auto-confirm soulbound loot", "autoLoot", leftX, y)
		y = y - rowStep
		-- Quest abandon
		CreateRowCheckbox("AutoConfirmUI_AutoAbandon", "Auto-confirm abandon quest", "autoAbandonQuest", leftX, y)
		y = y - rowStep
		-- Quest complete
		CreateRowCheckbox("AutoConfirmUI_AutoQuestAccept", "Auto-accept quests", "autoQuestAccept", leftX, y)
		y = y - rowStep

		CreateRowCheckbox("AutoConfirmUI_AutoQuestTurnIn", "Auto-complete/turn-in quests", "autoQuestTurnIn", leftX, y)
		y = y - rowStep

		-- DELETE confirm (FIXED KEY)
		CreateRowCheckbox("AutoConfirmUI_AutoDelete", "Auto-fill DELETE confirmation", "autoDelete", leftX, y)
		y = y - rowStep
		-- Quest item delete
		CreateRowCheckbox("AutoConfirmUI_AutoDeleteQuestItems", "Auto-delete quest items", "autoDeleteQuestItems", leftX, y)
		y = y - rowStep
		-- Bind on equip
		CreateRowCheckbox("AutoConfirmUI_AutoEquipConfirm", "Auto-confirm bind on equip", "autoEquipConfirm", leftX, y)
		y = y - rowStep
		-- Enchant replacement
		CreateRowCheckbox("AutoConfirmUI_AutoEnchantReplace", "Auto-confirm enchant replacement", "autoEnchantReplace", leftX, y)
		y = y - rowStep
		-- Party invites
		CreateRowCheckbox("AutoConfirmUI_AutoPartyInvite", "Auto-accept party invites", "autoPartyInvite", leftX, y)
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
	if not settings then InitializeSavedVariables() end

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
	elseif msg == "questaccept" then
		settings.autoQuestAccept = not settings.autoQuestAccept
		print("|cff00ff00AutoConfirm:|r Auto-accept quests: " .. (settings.autoQuestAccept and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
	elseif msg == "questturnin" then
		settings.autoQuestTurnIn = not settings.autoQuestTurnIn
		print("|cff00ff00AutoConfirm:|r Auto turn-in quests: " .. (settings.autoQuestTurnIn and "|cff00ff00ON|r" or "|cffff0000OFF|r"))

    elseif msg == "party" then
        settings.autoPartyInvite = not settings.autoPartyInvite
        print("|cff00ff00AutoConfirm:|r Auto-accept party invites: " .. (settings.autoPartyInvite and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
    elseif msg == "partyfriends" then
        settings.partyInviteFriendsOnly = not settings.partyInviteFriendsOnly
        print("|cff00ff00AutoConfirm:|r Party invites friends only: " .. (settings.partyInviteFriendsOnly and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
    elseif msg == "status" then
        print("|cff00ff00AutoConfirm Status:|r")
        print("  Auto-loot BoP: " .. (settings.autoLoot and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        print("  Auto-confirm abandon quest: " .. (settings.autoAbandonQuest and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        print("  Auto-confirm quest complete: " .. (settings.autoQuestComplete and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        print("  Auto-delete: " .. (settings.autoDelete and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        print("  Auto-delete quest items: " .. (settings.autoDeleteQuestItems and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        print("  Auto-confirm equip: " .. (settings.autoEquipConfirm and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        print("  Auto-confirm enchant replace: " .. (settings.autoEnchantReplace and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        print("  Auto-accept party invites: " .. (settings.autoPartyInvite and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        print("  Party invites friends only: " .. (settings.partyInviteFriendsOnly and "|cff00ff00ON|r" or "|cffff0000OFF|r"))

    else
        print("|cff00ff00AutoConfirm Commands:|r")
        print("  /ac loot - Toggle auto-confirm BoP loot")
        print("  /ac abandon - Toggle auto-confirm abandon quest")
        print("  /ac delete - Toggle auto-delete items")
        print("  /ac equip - Toggle auto-confirm equipment binding")
        print("  /ac enchant - Toggle auto-confirm enchant replacement")
        print("  /ac party - Toggle auto-accept party invites")
        print("  /ac partyfriends - Toggle party invites friends only")
        print("  /ac status - Show current settings")
		print("  /ac questaccept - Toggle auto-accept quests")
		print("  /ac questturnin - Toggle auto-complete/turn-in quests")

    end

    RefreshOptionsPanel()
end
print(addonName .. " loaded - Type /ac to open the UI, or /ac status")

