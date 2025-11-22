-- Guda Bag Scanner
-- Scans and stores bag contents

local addon = Guda

local BagScanner = {}
addon.Modules.BagScanner = BagScanner

-- Scan all bags and return data
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
    local bagType = "regular"
    if addon.Modules.Utils:IsSoulBag(bagID) then
        bagType = "soul"
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
    -- Correct order: itemName, itemLink, itemRarity, itemLevel, itemCategory, itemType,
    --                itemStackCount, itemSubType, itemTexture, itemEquipLoc, itemSellPrice
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
        class = itemCategory,      -- Category (e.g., "Consumable", "Armor")
        subclass = itemSubType,    -- SubType (e.g., "Potion", "Cloth")
        equipSlot = itemEquipLoc,  -- Equipment slot (e.g., "INVTYPE_HEAD") - correct now!
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

-- Initialize with auto-save on bag changes
function BagScanner:Initialize()
    -- Create event frame for bag updates
    local eventFrame = CreateFrame("Frame")
    self.eventFrame = eventFrame

    -- Register bag update events
    eventFrame:RegisterEvent("BAG_UPDATE")
    eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")

    eventFrame:SetScript("OnEvent", function()
        if event == "BAG_UPDATE" or event == "BAG_UPDATE_DELAYED" then
            addon:Debug("Bag update detected, saving data...")
            self:SaveToDatabase()
        end
    end)

    addon:Debug("Bag scanner initialized with auto-save")
end