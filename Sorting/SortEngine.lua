-- Guda Sort Engine
-- 6-Phase Advanced Sorting Algorithm for WoW 1.12.1 / Turtle WoW

local addon = Guda

local SortEngine = {}
addon.Modules.SortEngine = SortEngine

-- Flag to track if sorting is currently in progress
SortEngine.sortingInProgress = false

-- Update sort button appearance based on sorting state
function SortEngine:UpdateSortButtonState(isDisabled)
	local buttons = {
		getglobal("Guda_BagFrame_SortButton"),
		getglobal("Guda_BankFrame_SortButton")
	}

	for _, btn in ipairs(buttons) do
		if btn then
			local icon = getglobal(btn:GetName() .. "_Icon")
			if icon then
				if isDisabled then
					icon:SetVertexColor(0.4, 0.4, 0.4)
				else
					icon:SetVertexColor(0.8, 0.8, 0.8)
				end
			end
		end
	end
end

--===========================================================================
-- CONSTANTS
--===========================================================================

-- Turtle WoW GetItemInfo signature:
-- itemName, itemLink, itemRarity, itemLevel, itemCategory, itemType, itemStackCount,
-- itemSubType, itemTexture, itemEquipLoc, itemSellPrice = GetItemInfo(itemID)

-- Priority items that should always be sorted first
local PRIORITY_ITEMS = {
	[6948] = 1, -- Hearthstone (highest priority)
}

-- Equipment slot ordering (for sorting equippable gear by slot)
local EQUIP_SLOT_ORDER = {
	["INVTYPE_WEAPONMAINHAND"] = 1,
	["INVTYPE_WEAPONOFFHAND"] = 2,
	["INVTYPE_WEAPON"] = 3,
	["INVTYPE_2HWEAPON"] = 4,
	["INVTYPE_SHIELD"] = 5,
	["INVTYPE_HOLDABLE"] = 6,
	["INVTYPE_HEAD"] = 7,
	["INVTYPE_NECK"] = 8,
	["INVTYPE_SHOULDER"] = 9,
	["INVTYPE_CLOAK"] = 10,
	["INVTYPE_CHEST"] = 11,
	["INVTYPE_ROBE"] = 11,
	["INVTYPE_WRIST"] = 12,
	["INVTYPE_HAND"] = 13,
	["INVTYPE_WAIST"] = 14,
	["INVTYPE_LEGS"] = 15,
	["INVTYPE_FEET"] = 16,
	["INVTYPE_FINGER"] = 17,
	["INVTYPE_TRINKET"] = 18,
	["INVTYPE_RANGED"] = 19,
	["INVTYPE_RANGEDRIGHT"] = 20,
	["INVTYPE_THROWN"] = 21,
	["INVTYPE_RELIC"] = 22,
	["INVTYPE_BODY"] = 23,
	["INVTYPE_TABARD"] = 24,
	["INVTYPE_BAG"] = 25,
	["INVTYPE_QUIVER"] = 26,
}

-- Category sorting order (1 is reserved for equippable gear)
local CATEGORY_ORDER = {
	["Consumable"] = 2,
	["Projectile"] = 3,
	["Weapon"] = 4,      -- Non-equippable weapons
	["Armor"] = 5,       -- Non-equippable armor
	["Tools"] = 6,
	["Quest"] = 7,
	["Quiver"] = 8,
	["Reagent"] = 9,
	["Trade Goods"] = 10,
	["Recipe"] = 11,
	["Container"] = 12,
	["Key"] = 14,
	["Miscellaneous"] = 15,
	["Junk"] = 17,
	["Class Items"] = 18,
}

-- Subclass ordering for grouping related items
local SUBCLASS_ORDER = {
	gems = 1,
	cloth = 2,
	leather = 3,
	herbs = 4,
	elemental = 5,
	enchanting = 6,
	engineering = 7,
	consumable = 8,
	other = 99,
}

-- Gem name patterns for detection
local GEM_PATTERNS = {
	"ruby", "sapphire", "emerald", "diamond", "jade", "citrine",
	"aquamarine", "agate", "pearl", "topaz", "opal", "malachite",
	"tigerseye", "tiger's eye", "shadowgem"
}

--===========================================================================
-- UTILITY FUNCTIONS
--===========================================================================

