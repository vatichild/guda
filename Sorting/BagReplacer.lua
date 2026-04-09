--===========================================================================
-- BagReplacer: Auto-replace occupied bags by evacuating items first
--===========================================================================
local addon = Guda
local BagReplacer = {}
addon.Modules.BagReplacer = BagReplacer

BagReplacer.inProgress = false

local C = addon.Constants

--===========================================================================
-- Lock-wait mechanism (independent from SortEngine)
--===========================================================================
local replacerFrame = CreateFrame("Frame")
local pendingSlots = {}      -- flat array: {bagID1, slot1, bagID2, slot2, ...}
local pendingCount = 0
local pendingSet = {}         -- bagID*1000+slot -> true
local waitingForLocks = false
local onLocksCleared = nil

local function AddPendingLock(bagID, slot)
    local key = bagID * 1000 + slot
    if not pendingSet[key] then
        pendingSet[key] = true
        pendingCount = pendingCount + 1
        pendingSlots[pendingCount * 2 - 1] = bagID
        pendingSlots[pendingCount * 2] = slot
    end
end

local function ClearPendingLocks()
    for k in pairs(pendingSet) do pendingSet[k] = nil end
    for i = 1, pendingCount * 2 do pendingSlots[i] = nil end
    pendingCount = 0
end

local function AnyPendingLocked()
    if pendingCount == 0 then return false end
    for i = 1, pendingCount do
        local bagID = pendingSlots[i * 2 - 1]
        local slot = pendingSlots[i * 2]
        if bagID and slot then
            local _, _, locked = GetContainerItemInfo(bagID, slot)
            if locked then return true end
        end
    end
    return false
end

replacerFrame:RegisterEvent("ITEM_LOCK_CHANGED")
replacerFrame:SetScript("OnEvent", function()
    if waitingForLocks and onLocksCleared then
        if not AnyPendingLocked() then
            waitingForLocks = false
            local cb = onLocksCleared
            onLocksCleared = nil
            ClearPendingLocks()
            cb()
        end
    end
end)

local function WaitForLocksCleared(callback, timeout, minDelay)
    minDelay = minDelay or 0.15
    Guda_ScheduleTimer(minDelay, function()
        if not AnyPendingLocked() then
            ClearPendingLocks()
            callback()
            return
        end
        waitingForLocks = true
        onLocksCleared = callback
        local remaining = (timeout or 1.5) - minDelay
        if remaining < 0.3 then remaining = 0.3 end
        Guda_ScheduleTimer(remaining, function()
            if waitingForLocks then
                waitingForLocks = false
                onLocksCleared = nil
                ClearPendingLocks()
                ClearCursor()
                callback()
            end
        end)
    end)
end

local BATCH_SIZE = 5 -- moves per batch for evacuation

--===========================================================================
-- Check if item can go in a specific bag (mirrors SortEngine logic)
--===========================================================================
local function CanItemGoInBag(itemLink, targetBagID)
    if targetBagID == 0 or targetBagID == -1 or targetBagID == -2 then
        return true
    end
    local bagType = addon.Modules.Utils:GetSpecializedBagType(targetBagID)
    if not bagType then
        return true
    end
    local preferredType = addon.Modules.Utils:GetItemPreferredContainer(itemLink)
    return preferredType == bagType
end

--===========================================================================
-- Build list of free slots across all bags except the target bag
-- Returns: { {bagID, slotID, bagType}, ... }
--===========================================================================
local function GetAvailableFreeSlots(excludeBagID)
    local freeSlots = {}
    local count = 0

    -- Iterate bags 0-4, skipping the excluded bag
    for bagID = 0, C.BAG_LAST do
        if bagID ~= excludeBagID then
            local numSlots = GetContainerNumSlots(bagID)
            if numSlots and numSlots > 0 then
                local bagType = addon.Modules.Utils:GetSpecializedBagType(bagID)
                for slot = 1, numSlots do
                    local texture = GetContainerItemInfo(bagID, slot)
                    if not texture then
                        count = count + 1
                        freeSlots[count] = { bagID = bagID, slot = slot, bagType = bagType }
                    end
                end
            end
        end
    end

    return freeSlots, count
