-- Guda Utility Functions

local addon = Guda

local Utils = {}
addon.Modules.Utils = Utils

--=============================================================================
-- Tooltip Scan Caching
-- Caches results of expensive tooltip scanning operations
--=============================================================================
local tooltipCache = {
    questItem = {},       -- IsQuestItem results
    specialText = {},     -- HasSpecialTooltipText results
    bindOnEquip = {},     -- IsBindOnEquip results
    uniqueItem = {},      -- IsUniqueItem results
    restoreTag = {},      -- GetConsumableRestoreTag results
}
local tooltipCacheStats = {
    hits = 0,
    misses = 0,
}

-- Clear all tooltip caches
function Utils:ClearTooltipCache()
    tooltipCache.questItem = {}
    tooltipCache.specialText = {}
    tooltipCache.bindOnEquip = {}
    tooltipCache.uniqueItem = {}
    tooltipCache.restoreTag = {}
    tooltipCacheStats.hits = 0
    tooltipCacheStats.misses = 0
    addon:Debug("Tooltip cache cleared")
end

-- Get tooltip cache statistics
function Utils:GetTooltipCacheStats()
    local total = tooltipCacheStats.hits + tooltipCacheStats.misses
    local hitRate = total > 0 and (tooltipCacheStats.hits / total * 100) or 0
    return {
        hits = tooltipCacheStats.hits,
        misses = tooltipCacheStats.misses,
        total = total,
        hitRate = hitRate,
    }
end

-- Generate cache key from item link
local function GetTooltipCacheKey(itemLink)
    if not itemLink then return nil end
    -- Extract item ID from link for stable caching
    local _, _, itemID = string.find(itemLink, "item:(%d+)")
    return itemID
end

--=============================================================================
-- Frame Budget System (Baganator-inspired performance optimization)
-- Prevents any single operation from causing frame lag by spreading work
-- across multiple frames when operations exceed a time budget.
--=============================================================================

-- Frame budget configuration
local FRAME_BUDGET_SECONDS = 0.1  -- 100ms budget per frame (same as Baganator)
local lastEntryTime = 0
local workQueue = {}
local workQueueFrame = nil

-- Report that we're starting work (call at the beginning of expensive operations)
-- This resets the frame budget timer
function Utils:ReportEntry()
    lastEntryTime = GetTime()
end

-- Check if we've exceeded the frame budget
-- Returns true if we should defer remaining work to the next frame
function Utils:CheckTimeout()
    return (GetTime() - lastEntryTime) > FRAME_BUDGET_SECONDS
end

-- Queue work to be executed in the next frame
-- callback: function to call
-- context: optional context/owner for the callback (for debugging/cleanup)
function Utils:QueueWork(callback, context)
    if type(callback) ~= "function" then
        addon:Error("QueueWork: callback must be a function")
        return
    end

    table.insert(workQueue, {callback = callback, context = context or "unknown"})

    -- Create the work queue processor frame if it doesn't exist
    if not workQueueFrame then
        workQueueFrame = CreateFrame("Frame", "Guda_WorkQueueFrame", UIParent)
        workQueueFrame.elapsed = 0
        workQueueFrame:Hide()

        workQueueFrame:SetScript("OnUpdate", function()
            -- Process queued work with frame budget
            Utils:ReportEntry()

            local processedCount = 0
            local maxPerFrame = 50  -- Safety limit to prevent infinite loops

            while table.getn(workQueue) > 0 and processedCount < maxPerFrame do
                -- Check if we've exceeded frame budget
                if Utils:CheckTimeout() then
                    -- Still have work but exceeded budget, continue next frame
                    addon:Debug("Frame budget exceeded, deferring %d items to next frame", table.getn(workQueue))
                    return
                end

                local work = table.remove(workQueue, 1)
                if work and work.callback then
                    local success, err = pcall(work.callback)
                    if not success then
                        addon:Error("QueueWork callback error [%s]: %s", tostring(work.context), tostring(err))
                    end
                end
                processedCount = processedCount + 1
            end

            -- All work done, hide the frame to stop OnUpdate
            if table.getn(workQueue) == 0 then
                workQueueFrame:Hide()
            end
        end)
    end

    -- Show the frame to start processing
    workQueueFrame:Show()
end

-- Clear all queued work (useful when frame is hidden)
function Utils:ClearWorkQueue()
    workQueue = {}
    if workQueueFrame then
        workQueueFrame:Hide()
    end
end

-- Get the number of items in the work queue (for debugging)
function Utils:GetWorkQueueSize()
    return table.getn(workQueue)
end

-- Process items in batches with frame budget awareness
-- items: table of items to process
-- processor: function(item, index) called for each item
-- onComplete: optional function called when all items are processed
-- batchSize: optional number of items to process before checking timeout (default 10)
function Utils:ProcessWithBudget(items, processor, onComplete, batchSize)
    if not items or table.getn(items) == 0 then
        if onComplete then onComplete() end
        return
    end

    batchSize = batchSize or 10
    local index = 1
    local totalItems = table.getn(items)

    local function processNextBatch()
        Utils:ReportEntry()
        local batchCount = 0

        while index <= totalItems and batchCount < batchSize do
            if Utils:CheckTimeout() then
                -- Budget exceeded, queue continuation
                Utils:QueueWork(processNextBatch, "ProcessWithBudget")
                return
            end

            local item = items[index]
            if item then
                local success, err = pcall(processor, item, index)
                if not success then
                    addon:Error("ProcessWithBudget processor error at index %d: %s", index, tostring(err))
                end
            end

            index = index + 1
            batchCount = batchCount + 1
        end

        -- Check if we have more items
        if index <= totalItems then
            -- More items to process, queue next batch
            Utils:QueueWork(processNextBatch, "ProcessWithBudget")
        else
            -- All done
            if onComplete then
                local success, err = pcall(onComplete)
                if not success then
                    addon:Error("ProcessWithBudget onComplete error: %s", tostring(err))
                end
            end
        end
    end

    -- Start processing
    processNextBatch()