-- Tooltip for scanning item properties
local scanTooltip = CreateFrame("GameTooltip", "Guda_SortScanTooltip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

-- Property cache to prevent race conditions during rapid moves
local propertyCache = {}

function SortEngine:ClearCache()
	propertyCache = {}
end

local function GetItemProperties(bagID, slotID, itemLink)
	if not itemLink then return nil end
	
	-- Extract base item link for stable caching (item:ID:Enchant:...)
	local _, _, baseLink = string.find(itemLink, "(item:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+)")
	local cacheKey = baseLink or itemLink
	
	if propertyCache[cacheKey] then
		return propertyCache[cacheKey]
	end

	local props = {
		isQuest = false,
		isQuestStarter = false,
		isQuestUsable = false,
		isGray = false,
		restoreTag = nil
	}

	-- Quality check from link color code (|cff9d9d9d is gray)
	if string.find(itemLink, "|cff9d9d9d") then
		props.isGray = true
	end

	if bagID and slotID then
		scanTooltip:ClearLines()
		scanTooltip:SetBagItem(bagID, slotID)
		
		local numLines = scanTooltip:NumLines()
		if numLines and numLines > 0 then
			for i = 1, numLines do
				local line = getglobal("Guda_SortScanTooltipTextLeft" .. i)
				if line then
					local text = line:GetText()
					if text then
						local tl = string.lower(text)
						
						-- Quest item check
						if string.find(tl, "quest starter") or
						   string.find(tl, "this item begins a quest") or
						   string.find(tl, "starts a quest") or
						   string.find(tl, "quest item") or
						   string.find(tl, "manual") then
							props.isQuest = true
						end
						
						-- Starter check
						if string.find(tl, "quest starter") or 
						   string.find(tl, "this item begins a quest") or 
						   string.find(tl, "starts a quest") then
							props.isQuestStarter = true
						end
						
						-- Usable check
						if string.find(tl, "use:") or 
						   string.find(tl, "right%-click") or 
						   string.find(tl, "right click") or 
						   string.find(tl, "click to") then
							props.isQuestUsable = true
						end
						
						-- Restore tag check (higher priority tags override lower ones)
						if string.find(tl, "while eating") then
							props.restoreTag = "eat"
						elseif string.find(tl, "while drinking") then
							if props.restoreTag ~= "eat" then
								props.restoreTag = "drink"
							end
						elseif string.find(tl, "use: restores") then
							if not props.restoreTag then
								props.restoreTag = "restore"
							end
						end

						-- Gray check (header line color fallback)
						if i == 1 and string.find(text, "|cff9d9d9d") then
							props.isGray = true
						end
					end
				end
			end
		end
	end

	propertyCache[cacheKey] = props
	return props
end

-- Check if an item is a quest item by scanning its tooltip
local function IsQuestItemTooltip(bagID, slotID)
	if not bagID or not slotID then return false end
	local link = GetContainerItemLink(bagID, slotID)
	local props = GetItemProperties(bagID, slotID, link)
	return props and props.isQuest or false
end

-- Check if a quest item is usable (has 'Use:' or click to text)
local function IsQuestItemUsable(bagID, slotID)
	if not bagID or not slotID then return false end
	local link = GetContainerItemLink(bagID, slotID)
	local props = GetItemProperties(bagID, slotID, link)
	return props and props.isQuestUsable or false
end

-- Check if item is a quest starter (explicit 'Starts a Quest' or 'This Item Begins a Quest')
local function IsQuestItemStarter(bagID, slotID)
	if not bagID or not slotID then return false end
	local link = GetContainerItemLink(bagID, slotID)
	local props = GetItemProperties(bagID, slotID, link)
	return props and props.isQuestStarter or false
end

-- Check if an item has a gray title in its tooltip or link
local function IsItemGrayTooltip(bagID, slotID, itemLink)
	local props = GetItemProperties(bagID, slotID, itemLink)
	return props and props.isGray or false
end

-- Check if an item has a restore tag (eat, drink, or restore)
local function GetItemRestoreTagTooltip(bagID, slotID)
	if not bagID or not slotID then return nil end
	local link = GetContainerItemLink(bagID, slotID)
	local props = GetItemProperties(bagID, slotID, link)
	return props and props.restoreTag or nil
end

-- Extract itemID from item link
local function GetItemID(link)
	if not link then return 0 end
	local _, _, itemID = string.find(link, "item:(%d+)")
	return tonumber(itemID) or 0
end

-- Get item quality from link color code
local function GetQualityFromLink(link)
	if not link then return 1 end
	if string.find(link, "|cff9d9d9d") then return 0 end -- Gray
	if string.find(link, "|cffffffff") then return 1 end -- White
	if string.find(link, "|cff1eff00") then return 2 end -- Green
	if string.find(link, "|cff0070dd") then return 3 end -- Blue
	if string.find(link, "|cffa335ee") then return 4 end -- Purple
	if string.find(link, "|cffff8000") then return 5 end -- Orange
	if string.find(link, "|cffe6cc80") then return 6 end -- Red/Artifact
	return 1
end

-- Check if an item is a profession tool (should NOT be treated as junk)
local function IsProfessionTool(itemLink, itemSubclass)
    -- Check by item ID
    if itemLink then
        local itemID = GetItemID(itemLink)
        if itemID and addon.Constants.PROFESSION_TOOL_IDS and addon.Constants.PROFESSION_TOOL_IDS[itemID] then
            return true
        end
    end

    -- Check by subtype (e.g., Fishing Pole)
    if itemSubclass and addon.Constants.PROFESSION_TOOL_SUBTYPES and addon.Constants.PROFESSION_TOOL_SUBTYPES[itemSubclass] then
        return true
    end

    return false
end

-- Check if an item has special tooltip text (Use:, Equip:, green text)
-- These items should NOT be treated as junk
local function HasSpecialTooltipText(bagID, slotID, itemLink)
    if addon.Modules.Utils and addon.Modules.Utils.HasSpecialTooltipText then
        return addon.Modules.Utils:HasSpecialTooltipText(bagID, slotID, itemLink)
    end
    return false
end

-- Extract texture pattern for grouping similar items
local function GetTexturePattern(textureName)
	if not textureName then return "" end

	-- Remove "Interface\\Icons\\INV_" prefix if present
	local cleaned = string.gsub(textureName, "^Interface\\Icons\\INV_", "")

	-- Remove trailing numbers and underscores (like _01, _03, etc.)
	cleaned = string.gsub(cleaned, "_%d+$", "")  -- Remove trailing _01, _02, etc.
	cleaned = string.gsub(cleaned, "_$", "")     -- Remove trailing underscore if any
	return cleaned
end

-- Check if an item is a mount by texture path
function SortEngine.IsMount(itemTexture)
	if not itemTexture then return false end

	local textureLower = string.lower(itemTexture)

	-- Check for mount patterns in texture path
	-- Mount textures typically contain "mount" or "ability_mount"
	if string.find(textureLower, "_mount_") then
		return true
	end

	return false
end
local IsMount = SortEngine.IsMount

-- Determine subclass order for grouping related items
local function GetSubclassOrder(subclass, itemName)
	if not subclass then return 50 end

	local subLower = string.lower(subclass)
	local nameLower = itemName and string.lower(itemName) or ""

	-- Check for gems (by subclass or name)
	if string.find(subLower, "metal") or string.find(subLower, "stone") or string.find(subLower, "gem") then
		return SUBCLASS_ORDER.gems
	end

	for _, gemPattern in ipairs(GEM_PATTERNS) do
		if string.find(nameLower, gemPattern) then
			return SUBCLASS_ORDER.gems
		end
	end

	-- Check other categories
	-- Group metals, stones, ores, bars together with gems
	if string.find(subLower, "metal") or string.find(subLower, "stone") or
	   string.find(nameLower, "ore") or string.find(nameLower, "bar") or string.find(nameLower, "stone") then
		return SUBCLASS_ORDER.gems  -- Group ores/bars/stones with gems
	end
	if string.find(subLower, "cloth") then return SUBCLASS_ORDER.cloth end
	if string.find(subLower, "leather") then return SUBCLASS_ORDER.leather end
	if string.find(subLower, "herb") then return SUBCLASS_ORDER.herbs end
	if string.find(subLower, "elemental") then return SUBCLASS_ORDER.elemental end
	if string.find(subLower, "enchanting") then return SUBCLASS_ORDER.enchanting end
	if string.find(subLower, "engineering") or string.find(subLower, "parts") or string.find(subLower, "device") then
		return SUBCLASS_ORDER.engineering
	end
	if string.find(subLower, "consumable") or string.find(subLower, "food") or string.find(subLower, "drink") then
		return SUBCLASS_ORDER.consumable
	end
	if string.find(subLower, "trade goods") or string.find(subLower, "other") then
		return SUBCLASS_ORDER.other
	end

	return 50 -- Default for unknown types
end

--===========================================================================
-- PHASE 1: Special Container Detection
--===========================================================================

local function DetectSpecializedBags(bagIDs)
    local containers = {
        soul = {},
        herb = {},
        enchant = {},
        quiver = {},
        ammo = {},
        regular = {}
    }

	for _, bagID in ipairs(bagIDs) do
		local bagType = addon.Modules.Utils:GetSpecializedBagType(bagID)
        if bagType == "soul" then
            table.insert(containers.soul, bagID)
        elseif bagType == "herb" then
            table.insert(containers.herb, bagID)
        elseif bagType == "enchant" then
            table.insert(containers.enchant, bagID)
        elseif bagType == "quiver" then
            table.insert(containers.quiver, bagID)
        elseif bagType == "ammo" then
            table.insert(containers.ammo, bagID)
        else
            table.insert(containers.regular, bagID)
        end
    end

	return containers
end

--===========================================================================
-- PHASE 2: Specialized Item Routing
--===========================================================================

local function RouteSpecializedItems(bagIDs, containers)
	local routingPlan = {}

	-- Scan all items and plan moves to specialized containers
	for _, bagID in ipairs(bagIDs) do
		local numSlots = addon.Modules.Utils:GetBagSlotCount(bagID)
		if numSlots and numSlots > 0 then
			for slot = 1, numSlots do
				local link = GetContainerItemLink(bagID, slot)
				if link then
					local preferredType = addon.Modules.Utils:GetItemPreferredContainer(link)
					local currentBagType = addon.Modules.Utils:GetSpecializedBagType(bagID)

					-- Route item if it has a preferred container and isn't already in one
					if preferredType and currentBagType ~= preferredType then
						local targetBags = containers[preferredType]
						if targetBags and table.getn(targetBags) > 0 then
						-- Find first available slot in preferred containers
							local foundSlot = false
							for _, targetBagID in ipairs(targetBags) do
								if not foundSlot then
									local targetSlots = addon.Modules.Utils:GetBagSlotCount(targetBagID)
									for targetSlot = 1, targetSlots do
										if not GetContainerItemLink(targetBagID, targetSlot) then
											table.insert(routingPlan, {
												fromBag = bagID,
												fromSlot = slot,
												toBag = targetBagID,
												toSlot = targetSlot
											})
											foundSlot = true
											break
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end

	-- Execute routing plan
	for _, move in ipairs(routingPlan) do
		PickupContainerItem(move.fromBag, move.fromSlot)
		PickupContainerItem(move.toBag, move.toSlot)
		ClearCursor()
	end

	return table.getn(routingPlan)
end

--===========================================================================
-- PHASE 3: Stack Consolidation
--===========================================================================

local function ConsolidateStacks(bagIDs)
	local itemGroups = {}

	-- Collect all items with their locations
	for _, bagID in ipairs(bagIDs) do
		local numSlots = addon.Modules.Utils:GetBagSlotCount(bagID)
		if numSlots and numSlots > 0 then
			for slot = 1, numSlots do
				local link = GetContainerItemLink(bagID, slot)
				if link then
					local texture, count = GetContainerItemInfo(bagID, slot)
					local itemID = GetItemID(link)
					local _, _, itemRarity = GetItemInfo(itemID)

					-- Group by itemID and rarity
					local groupKey = itemID .. "_" .. (tonumber(itemRarity) or 0)

					if not itemGroups[groupKey] then
						itemGroups[groupKey] = {
							itemID = itemID,
							link = link,
							stacks = {}
						}
					end

					table.insert(itemGroups[groupKey].stacks, {
						bagID = bagID,
						slot = slot,
						count = count or 1,
						priority = tonumber(addon.Modules.Utils:GetContainerPriority(bagID)) or 0
					})
				end
			end
		end
	end

	-- Consolidate stacks for each group
	local consolidationMoves = 0
	for _, group in pairs(itemGroups) do
		if table.getn(group.stacks) > 1 then
			local itemID = GetItemID(group.link)
			local _, _, _, _, _, _, itemStackCount = GetItemInfo(itemID)
			local maxStack = tonumber(itemStackCount) or 1

			if maxStack > 1 then
			-- Sort stacks: higher priority bags first, then larger stacks
				table.sort(group.stacks, function(a, b)
					if a.priority ~= b.priority then
						return a.priority > b.priority
					end
					return a.count > b.count
				end)

				-- Greedy consolidation: fill stacks from left to right
				for i = 1, table.getn(group.stacks) do
					local source = group.stacks[i]
					if source.count < maxStack then
						for j = i + 1, table.getn(group.stacks) do
							local target = group.stacks[j]
							if target.count > 0 then
								local spaceAvailable = maxStack - source.count
								local amountToMove = math.min(spaceAvailable, target.count)

								if amountToMove > 0 then
									if amountToMove < target.count then
										SplitContainerItem(target.bagID, target.slot, amountToMove)
										PickupContainerItem(source.bagID, source.slot)
									else
										PickupContainerItem(target.bagID, target.slot)
										PickupContainerItem(source.bagID, source.slot)
									end
									ClearCursor()

									source.count = source.count + amountToMove
									target.count = target.count - amountToMove
									consolidationMoves = consolidationMoves + 1

									if source.count >= maxStack then
										break
									end
								end
							end
						end
					end
				end
			end
		end
	end

	return consolidationMoves
end

--===========================================================================
-- PHASE 4: Categorical Sorting
--===========================================================================

local function AddSortKeys(items)
	for _, item in ipairs(items) do
		if item.data and item.data.link then
			local itemID = GetItemID(item.data.link)
			
			-- Use data collected during the initial scan (item.data) for absolute stability
			local d = item.data
			local itemName = d.name
			local itemLink = d.link
			local itemRarity = d.quality
			local itemLevel = d.iLevel
			local itemCategory = d.class
			local itemType = d.type
			local itemSubType = d.subclass
			local itemTexture = d.texture
			local itemStackSize = d.stackSize or 1

			item.itemName = itemName or ""
			
			if not itemName then
				-- Skip items that couldn't be loaded (fallback safety)
				item.sortedClass = 999
				item.isEquippable = false
				item.priority = 1000
				item.equipSlotOrder = 999
				item.invertedQuality = 0
				item.invertedItemLevel = 0
				item.sortedSubclass = 999
				item.subclass = ""
				item.texturePattern = ""
				item.invertedCount = 0
				item.invertedItemID = 0
				item.maxStackCount = 1
				item.isStackable = false
				item.stackCount = 1
			else
				-- Check if item is equippable (Armor or Weapon category)
				local isEquippable = itemCategory == "Armor" or itemCategory == "Weapon"
				-- Check if item is a mount (by texture path)
				local isMount = IsMount(itemTexture)

				-- Priority (1 = hearthstone, 2 = mounts, 1000 = everything else)
				if PRIORITY_ITEMS[itemID] then
					item.priority = PRIORITY_ITEMS[itemID]
				elseif isMount then
					item.priority = 2
				else
					item.priority = 1000
				end
				item.isEquippable = isEquippable
				item.isMount = isMount

				-- Class and slot ordering
				-- Check for items that should be treated as junk:
				-- 1. Gray items (quality 0)
				-- 2. Items with gray tooltip
				-- 3. White equippable items (quality 1 Weapon/Armor) - vendor trash
				-- EXCLUDES from junk:
				--   - Trinkets, Rings, Necklaces (these typically have special effects)
				--   - Profession tools (skinning knife, mining pick, fishing poles, etc.)
				--   - Items with yellow description text (Use:, Equip:, Chance on hit: effects)
				--   - Items with green description text (set bonuses, special properties)
				local isGrayItem = itemRarity == 0 or IsItemGrayTooltip(item.bagID, item.slot, item.data.link)
				local isWhiteEquip = false

				if itemRarity == 1 and (itemCategory == "Weapon" or itemCategory == "Armor") then
					-- In Turtle WoW, equip slot info is in itemSubType, not itemEquipLoc
					addon:Debug("SortEngine isJunk: name='%s', subclass='%s', class='%s'",
						tostring(itemName), tostring(itemSubType), tostring(itemCategory))

					-- EXCLUDE: Trinkets, Rings, Necklaces, Tabards, Shirts - these typically have special effects or are cosmetic
					-- Check by itemSubType which contains INVTYPE_* values in Turtle WoW
					local isSpecialSlot = (itemSubType == "INVTYPE_TRINKET" or
					                       itemSubType == "INVTYPE_FINGER" or
					                       itemSubType == "INVTYPE_NECK" or
					                       itemSubType == "INVTYPE_TABARD" or
					                       itemSubType == "INVTYPE_BODY")

					if isSpecialSlot then
						addon:Debug("SortEngine: EXCLUDED (special slot) - %s (subclass=%s)", tostring(itemName), tostring(itemSubType))
					end

					if not isSpecialSlot then
						-- Check exclusions for white equippable items
						local isProfTool = IsProfessionTool(item.data.link, itemSubType)
						local hasSpecialText = false

						if not isProfTool then
							hasSpecialText = HasSpecialTooltipText(item.bagID, item.slot, item.data.link)
						end

						-- Only mark as junk if NOT a profession tool AND NOT has special text
						if not isProfTool and not hasSpecialText then
							isWhiteEquip = true
						end
					end
				end

				if isGrayItem or isWhiteEquip then
					item.sortedClass = CATEGORY_ORDER["Junk"] or 99
					item.equipSlotOrder = 999
					item.isEquippable = false -- Treat junk gear as junk, not gear
				elseif isEquippable then
					item.sortedClass = 1 -- All equippable gear gets priority class
					item.equipSlotOrder = EQUIP_SLOT_ORDER[itemSubType] or 999
				else
					item.sortedClass = CATEGORY_ORDER[itemCategory] or 99
					-- Heuristic: Detect items that should be in the Quest category (priority 7)
					-- but aren't categorized as such by the game (e.g. some "Manual" items)
					if item.sortedClass ~= (CATEGORY_ORDER["Quest"] or 7) then
						local nameLower = string.lower(item.itemName)
						if string.find(nameLower, "manual") or string.find(nameLower, "quest") then
							item.sortedClass = CATEGORY_ORDER["Quest"] or 7
						elseif IsQuestItemTooltip(item.bagID, item.slot) then
							item.sortedClass = CATEGORY_ORDER["Quest"] or 7
						elseif addon.IsQuestItemByID then
							-- Check QuestItemsDB for faction-specific quest items
							local playerFaction = UnitFactionGroup("player")
							if addon:IsQuestItemByID(itemID, playerFaction) then
								item.sortedClass = CATEGORY_ORDER["Quest"] or 7
							end
						end
					end
					item.equipSlotOrder = 999
				end

				-- Subclass ordering
				-- Detect consumable restore/eat/drink tag (if available) BEFORE computing subclass priority
				item.restoreTag = GetItemRestoreTagTooltip(item.bagID, item.slot)
				
				local baseSub = GetSubclassOrder(itemSubType, item.itemName)
				local function _cons_prk(t)
					if t == "eat" then return -300 end
					if t == "drink" then return -200 end
					if t == "restore" then return -100 end
					return 0
				end
				item.sortedSubclass = _cons_prk(item.restoreTag) + baseSub
				item.subclass = itemSubType or ""

				-- Quest flags: mark quest items and detect starter/usable states
				item.isQuest = false
				item.isQuestStarter = false
				item.isQuestUsable = false
				local nameLower = string.lower(item.itemName)
				if itemCategory == "Quest" or string.find(nameLower, "quest") or item.data.class == "Quest" or IsQuestItemTooltip(item.bagID, item.slot) then
					item.isQuest = true
					if IsQuestItemStarter(item.bagID, item.slot) then item.isQuestStarter = true end
					if IsQuestItemUsable(item.bagID, item.slot) then item.isQuestUsable = true end
				elseif addon.IsQuestItemByID then
					-- Check QuestItemsDB for faction-specific quest items
					local playerFaction = UnitFactionGroup("player")
					if addon:IsQuestItemByID(itemID, playerFaction) then
						item.isQuest = true
					end
				end

				-- Texture pattern for grouping similar items (especially trade goods)
				item.texturePattern = GetTexturePattern(itemTexture)
				-- Group Trade Goods: meats (names ending with 'meat') before eggs
				if itemType == "Trade Goods" then
					if string.find(nameLower, "meat$") then
						item.texturePattern = "trade_meat"
					elseif string.find(nameLower, "egg") then
						item.texturePattern = "trade_egg"
					end
				end

				-- Inverted values for descending sorts
				item.invertedQuality = -(tonumber(itemRarity) or 0)
				item.invertedItemLevel = -(tonumber(itemLevel) or 0)
				item.invertedCount = -(tonumber(item.data.count) or 1)
				item.invertedItemID = -tonumber(itemID)

				-- Stack info for reverse stack sorting
				item.maxStackCount = tonumber(itemStackSize) or 1
				item.isStackable = item.maxStackCount > 1
				item.stackCount = tonumber(item.data.count) or 1
			end
		end
	end
end

local function SortItems(items)
	AddSortKeys(items)

	-- Get reverse stack sort setting from DB
	local reverseStackSort = false
	if addon.Modules.DB and addon.Modules.DB.GetSetting then
		reverseStackSort = addon.Modules.DB:GetSetting("reverseStackSort")
		if reverseStackSort == nil then
			reverseStackSort = false
		end
	end

	table.sort(items, function(a, b)
	-- 1. Priority items first (Hearthstone, etc.)
		if a.priority ~= b.priority then
			return a.priority < b.priority
		end

		-- 2. Equippable items always come before non-equippable items
		if a.isEquippable ~= b.isEquippable then
			return a.isEquippable
		end

		-- 3. For equippable gear: sort by slot, subtype, texture pattern, quality, ilvl, name
		if a.isEquippable then
			if a.equipSlotOrder ~= b.equipSlotOrder then
				return a.equipSlotOrder < b.equipSlotOrder
			end
			-- Group by itemSubType first (e.g., "Ring", "Staff", "Cloth", etc.)
			if a.subclass ~= b.subclass then
				return a.subclass < b.subclass
			end
			-- Then group items with similar textures together
			if a.texturePattern ~= b.texturePattern then
				return a.texturePattern < b.texturePattern
			end
			if a.invertedQuality ~= b.invertedQuality then
				return a.invertedQuality < b.invertedQuality
			end
			if a.invertedItemLevel ~= b.invertedItemLevel then
				return a.invertedItemLevel < b.invertedItemLevel
			end
			if a.itemName ~= b.itemName then
				return a.itemName < b.itemName
			end
		else
		-- 4. For non-equippable items: prioritize consumable restoreTag, then class, subclass, texture pattern, quality, name
			-- If either item has a restoreTag, compare their priority (eat>drink>restore>none)
			local pa = a.restoreTag or nil
			local pb = b.restoreTag or nil
			local function pr(t)
				if t == "eat" then return 3 end
				if t == "drink" then return 2 end
				if t == "restore" then return 1 end
				return 0
			end
			if pr(pa) ~= pr(pb) then
				return pr(pa) > pr(pb)
			end
			if a.sortedClass ~= b.sortedClass then
				return a.sortedClass < b.sortedClass
			end
			-- If both items are in the Quest class, apply quest-specific ordering
			-- If both items are detected as quest items, apply quest-specific ordering
			if a.isQuest and b.isQuest then
				local function qrank(it)
					if it.isQuestStarter then return 3 end
					if it.isQuestUsable then return 2 end
					if it.isQuest then return 1 end
					return 0
				end
				local ra, rb = qrank(a), qrank(b)
				if ra ~= rb then
					return ra > rb
				end
			elseif a.isQuest ~= b.isQuest then
				-- If only one is a quest item and they are in the same sortedClass,
				-- put the quest item first within that class (or just let sortedClass handle it)
				-- Since we moved Quest to its own class 7, this might not be needed unless
				-- they are in different classes but one is marked isQuest.
				-- However, if they have same sortedClass, we want quest items first.
				return a.isQuest
			end
			if a.sortedSubclass ~= b.sortedSubclass then
				return a.sortedSubclass < b.sortedSubclass
			end
			if a.subclass ~= b.subclass then
				return a.subclass < b.subclass
			end
			-- Group items with similar textures (e.g., all "Misc_Food", all "Fabric_Linen")
			if a.texturePattern ~= b.texturePattern then
				return a.texturePattern < b.texturePattern
			end
			if a.invertedQuality ~= b.invertedQuality then
				return a.invertedQuality < b.invertedQuality
			end
			if a.itemName ~= b.itemName then
				return a.itemName < b.itemName
			end
		end

		-- 5. Final tiebreakers (group identical items together)
		-- Sort by itemID first to ensure identical items are adjacent
		if a.invertedItemID ~= b.invertedItemID then
			return a.invertedItemID < b.invertedItemID
		end
		-- Then by item level
		if a.invertedItemLevel ~= b.invertedItemLevel then
			return a.invertedItemLevel < b.invertedItemLevel
		end
		-- Then by stack count
		-- If reverse stack sort is enabled AND both items are the same stackable item,
		-- place smaller stacks before larger ones
		if a.invertedCount ~= b.invertedCount then
			-- Check if both items are the same stackable item (same itemID)
			if reverseStackSort and a.isStackable and b.isStackable and a.invertedItemID == b.invertedItemID then
				-- Reverse: smaller stacks first (compare stackCount ascending)
				return a.stackCount < b.stackCount
			else
				-- Normal: larger stacks first (use invertedCount)
				return a.invertedCount < b.invertedCount
			end
		end
		-- Final stable sort: preserve original collection order for identical items
		-- This prevents unnecessary reshuffling when items are already sorted
		return a.sequence < b.sequence
	end)

	return items
end

--===========================================================================
-- PHASE 5: Empty Slot Management & Apply Sort
--===========================================================================

local function CollectItems(bagIDs)
	local items = {}
	local sequence = 0  -- Add sequence number for stable sort

	for _, bagID in ipairs(bagIDs) do
		local numSlots = addon.Modules.Utils:GetBagSlotCount(bagID)

		if addon.Modules.Utils:IsBagValid(bagID) then
			for slot = 1, numSlots do
				-- Scan directly from game API instead of cached data
				local texture, itemCount, locked = GetContainerItemInfo(bagID, slot)
				local itemLink = GetContainerItemLink(bagID, slot)

				if itemLink then
					-- Get fresh item info with ALL return values
					local itemID = GetItemID(itemLink)
					local name, link, quality, iLevel, category, itemType, stackCount, subType, iconTex, equipLoc, sellPrice = GetItemInfo(itemID)
					
					-- Fallback for quality if GetItemInfo fails (ensures stability)
					if not quality then
						quality = GetQualityFromLink(itemLink)
					end

					sequence = sequence + 1
					table.insert(items, {
						bagID = bagID,
						slot = slot,
						sequence = sequence,  -- Preserve original order
						data = {
							link = itemLink,
							texture = texture or iconTex,
							count = itemCount or 1,
							quality = quality or 0,
							name = name,
							iLevel = iLevel,
							type = itemType,
							class = category,
							subclass = subType,
							equipLoc = equipLoc,
							stackSize = stackCount or 1,
							locked = locked,
						},
						quality = quality or 0,
						name = name or "",
						class = category or "",
					})
				end
			end
		end
	end

	return items
end

local function BuildTargetPositions(bagIDs, itemCount)
	local positions = {}
	local index = 1

	-- Sort bags by priority (descending), then by bag ID (ascending)
	local sortedBags = {}
	for _, bagID in ipairs(bagIDs) do
		table.insert(sortedBags, {
			bagID = bagID,
			priority = tonumber(addon.Modules.Utils:GetContainerPriority(bagID)) or 0
		})
	end

	table.sort(sortedBags, function(a, b)
		if a.priority ~= b.priority then
			return a.priority > b.priority
		end
		return a.bagID < b.bagID
	end)

	-- Build positions in priority order
	for _, bagInfo in ipairs(sortedBags) do
		local bagID = bagInfo.bagID
		local numSlots = addon.Modules.Utils:GetBagSlotCount(bagID)

		if addon.Modules.Utils:IsBagValid(bagID) then
			for slot = 1, numSlots do
				if index <= itemCount then
					positions[index] = {bag = bagID, slot = slot}
					index = index + 1
				else
					break
				end
			end
		end

		if index > itemCount then
			break
		end
	end

	return positions
end

local function ApplySort(bagIDs, items, targetPositions)
	ClearCursor()

	local moveToEmpty = {}
	local swapOccupied = {}

	-- Build move queues
	for i, item in ipairs(items) do
		local target = targetPositions[i]

		if target then
			local sourceBag, sourceSlot = item.bagID, item.slot
			local targetBag, targetSlot = target.bag, target.slot

			-- Skip if already in correct position
			if sourceBag ~= targetBag or sourceSlot ~= targetSlot then
				local targetItem = GetContainerItemLink(targetBag, targetSlot)

				if not targetItem then
					table.insert(moveToEmpty, {
						sourceBag = sourceBag,
						sourceSlot = sourceSlot,
						targetBag = targetBag,
						targetSlot = targetSlot,
					})
				else
					table.insert(swapOccupied, {
						sourceBag = sourceBag,
						sourceSlot = sourceSlot,
						targetBag = targetBag,
						targetSlot = targetSlot,
					})
				end
			end
		end
	end

	-- Execute moves to empty slots first
	local moveCount = 0
	for _, move in ipairs(moveToEmpty) do
		local _, _, locked = GetContainerItemInfo(move.sourceBag, move.sourceSlot)
		if not locked then
			PickupContainerItem(move.sourceBag, move.sourceSlot)
			PickupContainerItem(move.targetBag, move.targetSlot)
			ClearCursor()
			moveCount = moveCount + 1
		else
			-- If item is locked, it might be due to server lag or another process.
			-- We don't increment moveCount but the item will be picked up in next pass.
		end
	end

	-- Execute swaps with occupied slots
	for _, move in ipairs(swapOccupied) do
		local _, _, sourceLocked = GetContainerItemInfo(move.sourceBag, move.sourceSlot)
		local _, _, targetLocked = GetContainerItemInfo(move.targetBag, move.targetSlot)

		if not sourceLocked and not targetLocked then
			PickupContainerItem(move.sourceBag, move.sourceSlot)
			PickupContainerItem(move.targetBag, move.targetSlot)
			ClearCursor()
			moveCount = moveCount + 1
		end
	end

	return moveCount
end

--===========================================================================
-- GREY ITEM HANDLING HELPERS
--===========================================================================

-- Build tail positions (end-to-start) for a given count across the provided bags,
-- starting from the "last" regular bag (lowest priority, then highest bagID),
-- and spilling into previous bags when needed.
local function BuildGreyTailPositions(bagIDs, greyCount)
	local positions = {}
	if greyCount <= 0 then return positions end

	-- Order bags: lowest priority first (these are considered "last"),
	-- and for stable, pick higher bagID later within same priority.
	local ordered = {}
	for _, bagID in ipairs(bagIDs) do
	-- ONLY include bags that are valid and have slots
		if addon.Modules.Utils:IsBagValid(bagID) then
			local numSlots = addon.Modules.Utils:GetBagSlotCount(bagID) or 0
			if numSlots > 0 then
				table.insert(ordered, {
					bagID = bagID,
					priority = tonumber(addon.Modules.Utils:GetContainerPriority(bagID)) or 0,
					numSlots = numSlots,
				})
			end
		end
	end

	table.sort(ordered, function(a, b)
		if a.priority ~= b.priority then
			return a.priority < b.priority -- lowest first
		end
		return a.bagID > b.bagID -- higher bagID later (treated as further to the right)
	end)

	-- Collect tail slots from end to start, spilling to previous bags as needed.
	local tailSlots = {}
	for _, info in ipairs(ordered) do
		for slot = info.numSlots, 1, -1 do
			if table.getn(tailSlots) < greyCount then
				table.insert(tailSlots, { bag = info.bagID, slot = slot })
			else
				break
			end
		end
		if table.getn(tailSlots) >= greyCount then break end
	end

	-- STABILITY FIX: Sort the collected tail slots to match the ascending scan order.
	-- This ensures that identical items don't swap places every pass.
	-- Ascending order: Priority DESC, BagID ASC, Slot ASC (matching BuildTargetPositions)
	table.sort(tailSlots, function(a, b)
		local aPrio = tonumber(addon.Modules.Utils:GetContainerPriority(a.bag)) or 0
		local bPrio = tonumber(addon.Modules.Utils:GetContainerPriority(b.bag)) or 0
		if aPrio ~= bPrio then
			return aPrio > bPrio
		end
		if a.bag ~= b.bag then
			return a.bag < b.bag
		end
		return a.slot < b.slot
	end)

	return tailSlots
end

-- Split a list of collected items into non-junk and junk items
-- Junk includes: gray items (quality 0), gray tooltip items, white equippable items (quality 1 Weapon/Armor)
-- EXCLUDES from junk:
--   1. Trinkets, Rings, Necklaces (these typically have special effects)
--   2. Profession tools (skinning knife, mining pick, fishing poles, etc.)
--   3. Items with yellow description text (Use:, Equip:, Chance on hit: effects)
--   4. Items with green description text (set bonuses, special properties)
local function SplitGreyItems(items)
    local nonGreys, greys = {}, {}
    for _, item in ipairs(items) do
        -- Use same logic as AddSortKeys for determining Junk status (stability)
        local quality = tonumber(item.quality or 0)
        local isGray = quality == 0 or IsItemGrayTooltip(item.bagID, item.slot, item.data.link)
        -- White equippable items (Weapon/Armor) are also treated as junk
        local itemClass = item.class or ""
        local itemSubclass = item.data and item.data.subclass or ""
        local itemLink = item.data and item.data.link
        local isWhiteEquip = false

        if quality == 1 and (itemClass == "Weapon" or itemClass == "Armor") then
            -- In Turtle WoW, equip slot info is in itemSubType (stored as subclass), not equipLoc
            addon:Debug("SplitGreyItems isJunk: name='%s', subclass='%s', class='%s'",
                tostring(item.data and item.data.name), tostring(itemSubclass), tostring(itemClass))

            -- EXCLUDE: Trinkets, Rings, Necklaces, Tabards, Shirts - these typically have special effects or are cosmetic
            -- Check by subclass which contains INVTYPE_* values in Turtle WoW
            local isSpecialSlot = (itemSubclass == "INVTYPE_TRINKET" or
                                   itemSubclass == "INVTYPE_FINGER" or
                                   itemSubclass == "INVTYPE_NECK" or
                                   itemSubclass == "INVTYPE_TABARD" or
                                   itemSubclass == "INVTYPE_BODY")

            if isSpecialSlot then
                addon:Debug("SplitGreyItems: EXCLUDED (special slot) - %s (subclass='%s')", tostring(item.data and item.data.name), tostring(itemSubclass))
            end

            if not isSpecialSlot then
                -- Check exclusions for white equippable items
                local isProfTool = IsProfessionTool(itemLink, itemSubclass)
                local hasSpecialText = false

                if not isProfTool then
                    hasSpecialText = HasSpecialTooltipText(item.bagID, item.slot, itemLink)
                end

                -- Only mark as junk if NOT a profession tool AND NOT has special text
                if not isProfTool and not hasSpecialText then
                    isWhiteEquip = true
                end
            end
        end

        if isGray or isWhiteEquip then
            table.insert(greys, item)
        else
            table.insert(nonGreys, item)
        end
    end
    return nonGreys, greys
end

-- Rename for clarity and remove the helper function
function SortEngine:AnalyzeBags()
	return self:AnalyzeContainer(addon.Constants.BAGS, "bags")
end

function SortEngine:AnalyzeBank()
	if not addon.Modules.BankScanner:IsBankOpen() then
		return {passes = 0, itemsOutOfPlace = 0, totalItems = 0, alreadySorted = true}
	end
	return self:AnalyzeContainer(addon.Constants.BANK_BAGS, "bank")
end

-- Unified analysis function that matches the actual sort logic
function SortEngine:AnalyzeContainer(bagIDs, containerType)
-- Detect specialized bags (same as SortBags)
	local containers = DetectSpecializedBags(bagIDs)

	local totalOutOfPlace = 0
	local totalItems = 0

 -- Analyze specialized bags separately
 for _, bagType in ipairs({"enchant", "herb", "soul", "quiver", "ammo"}) do
     local specialBags = containers[bagType]
     for _, bagID in ipairs(specialBags) do
         local items = CollectItems({bagID})
         if table.getn(items) > 0 then
             local sortedItems = SortItems(items)
				local targetPositions = BuildTargetPositions({bagID}, table.getn(items))

				for i, item in ipairs(sortedItems) do
					local target = targetPositions[i]
					if target and (item.bagID ~= target.bag or item.slot ~= target.slot) then
						totalOutOfPlace = totalOutOfPlace + 1
					end
				end
				totalItems = totalItems + table.getn(items)
			end
		end
	end

	-- Analyze regular bags with two-phase logic (matches SortBags)
	local regularBagIDs = containers.regular

	-- FILTER OUT EMPTY/INVALID BAGS for analysis
	local validRegularBags = {}
	for _, bagID in ipairs(regularBagIDs) do
		if addon.Modules.Utils:IsBagValid(bagID) and addon.Modules.Utils:GetBagSlotCount(bagID) > 0 then
			table.insert(validRegularBags, bagID)
		end
	end

	if table.getn(validRegularBags) > 0 then
		local allItems = CollectItems(validRegularBags)
		totalItems = totalItems + table.getn(allItems)

		-- Split greys/non-greys like SortBags does
		local nonGreys, greys = SplitGreyItems(allItems)

		-- Check non-grey positioning (should be in front positions)
		if table.getn(nonGreys) > 0 then
			local sortedNonGreys = SortItems(nonGreys)
			local frontPositions = BuildTargetPositions(validRegularBags, table.getn(sortedNonGreys))

			for i, item in ipairs(sortedNonGreys) do
				local target = frontPositions[i]
				if target and (item.bagID ~= target.bag or item.slot ~= target.slot) then
					totalOutOfPlace = totalOutOfPlace + 1
				end
			end
		end

		-- Check grey positioning (should be in tail positions)
		if table.getn(greys) > 0 then
		-- CRITICAL FIX: Only use bags that actually exist and have slots
			local tailPositions = BuildGreyTailPositions(validRegularBags, table.getn(greys))

			for i, item in ipairs(greys) do
				local target = tailPositions[i]
				-- Only count as out of place if it doesn't match the specific stable target
				if target and (item.bagID ~= target.bag or item.slot ~= target.slot) then
					totalOutOfPlace = totalOutOfPlace + 1
				end
			end
		end
	end

 if totalOutOfPlace == 0 then
        return {passes = 0, itemsOutOfPlace = 0, totalItems = totalItems, alreadySorted = true}
    end

    -- Estimate passes (aligned to single-pass executor; cap at 6)
    local displacementRatio = totalOutOfPlace / math.max(1, totalItems)
    local estimatedPasses

    if displacementRatio < 0.10 then
        estimatedPasses = 1
    elseif displacementRatio < 0.30 then
        estimatedPasses = 2
    elseif displacementRatio < 0.50 then
        estimatedPasses = 3
    elseif displacementRatio < 0.70 then
        estimatedPasses = 4
    elseif displacementRatio < 0.85 then
        estimatedPasses = 5
    else
        estimatedPasses = 6
    end

	return {
		passes = estimatedPasses,
		itemsOutOfPlace = totalOutOfPlace,
		totalItems = totalItems,
		alreadySorted = false
	}
end

-- Execute exactly ONE full sorting pass over bags (used by safety wrapper)
function SortEngine:SortBagsPass()
    local bagIDs = addon.Constants.BAGS

    -- Phase 1: Detect specialized bags
    local containers = DetectSpecializedBags(bagIDs)

    -- Phase 2: Route specialized items to their bags
    local routeCount = RouteSpecializedItems(bagIDs, containers)

    -- Phase 3: Consolidate stacks in ALL bags (including specialized)
    local consolidateCount = ConsolidateStacks(bagIDs)

    -- Phase 4: Sort items WITHIN each specialized bag (enchant, herb, soul, quiver, ammo)
    local specializedMoves = 0
    for _, bagType in ipairs({"enchant", "herb", "soul", "quiver", "ammo"}) do
        local specialBags = containers[bagType]
        for _, bagID in ipairs(specialBags) do
            local items = CollectItems({bagID})
            if table.getn(items) > 0 then
                items = SortItems(items)
                local targetPositions = BuildTargetPositions({bagID}, table.getn(items))
                local moveCount = ApplySort({bagID}, items, targetPositions)
                specializedMoves = specializedMoves + moveCount
            end
        end
    end

    -- Phase 5: Two-phase sort for regular bags in a single pass
    local regularMoves = 0
    local regularBagIDs = containers.regular
    if table.getn(regularBagIDs) > 0 then
        -- Re-collect current state from regular bags
        local allItems = CollectItems(regularBagIDs)
        local nonGreys, greys = SplitGreyItems(allItems)

        -- 1) Non-greys: standard sort to the front positions only
        if table.getn(nonGreys) > 0 then
            local sortedNonGreys = SortItems(nonGreys)
            local frontPositions = BuildTargetPositions(regularBagIDs, table.getn(sortedNonGreys))
            regularMoves = regularMoves + (ApplySort(regularBagIDs, sortedNonGreys, frontPositions) or 0)
        end

        -- 2) Greys: end->start across bags
        local afterItems = CollectItems(regularBagIDs)
        local _, greysNow = SplitGreyItems(afterItems)
        if table.getn(greysNow) > 0 then
            local tailPositions = BuildGreyTailPositions(regularBagIDs, table.getn(greysNow))
            regularMoves = regularMoves + (ApplySort(regularBagIDs, greysNow, tailPositions) or 0)
        end
    end

    return routeCount + consolidateCount + specializedMoves + regularMoves
