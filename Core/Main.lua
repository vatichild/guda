-- Guda Main Initialization
-- Sets up all modules and auto-save system

local addon = Guda

local Main = {}
addon.Modules.Main = Main

-- Initialize addon
function Main:Initialize()
    -- Wait for PLAYER_LOGIN to ensure saved variables are loaded
    addon.Modules.Events:OnPlayerLogin(function()
        addon:Print("Initializing...")

        -- Initialize database
        addon.Modules.DB:Initialize()

        -- Initialize scanners
        addon.Modules.BagScanner:Initialize()
        addon.Modules.BankScanner:Initialize()
        addon.Modules.MoneyTracker:Initialize()
		addon.Modules.EquipmentScanner:Initialize()

        -- Initialize UI
        addon.Modules.BagFrame:Initialize()
        addon.Modules.BankFrame:Initialize()
        addon.Modules.SettingsPopup:Initialize()

        -- Initialize tooltip
        if addon.Modules.Tooltip then
            addon.Modules.Tooltip:Initialize()
        else
            addon:Error("Tooltip module not loaded!")
        end

        -- Setup slash commands
        Main:SetupSlashCommands()

        -- Mark addon ready for keybind wrappers and process any pending toggles
        addon._ready = true
        if addon._pendingToggleBags then
            addon._pendingToggleBags = false
            if addon.Modules.BagFrame and addon.Modules.BagFrame.Toggle then
                addon.Modules.BagFrame:Toggle()
            end
        end
        if addon._pendingToggleBank then
            addon._pendingToggleBank = false
            if addon.Modules.BankFrame and addon.Modules.BankFrame.Toggle then
                addon.Modules.BankFrame:Toggle()
            end
        end

        addon:Debug("Initialization complete")
        addon:Print("Ready! Type /guda to open bags")
    end, "Main")
end

-- Setup slash commands
function Main:SetupSlashCommands()
    SLASH_Guda1 = "/Guda"
    SLASH_Guda2 = "/guda"

    SlashCmdList["Guda"] = function(msg)
        msg = string.lower(msg or "")

        if msg == "" or msg == "bags" then
            -- Toggle bags
            addon.Modules.BagFrame:Toggle()

        elseif msg == "bank" then
            -- Toggle bank
            addon.Modules.BankFrame:Toggle()

        elseif msg == "sort" then
            -- Sort bags
            addon.Modules.SortEngine:SortBags()

        elseif msg == "sortbank" then
            -- Sort bank
            addon.Modules.SortEngine:SortBank()

        elseif msg == "debug" then
            -- Toggle debug
            addon.DEBUG = not addon.DEBUG
            addon:Print("Debug mode: %s", addon.DEBUG and "ON" or "OFF")

        elseif msg == "cleanup" then
            -- Cleanup old characters
            addon.Modules.DB:CleanupOldCharacters()

        elseif msg == "help" then
            -- Show help
            addon:Print("Commands:")
            addon:Print("/guda - Toggle bags")
            addon:Print("/guda bank - Toggle bank")
            addon:Print("/guda sort - Sort bags")
            addon:Print("/guda sortbank - Sort bank")
            addon:Print("/guda debug - Toggle debug mode")
            addon:Print("/guda cleanup - Remove old characters")

        else
            addon:Print("Unknown command. Type /guda help for commands")
        end
    end

    addon:Debug("Slash commands registered")
end

-- Run initialization
Main:Initialize()