end

-- Performance metrics tracking
local performanceStats = {
    budgetExceededCount = 0,
    totalUpdates = 0,
    lastUpdateDuration = 0,
    averageUpdateDuration = 0,
}

-- Get the current frame budget setting (in seconds)
function Utils:GetFrameBudget()
    return FRAME_BUDGET_SECONDS
end

-- Set the frame budget (in seconds, min 0.016 = 60fps, max 0.5)
function Utils:SetFrameBudget(seconds)
    if type(seconds) ~= "number" then return end
    FRAME_BUDGET_SECONDS = math.max(0.016, math.min(0.5, seconds))
    addon:Debug("Frame budget set to %.3f seconds", FRAME_BUDGET_SECONDS)
end

-- Record the end of an update cycle for performance tracking
function Utils:RecordUpdateEnd()
    local duration = GetTime() - lastEntryTime
    performanceStats.lastUpdateDuration = duration
    performanceStats.totalUpdates = performanceStats.totalUpdates + 1

    -- Update rolling average
    local alpha = 0.1  -- Smoothing factor
    performanceStats.averageUpdateDuration = performanceStats.averageUpdateDuration * (1 - alpha) + duration * alpha

    if duration > FRAME_BUDGET_SECONDS then
        performanceStats.budgetExceededCount = performanceStats.budgetExceededCount + 1
    end
end

-- Get performance statistics
function Utils:GetPerformanceStats()
    return {
        frameBudget = FRAME_BUDGET_SECONDS,
        lastUpdateDuration = performanceStats.lastUpdateDuration,
        averageUpdateDuration = performanceStats.averageUpdateDuration,
        totalUpdates = performanceStats.totalUpdates,
        budgetExceededCount = performanceStats.budgetExceededCount,
        workQueueSize = table.getn(workQueue),
    }
end

-- Reset performance statistics
function Utils:ResetPerformanceStats()
    performanceStats.budgetExceededCount = 0
    performanceStats.totalUpdates = 0
    performanceStats.lastUpdateDuration = 0
    performanceStats.averageUpdateDuration = 0
end

-- Print current performance statistics (for debugging)
function Utils:PrintPerformanceStats()
    local stats = self:GetPerformanceStats()
    addon:Print("=== Guda Performance Stats ===")
    addon:Print("Frame Budget: %.0fms", stats.frameBudget * 1000)
    addon:Print("Last Update: %.1fms", stats.lastUpdateDuration * 1000)
    addon:Print("Avg Update: %.1fms", stats.averageUpdateDuration * 1000)
    addon:Print("Total Updates: %d", stats.totalUpdates)
    addon:Print("Budget Exceeded: %d times", stats.budgetExceededCount)
    addon:Print("Work Queue: %d items", stats.workQueueSize)
end

--=============================================================================
-- SafeCall: Nil-safe module method invocation
-- Replaces verbose nil-checks like:
--   if addon and addon.Modules and addon.Modules.Utils and addon.Modules.Utils.Method then
--       return addon.Modules.Utils:Method(arg1, arg2)
--   end
-- With:
--   return Utils:SafeCall("Utils", "Method", arg1, arg2)
--=============================================================================

-- Call a method on a module safely, returns nil if module/method doesn't exist
-- Parameters:
--   moduleName: Name of the module in addon.Modules (e.g., "Utils", "DB", "BagFrame")
--   methodName: Name of the method to call (e.g., "GetQualityColor", "GetSetting")
--   ...: Arguments to pass to the method
-- Returns: The return value(s) of the method, or nil if not callable
function Utils:SafeCall(moduleName, methodName, ...)
    if not addon or not addon.Modules then
        return nil
    end

    local module = addon.Modules[moduleName]
    if not module then
        return nil
    end

    local method = module[methodName]
    if not method or type(method) ~= "function" then
        return nil
    end

    -- Call method with module as self (for : style calls)
    return method(module, unpack(arg))
end

-- Check if a module method exists without calling it
function Utils:HasMethod(moduleName, methodName)
    if not addon or not addon.Modules then
        return false
    end

    local module = addon.Modules[moduleName]
    if not module then
        return false
    end

    local method = module[methodName]
    return method ~= nil and type(method) == "function"
end

-- Get a module reference safely
function Utils:GetModule(moduleName)
    if not addon or not addon.Modules then
        return nil
    end
    return addon.Modules[moduleName]
end

-- Format money (copper to gold/silver/copper string) - WoW 1.12.1 version
function Utils:FormatMoney(copper, showZero, useColors)
    if not copper or copper == 0 then
        if useColors then
            return "|cFFFFFFFF" .. "0" .. "|r" .. "|cFFEDA55F" .. "c" .. "|r"
        else
            return "0c"
        end
    end

    local gold = math.floor(copper / 10000)
    local silver = math.floor(mod(copper, 10000) / 100)
    local bronze = mod(copper, 100)

    local str = ""

    if useColors then
        -- Colored version for tooltips - white numbers, colored g/s/c letters
        if gold > 0 then
            str = str .. "|cFFFFFFFF" .. gold .. "|r" .. "|cFFFFD700" .. "g" .. "|r "
        end
        if silver > 0 or gold > 0 then
            str = str .. "|cFFFFFFFF" .. silver .. "|r" .. "|cFFC7C7CF" .. "s" .. "|r "
        end
        str = str .. "|cFFFFFFFF" .. bronze .. "|r" .. "|cFFEDA55F" .. "c" .. "|r"
    else
        -- Plain text version
        if gold > 0 then
            str = str .. gold .. "g "
        end
        if silver > 0 or gold > 0 then
            str = str .. silver .. "s "
        end
        str = str .. bronze .. "c"
    end

    return str
