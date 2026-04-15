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

-- Walk player bags 0-4 and queue one ItemDetection:GetItemProperties per
-- occupied slot, plus Utils:GetConsumableRestoreTag for consumables. The
-- work queue spreads them across frames within the existing 100ms-per-frame
-- budget. This warms both tooltip caches the bag-open path reads
-- (ItemDetection.detectionCache and Utils.tooltipCache.restoreTag), so the
-- first bag open doesn't pay for synchronous tooltip scans.
function CacheWarmer:WarmItemDetectionCache()
    local Utils = Guda.Modules.Utils
    local ItemDetection = Guda.Modules.ItemDetection
    if not (Utils and Utils.QueueWork) then return end
    if not (ItemDetection and ItemDetection.GetItemProperties) then return end

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

                    -- Warm the consumable restoreTag cache too. Only consumables
                    -- ever carry the relevant tooltip lines, so check class via
                    -- GetItemInfo (cached by the client after the detection scan
                    -- above) and queue only matching items.
                    Utils:QueueWork(function()
                        local _, _, _, _, itemType = GetItemInfo(l)
                        if itemType == "Consumable" and Utils.GetConsumableRestoreTag then
                            Utils:GetConsumableRestoreTag(b, s, l)
                        end
                    end, "CacheWarmer.restoreTag")
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
    end)
end