end

function SortEngine:SortBags()
    local bagIDs = addon.Constants.BAGS

	-- Phase 1: Detect specialized bags
	local containers = DetectSpecializedBags(bagIDs)

	-- Phase 2: Route specialized items to their bags
	local routeCount = RouteSpecializedItems(bagIDs, containers)

	-- Phase 3: Consolidate stacks in ALL bags (including specialized)
	local consolidateCount = ConsolidateStacks(bagIDs)

 -- Phase 4: Sort items WITHIN each specialized bag (enchant, herb, soul, quiver, ammo)
 local specializedMoves = 0
 for _, bagType in ipairs({"enchant", "herb", "soul", "quiver", "ammo"}) do
     local specialBags = containers[bagType]
     for _, bagID in ipairs(specialBags) do
     -- Sort items within this single specialized bag
         local items = CollectItems({bagID})
         if table.getn(items) > 0 then
				items = SortItems(items)
				local targetPositions = BuildTargetPositions({bagID}, table.getn(items))
				local moveCount = ApplySort({bagID}, items, targetPositions)
				specializedMoves = specializedMoves + moveCount
			end
		end
	end

 -- Phase 5: Two-phase sort for regular bags (multi-pass legacy; kept for direct calls)
 local regularMoves = 0
 local regularBagIDs = containers.regular
 if table.getn(regularBagIDs) > 0 then
     local maxPasses = 6
     for pass = 1, maxPasses do
         local passMoves = 0

         -- Re-collect current state from regular bags
         local allItems = CollectItems(regularBagIDs)
         local nonGreys, greys = SplitGreyItems(allItems)

         -- 1) Non-greys: standard sort to the front positions only
         if table.getn(nonGreys) > 0 then
             local sortedNonGreys = SortItems(nonGreys)
             local frontPositions = BuildTargetPositions(regularBagIDs, table.getn(sortedNonGreys))
             passMoves = passMoves + (ApplySort(regularBagIDs, sortedNonGreys, frontPositions) or 0)
         end

         -- 2) Greys: ignore all other sorting rules; place end->start across bags
         -- Re-collect after possible movements above for accurate positions
         local afterItems = CollectItems(regularBagIDs)
         local _, greysNow = SplitGreyItems(afterItems)
         if table.getn(greysNow) > 0 then
             local tailPositions = BuildGreyTailPositions(regularBagIDs, table.getn(greysNow))
             passMoves = passMoves + (ApplySort(regularBagIDs, greysNow, tailPositions) or 0)
         end

         regularMoves = regularMoves + passMoves
         if passMoves == 0 then break end
     end
 end

	-- Return total moves made
	return routeCount + consolidateCount + specializedMoves + regularMoves