end

-- Get item info with caching
local itemCache = {}

-- Extract itemID from itemLink (Lua 5.0 compatible)
-- Returns: itemID as number, or nil if extraction fails
function Utils:ExtractItemID(itemLink)
    if not itemLink then return nil end
    local _, _, itemID = string.find(itemLink, "item:(%d+)")
    return itemID and tonumber(itemID) or nil
end

-- Get item info with error handling (does not cache)
-- Turtle WoW GetItemInfo signature:
-- itemName, itemLink, itemRarity, itemLevel, itemCategory, itemType, itemStackCount, itemSubType, itemTexture, itemEquipLoc, itemSellPrice
function Utils:GetItemInfoSafe(itemID)
    if not itemID then
        addon:Debug("GetItemInfoSafe: nil itemID")
        return nil
    end

    local itemName, itemLink, itemRarity, itemLevel, itemCategory, itemType, itemStackCount, itemSubType, itemTexture, itemEquipLoc, itemSellPrice = GetItemInfo(itemID)

    if not itemName then
        addon:Debug("GetItemInfoSafe: GetItemInfo failed for itemID %d", itemID)
        return nil
    end

    return itemName, itemLink, itemRarity, itemLevel, itemCategory, itemType, itemStackCount, itemSubType, itemTexture, itemEquipLoc, itemSellPrice
end

-- Get item info with caching (wrapper for backward compatibility)
function Utils:GetItemInfo(itemLink)
    if not itemLink then return nil end

    if itemCache[itemLink] then
        return unpack(itemCache[itemLink])
    end

    local itemID = self:ExtractItemID(itemLink)
    if not itemID then return nil end

    local itemName, retLink, itemRarity, itemLevel, itemCategory, itemType, itemStackCount, itemSubType, itemTexture, itemEquipLoc, itemSellPrice = self:GetItemInfoSafe(itemID)

    if itemName then
        itemCache[itemLink] = {itemName, retLink, itemRarity, itemLevel, itemCategory, itemType, itemStackCount, itemSubType, itemTexture, itemEquipLoc, itemSellPrice}
        return itemName, retLink, itemRarity, itemLevel, itemCategory, itemType, itemStackCount, itemSubType, itemTexture, itemEquipLoc, itemSellPrice
    end

    return nil
end

