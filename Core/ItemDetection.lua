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

-- Clear the entire detection cache (use sparingly - only for major events)
-- For simple item moves, use InvalidateItem() or don't invalidate at all
function ItemDetection:ClearCache()
    detectionCache = {}
    cacheHits = 0
    cacheMisses = 0
end

-- Invalidate a specific item from cache (by itemLink)
-- Use this when a specific item's properties might have changed
function ItemDetection:InvalidateItem(itemLink)
    if itemLink then
        detectionCache[itemLink] = nil
    end
end

-- Invalidate multiple items from cache
-- Use this for batch operations
function ItemDetection:InvalidateItems(itemLinks)
    if itemLinks then
        for _, link in ipairs(itemLinks) do
            if link then
                detectionCache[link] = nil
            end
        end
    end
end

-- Check if we have cached data for an item (useful for debugging)
function ItemDetection:IsCached(itemLink)
    return itemLink and detectionCache[itemLink] ~= nil
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
-- Uses shared tooltip from Utils module
--=====================================================

-- Scan tooltip and return all text lines
local function ScanTooltipLines(bagID, slotID, itemLink)
    -- Use shared tooltip from Utils module
    local tooltip, tooltipName = addon.Modules.Utils:GetScanTooltip()

    -- Ensure tooltip owner is set before each scan
    tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    tooltip:ClearLines()

    -- Helper to safely call SetHyperlink (can fail with "Unknown link type")
    local function SafeSetHyperlink(tip, link)
        if not link then return false end
        -- Extract just the item:XXXX portion for SetHyperlink
        local _, _, itemString = string.find(link, "|H(item:[^|]+)|h")
        if itemString then
            local success = pcall(function() tip:SetHyperlink(itemString) end)
            return success
        end
        return false
    end

    -- Set tooltip based on what we have
    if bagID and slotID then
        if bagID == -1 then
            -- Bank main bag: SetInventoryItem doesn't work for bank slots
            -- Use SetHyperlink with the item link instead
            if not SafeSetHyperlink(tooltip, itemLink) then
                return {}
            end
        elseif bagID >= 5 and bagID <= 10 then
            -- Bank bags: Try SetBagItem first, it should work for bank bags
            tooltip:SetBagItem(bagID, slotID)
        else
            -- Regular bags (0-4): SetBagItem works reliably
            tooltip:SetBagItem(bagID, slotID)
        end
    elseif itemLink then
        if not SafeSetHyperlink(tooltip, itemLink) then
            return {}
        end
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

        -- Get left text colors (for detecting yellow/green/red text)
        local lr, lg, lb, la = 1, 1, 1, 1
        if leftLine and leftLine.GetTextColor then
            lr, lg, lb, la = leftLine:GetTextColor()
        end

        -- Get right text colors (for detecting red requirements)
        local rr, rg, rb, ra = 1, 1, 1, 1
        if rightLine and rightLine.GetTextColor then
            rr, rg, rb, ra = rightLine:GetTextColor()
        end

        table.insert(lines, {
            left = leftText,
            right = rightText,
            leftLower = leftText and string.lower(leftText) or "",
            rightLower = rightText and string.lower(rightText) or "",
            r = lr, g = lg, b = lb,
            rightR = rr, rightG = rg, rightB = rb,
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

-- Durability pattern for filtering out broken item red text
local durabilityPattern = DURABILITY_TEMPLATE and string.gsub(DURABILITY_TEMPLATE, "%%d", "%%d+") or nil

-- Check if text color is red (unusable requirement)
local function IsRedColor(r, g, b)
    if not r or not g or not b then return false end
    -- RED_FONT_COLOR is typically (1.0, 0.1, 0.1)
    local dr = math.abs(r - 1.0)
    local dg = math.abs(g - 0.125)
    local db = math.abs(b - 0.125)
    return (dr < 0.15 and dg < 0.15 and db < 0.15)
end

-- Check if red text is a legitimate requirement (not just loading state or flavor text)
-- Returns true if text appears to be an actual unmet requirement
local function IsRequirementText(text)
    if not text or text == "" then return false end
    local lower = string.lower(text)

    -- Known requirement patterns in vanilla WoW
    if string.find(lower, "requires") then return true end      -- "Requires Level 60", "Requires Class:", etc.
    if string.find(lower, "require") then return true end       -- Alternate forms
    if string.find(lower, "classes:") then return true end      -- "Classes: Warrior, Paladin"
    if string.find(lower, "races:") then return true end        -- "Races: Dwarf, Gnome"
    if string.find(lower, "level %d") then return true end      -- "Level 60" (without Requires)
    if string.find(lower, "skill:") then return true end        -- Profession requirements
    if string.find(lower, "reputation") then return true end    -- Reputation requirements
    if string.find(lower, "riding") then return true end        -- Riding skill
    if string.find(lower, "already known") then return true end -- Recipe already known

    -- Class names (when shown in red, indicates class restriction)
    if string.find(lower, "warrior") then return true end
    if string.find(lower, "paladin") then return true end
    if string.find(lower, "hunter") then return true end
    if string.find(lower, "rogue") then return true end
    if string.find(lower, "priest") then return true end
    if string.find(lower, "shaman") then return true end
    if string.find(lower, "mage") then return true end
    if string.find(lower, "warlock") then return true end
    if string.find(lower, "druid") then return true end

    -- Race names (when shown in red, indicates race restriction)
    if string.find(lower, "human") then return true end
    if string.find(lower, "dwarf") then return true end
    if string.find(lower, "night elf") then return true end
    if string.find(lower, "gnome") then return true end
    if string.find(lower, "orc") then return true end
    if string.find(lower, "undead") then return true end
    if string.find(lower, "tauren") then return true end
    if string.find(lower, "troll") then return true end
    if string.find(lower, "goblin") then return true end        -- Turtle WoW
    if string.find(lower, "high elf") then return true end      -- Turtle WoW

    return false
end

-- Check if item is unusable (has red text indicating unmet requirements)
-- Excludes: durability lines, item name (line 1), non-requirement text
local function DetectUnusable(lines)
    local numLines = table.getn(lines)

    -- If tooltip has very few lines, data might not be loaded - be conservative
    if numLines < 2 then
        return false
    end

    -- Start from line 2 to skip the item name (line 1)
    -- Item names can appear red when data isn't fully loaded
    for i = 2, numLines do
        local line = lines[i]
        if line and line.r and line.g and line.b then
            -- Check for red text (requirements not met)
            local isRed = IsRedColor(line.r, line.g, line.b) or
                          (line.r > 0.85 and line.g < 0.3 and line.b < 0.3)

            if isRed then
                local text = line.left or ""

                -- Ignore durability lines (broken items)
                if durabilityPattern and string.find(text, durabilityPattern) then
                    -- skip durability
                -- Only count as unusable if text looks like a requirement
                elseif IsRequirementText(text) then
                    return true
                end
                -- If red but not a requirement pattern, ignore it (might be flavor text or loading state)
            end
        end

        -- Also check right column (some requirements appear there, like "Warrior" class)
        if line and line.rightR and line.rightG and line.rightB then
            local isRed = IsRedColor(line.rightR, line.rightG, line.rightB) or
                          (line.rightR > 0.85 and line.rightG < 0.3 and line.rightB < 0.3)

            if isRed then
                local text = line.right or ""
                if durabilityPattern and string.find(text, durabilityPattern) then
                    -- skip durability
                elseif IsRequirementText(text) then
                    return true
                end
            end
        end
    end
    return false
end

--=====================================================
-- Public API - Cached Detection
--=====================================================

-- Get all item properties at once (cached)
-- Returns: { isQuestItem, isQuestStarter, isQuestUsable, isJunk, isPermanentEnchant, isUnusable }
function ItemDetection:GetItemProperties(itemData, bagID, slotID)
    if not itemData then
        return {
            isQuestItem = false,
            isQuestStarter = false,
            isQuestUsable = false,
            isJunk = false,
            isPermanentEnchant = false,
            isUnusable = false,
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
    local numLines = table.getn(lines)

    -- Debug: log if tooltip scan failed
    if numLines == 0 and addon.DEBUG then
        addon:Debug("ItemDetection: No tooltip lines for %s (bag=%s, slot=%s)",
            tostring(itemData.name or itemLink), tostring(bagID), tostring(slotID))
    end

    -- Check if tooltip data appears complete
    -- A proper item tooltip should have at least 2 lines (name + something)
    -- If tooltip is too short, data may not be fully loaded - don't cache
    local tooltipLooksComplete = (numLines >= 2)

    -- Detect all properties
    local isPermanentEnchant = DetectPermanentEnchant(lines)
    local isQuestItem, isQuestStarter = DetectQuestItem(lines, itemData)
    local isQuestUsable = DetectQuestUsable(lines)
    local isJunk = DetectJunk(lines, itemData)
    local isUnusable = DetectUnusable(lines)

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
        isUnusable = isUnusable,
    }

    -- Only cache result if tooltip data appears complete
    -- This prevents caching incorrect results from partially-loaded item data
    if cacheKey and tooltipLooksComplete then
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

function ItemDetection:IsUnusable(itemData, bagID, slotID)
    local props = self:GetItemProperties(itemData, bagID, slotID)
    return props.isUnusable
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