end

-- Execute exactly ONE full sorting pass over bank (used by safety wrapper)
function SortEngine:SortBankPass()
    if not addon.Modules.BankScanner:IsBankOpen() then
        addon:Print("Bank must be open to sort!")
        return 0
    end

    local bagIDs = addon.Constants.BANK_BAGS

    -- Phase 1: Detect specialized bags
    local containers = DetectSpecializedBags(bagIDs)

    -- Phase 2: Route specialized items
    local routeCount = RouteSpecializedItems(bagIDs, containers)

    -- Phase 3: Consolidate stacks
    local consolidateCount = ConsolidateStacks(bagIDs)

    -- Phase 4: Sort items WITHIN each specialized bag (single pass)
    local specializedMoves = 0
    for _, bagType in ipairs({"enchant", "herb", "soul", "quiver", "ammo"}) do
        local specialBags = containers[bagType]
        for _, bagID in ipairs(specialBags) do
            local items = CollectItems({bagID})
            if table.getn(items) > 0 then
                items = SortItems(items)
                local targetPositions = BuildTargetPositions({bagID}, table.getn(items))
                local moved = ApplySort({bagID}, items, targetPositions)
                specializedMoves = specializedMoves + moved
            end
        end
    end

    -- Phase 5: Regular bank bags — single pass
    local regularBagIDs = containers.regular
    local regularMoves = 0
    if table.getn(regularBagIDs) > 0 then
        local allItems = CollectItems(regularBagIDs)
        local nonGreys, greys = SplitGreyItems(allItems)

        if table.getn(nonGreys) > 0 then
            local sortedNonGreys = SortItems(nonGreys)
            local frontPositions = BuildTargetPositions(regularBagIDs, table.getn(sortedNonGreys))
            regularMoves = regularMoves + (ApplySort(regularBagIDs, sortedNonGreys, frontPositions) or 0)
        end

        local afterItems = CollectItems(regularBagIDs)
        local _, greysNow = SplitGreyItems(afterItems)
        if table.getn(greysNow) > 0 then
            local tailPositions = BuildGreyTailPositions(regularBagIDs, table.getn(greysNow))
            regularMoves = regularMoves + (ApplySort(regularBagIDs, greysNow, tailPositions) or 0)
        end
    end

    return routeCount + consolidateCount + specializedMoves + regularMoves
