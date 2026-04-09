-- Guda Main Initialization
-- Sets up all modules and auto-save system

local addon = Guda
local L = Guda_L

local Main = {}
addon.Modules.Main = Main

-- Initialize addon
function Main:Initialize()
    -- Wait for PLAYER_LOGIN to ensure saved variables are loaded
    addon.Modules.Events:OnPlayerLogin(function()
        addon:Print(L["Initializing..."])

        -- Initialize database
        addon.Modules.DB:Initialize()

        -- Initialize cross-account sharing (optional, requires GudaIO DLL)
        if addon.Modules.SharedData and addon.Modules.SharedData.Initialize then
            addon.Modules.SharedData:Initialize()
        end

        -- Initialize item detection (before scanners, as they may use it)
        if addon.Modules.ItemDetection then
            addon.Modules.ItemDetection:Initialize()
        end

        -- Initialize scanners
        addon.Modules.BagScanner:Initialize()
        addon.Modules.BankScanner:Initialize()
        addon.Modules.MailboxScanner:Initialize()
        addon.Modules.MoneyTracker:Initialize()
		addon.Modules.EquipmentScanner:Initialize()

        -- Initialize equipment sets (Outfitter/ItemRack integration)
        if addon.Modules.EquipmentSets then
            addon.Modules.EquipmentSets:Initialize()
        end

        -- Initialize UI
        addon:Print(L["Initializing UI..."])
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

        -- Initialize auto-loot handler (LOOT_OPENED listener)
        if addon.Modules.AutoLoot and addon.Modules.AutoLoot.Initialize then
            addon.Modules.AutoLoot:Initialize()
        end

        -- Initialize clam opener (registers BAG_UPDATE for auto-open)
        if addon.Modules.ClamOpener and addon.Modules.ClamOpener.Initialize then
            addon.Modules.ClamOpener:Initialize()
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
        addon:Print(L["Ready! Type /guda to open bags"])
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

        elseif msg == "openclams" or msg == "clams" then
            -- Open all clams in bags
            addon.Modules.ClamOpener:Open()

        elseif msg == "debug" then
            -- Toggle debug
            addon.DEBUG = not addon.DEBUG
            addon:Print(L["Debug mode: %s"], addon.DEBUG and L["ON"] or L["OFF"])

        elseif msg == "debugsort" then
            -- Toggle debug sort (verbose sorting output)
            addon.DEBUG_SORT = not addon.DEBUG_SORT
            addon:Print(L["Debug sort mode: %s"], addon.DEBUG_SORT and L["ON"] or L["OFF"])

        elseif msg == "debugcat" then
            -- Toggle debug category view (for troubleshooting layout issues)
            addon.DEBUG_CATEGORY = not addon.DEBUG_CATEGORY
            addon:Print(L["Debug category mode: %s"], addon.DEBUG_CATEGORY and L["ON"] or L["OFF"])

        elseif msg == "quest" then
            -- Toggle quest bar
            local show = not addon.Modules.DB:GetSetting("showQuestBar")
            addon.Modules.DB:SetSetting("showQuestBar", show)
            addon.Modules.QuestItemBar:Update()
            addon:Print(L["Quest bar: %s"], show and L["ON"] or L["OFF"])

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

        elseif msg == "settings" or msg == "options" or msg == "config" then
            -- Open settings window
            if Guda_OpenSettings then
                Guda_OpenSettings()
            elseif addon.Modules.SettingsPopup and addon.Modules.SettingsPopup.Toggle then
                addon.Modules.SettingsPopup:Toggle()
            else
                addon:Print(L["Settings window not available"])
            end

        elseif msg == "cleanup" then
            -- Cleanup old characters
            addon.Modules.DB:CleanupOldCharacters()

        elseif msg == "perf" or msg == "performance" then
            -- Show performance statistics
            if addon.Modules.Utils and addon.Modules.Utils.PrintPerformanceStats then
                addon.Modules.Utils:PrintPerformanceStats()
            else
                addon:Print(L["Performance stats not available"])
            end
            -- Also show category cache stats
            if addon.Modules.CategoryManager and addon.Modules.CategoryManager.GetCacheStats then
                local stats = addon.Modules.CategoryManager:GetCacheStats()
                addon:Print("Category Cache: %d hits, %d misses (%.1f%% hit rate)",
                    stats.hits, stats.misses, stats.hitRate)
            end
            -- Show tooltip cache stats
            if addon.Modules.Utils and addon.Modules.Utils.GetTooltipCacheStats then
                local stats = addon.Modules.Utils:GetTooltipCacheStats()
                addon:Print("Tooltip Cache: %d hits, %d misses (%.1f%% hit rate)",
                    stats.hits, stats.misses, stats.hitRate)
            end
            -- Show item detection cache stats
            if addon.Modules.ItemDetection and addon.Modules.ItemDetection.GetCacheStats then
                local stats = addon.Modules.ItemDetection:GetCacheStats()
                addon:Print("ItemDetection Cache: %d hits, %d misses (%.1f%% hit rate, %d items)",
                    stats.hits, stats.misses, stats.hitRate, stats.size)
            end
            -- Show button pool stats
            if Guda_GetButtonPoolStats then
                local stats = Guda_GetButtonPoolStats()
                addon:Print("Button Pool: %d total (%d shown, %d hidden, %d inUse, %d available, max %d)",
                    stats.total, stats.shown, stats.hidden, stats.inUse, stats.available, stats.maxSize)
            end

        elseif msg == "perfreset" then
            -- Reset performance statistics
            if addon.Modules.Utils and addon.Modules.Utils.ResetPerformanceStats then
                addon.Modules.Utils:ResetPerformanceStats()
                addon:Print(L["Performance stats reset"])
            end
            -- Also clear category cache
            if addon.Modules.CategoryManager and addon.Modules.CategoryManager.ClearCache then
                addon.Modules.CategoryManager:ClearCache()
            end
            -- Clear tooltip cache
            if addon.Modules.Utils and addon.Modules.Utils.ClearTooltipCache then
                addon.Modules.Utils:ClearTooltipCache()
            end
            -- Clear item detection cache
            if addon.Modules.ItemDetection and addon.Modules.ItemDetection.ClearCache then
                addon.Modules.ItemDetection:ClearCache()
            end

        elseif msg == "poolreset" then
            -- Reset button pool (only safe when no frames are visible)
            local bagFrame = getglobal("Guda_BagFrame")
            local bankFrame = getglobal("Guda_BankFrame")
            if (bagFrame and bagFrame:IsShown()) or (bankFrame and bankFrame:IsShown()) then
                addon:Print(L["Cannot reset pool while bag/bank frames are open. Close them first."])
            else
                if Guda_ResetButtonPool then
                    Guda_ResetButtonPool()
                    addon:Print(L["Button pool reset. Pool is now empty."])
                else
                    addon:Print(L["Button pool reset function not available."])
                end
            end

        elseif msg == "help" then
            -- Show help
            addon:Print(L["Commands:"])
            addon:Print(L["/guda - Toggle bags"])
            addon:Print(L["/guda bank - Toggle bank"])
            addon:Print(L["/guda mail - Toggle mailbox"])
            addon:Print(L["/guda settings - Open settings"])
            addon:Print(L["/guda sort - Sort bags"])
            addon:Print(L["/guda sortbank - Sort bank"])
            addon:Print(L["/guda openclams - Open all clams in bags"])
            addon:Print(L["/guda track - Toggle item tracking"])
            addon:Print(L["/guda debug - Toggle debug mode"])
            addon:Print(L["/guda debugsort - Toggle sort debug output"])
            addon:Print(L["/guda cleanup - Remove old characters"])
            addon:Print(L["/guda perf - Show performance stats"])
            addon:Print(L["/guda perfreset - Reset performance stats"])
            addon:Print(L["/guda poolreset - Reset button pool (debug)"])

        else
            addon:Print(L["Unknown command. Type /guda help for commands"])
        end
    end

    addon:Debug("Slash commands registered")
end

-- Run initialization
Main:Initialize()