end

--===========================================================================
-- Get items in a bag
-- Returns: { {slot, itemLink}, ... }, count
--===========================================================================
local function GetBagItems(bagID)
    local items = {}
    local count = 0
    local numSlots = GetContainerNumSlots(bagID)

    if not numSlots or numSlots == 0 then
        return items, 0
    end

    for slot = 1, numSlots do
        local texture = GetContainerItemInfo(bagID, slot)
        if texture then
            local link = GetContainerItemLink(bagID, slot)
            count = count + 1
            items[count] = { slot = slot, itemLink = link }
        end
    end

    return items, count
end

--===========================================================================
-- BuildEvacuationPlan: assign each item to a free slot, reserve stash slot
-- Returns: plan table or nil, errorMsg
--===========================================================================
function BagReplacer:BuildEvacuationPlan(targetBagID)
    local items, itemCount = GetBagItems(targetBagID)
    addon:DebugSort("[BagReplacer] BuildEvacuationPlan: bag %d has %d items", targetBagID, itemCount)
    if itemCount == 0 then
        return { moves = {}, stashBag = nil, stashSlot = nil, itemCount = 0 }, nil
    end

    local freeSlots, freeCount = GetAvailableFreeSlots(targetBagID)
    local needed = itemCount + 1 -- +1 for stashing the new bag from cursor
    addon:DebugSort("[BagReplacer] Need %d free slots (items+stash), have %d", needed, freeCount)

    if freeCount < needed then
        return nil, string.format(
            "Not enough free bag space. Need %d free slots, have %d.",
            needed, freeCount
        )
    end

    -- Separate free slots into specialized and regular
    local regularFree = {}
    local regularCount = 0
    local specializedFree = {} -- keyed by bagType
    for i = 1, freeCount do
        local fs = freeSlots[i]
        if fs.bagType then
            if not specializedFree[fs.bagType] then
                specializedFree[fs.bagType] = {}
            end
            local t = specializedFree[fs.bagType]
            t[table.getn(t) + 1] = fs
        else
            regularCount = regularCount + 1
            regularFree[regularCount] = fs
        end
    end

    local moves = {}
    local moveCount = 0
    local regularIdx = 1 -- next regular free slot to use

    -- Assign each item to a free slot
    for i = 1, itemCount do
        local item = items[i]
        local assigned = false

        -- Try specialized bag first if item has a preferred type
        if item.itemLink then
            local preferredType = addon.Modules.Utils:GetItemPreferredContainer(item.itemLink)
            if preferredType and specializedFree[preferredType] then
                local specSlots = specializedFree[preferredType]
                if table.getn(specSlots) > 0 then
                    local fs = specSlots[table.getn(specSlots)]
                    specSlots[table.getn(specSlots)] = nil
                    moveCount = moveCount + 1
                    moves[moveCount] = {
                        fromBag = targetBagID, fromSlot = item.slot,
                        toBag = fs.bagID, toSlot = fs.slot
                    }
                    addon:DebugSort("[BagReplacer] Plan move #%d: bag%d/slot%d -> bag%d/slot%d (specialized %s)", moveCount, targetBagID, item.slot, fs.bagID, fs.slot, preferredType)
                    assigned = true
                end
            end
        end

        -- Fall back to regular free slot
        if not assigned then
            if regularIdx <= regularCount then
                local fs = regularFree[regularIdx]
                regularIdx = regularIdx + 1
                moveCount = moveCount + 1
                moves[moveCount] = {
                    fromBag = targetBagID, fromSlot = item.slot,
                    toBag = fs.bagID, toSlot = fs.slot
                }
                addon:DebugSort("[BagReplacer] Plan move #%d: bag%d/slot%d -> bag%d/slot%d (regular)", moveCount, targetBagID, item.slot, fs.bagID, fs.slot)
                assigned = true
            end
        end

        if not assigned then
            addon:DebugSort("[BagReplacer] Failed to assign slot %d to a free slot", item.slot)
            return nil, string.format(
                "Not enough compatible bag space. Need %d free slots, have %d.",
                needed, freeCount
            )
        end
    end

    -- Reserve a regular free slot for stashing the new bag from cursor
    local stashBag, stashSlot
    if regularIdx <= regularCount then
        local fs = regularFree[regularIdx]
        stashBag = fs.bagID
        stashSlot = fs.slot
        addon:DebugSort("[BagReplacer] Stash slot: bag%d/slot%d", stashBag, stashSlot)
    else
        -- No regular free slot left for stash - check if any specialized slot works
        -- (new bag is a container item, needs a regular slot)
        return nil, string.format(
            "Not enough free bag space. Need %d free slots, have %d.",
            needed, freeCount
        )
    end

    return {
        moves = moves,
        stashBag = stashBag,
        stashSlot = stashSlot,
        itemCount = itemCount,
        targetBagID = targetBagID
    }, nil