end

function SortEngine:SortBank()
	if not addon.Modules.BankScanner:IsBankOpen() then
		addon:Print("Bank must be open to sort!")
		return 0
	end

	local bagIDs = addon.Constants.BANK_BAGS

	-- Phase 1: Detect specialized bags
	local containers = DetectSpecializedBags(bagIDs)

	-- Phase 2: Route specialized items
	local routeCount = RouteSpecializedItems(bagIDs, containers)

	-- Phase 3: Consolidate stacks
	local consolidateCount = ConsolidateStacks(bagIDs)

 -- Phase 4: Sort items WITHIN each specialized bag (multi-pass to avoid mid-bag holes)
 local specializedMoves = 0
 for _, bagType in ipairs({"enchant", "herb", "soul", "quiver", "ammo"}) do
     local specialBags = containers[bagType]
     for _, bagID in ipairs(specialBags) do
         local maxPasses = 4
         for pass = 1, maxPasses do
             local items = CollectItems({bagID})
             if table.getn(items) == 0 then break end
             items = SortItems(items)
             local targetPositions = BuildTargetPositions({bagID}, table.getn(items))
             local moved = ApplySort({bagID}, items, targetPositions)
             specializedMoves = specializedMoves + moved
             if moved == 0 then break end
         end
     end
 end

 -- Phase 5: Regular bank bags — same two-phase approach (non-greys first, greys to tail)
 local regularBagIDs = containers.regular
 local regularMoves = 0
 if table.getn(regularBagIDs) > 0 then
     local maxPasses = 6
     for pass = 1, maxPasses do
         local passMoves = 0

         local allItems = CollectItems(regularBagIDs)
         local nonGreys, greys = SplitGreyItems(allItems)

         if table.getn(nonGreys) > 0 then
             local sortedNonGreys = SortItems(nonGreys)
             local frontPositions = BuildTargetPositions(regularBagIDs, table.getn(sortedNonGreys))
             passMoves = passMoves + (ApplySort(regularBagIDs, sortedNonGreys, frontPositions) or 0)
         end

         local afterItems = CollectItems(regularBagIDs)
         local _, greysNow = SplitGreyItems(afterItems)
         if table.getn(greysNow) > 0 then
             local tailPositions = BuildGreyTailPositions(regularBagIDs, table.getn(greysNow))
             passMoves = passMoves + (ApplySort(regularBagIDs, greysNow, tailPositions) or 0)
         end

         regularMoves = regularMoves + passMoves
         if passMoves == 0 then break end
     end
 end

	-- Return total moves made
	return routeCount + consolidateCount + specializedMoves + regularMoves
