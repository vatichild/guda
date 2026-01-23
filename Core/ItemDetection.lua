-- Guda Item Detection
-- Centralized item property detection with caching
-- Used by: CategoryManager, SortEngine, QuestItemBar, ItemButton, BagFrame, BankFrame

local addon = Guda

local ItemDetection = {}
addon.Modules.ItemDetection = ItemDetection

--=====================================================
-- Detection Result Caching
-- Caches tooltip scan results to avoid repeated scans
--=====================================================
local detectionCache = {}
local cacheHits = 0
local cacheMisses = 0

-- Clear the detection cache
function ItemDetection:ClearCache()
    detectionCache = {}
    cacheHits = 0
    cacheMisses = 0
end

-- Get cache statistics
function ItemDetection:GetCacheStats()
    local total = cacheHits + cacheMisses
    local hitRate = total > 0 and (cacheHits / total * 100) or 0
    local size = 0
    for _ in pairs(detectionCache) do size = size + 1 end
    return {
        hits = cacheHits,
        misses = cacheMisses,
        total = total,
        hitRate = hitRate,
        size = size,
    }
end

-- Generate cache key for an item
local function GetCacheKey(itemLink)
    if not itemLink then return nil end
    return itemLink
end

--=====================================================
-- Tooltip Scanning Helpers
--=====================================================

-- Get or create the scanning tooltip
local scanTooltip = nil
local function GetScanTooltip()
    if not scanTooltip then
        scanTooltip = CreateFrame("GameTooltip", "GudaItemDetectionTooltip", nil, "GameTooltipTemplate")
        scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end
    return scanTooltip
end

-- Scan tooltip and return all text lines
local function ScanTooltipLines(bagID, slotID, itemLink)
    local tooltip = GetScanTooltip()
    local tooltipName = "GudaItemDetectionTooltip"

    -- Ensure tooltip owner is set before each scan
    tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    tooltip:ClearLines()

    -- Set tooltip based on what we have
    if bagID and slotID then
        if bagID == -1 then
            -- Bank main bag: use SetInventoryItem (slot 39 + slotID)
            if tooltip.SetInventoryItem then
                tooltip:SetInventoryItem("player", 39 + slotID)
            else
                -- Fallback to hyperlink if SetInventoryItem not available
                if itemLink then
                    tooltip:SetHyperlink(itemLink)
                else
                    return {}
                end
            end
        else
            -- Regular bags and bank bags (5-11)
            tooltip:SetBagItem(bagID, slotID)
        end
    elseif itemLink then
        tooltip:SetHyperlink(itemLink)
    else
        return {}
    end

    local lines = {}
    local numLines = tooltip:NumLines() or 0

    for i = 1, numLines do
        local leftLine = getglobal(tooltipName .. "TextLeft" .. i)
        local rightLine = getglobal(tooltipName .. "TextRight" .. i)

        local leftText = leftLine and leftLine:GetText() or ""
        local rightText = rightLine and rightLine:GetText() or ""

        -- Get text colors (for detecting yellow/green text)
        local lr, lg, lb, la = 1, 1, 1, 1
        if leftLine and leftLine.GetTextColor then
            lr, lg, lb, la = leftLine:GetTextColor()
        end

        table.insert(lines, {
            left = leftText,
            right = rightText,
            leftLower = leftText and string.lower(leftText) or "",
            rightLower = rightText and string.lower(rightText) or "",
            r = lr, g = lg, b = lb,
        })
    end

    return lines
end

--=====================================================
-- Core Detection Functions
--=====================================================

-- Check if item is a permanent enchant (enchanting scroll/vellum)
local function DetectPermanentEnchant(lines)
    for _, line in ipairs(lines) do
        if string.find(line.leftLower, "permanently") then
            return true
        end
    end
    return false
end

-- Check if item is a quest item and/or quest starter
local function DetectQuestItem(lines, itemData)
    local isQuestItem = false
    local isQuestStarter = false

    -- Check item category first
    if itemData and itemData.class == "Quest" then
        isQuestItem = true
    end

    -- Scan tooltip for quest-related text
    for _, line in ipairs(lines) do
        local text = line.leftLower

        -- Quest starter patterns (highest priority)
        if string.find(text, "quest starter") or
           string.find(text, "this item begins a quest") or
           string.find(text, "begins a quest") or
           string.find(text, "starts a quest") then
            isQuestItem = true
            isQuestStarter = true
        end

        -- Quest item patterns
        if string.find(text, "quest item") then
            isQuestItem = true
        end
    end

    return isQuestItem, isQuestStarter
end

