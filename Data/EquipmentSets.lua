-- Guda Equipment Sets Module
-- Detects and tracks equipment sets from Outfitter and ItemRack addons
-- Provides API for checking if items belong to equipment sets

local addon = Guda

local EquipmentSets = {}
addon.Modules.EquipmentSets = EquipmentSets

-- Internal state
local setData = {}       -- { setName => { itemIDs = {[itemID] = true} } }
local itemToSets = {}    -- { [itemID] => { setName1 = true, setName2 = true } }
local initialized = false
local outfitterReady = false
local itemRackReady = false

-------------------------------------------
-- Public API
-------------------------------------------

-- Check if an item ID belongs to any equipment set
function EquipmentSets:IsInSet(itemID)
    if not itemID then return false end
    return itemToSets[itemID] ~= nil
end

-- Get set names that contain a specific item ID
-- Returns a table of set names or nil
function EquipmentSets:GetSetNames(itemID)
    if not itemID then return nil end
    local sets = itemToSets[itemID]
    if not sets then return nil end

    local names = {}
    for name in pairs(sets) do
        table.insert(names, name)
    end
    if table.getn(names) == 0 then return nil end
    return names
end

-- Get all known set names (sorted)
function EquipmentSets:GetAllSetNames()
    local names = {}
    for name in pairs(setData) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

-------------------------------------------
-- Internal: Rebuild item-to-set index
-------------------------------------------

local function RebuildItemIndex()
    itemToSets = {}
    for setName, data in pairs(setData) do
        if data.itemIDs then
            for itemID in pairs(data.itemIDs) do
                if not itemToSets[itemID] then
                    itemToSets[itemID] = {}
                end
                itemToSets[itemID][setName] = true
            end
        end
    end
end

-------------------------------------------
-- Outfitter Integration
-------------------------------------------

local function ScanOutfitter()
    -- Check if Outfitter is loaded and initialized
    if not Outfitter_GetCategoryOrder then return false end

    addon:Debug("EquipmentSets: Scanning Outfitter outfits...")

    local categoryOrder = Outfitter_GetCategoryOrder()
    if not categoryOrder then return false end

    local scannedSets = 0
    for _, catID in ipairs(categoryOrder) do
        local outfits = nil
        if Outfitter_GetOutfitsByCategoryID then
            outfits = Outfitter_GetOutfitsByCategoryID(catID)
        end
        if outfits then
            for _, outfit in ipairs(outfits) do
                local setName = outfit.Name
                if setName and outfit.Items then
                    local itemIDs = {}
                    for slotName, item in pairs(outfit.Items) do
                        if item then
                            local itemID = nil
                            -- Outfitter stores item codes
                            if item.Code then
                                itemID = tonumber(item.Code)
                            elseif item.ItemID then
                                itemID = tonumber(item.ItemID)
                            end
                            if itemID and itemID > 0 then
                                itemIDs[itemID] = true
                            end
                        end
                    end

                    setData[setName] = { itemIDs = itemIDs, source = "Outfitter" }
                    scannedSets = scannedSets + 1
                end
            end
        end
    end

    addon:Debug("EquipmentSets: Scanned %d Outfitter outfits", scannedSets)
    return scannedSets > 0
end

local function HookOutfitterEvents()
    if not Outfitter_RegisterOutfitEvent then return end

    local events = { "ADD", "DELETE", "EDIT", "RENAME" }
    for _, eventName in ipairs(events) do
        local success, err = pcall(function()
            Outfitter_RegisterOutfitEvent(eventName, function()
                -- Rescan after a brief delay to let Outfitter finish its update
                addon:Debug("EquipmentSets: Outfitter event '%s', rescanning...", eventName)
                ScanOutfitter()
                RebuildItemIndex()
                -- Sync categories
                if addon.Modules.CategoryManager then
                    addon.Modules.CategoryManager:SyncEquipmentSetCategories()
                end
            end)
        end)
        if not success then
            addon:Debug("EquipmentSets: Failed to hook Outfitter event '%s': %s", eventName, tostring(err))
        end
    end
end

-------------------------------------------
-- ItemRack Integration
-------------------------------------------

