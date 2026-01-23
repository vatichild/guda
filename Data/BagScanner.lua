-- Guda Bag Scanner
-- Scans and stores bag contents with caching and event pending tracking

local addon = Guda

local BagScanner = {}
addon.Modules.BagScanner = BagScanner

-- Cache for bag data to avoid re-scanning all slots on every update
local bagCache = nil
local cacheValid = false

-- Event pending tracking (like Baganator's IsBagEventPending)
local eventPending = false
local dirtySlots = {}  -- Track specific slots that changed: dirtySlots[bagID][slotID] = true

-- Clear the bag cache
function BagScanner:ClearCache()
    bagCache = nil
    cacheValid = false
    dirtySlots = {}
end

-- Check if a bag event is pending (use before transfers)
function BagScanner:IsEventPending()
    return eventPending
end

-- Clear the pending flag (call after processing)
function BagScanner:ClearEventPending()
    eventPending = false
end

-- Mark a specific slot as dirty (incremental tracking)
function BagScanner:MarkSlotDirty(bagID, slotID)
    if not dirtySlots[bagID] then
        dirtySlots[bagID] = {}
    end
    dirtySlots[bagID][slotID] = true
    eventPending = true
end

-- Get dirty slots and clear them
function BagScanner:GetAndClearDirtySlots()
    local dirty = dirtySlots
    dirtySlots = {}
    return dirty
end

-- Get cached bag data, or scan if cache is invalid
function BagScanner:GetBagData()
    if cacheValid and bagCache then
        -- Process any dirty slots incrementally
        for bagID, slots in pairs(dirtySlots) do
            if bagCache[bagID] then
                for slotID in pairs(slots) do
                    local oldData = bagCache[bagID].slots[slotID]
                    local newData = self:ScanSlot(bagID, slotID)
                    bagCache[bagID].slots[slotID] = newData

                    -- Update free slot count
                    local wasEmpty = (oldData == nil)
                    local isEmpty = (newData == nil)
                    if wasEmpty and not isEmpty then
                        bagCache[bagID].freeSlots = bagCache[bagID].freeSlots - 1
                    elseif not wasEmpty and isEmpty then
                        bagCache[bagID].freeSlots = bagCache[bagID].freeSlots + 1
                    end
                end
            else
                -- Bag not in cache, scan it
                bagCache[bagID] = self:ScanBag(bagID)
            end
        end
        dirtySlots = {}
        return bagCache
    end

    -- Cache miss - do full scan
    bagCache = self:ScanBags()
    cacheValid = true
    dirtySlots = {}
    return bagCache
end

-- Invalidate cache (force full re-scan on next update)
function BagScanner:InvalidateCache()
    cacheValid = false
end

-- Invalidate a specific bag in the cache
function BagScanner:InvalidateBag(bagID)
    if not bagCache then return end
    bagCache[bagID] = nil
end

-- Scan all bags and return data (full scan)
function BagScanner:ScanBags()
    local bagData = {}

    -- Scan regular bags
    for _, bagID in ipairs(addon.Constants.BAGS) do
        bagData[bagID] = self:ScanBag(bagID)
    end

    -- Also scan keyring (bagID -2)
    bagData[-2] = self:ScanBag(-2)

    return bagData
end

-- Scan a single bag
function BagScanner:ScanBag(bagID)
    -- Determine bag type
    local bagType = addon.Modules.Utils:GetSpecializedBagType(bagID) or "regular"

    local bag = {
        slots = {},
        numSlots = addon.Modules.Utils:GetBagSlotCount(bagID),
        freeSlots = 0,
        bagType = bagType,
    }

    if not addon.Modules.Utils:IsBagValid(bagID) then
        return bag
    end

    for slot = 1, bag.numSlots do
        local itemData = self:ScanSlot(bagID, slot)
        bag.slots[slot] = itemData

        if not itemData then
            bag.freeSlots = bag.freeSlots + 1
        end
    end

    return bag
end

-- Scan a single slot
function BagScanner:ScanSlot(bagID, slot)
    local texture, itemCount, locked, quality, readable, lootable = GetContainerItemInfo(bagID, slot)

    if not texture then
        return nil
    end

    -- In 1.12.1, must use GetContainerItemLink separately!
    local itemLink = GetContainerItemLink(bagID, slot)

    -- Get item info
    local name, link, itemQuality, iLevel, itemCategory, itemType, itemStackCount, itemSubType, itemTexture, itemEquipLoc, itemSellPrice
    if itemLink then
        name, link, itemQuality, iLevel, itemCategory, itemType, itemStackCount, itemSubType, itemTexture, itemEquipLoc, itemSellPrice = addon.Modules.Utils:GetItemInfo(itemLink)
    end

    return {
        link = itemLink,
        texture = texture,
        count = itemCount or 1,
        quality = quality or itemQuality or 0,
        name = name,
        iLevel = iLevel,
        type = itemType,
        class = itemCategory,
        subclass = itemSubType,
        equipSlot = itemEquipLoc,
        locked = locked,
    }
end

-- Save current bags to database
function BagScanner:SaveToDatabase()
    local bagData = self:ScanBags()
    addon.Modules.DB:SaveBags(bagData)
    addon:Debug("Bag data saved to database")

    -- Clear tooltip cache so counts update immediately
    if addon.Modules.Tooltip and addon.Modules.Tooltip.ClearCache then
        addon.Modules.Tooltip:ClearCache()
    end
end

-- Initialize with event pending tracking
function BagScanner:Initialize()
    local eventFrame = CreateFrame("Frame")
    self.eventFrame = eventFrame

    -- Register bag update events for pending tracking
    eventFrame:RegisterEvent("BAG_UPDATE")
    eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    eventFrame:SetScript("OnEvent", function()
        eventPending = true
        -- Mark the specific bag as having changes
        if arg1 then
            if not dirtySlots[arg1] then
                dirtySlots[arg1] = {}
            end
            -- We don't know which slot, so mark entire bag for rescan
            -- by invalidating it
            if bagCache and bagCache[arg1] then
                bagCache[arg1] = nil
            end
        end
    end)

    addon:Debug("Bag scanner initialized with event pending tracking")
end
