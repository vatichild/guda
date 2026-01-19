-- Guda Utility Functions

local addon = Guda

local Utils = {}
addon.Modules.Utils = Utils

--=============================================================================
-- SafeCall: Nil-safe module method invocation
-- Replaces verbose nil-checks like:
--   if addon and addon.Modules and addon.Modules.Utils and addon.Modules.Utils.Method then
--       return addon.Modules.Utils:Method(arg1, arg2)
--   end
-- With:
--   return Utils:SafeCall("Utils", "Method", arg1, arg2)
--=============================================================================

-- Call a method on a module safely, returns nil if module/method doesn't exist
-- Parameters:
--   moduleName: Name of the module in addon.Modules (e.g., "Utils", "DB", "BagFrame")
--   methodName: Name of the method to call (e.g., "GetQualityColor", "GetSetting")
--   ...: Arguments to pass to the method
-- Returns: The return value(s) of the method, or nil if not callable
function Utils:SafeCall(moduleName, methodName, ...)
    if not addon or not addon.Modules then
        return nil
    end

    local module = addon.Modules[moduleName]
    if not module then
        return nil
    end

    local method = module[methodName]
    if not method or type(method) ~= "function" then
        return nil
    end

    -- Call method with module as self (for : style calls)
    return method(module, unpack(arg))
end

-- Check if a module method exists without calling it
function Utils:HasMethod(moduleName, methodName)
    if not addon or not addon.Modules then
        return false
    end

    local module = addon.Modules[moduleName]
    if not module then
        return false
    end

    local method = module[methodName]
    return method ~= nil and type(method) == "function"
end

-- Get a module reference safely
function Utils:GetModule(moduleName)
    if not addon or not addon.Modules then
        return nil
    end
    return addon.Modules[moduleName]
end

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

-- Extract itemID from itemLink (Lua 5.0 compatible)
-- Returns: itemID as number, or nil if extraction fails
function Utils:ExtractItemID(itemLink)
    if not itemLink then return nil end
    local _, _, itemID = string.find(itemLink, "item:(%d+)")
    return itemID and tonumber(itemID) or nil
end

-- Get item info with error handling (does not cache)
-- Turtle WoW GetItemInfo signature:
-- itemName, itemLink, itemRarity, itemLevel, itemCategory, itemType, itemStackCount, itemSubType, itemTexture, itemEquipLoc, itemSellPrice
function Utils:GetItemInfoSafe(itemID)
    if not itemID then
        addon:Debug("GetItemInfoSafe: nil itemID")
        return nil
    end

    local itemName, itemLink, itemRarity, itemLevel, itemCategory, itemType, itemStackCount, itemSubType, itemTexture, itemEquipLoc, itemSellPrice = GetItemInfo(itemID)

    if not itemName then
        addon:Debug("GetItemInfoSafe: GetItemInfo failed for itemID %d", itemID)
        return nil
    end

    return itemName, itemLink, itemRarity, itemLevel, itemCategory, itemType, itemStackCount, itemSubType, itemTexture, itemEquipLoc, itemSellPrice
end

-- Get item info with caching (wrapper for backward compatibility)
function Utils:GetItemInfo(itemLink)
    if not itemLink then return nil end

    if itemCache[itemLink] then
        return unpack(itemCache[itemLink])
    end

    local itemID = self:ExtractItemID(itemLink)
    if not itemID then return nil end

    local itemName, retLink, itemRarity, itemLevel, itemCategory, itemType, itemStackCount, itemSubType, itemTexture, itemEquipLoc, itemSellPrice = self:GetItemInfoSafe(itemID)

    if itemName then
        itemCache[itemLink] = {itemName, retLink, itemRarity, itemLevel, itemCategory, itemType, itemStackCount, itemSubType, itemTexture, itemEquipLoc, itemSellPrice}
        return itemName, retLink, itemRarity, itemLevel, itemCategory, itemType, itemStackCount, itemSubType, itemTexture, itemEquipLoc, itemSellPrice
    end

    return nil
