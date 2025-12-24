-- AutoConfirm.lua
local addonName = "AutoConfirm"
local frame = CreateFrame("Frame")

-- Settings
local settings = {
    autoLoot = true,
    autoDelete = true
}

-- Auto-confirm soulbound item loots
frame:RegisterEvent("LOOT_BIND_CONFIRM")

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

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "LOOT_BIND_CONFIRM" then
        if settings.autoLoot then
            local slot = ...
            ConfirmLootSlot(slot)
        end
    end
end)

-- Hook into StaticPopup to auto-fill delete text and click
hooksecurefunc("StaticPopup_Show", function(which)
    if which == "DELETE_GOOD_ITEM" then
        AutoFillDelete()
    end
end)

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
    elseif msg == "status" then
        print("|cff00ff00AutoConfirm Status:|r")
        print("  Auto-loot BoP: " .. (settings.autoLoot and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        print("  Auto-delete: " .. (settings.autoDelete and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
    else
        print("|cff00ff00AutoConfirm Commands:|r")
        print("  /ac loot - Toggle auto-confirm BoP loot")
        print("  /ac delete - Toggle auto-delete items")
        print("  /ac status - Show current settings")
    end
end

print(addonName .. " loaded - Type /ac for commands")