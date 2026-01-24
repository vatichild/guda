-- Guda Bank Scanner
-- Scans and stores bank contents with caching and event pending tracking

local addon = Guda

local BankScanner = {}
addon.Modules.BankScanner = BankScanner

local bankOpen = false

-- Cache for bank data to avoid re-scanning all slots on every update
local bankCache = nil
local cacheValid = false

-- Event pending tracking (like Baganator's IsBagEventPending)
local eventPending = false
local dirtySlots = {}  -- Track specific slots that changed

-- Clear the bank cache (called when bank opens or significant changes occur)
function BankScanner:ClearCache()
    bankCache = nil
    cacheValid = false
    dirtySlots = {}
    eventPending = false
end

-- Check if a bank event is pending (use before transfers)
function BankScanner:IsEventPending()
    return eventPending
end

-- Clear the pending flag (call after processing)
function BankScanner:ClearEventPending()
    eventPending = false
end

-- Mark a specific slot as dirty (incremental tracking)
function BankScanner:MarkSlotDirty(bagID, slotID)
    if not dirtySlots[bagID] then
        dirtySlots[bagID] = {}
    end
    dirtySlots[bagID][slotID] = true
    eventPending = true
end

-- Get cached bank data, or scan if cache is invalid
function BankScanner:GetBankData()
    addon:DebugCategory("GetBankData: ENTRY bankOpen=%s, cacheValid=%s, hasCache=%s",
        tostring(bankOpen), tostring(cacheValid), tostring(bankCache ~= nil))

    -- Check if bank is accessible (either officially open OR we can access bank slots)
    local bankAccessible = bankOpen
    local forceRescan = false
    if not bankAccessible then
        -- Try to access main bank - if it has slots, bank is actually accessible
        local testSlots = GetContainerNumSlots(-1)
        if testSlots and testSlots > 0 then
            bankAccessible = true
            -- Force rescan when bankOpen is false but bank is accessible
            -- This handles edge cases where cache has stale data
            forceRescan = true
            addon:DebugCategory("GetBankData: bankOpen=false but bank accessible (%d slots), forcing rescan", testSlots)
        end
    end

    if not bankAccessible then
        addon:DebugCategory("GetBankData: bank NOT accessible, returning empty")
        return {}
    end

    -- Force rescan when bankOpen state is inconsistent
    if forceRescan then
        cacheValid = false
    end

    if cacheValid and bankCache then
        addon:DebugCategory("GetBankData: using cached data (cacheValid=true)")
        -- Process any dirty slots incrementally
        for bagID, slots in pairs(dirtySlots) do
            if bagID ~= nil and type(slots) == "table" then
                if bankCache[bagID] then
                    for slotID in pairs(slots) do
                        -- Validate slotID is a valid number
                        if type(slotID) == "number" and slotID >= 1 then
                            local oldData = bankCache[bagID].slots[slotID]
                            local newData = addon.Modules.BagScanner:ScanSlot(bagID, slotID)
                            bankCache[bagID].slots[slotID] = newData

                            -- Update free slot count
                            local wasEmpty = (oldData == nil)
                            local isEmpty = (newData == nil)
                            if wasEmpty and not isEmpty then
                                bankCache[bagID].freeSlots = bankCache[bagID].freeSlots - 1
                            elseif not wasEmpty and isEmpty then
                                bankCache[bagID].freeSlots = bankCache[bagID].freeSlots + 1
                            end
                        end
                    end
                else
                    -- Bag not in cache, scan it
                    bankCache[bagID] = self:ScanBankBag(bagID)
                end
            end
        end
        dirtySlots = {}

        -- Check for invalidated bags (nil entries) and rescan them
        local rescannedBags = 0
        for _, bagID in ipairs(addon.Constants.BANK_BAGS) do
            if bankCache[bagID] == nil then
                addon:DebugCategory("GetBankData: rescanning invalidated bag %d", bagID)
                bankCache[bagID] = self:ScanBankBag(bagID)
                rescannedBags = rescannedBags + 1
            end
        end
        if rescannedBags > 0 then
            addon:DebugCategory("GetBankData: rescanned %d invalidated bags", rescannedBags)
        end

        -- Verify cache matches reality for ALL bank bags
        -- Only force full rescan when items are ADDED (API > cache)
        -- When items are REMOVED (cache > API), the incremental update + empty placeholders should handle it
        local needsFullRescan = false
        for _, bagID in ipairs(addon.Constants.BANK_BAGS) do
            local cacheItems = 0
            local realItems = 0
            if bankCache[bagID] and bankCache[bagID].slots then
                for slotID, item in pairs(bankCache[bagID].slots) do
                    if item then cacheItems = cacheItems + 1 end
                end
            end
            -- Check actual API state
            local numSlots = GetContainerNumSlots(bagID) or 0
            for slot = 1, numSlots do
                local texture = GetContainerItemInfo(bagID, slot)
                if texture then realItems = realItems + 1 end
            end
            if realItems > cacheItems then
                -- Items were ADDED to bank - need full rescan to show them
                addon:DebugCategory("GetBankData: ITEMS ADDED in bag %d! cache=%d, API=%d -> full rescan",
                    bagID, cacheItems, realItems)
                needsFullRescan = true
            elseif cacheItems > realItems then
                -- Items were REMOVED from bank - incremental update handles this
                -- Just update the cache for this bag to reflect removals
                addon:DebugCategory("GetBankData: ITEMS REMOVED in bag %d, cache=%d, API=%d -> incremental update",
                    bagID, cacheItems, realItems)
                -- Rescan just this bag to update the cache (not full UI redraw)
                bankCache[bagID] = self:ScanBankBag(bagID)
            end
        end
        if needsFullRescan then
            -- Force a full rescan only when items were added
            cacheValid = false
            bankCache = self:ScanBank()
            cacheValid = true
            addon:DebugCategory("GetBankData: forced full rescan due to new items")
        end

        return bankCache
    end

    -- Cache miss - do full scan
    addon:DebugCategory("GetBankData: cache miss, doing full scan (cacheValid=%s, bankCache=%s)",
        tostring(cacheValid), tostring(bankCache ~= nil))
    bankCache = self:ScanBank()
    cacheValid = true
    dirtySlots = {}
    return bankCache
end

-- Update a single slot in the cache (incremental update)
function BankScanner:UpdateSlot(bagID, slotID)
    if not bankOpen then return end

    -- Mark as dirty for next GetBankData call
    self:MarkSlotDirty(bagID, slotID)
end

-- Invalidate cache (force full re-scan on next update)
function BankScanner:InvalidateCache()
    cacheValid = false
end

-- Get the cached item count for a bag WITHOUT triggering a rescan
-- Used for comparing before/after counts during event handling
function BankScanner:GetCachedItemCount(bagID)
    if not bankCache or not bankCache[bagID] or not bankCache[bagID].slots then
        return 0
    end
    local count = 0
    for slotID, item in pairs(bankCache[bagID].slots) do
        if item then count = count + 1 end
    end
    return count
end

-- Invalidate a specific bag in the cache (force re-scan of just that bag)
function BankScanner:InvalidateBag(bagID)
    -- Allow invalidation if bank is accessible (not just officially open)
    local bankAccessible = bankOpen
    if not bankAccessible then
        local testSlots = GetContainerNumSlots(-1)
        if testSlots and testSlots > 0 then
            bankAccessible = true
        end
    end
    if not bankAccessible then
        addon:DebugCategory("InvalidateBag(%d): bank not accessible, skipping", bagID)
        return
    end
    if not bankCache then
        addon:DebugCategory("InvalidateBag(%d): no bankCache exists, skipping", bagID)
        return
    end
    local hadBag = (bankCache[bagID] ~= nil)
    bankCache[bagID] = nil
    addon:DebugCategory("InvalidateBag(%d): invalidated (hadBag=%s, cacheValid=%s)",
        bagID, tostring(hadBag), tostring(cacheValid))
end

-- Scan all bank bags and return data (full scan)
function BankScanner:ScanBank()
    -- Check if bank is accessible (officially open OR slots are readable)
    local bankAccessible = bankOpen
    if not bankAccessible then
        local testSlots = GetContainerNumSlots(-1)
        if testSlots and testSlots > 0 then
            bankAccessible = true
        end
    end

    if not bankAccessible then
        addon:Debug("Cannot scan bank - not accessible")
        return {}
    end

    local bankData = {}
    local totalItems = 0

    for _, bagID in ipairs(addon.Constants.BANK_BAGS) do
        bankData[bagID] = self:ScanBankBag(bagID)
        local bagItems = 0
        if bankData[bagID] and bankData[bagID].slots then
            for _, item in pairs(bankData[bagID].slots) do
                if item then
                    bagItems = bagItems + 1
                    totalItems = totalItems + 1
                end
            end
        end
        if bagItems > 0 then
            addon:DebugCategory("ScanBank: bag %d has %d items", bagID, bagItems)
        end
    end
    addon:DebugCategory("ScanBank: total %d items across all bags", totalItems)

    return bankData
end

-- Scan a single bank bag
function BankScanner:ScanBankBag(bagID)
    -- Determine bag type
    local bagType = "regular"
    if addon.Modules.Utils:IsSoulBag(bagID) then
        bagType = "soul"
    elseif addon.Modules.Utils:IsHerbBag(bagID) then
        bagType = "herb"
    elseif addon.Modules.Utils:IsEnchantBag(bagID) then
        bagType = "enchant"
    elseif addon.Modules.Utils:IsAmmoQuiverBag(bagID) then
        bagType = "ammo"
    end

    local bag = {
        slots = {},
        numSlots = addon.Modules.Utils:GetBagSlotCount(bagID),
        freeSlots = 0,
        bagType = bagType,
    }

    if not addon.Modules.Utils:IsBagValid(bagID) then
        addon:DebugCategory("ScanBankBag(%d): bag not valid", bagID)
        return bag
    end

    local itemCount = 0
    for slot = 1, bag.numSlots do
        local itemData = addon.Modules.BagScanner:ScanSlot(bagID, slot)
        bag.slots[slot] = itemData

        if not itemData then
            bag.freeSlots = bag.freeSlots + 1
        else
            itemCount = itemCount + 1
        end
    end

    addon:DebugCategory("ScanBankBag(%d): numSlots=%d, items=%d, freeSlots=%d",
        bagID, bag.numSlots, itemCount, bag.freeSlots)

    return bag
end

-- Save current bank to database
function BankScanner:SaveToDatabase()
    if not bankOpen then
        return
    end

    local bankData = self:GetBankData()  -- Use cached data
    addon.Modules.DB:SaveBank(bankData)
    addon:Debug("Bank data saved")
end

-- Initialize bank scanner
function BankScanner:Initialize()
    -- Bank opened - do initial scan
    addon.Modules.Events:OnBankOpen(function()
        bankOpen = true
        BankScanner:ClearCache()  -- Clear cache on open
        addon:Debug("Bank opened")

        -- Delay scan to ensure bank is fully loaded (uses pooled timer)
        Guda_ScheduleTimer(0.5, function()
            BankScanner:SaveToDatabase()
        end)
    end, "BankScanner")

    -- Bank closed
    addon.Modules.Events:OnBankClose(function()
        -- Do a final save on close before marking bank as closed
        addon:Debug("Bank closing - performing final save")
        BankScanner:SaveToDatabase()

        bankOpen = false
        BankScanner:ClearCache()  -- Clear cache on close
        addon:Debug("Bank closed")
    end, "BankScanner")
end

-- Check if bank is currently open
function BankScanner:IsBankOpen()
    return bankOpen
end