end

--===========================================================================
-- Abort: cleanup on failure
--===========================================================================
function BagReplacer:Abort(reason)
    addon:DebugSort("[BagReplacer] Abort: %s", reason or "unknown")
    ClearCursor()
    ClearPendingLocks()
    waitingForLocks = false
    onLocksCleared = nil
    self.inProgress = false
    if reason then
        addon:Print(reason)
    end
    -- Refresh UI
    if addon.Modules.BagFrame and addon.Modules.BagFrame.Update then
        addon.Modules.BagFrame:Update()
    end
end

--===========================================================================
-- FinishReplacement: pick up new bag from stash, equip it, handle old bag
--===========================================================================
local function FinalizeReplacement()
    ClearPendingLocks()
    waitingForLocks = false
    onLocksCleared = nil
    BagReplacer.inProgress = false
    addon:Print(Guda_L["Bag replaced successfully!"])

    -- Invalidate bag scanner cache BEFORE update so it does a full rescan
    -- (bag slot count changed, incremental update can't handle that)
    if addon.Modules.BagScanner and addon.Modules.BagScanner.InvalidateCache then
        addon.Modules.BagScanner:InvalidateCache()
    end
    -- Refresh UI
    if addon.Modules.BagFrame and addon.Modules.BagFrame.Update then
        addon.Modules.BagFrame:Update()
    end
end

-- Wait for BAG_UPDATE on the target bag to confirm the server processed the equip,
-- then run the completion callback. Safety timeout if event never fires.
local bagUpdateFrame = CreateFrame("Frame")
local bagUpdateCallback = nil
local bagUpdateTarget = nil

bagUpdateFrame:SetScript("OnEvent", function()
    if bagUpdateCallback and arg1 == bagUpdateTarget then
        addon:DebugSort("[BagReplacer] BAG_UPDATE received for bag %d", arg1)
        bagUpdateFrame:UnregisterEvent("BAG_UPDATE")
        local cb = bagUpdateCallback
        bagUpdateCallback = nil
        bagUpdateTarget = nil
        -- Small delay to let all related events settle
        Guda_ScheduleTimer(0.15, cb)
    end
end)

local function WaitForBagUpdate(targetBagID, callback)
    bagUpdateCallback = callback
    bagUpdateTarget = targetBagID
    bagUpdateFrame:RegisterEvent("BAG_UPDATE")
    -- Safety timeout
    Guda_ScheduleTimer(1.5, function()
        if bagUpdateCallback then
            addon:DebugSort("[BagReplacer] BAG_UPDATE timeout for bag %d, proceeding", targetBagID)
            bagUpdateFrame:UnregisterEvent("BAG_UPDATE")
            local cb = bagUpdateCallback
            bagUpdateCallback = nil
            bagUpdateTarget = nil
            cb()
        end
    end)
end

function BagReplacer:FinishReplacement(invSlot, stashBag, stashSlot, targetBagID)
    addon:DebugSort("[BagReplacer] FinishReplacement: picking up new bag from bag%d/slot%d, equipping to invSlot %d (bag %d)", stashBag, stashSlot, invSlot, targetBagID)
    -- Verify new bag is still in stash slot
    local stashTexture = GetContainerItemInfo(stashBag, stashSlot)
    if not stashTexture then
        self:Abort("Bag replacement failed: stashed bag is missing.")
        return
    end

    -- Pick up new bag from stash
    PickupContainerItem(stashBag, stashSlot)
    AddPendingLock(stashBag, stashSlot)

    -- Wait briefly for pickup, then equip
    Guda_ScheduleTimer(0.15, function()
        if CursorHasItem and CursorHasItem() then
            addon:DebugSort("[BagReplacer] Equipping new bag to invSlot %d", invSlot)
            EquipCursorItem(invSlot)

            -- Wait for BAG_UPDATE to confirm server processed the bag change
            WaitForBagUpdate(targetBagID, function()
                if CursorHasItem and CursorHasItem() then
                    addon:DebugSort("[BagReplacer] Old bag on cursor, finding free slot to place it")
                    -- Old bag is on cursor - try to find a free slot for it
                    local freeSlots, freeCount = GetAvailableFreeSlots(-999) -- exclude nothing
                    for i = 1, freeCount do
                        local fs = freeSlots[i]
                        if not fs.bagType then -- regular slot only
                            addon:DebugSort("[BagReplacer] Placing old bag into bag%d/slot%d", fs.bagID, fs.slot)
                            PickupContainerItem(fs.bagID, fs.slot)
                            ClearCursor()
                            break
                        end
                    end
                    -- If still on cursor, that's fine - user can place manually
                end

                FinalizeReplacement()
            end)
        else
            BagReplacer:Abort("Bag replacement failed: could not pick up new bag.")
        end
    end)
end

--===========================================================================
-- ExecuteNextBatch: move items in batches for speed
--===========================================================================
function BagReplacer:ExecuteNextBatch(plan, index, invSlot)
    local moves = plan.moves
    local totalMoves = table.getn(moves)

    -- Skip any already-empty source slots
    while index <= totalMoves do
        local sourceTexture = GetContainerItemInfo(moves[index].fromBag, moves[index].fromSlot)
        if sourceTexture then break end
        addon:DebugSort("[BagReplacer] Source slot empty, skipping move %d", index)
        index = index + 1
    end

    -- All moves done - finish replacement
    if index > totalMoves then
        addon:DebugSort("[BagReplacer] All %d moves complete, finishing replacement", totalMoves)
        self:FinishReplacement(invSlot, plan.stashBag, plan.stashSlot, plan.targetBagID)
        return
    end

    -- Check if first item in batch is locked (wait if so)
    local firstMove = moves[index]
    local _, _, locked = GetContainerItemInfo(firstMove.fromBag, firstMove.fromSlot)
    if locked then
        addon:DebugSort("[BagReplacer] Source bag%d/slot%d locked, waiting", firstMove.fromBag, firstMove.fromSlot)
        AddPendingLock(firstMove.fromBag, firstMove.fromSlot)
        WaitForLocksCleared(function()
            BagReplacer:ExecuteNextBatch(plan, index, invSlot)
        end)
        return
    end

    -- Execute a batch of moves
    local batchEnd = index + BATCH_SIZE - 1
    if batchEnd > totalMoves then batchEnd = totalMoves end
    local moved = 0

    for i = index, batchEnd do
        local move = moves[i]

        -- Verify source still has an item
        local sourceTexture = GetContainerItemInfo(move.fromBag, move.fromSlot)
        if sourceTexture then
            local _, _, sLocked = GetContainerItemInfo(move.fromBag, move.fromSlot)
            if not sLocked then
                PickupContainerItem(move.fromBag, move.fromSlot)
                PickupContainerItem(move.toBag, move.toSlot)
                ClearCursor()
                AddPendingLock(move.fromBag, move.fromSlot)
                AddPendingLock(move.toBag, move.toSlot)
                moved = moved + 1
                addon:DebugSort("[BagReplacer] Moved %d/%d: bag%d/slot%d -> bag%d/slot%d", i, totalMoves, move.fromBag, move.fromSlot, move.toBag, move.toSlot)
            else
                addon:DebugSort("[BagReplacer] Slot %d locked mid-batch, stopping batch", i)
                batchEnd = i - 1
                break
            end
        else
            addon:DebugSort("[BagReplacer] Source slot %d empty, skipping", i)
        end
    end

    local nextIndex = batchEnd + 1
    addon:DebugSort("[BagReplacer] Batch done: %d items moved, next index %d/%d", moved, nextIndex, totalMoves)

    if moved > 0 then
        -- Wait for batch locks to clear, then next batch
        WaitForLocksCleared(function()
            BagReplacer:ExecuteNextBatch(plan, nextIndex, invSlot)
        end)
    else
        -- Nothing moved (all empty/locked), try next batch immediately
        BagReplacer:ExecuteNextBatch(plan, nextIndex, invSlot)
    end
end

--===========================================================================
-- Execute: main entry point
--===========================================================================
function BagReplacer:Execute(targetBagID, invSlot)
    addon:DebugSort("[BagReplacer] Execute: targetBagID=%d, invSlot=%d", targetBagID, invSlot)

    -- Guard: already in progress
    if self.inProgress then
        addon:DebugSort("[BagReplacer] Blocked: replacement already in progress")
        addon:Print(Guda_L["Cannot replace bag: another replacement is in progress."])
        return
    end

    -- Guard: sorting in progress
    local SortEngine = addon.Modules.SortEngine
    if SortEngine and SortEngine.sortingInProgress then
        addon:DebugSort("[BagReplacer] Blocked: sorting in progress")
        addon:Print(Guda_L["Cannot replace bag while sorting is in progress."])
        return
    end

    -- Guard: combat
    if UnitAffectingCombat("player") then
        addon:DebugSort("[BagReplacer] Blocked: in combat")
        addon:Print(Guda_L["Cannot replace bag during combat."])
        return
    end

    -- Check if bag is empty (normal equip works)
    local _, itemCount = GetBagItems(targetBagID)
    if itemCount == 0 then
        addon:DebugSort("[BagReplacer] Bag is empty, using normal equip")
        if EquipCursorItem then
            EquipCursorItem(invSlot)
        elseif PutItemInBag then
            PutItemInBag(invSlot)
        end
        return
    end

    -- Build evacuation plan
    local plan, errorMsg = self:BuildEvacuationPlan(targetBagID)
    if not plan then
        addon:DebugSort("[BagReplacer] Plan failed: %s", errorMsg)
        addon:Print(errorMsg)
        return -- cursor untouched, user keeps holding new bag
    end

    -- Start replacement
    self.inProgress = true
    addon:Print(string.format("Replacing bag: moving %d items...", plan.itemCount))
    addon:DebugSort("[BagReplacer] Starting replacement: %d moves, stash at bag%d/slot%d", table.getn(plan.moves), plan.stashBag, plan.stashSlot)

    -- Step 1: Stash the new bag from cursor into the reserved free slot
    addon:DebugSort("[BagReplacer] Stashing cursor item to bag%d/slot%d", plan.stashBag, plan.stashSlot)
    PickupContainerItem(plan.stashBag, plan.stashSlot)
    -- This places cursor item (new bag) into stashSlot
    AddPendingLock(plan.stashBag, plan.stashSlot)

    -- Wait for stash to complete, then start evacuating
    WaitForLocksCleared(function()
        -- Verify the new bag was stashed
        local stashTexture = GetContainerItemInfo(plan.stashBag, plan.stashSlot)
        if not stashTexture then
            BagReplacer:Abort("Bag replacement failed: could not stash new bag.")
            return
        end
        addon:DebugSort("[BagReplacer] Stash confirmed, beginning evacuation")
        -- Begin moving items out of target bag
        BagReplacer:ExecuteNextBatch(plan, 1, invSlot)
    end)
end
