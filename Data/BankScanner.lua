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
    if not bankOpen then
        return {}
    end

    if cacheValid and bankCache then
        -- Process any dirty slots incrementally
        for bagID, slots in pairs(dirtySlots) do
            if bankCache[bagID] then
                for slotID in pairs(slots) do
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
            else
                -- Bag not in cache, scan it
                bankCache[bagID] = self:ScanBankBag(bagID)
            end
        end
        dirtySlots = {}
        return bankCache
    end

    -- Cache miss - do full scan
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

-- Invalidate a specific bag in the cache (force re-scan of just that bag)
function BankScanner:InvalidateBag(bagID)
    if not bankOpen then return end
    if not bankCache then return end
    bankCache[bagID] = nil
end

-- Scan all bank bags and return data (full scan)
function BankScanner:ScanBank()
    if not bankOpen then
        addon:Debug("Cannot scan bank - not open")
        return {}
    end

    local bankData = {}

    for _, bagID in ipairs(addon.Constants.BANK_BAGS) do
        bankData[bagID] = self:ScanBankBag(bagID)
    end

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
        return bag
    end

    for slot = 1, bag.numSlots do
        local itemData = addon.Modules.BagScanner:ScanSlot(bagID, slot)
        bag.slots[slot] = itemData

        if not itemData then
            bag.freeSlots = bag.freeSlots + 1
        end
    end

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

        -- Delay scan to ensure bank is fully loaded
        local frame = CreateFrame("Frame")
        local elapsed = 0
        frame:SetScript("OnUpdate", function()
            elapsed = elapsed + arg1
            if elapsed >= 0.5 then
                frame:SetScript("OnUpdate", nil)
                BankScanner:SaveToDatabase()
            end
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