-- Check if item is junk (gray or white equippable without special properties)
local function DetectJunk(lines, itemData)
    if not itemData then return false end

    -- Ensure quality is a number
    local quality = tonumber(itemData.quality)
    local itemClass = itemData.class or ""
    local itemSubclass = itemData.subclass or ""
    local itemName = itemData.name or ""
    local itemLink = itemData.link or ""

    -- Gray items are always junk
    -- Check quality value OR link color (gray = |cff9d9d9d)
    if quality == 0 then
        return true
    end

    -- Fallback: check link color for gray items
    if itemLink and string.find(itemLink, "|cff9d9d9d") then
        return true
    end

    -- If quality is still nil, try to determine from link color
    if quality == nil then
        if string.find(itemLink, "|cffffffff") then
            quality = 1  -- White
        else
            return false  -- Unknown quality, don't mark as junk
        end
    end

    -- White equippable items might be junk
    if quality == 1 and (itemClass == "Weapon" or itemClass == "Armor") then
        -- Exclusions: trinkets, rings, necklaces, tabards, shirts
        local subLower = string.lower(itemSubclass)
        if string.find(subLower, "trinket") or
           string.find(subLower, "ring") or
           string.find(subLower, "neck") or
           string.find(subLower, "tabard") or
           string.find(subLower, "shirt") then
            return false
        end

        -- Check for profession tools by common names
        local nameLower = string.lower(itemName)
        if string.find(nameLower, "mining pick") or
           string.find(nameLower, "skinning knife") or
           string.find(nameLower, "blacksmith hammer") or
           string.find(nameLower, "fishing pole") or
           string.find(nameLower, "gnomish army knife") then
            return false
        end

        -- Check for profession tool subtype
        if string.find(subLower, "fishing pole") or
           string.find(subLower, "mining pick") or
           string.find(subLower, "skinning knife") then
            return false
        end

        -- Check tooltip for special text (Use:, Equip:, green text)
        for _, line in ipairs(lines) do
            local text = line.leftLower

            -- Yellow text (Use:, Equip:)
            if line.r and line.g and line.b then
                local isYellow = (line.r > 0.9 and line.g > 0.75 and line.b < 0.2)
                local isGreen = (line.r < 0.2 and line.g > 0.9 and line.b < 0.2)

                if isYellow and (string.find(text, "use:") or string.find(text, "equip:")) then
                    return false
                end

                if isGreen then
                    return false
                end
            end
        end

        -- White equippable without special properties = junk
        return true
    end

    return false
end

-- Check if item is usable for a quest (has yellow "Use:" text related to quest)
local function DetectQuestUsable(lines)
    for _, line in ipairs(lines) do
        -- Check for yellow "Use:" text
        if line.r and line.g and line.b then
            local isYellow = (line.r > 0.9 and line.g > 0.75 and line.b < 0.2)
            if isYellow and string.find(line.leftLower, "use:") then
                return true
            end
        end
    end
    return false
end

--=====================================================
-- Public API - Cached Detection
--=====================================================

-- Get all item properties at once (cached)
-- Returns: { isQuestItem, isQuestStarter, isQuestUsable, isJunk, isPermanentEnchant }
function ItemDetection:GetItemProperties(itemData, bagID, slotID)
    if not itemData then
        return {
            isQuestItem = false,
            isQuestStarter = false,
            isQuestUsable = false,
            isJunk = false,
            isPermanentEnchant = false,
        }
    end

    local itemLink = itemData.link
    local cacheKey = GetCacheKey(itemLink)

    -- Check cache
    if cacheKey and detectionCache[cacheKey] then
        cacheHits = cacheHits + 1
        return detectionCache[cacheKey]
    end
    cacheMisses = cacheMisses + 1

    -- Scan tooltip once
    local lines = ScanTooltipLines(bagID, slotID, itemLink)

    -- Debug: log if tooltip scan failed
    if table.getn(lines) == 0 and addon.DEBUG then
        addon:Debug("ItemDetection: No tooltip lines for %s (bag=%s, slot=%s)",
            tostring(itemData.name or itemLink), tostring(bagID), tostring(slotID))
    end

    -- Detect all properties
    local isPermanentEnchant = DetectPermanentEnchant(lines)
    local isQuestItem, isQuestStarter = DetectQuestItem(lines, itemData)
    local isQuestUsable = DetectQuestUsable(lines)
    local isJunk = DetectJunk(lines, itemData)

    -- Debug: log junk detection for gray items
    if addon.DEBUG then
        local quality = tonumber(itemData.quality)
        local linkHasGray = itemLink and string.find(itemLink, "|cff9d9d9d")
        if quality == 0 or linkHasGray then
            addon:Debug("ItemDetection JUNK: %s quality=%s linkGray=%s isJunk=%s",
                tostring(itemData.name), tostring(quality), tostring(linkHasGray), tostring(isJunk))
        end
    end

    -- Permanent enchants are NOT quest items (even if categorized as Quest)
    if isPermanentEnchant then
        isQuestItem = false
        isQuestStarter = false
        isQuestUsable = false
    end

    local result = {
        isQuestItem = isQuestItem,
        isQuestStarter = isQuestStarter,
        isQuestUsable = isQuestUsable,
        isJunk = isJunk,
        isPermanentEnchant = isPermanentEnchant,
    }

    -- Cache result
    if cacheKey then
        detectionCache[cacheKey] = result
    end

    return result
end

-- Convenience functions for single property checks
function ItemDetection:IsQuestItem(itemData, bagID, slotID)
    local props = self:GetItemProperties(itemData, bagID, slotID)
    return props.isQuestItem, props.isQuestStarter
end

function ItemDetection:IsQuestStarter(itemData, bagID, slotID)
    local props = self:GetItemProperties(itemData, bagID, slotID)
    return props.isQuestStarter
end

function ItemDetection:IsQuestUsable(itemData, bagID, slotID)
    local props = self:GetItemProperties(itemData, bagID, slotID)
    return props.isQuestUsable
end

function ItemDetection:IsJunk(itemData, bagID, slotID)
    local props = self:GetItemProperties(itemData, bagID, slotID)
    return props.isJunk
end

function ItemDetection:IsPermanentEnchant(itemData, bagID, slotID)
    local props = self:GetItemProperties(itemData, bagID, slotID)
    return props.isPermanentEnchant
end

--=====================================================
-- Initialization
--=====================================================

function ItemDetection:Initialize()
    -- Clear cache when entering world (character switch)
    addon.Modules.Events:Register("PLAYER_ENTERING_WORLD", function()
        self:ClearCache()
    end, "ItemDetection")

    addon:Debug("ItemDetection module initialized")
end
