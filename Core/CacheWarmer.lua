-- Guda CacheWarmer
-- Pre-warms ItemDetection's tooltip-scan cache and BagScanner's bag-data
-- cache shortly after PLAYER_LOGIN, in the background, so the FIRST time the
-- user opens the bag frame they don't pay for ~80 synchronous tooltip scans.
--
-- Reuses Utils:QueueWork (Core/Utils.lua) for frame-budgeted background
-- processing — no new scheduler.

local addon = Guda

local CacheWarmer = {}
addon.Modules.CacheWarmer = CacheWarmer

-- Walk player bags 0-4 and warm BagScanner per-bag cache. Cheap, runs inline.
function CacheWarmer:WarmBagScanner()
    local BagScanner = Guda.Modules.BagScanner
    if not BagScanner or not BagScanner.ScanBag then return end
    -- ScanBag populates the per-bag cache used by GetBagData later.
    for bagID = 0, 4 do
        local ok = pcall(function() BagScanner:ScanBag(bagID) end)
        if not ok then break end
    end
end

-- Walk player bags 0-4 and queue tooltip-scan work for every cache the
-- bag-open path reads, so the first DisplayItemsByCategory never blocks on
-- a cold lookup. Targets:
--   * ItemDetection.detectionCache  — used for isJunk / isQuestItem rules
--   * Utils.tooltipCache.restoreTag — used for consumable food/drink grouping
--   * Utils.tooltipCache.bindOnEquip — used for the isBoE rule
--   * CategoryManager.categoryCache — used directly by the layout path
-- Queue order is FIFO and budget-limited to 100ms/frame, so this all runs
-- in the 0.5s–~2s window after PLAYER_LOGIN.
function CacheWarmer:WarmItemDetectionCache()
    local Utils = Guda.Modules.Utils
    local ItemDetection = Guda.Modules.ItemDetection
    local CategoryManager = Guda.Modules.CategoryManager
    local BagScanner = Guda.Modules.BagScanner
    if not (Utils and Utils.QueueWork) then return end
    if not (ItemDetection and ItemDetection.GetItemProperties) then return end

    -- WarmBagScanner ran just before us, so GetBagData() is a cache hit and
    -- returns the already-populated itemData with class/subclass/quality.
    local bagData = BagScanner and BagScanner.GetBagData and BagScanner:GetBagData()

    for bagID = 0, 4 do
        local numSlots = GetContainerNumSlots(bagID)
        if numSlots and numSlots > 0 then
            for slotID = 1, numSlots do
                local link = GetContainerItemLink(bagID, slotID)
                if link then
                    -- Capture upvalues so the closure has stable bag/slot/link.
                    local b, s, l = bagID, slotID, link

                    Utils:QueueWork(function()
                        -- Minimal itemData — GetItemProperties only needs
                        -- .link to compute the cache key; bagID/slotID feed
                        -- the tooltip scan.
                        ItemDetection:GetItemProperties({ link = l }, b, s)
                    end, "CacheWarmer.itemDetection")

                    -- Consumable restoreTag cache (only consumables carry
                    -- "while eating" / "while drinking" / "use: restores").
                    Utils:QueueWork(function()
                        local _, _, _, _, itemType = GetItemInfo(l)
                        if itemType == "Consumable" and Utils.GetConsumableRestoreTag then
                            Utils:GetConsumableRestoreTag(b, s, l)
                        end
                    end, "CacheWarmer.restoreTag")

                    -- BoE tooltip cache. Only weapons/armor can be BoE; skip
                    -- everything else so we don't scan consumables / trade
                    -- goods tooltips for nothing.
                    Utils:QueueWork(function()
                        local _, _, _, _, _, class = GetItemInfo(l)
                        if (class == "Weapon" or class == "Armor") and Utils.IsBindOnEquip then
                            Utils:IsBindOnEquip(b, s, l)
                        end
                    end, "CacheWarmer.boe")

                    -- CategoryManager cache. Snapshot itemData fields because
                    -- BagScanner uses a pool and may recycle the table later.
                    -- The restoreTag field is populated inside the callback
                    -- (not here) because the restoreTag warmer runs first via
                    -- FIFO queue order — so by the time this fires, the
                    -- tooltipCache.restoreTag lookup is a cache hit.
                    if CategoryManager and CategoryManager.CategorizeItem and bagData then
                        local bag = bagData[b]
                        local slotData = bag and bag.slots and bag.slots[s]
                        if slotData and slotData.link then
                            local snapshot = {
                                link = slotData.link,
                                name = slotData.name,
                                class = slotData.class,
                                type = slotData.type,
                                subclass = slotData.subclass,
                                quality = slotData.quality,
                                texture = slotData.texture,
                                equipSlot = slotData.equipSlot,
                            }
                            Utils:QueueWork(function()
                                -- Pull restoreTag from warm cache so rules that
                                -- key on it (Food/Drink categories) match.
                                if snapshot.class == "Consumable"
                                   and Utils.GetConsumableRestoreTag then
                                    snapshot.restoreTag =
                                        Utils:GetConsumableRestoreTag(b, s, snapshot.link)
                                end
                                CategoryManager:CategorizeItem(snapshot, b, s, false)
                            end, "CacheWarmer.category")
                        end
                    end
                end
            end
        end
    end
end

function CacheWarmer:Initialize()
    -- Defer ~0.5s so we don't compete with the busy login frame. The user
    -- typically opens bags several seconds later, so the cache will be hot.
    Guda_ScheduleTimer(0.5, function()
        CacheWarmer:WarmBagScanner()
        CacheWarmer:WarmItemDetectionCache()

        -- Completion marker — runs after all prior warmers drain. Re-layouts
        -- the bag so items that fell back to their class bucket on the first
        -- (cold-cache) render now land in their real categories, and re-sweeps
        -- tints for items whose detection finished while the bag was already
        -- open.
        local Utils = Guda.Modules.Utils
        if Utils and Utils.QueueWork then
            Utils:QueueWork(function()
                if Guda_BagFrame and Guda_BagFrame:IsShown()
                   and Guda.Modules.BagFrame and Guda.Modules.BagFrame.Update then
                    Guda.Modules.BagFrame:Update()
                end
                if Guda_BagFrame_UpdateAllUsabilityTints then
                    Guda_BagFrame_UpdateAllUsabilityTints()
                end
            end, "CacheWarmer.completionSweep")
        end
    end)
end