local function ScanItemRack()
    -- Check if ItemRack is loaded
    if not ItemRackUser or not ItemRackUser.Sets then return false end

    addon:Debug("EquipmentSets: Scanning ItemRack sets...")

    local scannedSets = 0
    for setName, setInfo in pairs(ItemRackUser.Sets) do
        -- Skip internal sets (start with special chars)
        if not string.find(setName, "^~") then
            local itemIDs = {}
            if setInfo.equip then
                for slot, itemString in pairs(setInfo.equip) do
                    -- ItemRack format: "itemID:enchant:suffix:unique"
                    if type(itemString) == "string" then
                        local _, _, idStr = string.find(itemString, "^(%d+)")
                        local itemID = tonumber(idStr)
                        if itemID and itemID > 0 then
                            itemIDs[itemID] = true
                        end
                    elseif type(itemString) == "number" then
                        if itemString > 0 then
                            itemIDs[itemString] = true
                        end
                    end
                end
            end

            setData[setName] = { itemIDs = itemIDs, source = "ItemRack" }
            scannedSets = scannedSets + 1
        end
    end

    addon:Debug("EquipmentSets: Scanned %d ItemRack sets", scannedSets)
    return scannedSets > 0
end

-------------------------------------------
-- Full Scan (all sources)
-------------------------------------------

local function FullScan()
    setData = {}

    local hasOutfitter = ScanOutfitter()
    local hasItemRack = ScanItemRack()

    RebuildItemIndex()

    -- Sync equipment set categories
    if addon.Modules.CategoryManager then
        addon.Modules.CategoryManager:SyncEquipmentSetCategories()
    end

    if hasOutfitter or hasItemRack then
        addon:Debug("EquipmentSets: Full scan complete, %d total sets", table.getn(EquipmentSets:GetAllSetNames()))
    end
end

-------------------------------------------
-- Initialization
-------------------------------------------

function EquipmentSets:Initialize()
    if initialized then return end
    initialized = true

    -- Register for ADDON_LOADED to catch late-loading addons
    addon.Modules.Events:Register("ADDON_LOADED", function(event, addonName)
        if addonName == "Outfitter" then
            -- Outfitter needs its INIT event before scanning
            outfitterReady = true
            addon:Debug("EquipmentSets: Outfitter loaded, waiting for INIT...")
        elseif addonName == "ItemRack" then
            itemRackReady = true
            addon:Debug("EquipmentSets: ItemRack loaded, scanning...")
            FullScan()
        end
    end, "EquipmentSets")

    -- Register for PLAYER_ENTERING_WORLD to catch already-loaded addons
    addon.Modules.Events:Register("PLAYER_ENTERING_WORLD", function()
        -- Check if Outfitter is already loaded
        if Outfitter_GetCategoryOrder or gOutfitter_Initialized then
            outfitterReady = true
            HookOutfitterEvents()
            FullScan()
        end

        -- Check if ItemRack is already loaded
        if ItemRackUser and ItemRackUser.Sets then
            itemRackReady = true
            FullScan()
        end
    end, "EquipmentSets")

    -- Hook Outfitter's INIT event if available (fires after Outfitter finishes setup)
    -- This uses a frame to check periodically since OUTFITTER_INIT is a custom event
    local initCheckFrame = CreateFrame("Frame")
    initCheckFrame.elapsed = 0
    initCheckFrame.checks = 0
    initCheckFrame:SetScript("OnUpdate", function()
        this.elapsed = this.elapsed + arg1
        if this.elapsed < 1 then return end
        this.elapsed = 0
        this.checks = this.checks + 1

        -- Check if Outfitter became available
        if not outfitterReady and (gOutfitter_Initialized or Outfitter_GetCategoryOrder) then
            outfitterReady = true
            HookOutfitterEvents()
            FullScan()
            this:Hide()
            return
        end

        -- Stop checking after 30 seconds
        if this.checks > 30 then
            this:Hide()
            -- Do a final scan anyway in case addons loaded without events
            if Outfitter_GetCategoryOrder or (ItemRackUser and ItemRackUser.Sets) then
                FullScan()
            end
        end
    end)
    initCheckFrame:Show()

    addon:Debug("EquipmentSets: Module initialized")
end

-- Force a rescan of all equipment set sources
function EquipmentSets:Rescan()
    FullScan()
end
