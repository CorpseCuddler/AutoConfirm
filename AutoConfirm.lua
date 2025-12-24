-- AutoConfirm.lua
local addonName = "AutoConfirm"
local frame = CreateFrame("Frame")

-- Settings
local defaultSettings = {
    autoLoot = true,
    autoDelete = true,
    autoEquipConfirm = true,
    autoEnchantReplace = true
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

-- Auto-fill DELETE confirmation and click accept
local function AutoFillDelete()
    if not settings.autoDelete then return end
    
    if StaticPopup1EditBox and StaticPopup1EditBox:IsVisible() then
        local dialog = StaticPopup1
        if dialog and dialog.which == "DELETE_GOOD_ITEM" then
            StaticPopup1EditBox:SetText(DELETE_ITEM_CONFIRM_STRING)
            -- Small delay to ensure the text is set before clicking
            C_Timer.After(0.1, function()
                if StaticPopup1Button1:IsEnabled() then
                    StaticPopup1Button1:Click()
                end
            end)
        end
    end
end

local function AutoConfirmStaticPopup(which)
    if which == "EQUIP_BIND" or which == "EQUIP_BIND_CONFIRM" or which == "AUTOEQUIP_BIND_CONFIRM" then
        if settings.autoEquipConfirm and StaticPopup1Button1 and StaticPopup1Button1:IsEnabled() then
            StaticPopup1Button1:Click()
        end
        return
    end

    if which == "REPLACE_ENCHANT" or which == "CONFIRM_ENCHANT_REPLACE" then
        if settings.autoEnchantReplace and StaticPopup1Button1 and StaticPopup1Button1:IsEnabled() then
            StaticPopup1Button1:Click()
        end
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

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            InitializeSavedVariables()
        end
        return
    end

    if event == "LOOT_BIND_CONFIRM" then
        if settings.autoLoot then
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
        AutoFillDelete()
    else
        AutoConfirmStaticPopup(which)
    end
end)

local optionsPanel = CreateFrame("Frame", "AutoConfirmOptions", UIParent)
optionsPanel.name = "AutoConfirm"

local function CreateOptionCheckbox(name, label, settingKey, anchor, offsetY)
    local checkbox = CreateFrame("CheckButton", name, optionsPanel, "InterfaceOptionsCheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY)
    checkbox.Text:SetText(label)

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
local deleteCheckbox = CreateOptionCheckbox("AutoConfirmDeleteCheckbox", "Auto-fill DELETE confirmation", "autoDelete", lootCheckbox, -8)
local equipCheckbox = CreateOptionCheckbox("AutoConfirmEquipCheckbox", "Auto-confirm equipment binding", "autoEquipConfirm", deleteCheckbox, -8)
local enchantCheckbox = CreateOptionCheckbox("AutoConfirmEnchantCheckbox", "Auto-confirm enchant replacement", "autoEnchantReplace", equipCheckbox, -8)

local function RefreshOptionsPanel()
    if not settings then
        return
    end

    lootCheckbox:SetChecked(settings.autoLoot)
    deleteCheckbox:SetChecked(settings.autoDelete)
    equipCheckbox:SetChecked(settings.autoEquipConfirm)
    enchantCheckbox:SetChecked(settings.autoEnchantReplace)
end

optionsPanel:SetScript("OnShow", RefreshOptionsPanel)
InterfaceOptions_AddCategory(optionsPanel)

-- Slash command handler
SLASH_AUTOCONFIRM1 = "/autoconfirm"
SLASH_AUTOCONFIRM2 = "/ac"

SlashCmdList["AUTOCONFIRM"] = function(msg)
    msg = msg:lower():trim()
    
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
    elseif msg == "status" then
        print("|cff00ff00AutoConfirm Status:|r")
        print("  Auto-loot BoP: " .. (settings.autoLoot and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        print("  Auto-delete: " .. (settings.autoDelete and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        print("  Auto-confirm equip: " .. (settings.autoEquipConfirm and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        print("  Auto-confirm enchant replace: " .. (settings.autoEnchantReplace and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        print("  Supported equip popups: EQUIP_BIND, EQUIP_BIND_CONFIRM, AUTOEQUIP_BIND_CONFIRM")
        print("  Supported enchant popups: REPLACE_ENCHANT, CONFIRM_ENCHANT_REPLACE")
    else
        print("|cff00ff00AutoConfirm Commands:|r")
        print("  /ac loot - Toggle auto-confirm BoP loot")
        print("  /ac delete - Toggle auto-delete items")
        print("  /ac equip - Toggle auto-confirm equipment binding")
        print("  /ac enchant - Toggle auto-confirm enchant replacement")
        print("  /ac status - Show current settings")
    end

    RefreshOptionsPanel()
end

print(addonName .. " loaded - Type /ac for commands")