-- Create a single shared tooltip for all scanning operations
-- This tooltip is used by: Utils, ItemDetection, SortEngine
local scanTooltip = CreateFrame("GameTooltip", "GudaScanTooltip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
local SCAN_TOOLTIP_NAME = "GudaScanTooltip"

-- Public getter for the shared scan tooltip (used by ItemDetection, SortEngine)
function Utils:GetScanTooltip()
    return scanTooltip, SCAN_TOOLTIP_NAME
end

-- Get item link from mailbox attachment (WoW 1.12.1 workaround)
function Utils:GetInboxItemLink(index, itemIndex)
    -- Try global function first (if it exists on this server/version)
    if GetInboxItemLink then
        -- Turtle WoW might support (index, itemIndex) for multiple attachments
        local link = GetInboxItemLink(index, itemIndex or 1)
        if link then return link end
        
        -- Fallback to single argument if that failed
        link = GetInboxItemLink(index)
        if link then return link end
    end

    -- In 1.12.1, GameTooltip:GetHyperlink() does not exist.
    -- Let's try to use GetItemInfo(name) as the primary way.
    local name, texture, count, quality = GetInboxItem(index, itemIndex or 1)
    if name then
        local itemName, link = GetItemInfo(name)
        if link then
            return link
        end
    end
    
    return nil
end

-- Get quality color
function Utils:GetQualityColor(quality)
    local color = addon.Constants.QUALITY_COLORS[quality] or addon.Constants.QUALITY_COLORS[1]
    return color.r, color.g, color.b
end

-- Create colored text
function Utils:ColorText(text, r, g, b)
    local red = math.floor(r * 255)
    local green = math.floor(g * 255)
    local blue = math.floor(b * 255)
    return string.format("|cFF%02X%02X%02X%s|r", red, green, blue, text)
end

-- Deep copy table
function Utils:DeepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[Utils:DeepCopy(orig_key)] = Utils:DeepCopy(orig_value)
        end
        setmetatable(copy, Utils:DeepCopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

-- Get class color
function Utils:GetClassColor(class)
    local colors = {
        WARRIOR = {r = 0.78, g = 0.61, b = 0.43},
        PALADIN = {r = 0.96, g = 0.55, b = 0.73},
        HUNTER = {r = 0.67, g = 0.83, b = 0.45},
        ROGUE = {r = 1.00, g = 0.96, b = 0.41},
        PRIEST = {r = 1.00, g = 1.00, b = 1.00},
        SHAMAN = {r = 0.00, g = 0.44, b = 0.87},
        MAGE = {r = 0.41, g = 0.80, b = 0.94},
        WARLOCK = {r = 0.58, g = 0.51, b = 0.79},
        DRUID = {r = 1.00, g = 0.49, b = 0.04},
    }
    return colors[class] or {r = 0.5, g = 0.5, b = 0.5}
end

-- Format time ago
function Utils:FormatTimeAgo(timestamp)
    local diff = time() - timestamp
    if diff < 60 then
        return "Just now"
    elseif diff < 3600 then
        return math.floor(diff / 60) .. "m ago"
    elseif diff < 86400 then
        return math.floor(diff / 3600) .. "h ago"
    else
        return math.floor(diff / 86400) .. "d ago"
    end
end

-- Create hidden tooltip for scanning (only once)
local function GetScanTooltip()
    return scanTooltip
end

-- Helper: Check if a color is yellow/gold (Use:, Equip:, Chance on hit: effects)
-- Yellow in WoW tooltips can be various shades:
--   Gold: RGB ~(1, 0.82, 0) or (255, 209, 0)
--   Yellow: RGB ~(1, 1, 0)
--   Light gold: RGB ~(1, 0.85, 0.1)
local function IsYellowColor(r, g, b)
    if not r or not g or not b then return false end
    -- Yellow/Gold: high red (>0.8), medium-high green (>0.5), low blue (<0.4)
    return r > 0.8 and g > 0.5 and b < 0.4
end

-- Helper: Check if a color is green (set bonuses, special properties)
-- Green in WoW tooltips is typically RGB ~(0, 1, 0) or (0.12, 1, 0)
local function IsGreenColor(r, g, b)
    if not r or not g or not b then return false end
    -- Green: low red (<0.4), high green (>0.7), low blue (<0.4)
    return r < 0.4 and g > 0.7 and b < 0.4
end

-- Patterns that indicate an item has special functionality (not junk)
local SPECIAL_TEXT_PATTERNS = {
    -- Use effects
    "use:",
    "use :",
    -- Equip effects
    "equip:",
    "equip :",
    -- Proc effects
    "chance on hit:",
    "chance on hit :",
    "chance to",
    "chance on",
    -- Stat effects
    "increases",
    "improves",
    "restores",
    "regenerate",
    "generates",
    "absorbs",
    "reduces",
    "grants",
    "gives",
    -- Learning
    "teaches",
    "learn",
    -- Special actions
    "creates",
    "summons",
    "teleports",
    "opens",
    "activates",
    -- Resistance/stats
    "resistance",
    "armor",
    "damage",
    "healing",
    "mana",
    "health",
    "spirit",
    "intellect",
    "stamina",
    "strength",
    "agility",
}

-- Check if an item's tooltip contains yellow or green description text
-- This indicates the item has a use effect, equip effect, or special property
-- Returns: hasSpecialText (boolean), textType ("yellow", "green", or nil)
function Utils:HasSpecialTooltipText(bagID, slotID, itemLink)
    bagID = tonumber(bagID)
    slotID = tonumber(slotID)

    -- Get item link for cache key if not provided
    local cacheLink = itemLink
    if not cacheLink and bagID and slotID then
        cacheLink = GetContainerItemLink(bagID, slotID)
    end

    -- Check cache first
    local cacheKey = GetTooltipCacheKey(cacheLink)
    if cacheKey and tooltipCache.specialText[cacheKey] ~= nil then
        tooltipCacheStats.hits = tooltipCacheStats.hits + 1
        local cached = tooltipCache.specialText[cacheKey]
        return cached.hasSpecial, cached.textType
    end
    tooltipCacheStats.misses = tooltipCacheStats.misses + 1

    local tooltip = GetScanTooltip()
    if not tooltip then return false, nil end

    tooltip:ClearLines()

    -- Set the tooltip to the item
    if bagID and slotID then
        tooltip:SetBagItem(bagID, slotID)
    elseif itemLink then
        local _, _, itemString = string.find(itemLink, "(item:%d+:%d+:%d+:%d+)")
        if itemString then
            tooltip:SetHyperlink(itemString)
        else
            return false, nil
        end
    else
        return false, nil
    end

    local numLines = tooltip:NumLines() or 0
    if numLines == 0 then
        -- Cache negative result
        if cacheKey then
            tooltipCache.specialText[cacheKey] = { hasSpecial = false, textType = nil }
        end
        return false, nil
    end

    -- Scan tooltip lines for yellow or green text
    for i = 2, numLines do  -- Start from line 2 (skip item name on line 1)
        local leftLine = getglobal("GudaScanTooltipTextLeft" .. i)
        if leftLine and leftLine:IsShown() then
            local text = leftLine:GetText()
            local r, g, b = leftLine:GetTextColor()

            if text and r and g and b then
                local textLower = string.lower(text)

                -- Check for yellow/gold text (Use:, Equip:, Chance on hit:, etc.)
                if IsYellowColor(r, g, b) then
                    -- Check if it matches any special text pattern
                    for _, pattern in ipairs(SPECIAL_TEXT_PATTERNS) do
                        if string.find(textLower, pattern) then
                            addon:Debug("HasSpecialTooltipText: YELLOW match '%s' in: %s", pattern, text)
                            -- Cache positive result
                            if cacheKey then
                                tooltipCache.specialText[cacheKey] = { hasSpecial = true, textType = "yellow" }
                            end
                            return true, "yellow"
                        end
                    end
                end

                -- Check for green text (set bonuses, enchants, special properties)
                -- Green text is ALWAYS considered special (no pattern check needed)
                if IsGreenColor(r, g, b) then
                    addon:Debug("HasSpecialTooltipText: Found GREEN text: %s (r=%.2f g=%.2f b=%.2f)", text, r, g, b)
                    -- Cache positive result
                    if cacheKey then
                        tooltipCache.specialText[cacheKey] = { hasSpecial = true, textType = "green" }
                    end
                    return true, "green"
                end

                -- Also check for "Use:" or "Equip:" regardless of color (some items may have different colors)
                if string.find(textLower, "^use:") or string.find(textLower, "^equip:") then
                    addon:Debug("HasSpecialTooltipText: Found Use/Equip text: %s", text)
                    -- Cache positive result
                    if cacheKey then
                        tooltipCache.specialText[cacheKey] = { hasSpecial = true, textType = "yellow" }
                    end
                    return true, "yellow"
                end
            end
        end

        -- Also check right side of tooltip
        local rightLine = getglobal("GudaScanTooltipTextRight" .. i)
        if rightLine and rightLine:IsShown() then
            local text = rightLine:GetText()
            local r, g, b = rightLine:GetTextColor()

            if text and r and g and b then
                if IsYellowColor(r, g, b) or IsGreenColor(r, g, b) then
                    addon:Debug("HasSpecialTooltipText: Found special text (right): %s", text)
                    local textType = IsYellowColor(r, g, b) and "yellow" or "green"
                    -- Cache positive result
                    if cacheKey then
                        tooltipCache.specialText[cacheKey] = { hasSpecial = true, textType = textType }
                    end
                    return true, textType
                end
            end
        end
    end

    -- Cache negative result
    if cacheKey then
        tooltipCache.specialText[cacheKey] = { hasSpecial = false, textType = nil }
    end
    return false, nil
end

-- Check if an item is a quest item by scanning its tooltip (internal helper)
-- Returns: isQuestItem, isQuestStarter
local function ScanTooltipForQuest(tooltip, tooltipName)
    local isQuestItem = false
    local isQuestStarter = false

    for i = 1, tooltip:NumLines() do
        local line = getglobal(tooltipName .. "TextLeft" .. i)
        if line then
            local text = line:GetText()
            if text then
                local tl = string.lower(text)
                -- Check for quest starter patterns first
                if string.find(tl, "quest starter") or
                   string.find(tl, "this item begins a quest") or
                   string.find(tl, "starts a quest") then
                    isQuestItem = true
                    isQuestStarter = true
                    break
                -- Check for regular quest item patterns
                elseif string.find(tl, "quest item") or
                       string.find(tl, "manual") then
                    isQuestItem = true
                    -- Don't break, might still find a quest starter pattern
                end
            end
        end
    end

    return isQuestItem, isQuestStarter
end

-- Check if item has "Permanently..." text (enchanting scrolls/vellums)
-- These should NOT be considered quest items even if they have Quest category
local function IsPermanentEnchantItem(tooltip, tooltipName)
    if not tooltip then return false end
    local numLines = tooltip:NumLines() or 0
    for i = 1, numLines do
        local line = getglobal(tooltipName .. "TextLeft" .. i)
        if line then
            local text = line:GetText()
            if text then
                local tl = string.lower(text)
                if string.find(tl, "permanently") then
                    return true
                end
            end
        end
    end
    return false
end

-- Consolidated quest item detection function
-- Handles tooltip scanning, category checks, equipment filtering, and QuestItemsDB lookup
-- Parameters:
--   bagID, slotID: Required for tooltip scanning (can be nil for other char items)
--   itemData: Optional item data table with link, class/category, type fields
--   isOtherChar: Boolean, true if checking an item from another character's saved data
--   isBank: Boolean, true if the item is in the bank
-- Returns: isQuestItem (boolean), isQuestStarter (boolean)
function Utils:IsQuestItem(bagID, slotID, itemData, isOtherChar, isBank)
    bagID = tonumber(bagID)
    slotID = tonumber(slotID)

    local isQuestItem = false
    local isQuestStarter = false

    -- Get item link and category info
    local itemLink = itemData and itemData.link
    local itemCategory = itemData and (itemData.class or itemData.category) or ""
    local itemType = itemData and itemData.type or ""
    local itemID

    -- For live items, query the link directly
    if not isOtherChar and bagID and slotID then
        itemLink = GetContainerItemLink(bagID, slotID)
    end

    if itemLink then
        itemID = self:ExtractItemID(itemLink)
        if itemID then
            local _, _, _, _, cat, typ = self:GetItemInfoSafe(itemID)
            itemCategory = cat or itemCategory
            itemType = typ or itemType
        end
    end

    -- Check if item is equipment (should not be classified as quest unless explicitly Quest category)
    local isEquipment = (itemCategory == "Weapon" or itemCategory == "Armor" or
                         itemType == "Weapon" or itemType == "Armor")
    local isQuestCategory = (itemCategory == "Quest" or itemType == "Quest")

    -- Priority 1: If explicitly categorized as Quest, check if it's actually an enchant item first
    if isQuestCategory then
        -- Check tooltip for "Permanently" (enchanting scrolls should not be quest items)
        if not isOtherChar and bagID and slotID then
            local tooltip = GetScanTooltip()
            tooltip:ClearLines()
            tooltip:SetBagItem(bagID, slotID)
            if IsPermanentEnchantItem(tooltip, "GudaScanTooltip") then
                return false, false  -- Not a quest item, it's an enchant scroll
            end
            -- Also scan for quest starter text
            local _, starterDetected = ScanTooltipForQuest(tooltip, "GudaScanTooltip")
            return true, starterDetected
        end
        return true, false
    end

    -- Priority 2: Tooltip scanning for current character items
    if not isOtherChar and bagID and slotID then
        local tooltip = GetScanTooltip()
        tooltip:ClearLines()

        -- Handle bank items differently
        if isBank and bagID == -1 then
            if tooltip.SetInventoryItem then
                tooltip:SetInventoryItem("player", 39 + slotID)
            else
                tooltip:SetBagItem(bagID, slotID)
            end
        else
            tooltip:SetBagItem(bagID, slotID)
        end

        isQuestItem, isQuestStarter = ScanTooltipForQuest(tooltip, "GudaScanTooltip")

        -- Filter out equipment that has quest-like text but isn't categorized as Quest
        if isQuestItem and isEquipment and not isQuestCategory then
            isQuestItem = false
            isQuestStarter = false
        end
    end

    -- Priority 3: Check QuestItemsDB for known faction-specific quest items
    if not isQuestItem and itemID and addon.IsQuestItemByID then
        local playerFaction = UnitFactionGroup("player")
        if addon:IsQuestItemByID(itemID, playerFaction) then
            isQuestItem = true
        end
    end

    return isQuestItem, isQuestStarter
end

-- Legacy compatibility wrapper - keep the old function name working
function Utils:IsQuestItemTooltip(bagID, slotID)
    local isQuest, _ = self:IsQuestItem(bagID, slotID, nil, false, false)
    return isQuest
end

-- Check if an item has a gray title in its tooltip or link
function Utils:IsItemGrayTooltip(bagID, slotID, itemLink)
    -- Check link first if provided (works for other characters too)
    if itemLink and string.find(itemLink, "|cff9d9d9d") then
        return true
    end

    if not bagID or not slotID then return false end

    local tooltip = GetScanTooltip()
    tooltip:ClearLines()
    tooltip:SetBagItem(bagID, slotID)

    local line = getglobal("GudaScanTooltipTextLeft1")
    if line then
        local text = line:GetText()
        if text then
            -- Poor quality color code is |cff9d9d9d
            if string.find(text, "|cff9d9d9d") then
                return true
            end
        end
    end
    return false
end

-- Get bag slot count
function Utils:GetBagSlotCount(bagID)
    if bagID == -1 then
        -- Bank has 24 slots in vanilla
        return 24
    elseif bagID == -2 then
        -- Keyring - vanilla WoW has 12-32 slots depending on version
        local slots = GetContainerNumSlots(bagID)
        if not slots or slots == 0 then
            -- Fallback: keyring typically has 12 slots in vanilla
            return 12
        end
        return slots
    else
        return GetContainerNumSlots(bagID) or 0
    end
end

-- Check if bag is valid
function Utils:IsBagValid(bagID)
    if bagID == 0 or bagID == -1 or bagID == -2 then
        return true
    end
    return GetContainerNumSlots(bagID) and GetContainerNumSlots(bagID) > 0
end

-- Truncate text to length
function Utils:TruncateText(text, maxLen)
    if not text then return "" end
    if string.len(text) <= maxLen then
        return text
    end
    return string.sub(text, 1, maxLen - 3) .. "..."
end

-- Returns: "soul", "herb", "enchant", "quiver", "ammo", or nil
-- This is the consolidated bag type detection function with tooltip fallback
function Utils:GetSpecializedBagType(bagID)
    -- Skip backpack, bank, and keyring
    if bagID == 0 or bagID == -1 or bagID == -2 then
        return nil
    end

    -- Get the bag item
    local invSlot = ContainerIDToInventoryID(bagID)
    if not invSlot then
        return nil
    end

    local link = GetInventoryItemLink("player", invSlot)
    if not link then
        return nil
    end

    local itemID = self:ExtractItemID(link)

    -- Try GetItemInfo first (more reliable when available)
    if itemID then
        local _, _, _, _, _, itemType = self:GetItemInfoSafe(itemID)
        if itemType then
            local typeLower = string.lower(itemType)

            if string.find(typeLower, "soul bag") or string.find(typeLower, "soul pouch") then
                return "soul"
            end
            if string.find(typeLower, "herb bag") then
                return "herb"
            end
            if string.find(typeLower, "enchanting bag") then
                return "enchant"
            end
            if string.find(typeLower, "quiver") then
                return "quiver"
            end
            if string.find(typeLower, "ammo pouch") then
                return "ammo"
            end
        end
    end

    -- Fallback: tooltip scanning for all bag types
    local tooltip = GetScanTooltip()
    tooltip:ClearLines()
    tooltip:SetInventoryItem("player", invSlot)

    for i = 1, tooltip:NumLines() do
        local line = getglobal("GudaScanTooltipTextLeft" .. i)
        if line then
            local text = line:GetText()
            if text then
                local textLower = string.lower(text)

                -- Soul Bag / Soul Pouch
                if string.find(textLower, "soul bag") or string.find(textLower, "soul pouch") or
                   (string.find(textLower, "soul") and (string.find(textLower, "bag") or string.find(textLower, "pouch"))) then
                    return "soul"
                end

                -- Herb Bag
                if string.find(textLower, "herb bag") then
                    return "herb"
                end

                -- Enchanting Bag
                if string.find(textLower, "enchanting bag") then
                    return "enchant"
                end

                -- Quiver
                if string.find(textLower, "quiver") then
                    return "quiver"
                end

                -- Ammo Pouch
                if string.find(textLower, "ammo pouch") then
                    return "ammo"
                end
            end
        end
    end

    return nil
end

-- Simple helper to check if a bag is of a specific type
function Utils:IsBagType(bagID, bagType)
    return self:GetSpecializedBagType(bagID) == bagType
end

-- Convenience wrappers for common bag type checks
function Utils:IsAmmoQuiverBag(bagID)
    local bagType = self:GetSpecializedBagType(bagID)
    return bagType == "quiver" or bagType == "ammo"
end

function Utils:IsHerbBag(bagID)
    return self:IsBagType(bagID, "herb")
end

function Utils:IsSoulBag(bagID)
    return self:IsBagType(bagID, "soul")
end

-- Get container priority for sorting (higher = more important)
function Utils:GetContainerPriority(bagID)
    local bagType = self:GetSpecializedBagType(bagID)
    if bagType == "enchant" then
        return 50
    elseif bagType == "herb" then
        return 45
    elseif bagType == "soul" then
        return 40
    elseif bagType == "quiver" then
        return 30
    elseif bagType == "ammo" then
        return 20
    else
        return 10  -- Regular bag
    end
end

-- Soul Shard item ID
local SOUL_SHARD_ID = 6265

-- Check if item is a Soul Shard
function Utils:IsSoulShard(itemLink)
    if not itemLink then return false end
    local itemID = self:ExtractItemID(itemLink)
    return itemID == SOUL_SHARD_ID
end

-- Extract hyperlink from item link for tooltip scanning
local function ExtractHyperlink(itemLink)
    if not itemLink then return nil end
    local _, _, hyperlink = string.find(itemLink, "|H(.+)|h")
    return hyperlink
end

-- Detect if a consumable has 'Use: Restores' or mentions 'while eating'/'while drinking'
function Utils:GetConsumableRestoreTag(bagID, slotID, itemLink)
    if not bagID or not slotID then return nil end

    -- Get item link for cache key if not provided
    local cacheLink = itemLink or GetContainerItemLink(bagID, slotID)

    -- Check cache first
    local cacheKey = GetTooltipCacheKey(cacheLink)
    if cacheKey and tooltipCache.restoreTag[cacheKey] ~= nil then
        tooltipCacheStats.hits = tooltipCacheStats.hits + 1
        local cached = tooltipCache.restoreTag[cacheKey]
        -- Return nil if cached as false, otherwise return the tag
        return cached ~= false and cached or nil
    end
    tooltipCacheStats.misses = tooltipCacheStats.misses + 1

    local tooltip = GetScanTooltip()
    tooltip:ClearLines()
    tooltip:SetBagItem(bagID, slotID)
    local tag = nil
    for i = 1, tooltip:NumLines() do
        local line = getglobal("GudaScanTooltipTextLeft" .. i)
        if line then
            local text = line:GetText()
            if text then
                local tl = string.lower(text)
                if string.find(tl, "while eating") then
                    tag = "eat"
                    break
                elseif string.find(tl, "while drinking") then
                    tag = "drink"
                    break
                elseif string.find(tl, "use: restores") then
                    tag = "restore"
                end
            end
        end
    end

    -- Cache the result (nil becomes false for cache check purposes)
    if cacheKey then
        tooltipCache.restoreTag[cacheKey] = tag or false
    end

    return tag
end

-- Check if item is Arrow or Bullet (for Quiver routing)
function Utils:IsArrowOrBullet(itemType)
	if not itemType then return false end
	-- Exact matching only
	return itemType == "Arrow" or itemType == "Bullet"
end

-- Check if item is Ammo (any type - for Ammo Pouch)
function Utils:IsAmmo(itemType)
	if not itemType then return false end
	return itemType == "Arrow" or itemType == "Bullet"
end

-- Get preferred container type for an item
-- Returns: "soul", "herb", "enchant", "quiver", "ammo", or nil
function Utils:GetItemPreferredContainer(itemLink)
    if not itemLink then return nil end

    -- Check for soul shards first
    if self:IsSoulShard(itemLink) then
        return "soul"
    end

    -- Get item info using utility function
    local itemID = self:ExtractItemID(itemLink)
    if not itemID then return nil end

    local itemName, _, itemRarity, itemLevel, itemCategory, itemType, itemStackCount, itemSubType, itemTexture = self:GetItemInfoSafe(itemID)
    if not itemType then return nil end

    -- Only route PROJECTILE category items that are specifically arrows or bullets
    if itemCategory == "Projectile" then
        if itemType == "Arrow" then
            return "quiver"
        elseif itemType == "Bullet" then
            return "ammo"
        end
    end

    -- Route herbs to herb bags (robust: category/subtype OR texture pattern fallback)
    if self:IsHerbItem(itemLink) then
        return "herb"
    end

    -- Route enchanting materials to enchanting bags
    if self:IsEnchantingItem(itemLink) then
        return "enchant"
    end

    return nil
end

-- Check if an item is "Binds when equipped" by scanning its tooltip
-- For bank items, use itemLink since SetBagItem may not work for bank slots
function Utils:IsBindOnEquip(bagID, slotID, itemLink)
    if not bagID or not slotID then return false end

    -- Get item link for cache key if not provided
    local cacheLink = itemLink or GetContainerItemLink(bagID, slotID)

    -- Check cache first
    local cacheKey = GetTooltipCacheKey(cacheLink)
    if cacheKey and tooltipCache.bindOnEquip[cacheKey] ~= nil then
        tooltipCacheStats.hits = tooltipCacheStats.hits + 1
        return tooltipCache.bindOnEquip[cacheKey]
    end
    tooltipCacheStats.misses = tooltipCacheStats.misses + 1

    local tooltip = GetScanTooltip()
    if not tooltip then return false end

    tooltip:ClearLines()

    -- Try SetBagItem first (works for regular bags and bank when open)
    tooltip:SetBagItem(bagID, slotID)

    local numLines = tooltip:NumLines()

    -- If no lines and we have itemLink, try SetHyperlink with itemString as fallback
    if (not numLines or numLines == 0) and itemLink then
        -- Extract itemString from link (format: item:12345:0:0:0...)
        local _, _, itemString = string.find(itemLink, "(item:%d+:%d+:%d+:%d+)")
        if itemString then
            tooltip:ClearLines()
            tooltip:SetHyperlink(itemString)
            numLines = tooltip:NumLines()
        end
    end

    if not numLines or numLines == 0 then
        if cacheKey then tooltipCache.bindOnEquip[cacheKey] = false end
        return false
    end

    -- Check tooltip lines for "Binds when equipped"
    for i = 1, numLines do
        local line = getglobal("GudaScanTooltipTextLeft" .. i)
        if line then
            local text = line:GetText()
            if text and string.find(string.lower(text), "binds when equipped") then
                if cacheKey then tooltipCache.bindOnEquip[cacheKey] = true end
                return true
            end
        end
    end

    if cacheKey then tooltipCache.bindOnEquip[cacheKey] = false end
    return false
end

-- Check if an item is "Unique" by scanning its tooltip
function Utils:IsUniqueItem(bagID, slotID, itemLink)
    if not bagID or not slotID then return false end

    -- Get item link for cache key if not provided
    local cacheLink = itemLink or GetContainerItemLink(bagID, slotID)

    -- Check cache first
    local cacheKey = GetTooltipCacheKey(cacheLink)
    if cacheKey and tooltipCache.uniqueItem[cacheKey] ~= nil then
        tooltipCacheStats.hits = tooltipCacheStats.hits + 1
        return tooltipCache.uniqueItem[cacheKey]
    end
    tooltipCacheStats.misses = tooltipCacheStats.misses + 1

    local tooltip = GetScanTooltip()
    if not tooltip then
        if cacheKey then tooltipCache.uniqueItem[cacheKey] = false end
        return false
    end

    tooltip:ClearLines()

    -- Try SetBagItem first (works for regular bags and bank when open)
    tooltip:SetBagItem(bagID, slotID)

    local numLines = tooltip:NumLines()

    -- If no lines and we have itemLink, try SetHyperlink with itemString as fallback
    if (not numLines or numLines == 0) and itemLink then
        local _, _, itemString = string.find(itemLink, "(item:%d+:%d+:%d+:%d+)")
        if itemString then
            tooltip:ClearLines()
            tooltip:SetHyperlink(itemString)
            numLines = tooltip:NumLines()
        end
    end

    if not numLines or numLines == 0 then
        if cacheKey then tooltipCache.uniqueItem[cacheKey] = false end
        return false
    end

    -- Check tooltip lines for "Unique" (but not "Unique-Equipped")
    for i = 1, numLines do
        local line = getglobal("GudaScanTooltipTextLeft" .. i)
        if line then
            local text = line:GetText()
            if text then
                local textLower = string.lower(text)
                -- Match "unique" but not "unique-equipped"
                if textLower == "unique" or string.find(textLower, "^unique$") or string.find(textLower, "^unique%s") then
                    if cacheKey then tooltipCache.uniqueItem[cacheKey] = true end
                    return true
                end
            end
        end
    end

    if cacheKey then tooltipCache.uniqueItem[cacheKey] = false end
    return false
end

-- Check if an item is equipment (armor, weapon, or other equippable)
-- Returns: true if item is equipment, false otherwise
function Utils:IsEquipment(itemLink)
	if not itemLink then return false end

	local itemID = self:ExtractItemID(itemLink)
	if not itemID then return false end

	local itemName, _, itemRarity, itemLevel, itemCategory, itemType, itemStackCount, itemSubType, itemTexture, itemEquipLoc = self:GetItemInfoSafe(itemID)

	-- Check if item has an equip location (most reliable method)
	if itemEquipLoc and itemEquipLoc ~= "" and itemEquipLoc ~= "INVTYPE_BAG" then
		return true
	end

	-- Fallback: Check category (in case itemEquipLoc is not set)
	if itemCategory then
		local categoryLower = string.lower(itemCategory)
		if categoryLower == "armor" or categoryLower == "weapon" then
			return true
		end
	end

 return false
end

-- Determine if an item is a herb (for routing to herb bags)
-- NEW rule (per request): require BOTH
--   1) itemCategory == "Trade Goods"
--   2) texture contains "INV_Misc_Herb" (case-insensitive; prefix tolerated)
function Utils:IsHerbItem(itemLink)
    if not itemLink then return false end

    local itemID = self:ExtractItemID(itemLink)
    if not itemID then return false end

    local name, _, quality, iLevel, itemCategory, itemType, itemStackCount, itemSubType, itemTexture = self:GetItemInfoSafe(itemID)

    if itemCategory ~= "Trade Goods" then
        return false
    end

    if not itemTexture then
        return false
    end

    -- Normalize and check texture name
    local tex = string.lower(itemTexture)
    tex = string.gsub(tex, "^interface\\\\icons\\\\", "")

    if string.find(tex, "inv_misc_herb") or string.find(tex, "misc_herb") then
        return true
    end

    return false
