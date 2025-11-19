-- Guda Utility Functions

local addon = Guda

local Utils = {}
addon.Modules.Utils = Utils

-- Format money (copper to gold/silver/copper string) - WoW 1.12.1 version
function Utils:FormatMoney(copper, showZero, useColors)
    if not copper or copper == 0 then
        if useColors then
            return "|cFFFFFFFF" .. "0" .. "|r" .. "|cFFEDA55F" .. "c" .. "|r"
        else
            return "0c"
        end
    end

    local gold = math.floor(copper / 10000)
    local silver = math.floor(mod(copper, 10000) / 100)
    local bronze = mod(copper, 100)

    local str = ""

    if useColors then
        -- Colored version for tooltips - white numbers, colored g/s/c letters
        if gold > 0 then
            str = str .. "|cFFFFFFFF" .. gold .. "|r" .. "|cFFFFD700" .. "g" .. "|r "
        end
        if silver > 0 or gold > 0 then
            str = str .. "|cFFFFFFFF" .. silver .. "|r" .. "|cFFC7C7CF" .. "s" .. "|r "
        end
        str = str .. "|cFFFFFFFF" .. bronze .. "|r" .. "|cFFEDA55F" .. "c" .. "|r"
    else
        -- Plain text version
        if gold > 0 then
            str = str .. gold .. "g "
        end
        if silver > 0 or gold > 0 then
            str = str .. silver .. "s "
        end
        str = str .. bronze .. "c"
    end

    return str
end

-- Get item info with caching
local itemCache = {}

local function DebugGetItemInfo(itemID, itemName)
	if not itemID then
		addon:Print("NO ITEM ID for: " .. tostring(itemName))
		return
	end


	local itemName, itemLink, itemRarity, itemLevel, itemCategory, itemType, itemStackCount,
	itemSubType, itemTexture, itemEquipLoc, itemSellPrice = GetItemInfo(itemID)
	addon:Print("=== GetItemInfo DEBUG ===")
	addon:Print(string.format("Input ItemID: %d", itemID))
	addon:Print(string.format("Input Name: %s", tostring(itemName)))
	addon:Print("--- Return Values ---")
	addon:Print(string.format("1. itemName: '%s'", tostring(itemName)))
	addon:Print(string.format("2. itemLink: '%s'", tostring(itemLink)))
	addon:Print(string.format("3. itemRarity: %s", itemRarity or 0))
	addon:Print(string.format("4. itemLevel: %s", itemLevel or 0))
	addon:Print(string.format("5. itemMinLevel: %s", itemMinLevel or 0))
	addon:Print(string.format("6. itemType: '%s'", tostring(itemType)))
	addon:Print(string.format("7. itemSubType: '%s'", tostring(itemSubType)))
	addon:Print(string.format("8. itemStackCount: %s", itemStackCount or 0))
	addon:Print(string.format("9. itemEquipLoc: '%s'", tostring(itemEquipLoc)))
	addon:Print(string.format("10. itemTexture: '%s'", tostring(itemTexture)))
	addon:Print(string.format("11. itemSellPrice: %s", itemSellPrice or 0))
	addon:Print("=====================")
end
function Utils:GetItemInfo(itemLink)
    if not itemLink then return nil end

    if itemCache[itemLink] then
        return unpack(itemCache[itemLink])
    end

    -- Extract itemID from itemLink
    local _, _, itemID = string.find(itemLink, "item:(%d+)")
    if not itemID then return nil end

    -- Turtle WoW GetItemInfo signature:
    -- itemName, itemLink, itemRarity, itemLevel, itemCategory, itemType, itemStackCount, itemSubType, itemTexture, itemEquipLoc, itemSellPrice
    local itemName, retLink, itemRarity, itemLevel, itemCategory, itemType, itemStackCount, itemSubType, itemTexture, itemEquipLoc, itemSellPrice = GetItemInfo(tonumber(itemID))
    if itemName then
        itemCache[itemLink] = {itemName, retLink, itemRarity, itemLevel, itemCategory, itemType, itemStackCount, itemSubType, itemTexture, itemEquipLoc, itemSellPrice}
        return itemName, retLink, itemRarity, itemLevel, itemCategory, itemType, itemStackCount, itemSubType, itemTexture, itemEquipLoc, itemSellPrice
    end

    return nil