end

-- Create a hidden tooltip for scanning
local scanTooltip = CreateFrame("GameTooltip", "GudaBagScanTooltip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

-- Get item link from mailbox attachment (WoW 1.12.1 workaround)
function Utils:GetInboxItemLink(index, itemIndex)
    -- Try global function first (if it exists on this server/version)
    if GetInboxItemLink then
        -- Turtle WoW might support (index, itemIndex) for multiple attachments
        local link = GetInboxItemLink(index, itemIndex or 1)
        if link then return link end
        
        -- Fallback to single argument if that failed
        link = GetInboxItemLink(index)
        if link then return link end
    end

    -- In 1.12.1, GameTooltip:GetHyperlink() does not exist.
    -- Let's try to use GetItemInfo(name) as the primary way.
    local name, texture, count, quality = GetInboxItem(index, itemIndex or 1)
    if name then
        local itemName, link = GetItemInfo(name)
        if link then
            return link
        end
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

-- Create hidden tooltip for scanning (only once)
local function GetScanTooltip()
    return scanTooltip
end

-- Check if an item is a quest item by scanning its tooltip (internal helper)
-- Returns: isQuestItem, isQuestStarter
local function ScanTooltipForQuest(tooltip, tooltipName)
    local isQuestItem = false
    local isQuestStarter = false

    for i = 1, tooltip:NumLines() do
        local line = getglobal(tooltipName .. "TextLeft" .. i)
        if line then
            local text = line:GetText()
            if text then
                local tl = string.lower(text)
                -- Check for quest starter patterns first
                if string.find(tl, "quest starter") or
                   string.find(tl, "this item begins a quest") or
                   string.find(tl, "starts a quest") then
                    isQuestItem = true
                    isQuestStarter = true
                    break
                -- Check for regular quest item patterns
                elseif string.find(tl, "quest item") or
                       string.find(tl, "manual") then
                    isQuestItem = true
                    -- Don't break, might still find a quest starter pattern
                end
            end
        end
    end

    return isQuestItem, isQuestStarter
end

-- Consolidated quest item detection function
-- Handles tooltip scanning, category checks, equipment filtering, and QuestItemsDB lookup
-- Parameters:
--   bagID, slotID: Required for tooltip scanning (can be nil for other char items)
--   itemData: Optional item data table with link, class/category, type fields
--   isOtherChar: Boolean, true if checking an item from another character's saved data
--   isBank: Boolean, true if the item is in the bank
-- Returns: isQuestItem (boolean), isQuestStarter (boolean)
function Utils:IsQuestItem(bagID, slotID, itemData, isOtherChar, isBank)
    bagID = tonumber(bagID)
    slotID = tonumber(slotID)

    local isQuestItem = false
    local isQuestStarter = false

    -- Get item link and category info
    local itemLink = itemData and itemData.link
    local itemCategory = itemData and (itemData.class or itemData.category) or ""
    local itemType = itemData and itemData.type or ""
    local itemID

    -- For live items, query the link directly
    if not isOtherChar and bagID and slotID then
        itemLink = GetContainerItemLink(bagID, slotID)
    end

    if itemLink then
        itemID = self:ExtractItemID(itemLink)
        if itemID then
            local _, _, _, _, cat, typ = self:GetItemInfoSafe(itemID)
            itemCategory = cat or itemCategory
            itemType = typ or itemType
        end
    end

    -- Check if item is equipment (should not be classified as quest unless explicitly Quest category)
    local isEquipment = (itemCategory == "Weapon" or itemCategory == "Armor" or
                         itemType == "Weapon" or itemType == "Armor")
    local isQuestCategory = (itemCategory == "Quest" or itemType == "Quest")

    -- Priority 1: If explicitly categorized as Quest, it's a quest item
    if isQuestCategory then
        return true, false
    end

    -- Priority 2: Tooltip scanning for current character items
    if not isOtherChar and bagID and slotID then
        local tooltip = GetScanTooltip()
        tooltip:ClearLines()

        -- Handle bank items differently
        if isBank and bagID == -1 then
            if tooltip.SetInventoryItem then
                tooltip:SetInventoryItem("player", 39 + slotID)
            else
                tooltip:SetBagItem(bagID, slotID)
            end
        else
            tooltip:SetBagItem(bagID, slotID)
        end

        isQuestItem, isQuestStarter = ScanTooltipForQuest(tooltip, "GudaBagScanTooltip")

        -- Filter out equipment that has quest-like text but isn't categorized as Quest
        if isQuestItem and isEquipment and not isQuestCategory then
            isQuestItem = false
            isQuestStarter = false
        end
    end

    -- Priority 3: Check QuestItemsDB for known faction-specific quest items
    if not isQuestItem and itemID and addon.IsQuestItemByID then
        local playerFaction = UnitFactionGroup("player")
        if addon:IsQuestItemByID(itemID, playerFaction) then
            isQuestItem = true
        end
    end

    return isQuestItem, isQuestStarter
end

-- Legacy compatibility wrapper - keep the old function name working
function Utils:IsQuestItemTooltip(bagID, slotID)
    local isQuest, _ = self:IsQuestItem(bagID, slotID, nil, false, false)
    return isQuest
end

-- Check if an item has a gray title in its tooltip or link
function Utils:IsItemGrayTooltip(bagID, slotID, itemLink)
    -- Check link first if provided (works for other characters too)
    if itemLink and string.find(itemLink, "|cff9d9d9d") then
        return true
    end

    if not bagID or not slotID then return false end

    local tooltip = GetScanTooltip()
    tooltip:ClearLines()
    tooltip:SetBagItem(bagID, slotID)

    local line = getglobal("GudaBagScanTooltipTextLeft1")
    if line then
        local text = line:GetText()
        if text then
            -- Poor quality color code is |cff9d9d9d
            if string.find(text, "|cff9d9d9d") then
                return true
            end
        end
    end
    return false
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

-- Returns: "soul", "herb", "enchant", "quiver", "ammo", or nil
-- This is the consolidated bag type detection function with tooltip fallback
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

    local itemID = self:ExtractItemID(link)

    -- Try GetItemInfo first (more reliable when available)
    if itemID then
        local _, _, _, _, _, itemType = self:GetItemInfoSafe(itemID)
        if itemType then
            local typeLower = string.lower(itemType)

            if string.find(typeLower, "soul bag") or string.find(typeLower, "soul pouch") then
                return "soul"
            end
            if string.find(typeLower, "herb bag") then
                return "herb"
            end
            if string.find(typeLower, "enchanting bag") then
                return "enchant"
            end
            if string.find(typeLower, "quiver") then
                return "quiver"
            end
            if string.find(typeLower, "ammo pouch") then
                return "ammo"
            end
        end
    end

    -- Fallback: tooltip scanning for all bag types
    local tooltip = GetScanTooltip()
    tooltip:ClearLines()
    tooltip:SetInventoryItem("player", invSlot)

    for i = 1, tooltip:NumLines() do
        local line = getglobal("GudaBagScanTooltipTextLeft" .. i)
        if line then
            local text = line:GetText()
            if text then
                local textLower = string.lower(text)

                -- Soul Bag / Soul Pouch
                if string.find(textLower, "soul bag") or string.find(textLower, "soul pouch") or
                   (string.find(textLower, "soul") and (string.find(textLower, "bag") or string.find(textLower, "pouch"))) then
                    return "soul"
                end

                -- Herb Bag
                if string.find(textLower, "herb bag") then
                    return "herb"
                end

                -- Enchanting Bag
                if string.find(textLower, "enchanting bag") then
                    return "enchant"
                end

                -- Quiver
                if string.find(textLower, "quiver") then
                    return "quiver"
                end

                -- Ammo Pouch
                if string.find(textLower, "ammo pouch") then
                    return "ammo"
                end
            end
        end
    end

    return nil
end

-- Simple helper to check if a bag is of a specific type
function Utils:IsBagType(bagID, bagType)
    return self:GetSpecializedBagType(bagID) == bagType
end

-- Convenience wrappers for common bag type checks
function Utils:IsAmmoQuiverBag(bagID)
    local bagType = self:GetSpecializedBagType(bagID)
    return bagType == "quiver" or bagType == "ammo"
end

function Utils:IsHerbBag(bagID)
    return self:IsBagType(bagID, "herb")
end

function Utils:IsSoulBag(bagID)
    return self:IsBagType(bagID, "soul")
end

-- Get container priority for sorting (higher = more important)
function Utils:GetContainerPriority(bagID)
    local bagType = self:GetSpecializedBagType(bagID)
    if bagType == "enchant" then
        return 50
    elseif bagType == "herb" then
        return 45
    elseif bagType == "soul" then
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
    local itemID = self:ExtractItemID(itemLink)
    return itemID == SOUL_SHARD_ID
end

-- Extract hyperlink from item link for tooltip scanning
local function ExtractHyperlink(itemLink)
    if not itemLink then return nil end
    local _, _, hyperlink = string.find(itemLink, "|H(.+)|h")
    return hyperlink
end

-- Detect if a consumable has 'Use: Restores' or mentions 'while eating'/'while drinking'
function Utils:GetConsumableRestoreTag(bagID, slotID)
    if not bagID or not slotID then return nil end
    local tooltip = GetScanTooltip()
    tooltip:ClearLines()
    tooltip:SetBagItem(bagID, slotID)
    local tag = nil
    for i = 1, tooltip:NumLines() do
        local line = getglobal("GudaBagScanTooltipTextLeft" .. i)
        if line then
            local text = line:GetText()
            if text then
                local tl = string.lower(text)
                if string.find(tl, "while eating") then
                    tag = "eat"
                    break
                elseif string.find(tl, "while drinking") then
                    tag = "drink"
                    break
                elseif string.find(tl, "use: restores") then
                    tag = "restore"
                end
            end
        end
    end
    return tag
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
-- Returns: "soul", "herb", "enchant", "quiver", "ammo", or nil
function Utils:GetItemPreferredContainer(itemLink)
    if not itemLink then return nil end

    -- Check for soul shards first
    if self:IsSoulShard(itemLink) then
        return "soul"
    end

    -- Get item info using utility function
    local itemID = self:ExtractItemID(itemLink)
    if not itemID then return nil end

    local itemName, _, itemRarity, itemLevel, itemCategory, itemType, itemStackCount, itemSubType, itemTexture = self:GetItemInfoSafe(itemID)
    if not itemType then return nil end

    -- Only route PROJECTILE category items that are specifically arrows or bullets
    if itemCategory == "Projectile" then
        if itemType == "Arrow" then
            return "quiver"
        elseif itemType == "Bullet" then
            return "ammo"
        end
    end

    -- Route herbs to herb bags (robust: category/subtype OR texture pattern fallback)
    if self:IsHerbItem(itemLink) then
        return "herb"
    end

    -- Route enchanting materials to enchanting bags
    if self:IsEnchantingItem(itemLink) then
        return "enchant"
    end

    return nil
end

-- Check if an item is "Binds when equipped" by scanning its tooltip
-- For bank items, use itemLink since SetBagItem may not work for bank slots
function Utils:IsBindOnEquip(bagID, slotID, itemLink)
    if not bagID or not slotID then return false end
    
    local tooltip = GetScanTooltip()
    if not tooltip then return false end
    
    tooltip:ClearLines()
    
    -- Try SetBagItem first (works for regular bags and bank when open)
    tooltip:SetBagItem(bagID, slotID)
    
    local numLines = tooltip:NumLines()
    
    -- If no lines and we have itemLink, try SetHyperlink with itemString as fallback
    if (not numLines or numLines == 0) and itemLink then
        -- Extract itemString from link (format: item:12345:0:0:0...)
        local _, _, itemString = string.find(itemLink, "(item:%d+:%d+:%d+:%d+)")
        if itemString then
            tooltip:ClearLines()
            tooltip:SetHyperlink(itemString)
            numLines = tooltip:NumLines()
        end
    end
    
    if not numLines or numLines == 0 then return false end
    
    -- Check tooltip lines for "Binds when equipped"
    for i = 1, numLines do
        local line = getglobal("GudaBagScanTooltipTextLeft" .. i)
        if line then
            local text = line:GetText()
            if text and string.find(string.lower(text), "binds when equipped") then
                return true
            end
        end
    end
    return false
end

-- Check if an item is equipment (armor, weapon, or other equippable)
-- Returns: true if item is equipment, false otherwise
function Utils:IsEquipment(itemLink)
	if not itemLink then return false end

	local itemID = self:ExtractItemID(itemLink)
	if not itemID then return false end

	local itemName, _, itemRarity, itemLevel, itemCategory, itemType, itemStackCount, itemSubType, itemTexture, itemEquipLoc = self:GetItemInfoSafe(itemID)

	-- Check if item has an equip location (most reliable method)
	if itemEquipLoc and itemEquipLoc ~= "" and itemEquipLoc ~= "INVTYPE_BAG" then
		return true
	end

	-- Fallback: Check category (in case itemEquipLoc is not set)
	if itemCategory then
		local categoryLower = string.lower(itemCategory)
		if categoryLower == "armor" or categoryLower == "weapon" then
			return true
		end
	end

 return false
end

-- Determine if an item is a herb (for routing to herb bags)
-- NEW rule (per request): require BOTH
--   1) itemCategory == "Trade Goods"
--   2) texture contains "INV_Misc_Herb" (case-insensitive; prefix tolerated)
function Utils:IsHerbItem(itemLink)
    if not itemLink then return false end

    local itemID = self:ExtractItemID(itemLink)
    if not itemID then return false end

    local name, _, quality, iLevel, itemCategory, itemType, itemStackCount, itemSubType, itemTexture = self:GetItemInfoSafe(itemID)

    if itemCategory ~= "Trade Goods" then
        return false
    end

    if not itemTexture then
        return false
    end

    -- Normalize and check texture name
    local tex = string.lower(itemTexture)
    tex = string.gsub(tex, "^interface\\\\icons\\\\", "")

    if string.find(tex, "inv_misc_herb") or string.find(tex, "misc_herb") then
        return true
    end

    return false