end

-- Determine if an item is an enchanting material (for routing to enchanting bags)
-- Rules:
--   1) itemCategory == "Trade Goods"
--   2) (itemSubType == "Enchanting") OR texture contains "INV_Enchant" (case-insensitive)
function Utils:IsEnchantingItem(itemLink)
    if not itemLink then return false end

    local itemID = self:ExtractItemID(itemLink)
    if not itemID then return false end

    local name, _, quality, iLevel, itemCategory, itemType, itemStackCount, itemSubType, itemTexture = self:GetItemInfoSafe(itemID)

    if itemCategory ~= "Trade Goods" then
        -- Some private servers may report Enchanting directly as type
        if itemType ~= "Enchanting" and itemSubType ~= "Enchanting" then
            return false
        end
    end

    -- If explicit Enchanting subtype/type, accept immediately
    if itemType == "Enchanting" or itemSubType == "Enchanting" then
        return true
    end

    if not itemTexture then
        return false
    end

    -- Normalize and check texture name
    local tex = string.lower(itemTexture)
    tex = string.gsub(tex, "^interface\\\\icons\\\\", "")

    if string.find(tex, "inv_enchant") or string.find(tex, "enchant") then
        return true
    end

    return false
end

-- Check if a bag is Enchanting Bag
function Utils:IsEnchantBag(bagID)
    return self:IsBagType(bagID, "enchant")
end