end

--===========================================================================
-- Reusable Sort Execution with Smart Pass Management
--===========================================================================

function SortEngine:ExecuteSort(sortFunction, analyzeFunction, updateFrame, sortType)
	-- Check if sorting is already in progress
	if self.sortingInProgress then
		addon:Print("Sorting already in progress, please wait...")
		return false, "sorting in progress"
	end

	-- Clear property cache at the start of a sort operation
	self:ClearCache()

-- Analyze to determine how many passes are needed
	local analysis = analyzeFunction()

	-- Check if already sorted
	if analysis.alreadySorted then
		return false, "already sorted"
	end

	-- Set sorting flag and update button appearance
	self.sortingInProgress = true
	self:UpdateSortButtonState(true)

	-- Print analysis results (only when debug sort is enabled)
	addon:DebugSort("Sorting %s... (%d/%d items need sorting, estimated %d passes)",
		sortType, analysis.itemsOutOfPlace, analysis.totalItems, analysis.passes)

 local passCount = 0
 local maxPasses = math.max(analysis.passes, 1)  -- Use estimated passes, minimum 1
 local safetyLimit = math.max(maxPasses * 3, 10)  -- Reasonable upper bound
 local totalMoves = 0
 local noProgressPasses = 0

	addon:DebugSort("Starting %s sort (estimated: %d passes, safety limit: %d)", sortType, maxPasses, safetyLimit)

	local function DoSortPass()
		passCount = passCount + 1

  -- Perform one sort pass
  local moveCount = sortFunction()
  totalMoves = totalMoves + moveCount

		-- Check if sorting is complete by re-analyzing
		local currentAnalysis = analyzeFunction()

  if currentAnalysis.alreadySorted then
            -- Sorting is complete!
            addon:DebugSort("%s sort complete! (%d passes, %d total moves)", sortType, passCount, totalMoves)

			-- Final update
			local frame = CreateFrame("Frame")
			local startTime = GetTime()
			frame:SetScript("OnUpdate", function()
				if GetTime() - startTime >= 0.7 then
					frame:SetScript("OnUpdate", nil)
					SortEngine.sortingInProgress = false
					SortEngine:UpdateSortButtonState(false)
					updateFrame()
				end
			end)
  elseif passCount >= safetyLimit then
            -- Hit safety limit but not fully sorted
            addon:DebugSort("%s sort stopped at safety limit! (%d/%d items still need sorting after %d passes)",
                sortType, currentAnalysis.itemsOutOfPlace, currentAnalysis.totalItems, passCount)

			-- Final update
			local frame = CreateFrame("Frame")
			local startTime = GetTime()
			frame:SetScript("OnUpdate", function()
				if GetTime() - startTime >= 0.7 then
					frame:SetScript("OnUpdate", nil)
					SortEngine.sortingInProgress = false
					SortEngine:UpdateSortButtonState(false)
					updateFrame()
				end
			end)
  else
            -- No progress guard: stop if we make no moves repeatedly
            if moveCount == 0 then
                noProgressPasses = noProgressPasses + 1
            else
                noProgressPasses = 0
            end

            if noProgressPasses >= 5 then
                addon:DebugSort("%s sort stopped due to no progress after %d passes (items remaining: %d/%d)",
                    sortType, passCount, currentAnalysis.itemsOutOfPlace, currentAnalysis.totalItems)
                -- Final update
                local frame = CreateFrame("Frame")
                local startTime = GetTime()
                frame:SetScript("OnUpdate", function()
                    if GetTime() - startTime >= 0.7 then
                        frame:SetScript("OnUpdate", nil)
                        SortEngine.sortingInProgress = false
                        SortEngine:UpdateSortButtonState(false)
                        updateFrame()
                    end
                end)
                return
            end

            -- More sorting needed
            local remainingRatio = currentAnalysis.itemsOutOfPlace / math.max(1, currentAnalysis.totalItems)
            addon:DebugSort("%s Pass %d: %d moves, %d/%d items remaining (%.1f%%)",
                sortType, passCount, moveCount, currentAnalysis.itemsOutOfPlace, currentAnalysis.totalItems, remainingRatio * 100)

			-- PROGRESSIVE DELAY: Calculate delay based on remaining complexity
			local baseDelay = 0.9
			local complexityDelay = math.min(currentAnalysis.itemsOutOfPlace * 0.06, 2.5) -- max 2.5 seconds
			local totalDelay = baseDelay + complexityDelay

			addon:DebugSort("Waiting %.1f seconds before next pass...", totalDelay)

			-- Wait with progressive delay, then sort again
			local frame = CreateFrame("Frame")
			local startTime = GetTime()
			frame:SetScript("OnUpdate", function()
				if GetTime() - startTime >= totalDelay then
					frame:SetScript("OnUpdate", nil)
					DoSortPass()  -- Recursive call for next pass
				end
			end)
		end
	end

	-- Start the first pass
	DoSortPass()
	return true, "sorting started"
end