end

-- Get quality color
function Utils:GetQualityColor(quality)
    local color = addon.Constants.QUALITY_COLORS[quality] or addon.Constants.QUALITY_COLORS[1]
    return color.r, color.g, color.b
end

-- Create colored text
function Utils:ColorText(text, r, g, b)
    local red = math.floor(r * 255)
    local green = math.floor(g * 255)
    local blue = math.floor(b * 255)
    return string.format("|cFF%02X%02X%02X%s|r", red, green, blue, text)
end

-- Deep copy table
function Utils:DeepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[Utils:DeepCopy(orig_key)] = Utils:DeepCopy(orig_value)
        end
        setmetatable(copy, Utils:DeepCopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

-- Get class color
function Utils:GetClassColor(class)
    local colors = {
        WARRIOR = {r = 0.78, g = 0.61, b = 0.43},
        PALADIN = {r = 0.96, g = 0.55, b = 0.73},
        HUNTER = {r = 0.67, g = 0.83, b = 0.45},
        ROGUE = {r = 1.00, g = 0.96, b = 0.41},
        PRIEST = {r = 1.00, g = 1.00, b = 1.00},
        SHAMAN = {r = 0.00, g = 0.44, b = 0.87},
        MAGE = {r = 0.41, g = 0.80, b = 0.94},
        WARLOCK = {r = 0.58, g = 0.51, b = 0.79},
        DRUID = {r = 1.00, g = 0.49, b = 0.04},
    }
    return colors[class] or {r = 0.5, g = 0.5, b = 0.5}
end

-- Format time ago
function Utils:FormatTimeAgo(timestamp)
    local diff = time() - timestamp
    if diff < 60 then
        return "Just now"
    elseif diff < 3600 then
        return math.floor(diff / 60) .. "m ago"
    elseif diff < 86400 then
        return math.floor(diff / 3600) .. "h ago"
    else
        return math.floor(diff / 86400) .. "d ago"
    end
end

-- Get bag slot count
function Utils:GetBagSlotCount(bagID)
    if bagID == -1 then
        -- Bank has 24 slots in vanilla
        return 24
    elseif bagID == -2 then
        -- Keyring - vanilla WoW has 12-32 slots depending on version
        local slots = GetContainerNumSlots(bagID)
        if not slots or slots == 0 then
            -- Fallback: keyring typically has 12 slots in vanilla
            return 12
        end
        return slots
    else
        return GetContainerNumSlots(bagID) or 0
    end
end

-- Check if bag is valid
function Utils:IsBagValid(bagID)
    if bagID == 0 or bagID == -1 or bagID == -2 then
        return true
    end
    return GetContainerNumSlots(bagID) and GetContainerNumSlots(bagID) > 0
end

-- Truncate text to length
function Utils:TruncateText(text, maxLen)
    if not text then return "" end
    if string.len(text) <= maxLen then
        return text
    end
    return string.sub(text, 1, maxLen - 3) .. "..."
end

-- Create hidden tooltip for scanning (only once)
local scanTooltip = nil
local function GetScanTooltip()
    if not scanTooltip then
        scanTooltip = CreateFrame("GameTooltip", "GudaBagScanTooltip", nil, "GameTooltipTemplate")
        scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end
    return scanTooltip
end

-- Check if a bag is Quiver or Ammo Pouch
function Utils:IsAmmoQuiverBag(bagID)
    -- Skip backpack, bank, and keyring
    if bagID == 0 or bagID == -1 or bagID == -2 then
        return false
    end

    -- Get the bag item
    local invSlot = ContainerIDToInventoryID(bagID)
    if not invSlot then
        return false
    end

    local link = GetInventoryItemLink("player", invSlot)
    if not link then
        return false
    end

    -- Use tooltip scanning to get item class (more reliable in 1.12.1)
    local tooltip = GetScanTooltip()
    tooltip:ClearLines()
    tooltip:SetInventoryItem("player", invSlot)

    -- Scan tooltip lines for "Quiver" or "Ammo Pouch"
    for i = 1, tooltip:NumLines() do
        local line = getglobal("GudaBagScanTooltipTextLeft" .. i)
        if line then
            local text = line:GetText()
            if text then
                -- Check if the line contains "Quiver" or "Ammo Pouch"
                if string.find(text, "Quiver") or string.find(text, "Ammo Pouch") then
                    return true
                end
            end
        end
    end

    return false
end

-- Get specialized bag type (for sorting priority)
-- Returns: "soul", "quiver", "ammo", or nil
function Utils:GetSpecializedBagType(bagID)
    -- Skip backpack, bank, and keyring
    if bagID == 0 or bagID == -1 or bagID == -2 then
        return nil
    end

    -- Get the bag item
    local invSlot = ContainerIDToInventoryID(bagID)
    if not invSlot then
        return nil
    end

    local link = GetInventoryItemLink("player", invSlot)
    if not link then
        return nil
    end

    -- Extract itemID from link
    local _, _, itemID = string.find(link, "item:(%d+)")
    if not itemID then
        return nil
    end

    -- Use GetItemInfo to get subType (Turtle WoW signature)
    local itemName, _, itemRarity, itemLevel, itemCategory, itemType, itemStackCount, itemSubType = GetItemInfo(tonumber(itemID))
    if itemType then
        -- Check for exact subtype matches
        local typeLower = string.lower(itemType)

        -- Soul Bag / Soul Pouch
        if string.find(typeLower, "soul bag") or string.find(typeLower, "soul pouch") then
            return "soul"
        end

        -- Quiver
        if string.find(typeLower, "quiver") then
            return "quiver"
        end

        -- Ammo Pouch
        if string.find(typeLower, "ammo pouch") then
            return "ammo"
        end
    end

    return nil
end

-- Get container priority for sorting (higher = more important)
function Utils:GetContainerPriority(bagID)
    local bagType = self:GetSpecializedBagType(bagID)
    if bagType == "soul" then
        return 40
    elseif bagType == "quiver" then
        return 30
    elseif bagType == "ammo" then
        return 20
    else
        return 10  -- Regular bag
    end
end

-- Soul Shard item ID
local SOUL_SHARD_ID = 6265

-- Check if item is a Soul Shard
function Utils:IsSoulShard(itemLink)
    if not itemLink then return false end
    local _, _, itemID = string.find(itemLink, "item:(%d+)")
    return tonumber(itemID) == SOUL_SHARD_ID
end

-- Extract hyperlink from item link for tooltip scanning
local function ExtractHyperlink(itemLink)
    if not itemLink then return nil end
    local _, _, hyperlink = string.find(itemLink, "|H(.+)|h")
    return hyperlink
end

-- Check if item is Arrow or Bullet (for Quiver routing)
function Utils:IsArrowOrBullet(itemType)
	if not itemType then return false end
	-- Exact matching only
	return itemType == "Arrow" or itemType == "Bullet"
end

-- Check if item is Ammo (any type - for Ammo Pouch)
function Utils:IsAmmo(itemType)
	if not itemType then return false end
	return itemType == "Arrow" or itemType == "Bullet"
end

-- Get preferred container type for an item
-- Returns: "soul", "quiver", "ammo", or nil
function Utils:GetItemPreferredContainer(itemLink)
	if not itemLink then return nil end

	-- Check for soul shards first
	if self:IsSoulShard(itemLink) then
		return "soul"
	end

	-- Extract itemID and get item info
	local _, _, itemID = string.find(itemLink, "item:(%d+)")
	if not itemID then return nil end

	local itemName, _, itemRarity, itemLevel, itemCategory, itemType, itemStackCount, itemSubType = GetItemInfo(tonumber(itemID))
	if not itemType then return nil end

	-- Only route PROJECTILE category items that are specifically arrows or bullets
	if itemCategory == "Projectile" then
		if itemType == "Arrow" then
			addon:Print("-> Routing to QUIVER (Projectile - Arrow)")
			return "quiver"
		elseif itemType == "Bullet" then
			addon:Print("-> Routing to AMMO (Projectile - Bullet)")
			return "ammo"
		end
	end

	return nil
end