end

-- Determine if an item is an enchanting material (for routing to enchanting bags)
-- Rules:
--   1) itemCategory == "Trade Goods"
--   2) (itemSubType == "Enchanting") OR texture contains "INV_Enchant" (case-insensitive)
function Utils:IsEnchantingItem(itemLink)
    if not itemLink then return false end

    local itemID = self:ExtractItemID(itemLink)
    if not itemID then return false end

    local name, _, quality, iLevel, itemCategory, itemType, itemStackCount, itemSubType, itemTexture = self:GetItemInfoSafe(itemID)

    if itemCategory ~= "Trade Goods" then
        -- Some private servers may report Enchanting directly as type
        if itemType ~= "Enchanting" and itemSubType ~= "Enchanting" then
            return false
        end
    end

    -- If explicit Enchanting subtype/type, accept immediately
    if itemType == "Enchanting" or itemSubType == "Enchanting" then
        return true
    end

    if not itemTexture then
        return false
    end

    -- Normalize and check texture name
    local tex = string.lower(itemTexture)
    tex = string.gsub(tex, "^interface\\\\icons\\\\", "")

    if string.find(tex, "inv_enchant") or string.find(tex, "enchant") then
        return true
    end

    return false
end

-- Check if a bag is Enchanting Bag
function Utils:IsEnchantBag(bagID)
    return self:IsBagType(bagID, "enchant")
end