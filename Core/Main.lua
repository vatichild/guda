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
        addon.Modules.MailboxScanner:Initialize()
        addon.Modules.MoneyTracker:Initialize()
		addon.Modules.EquipmentScanner:Initialize()

        -- Initialize UI
        addon:Print("Initializing UI...")
        addon.Modules.BagFrame:Initialize()
        addon.Modules.BankFrame:Initialize()
        addon.Modules.MailboxFrame:Initialize()
        
        addon:Debug("Checking QuestItemBar module...")
        if addon.Modules.QuestItemBar and addon.Modules.QuestItemBar.isLoaded then
            addon:Debug("QuestItemBar module found and loaded, initializing...")
            local success, err = pcall(function() addon.Modules.QuestItemBar:Initialize() end)
            if not success then
                addon:Error("Failed to initialize QuestItemBar: %s", tostring(err))
            end
        else
            if not addon.Modules.QuestItemBar then
                addon:Error("QuestItemBar module table is MISSING from addon.Modules!")
            else
                addon:Error("QuestItemBar module file failed to load (isLoaded is nil)!")
            end
        end

        addon:Debug("Checking TrackedItemBar module...")
        if addon.Modules.TrackedItemBar and addon.Modules.TrackedItemBar.isLoaded then
            addon:Debug("TrackedItemBar module found and loaded, initializing...")
            local success, err = pcall(function() addon.Modules.TrackedItemBar:Initialize() end)
            if not success then
                addon:Error("Failed to initialize TrackedItemBar: %s", tostring(err))
            end
        end
        
        addon.Modules.SettingsPopup:Initialize()

        -- Apply initial transparency settings
        if Guda_ApplyBackgroundTransparency then
            Guda_ApplyBackgroundTransparency()
        end

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

        elseif msg == "mail" or msg == "mailbox" then
            -- Toggle mailbox
            addon.Modules.MailboxFrame:Toggle()

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

        elseif msg == "debugsort" then
            -- Toggle debug sort (verbose sorting output)
            addon.DEBUG_SORT = not addon.DEBUG_SORT
            addon:Print("Debug sort mode: %s", addon.DEBUG_SORT and "ON" or "OFF")

        elseif msg == "quest" then
            -- Toggle quest bar
            local show = not addon.Modules.DB:GetSetting("showQuestBar")
            addon.Modules.DB:SetSetting("showQuestBar", show)
            addon.Modules.QuestItemBar:Update()
            addon:Print("Quest bar: %s", show and "ON" or "OFF")

        elseif msg == "track" then
            -- Toggle tracked items bar visibility
            local frame = Guda_TrackedItemBar
            if frame then
                if frame:IsShown() then
                    frame:Hide()
                else
                    frame:Show()
                end
            end

        elseif msg == "cleanup" then
            -- Cleanup old characters
            addon.Modules.DB:CleanupOldCharacters()

        elseif msg == "perf" or msg == "performance" then
            -- Show performance statistics
            if addon.Modules.Utils and addon.Modules.Utils.PrintPerformanceStats then
                addon.Modules.Utils:PrintPerformanceStats()
            else
                addon:Print("Performance stats not available")
            end

        elseif msg == "perfreset" then
            -- Reset performance statistics
            if addon.Modules.Utils and addon.Modules.Utils.ResetPerformanceStats then
                addon.Modules.Utils:ResetPerformanceStats()
                addon:Print("Performance stats reset")
            end

        elseif msg == "help" then
            -- Show help
            addon:Print("Commands:")
            addon:Print("/guda - Toggle bags")
            addon:Print("/guda bank - Toggle bank")
            addon:Print("/guda mail - Toggle mailbox")
            addon:Print("/guda sort - Sort bags")
            addon:Print("/guda sortbank - Sort bank")
            addon:Print("/guda track - Toggle item tracking")
            addon:Print("/guda debug - Toggle debug mode")
            addon:Print("/guda debugsort - Toggle sort debug output")
            addon:Print("/guda cleanup - Remove old characters")
            addon:Print("/guda perf - Show performance stats")
            addon:Print("/guda perfreset - Reset performance stats")

        else
            addon:Print("Unknown command. Type /guda help for commands")
        end
    end

    addon:Debug("Slash commands registered")
end

-- Run initialization
Main:Initialize()
