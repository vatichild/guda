-- Guda Tooltip Module - Lua 5.0 Compatible
local addon = Guda

local Tooltip = {}
addon.Modules.Tooltip = Tooltip

-- Helper function to get item ID from link (Lua 5.0 compatible)
local function GetItemIDFromLink(link)
	if not link then return nil end
	local _, _, itemID = strfind(link, "item:(%d+):?")
	return itemID and tonumber(itemID) or nil
end

-- Count items for a specific character
local function CountItemsForCharacter(itemID, characterData)
	local bagCount = 0
	local bankCount = 0
	local equippedCount = 0

	-- Count bags
	if characterData.bags then
		for bagID, bagData in pairs(characterData.bags) do
			if bagData and bagData.slots then
				for slotID, itemData in pairs(bagData.slots) do
					if itemData and itemData.link then
						local slotItemID = GetItemIDFromLink(itemData.link)
						if slotItemID == itemID then
							bagCount = bagCount + (itemData.count or 1)
						end
					end
				end
			end
		end
	end

	-- Count bank
	if characterData.bank then
		for bagID, bagData in pairs(characterData.bank) do
			if bagData and bagData.slots then
				for slotID, itemData in pairs(bagData.slots) do
					if itemData and itemData.link then
						local slotItemID = GetItemIDFromLink(itemData.link)
						if slotItemID == itemID then
							bankCount = bankCount + (itemData.count or 1)
						end
					end
				end
			end
		end
	end

	-- Count equipped items from EquipmentScanner data
	if characterData.equipped then
		for slotName, itemData in pairs(characterData.equipped) do
			if itemData and itemData.link then
				local slotItemID = GetItemIDFromLink(itemData.link)
				if slotItemID == itemID then
					equippedCount = equippedCount + 1
				end
			end
		end
	end

	return bagCount, bankCount, equippedCount
end

-- Get class color
local function GetClassColor(classToken)
	if not classToken then return 1.0, 1.0, 1.0 end
	local color = RAID_CLASS_COLORS[classToken]
	if color then return color.r, color.g, color.b end
	return 1.0, 1.0, 1.0
end

-- Add inventory info to tooltip
-- Add inventory info to tooltip
-- Add inventory info to tooltip
function Tooltip:AddInventoryInfo(tooltip, link)
	if not Guda_DB or not Guda_DB.characters then
		return
	end

	local itemID = GetItemIDFromLink(link)
	if not itemID then
		return
	end

	local totalBags = 0
	local totalBank = 0
	local totalEquipped = 0
	local characterCounts = {}
	local hasAnyItems = false

	-- Count items across all characters
	for charName, charData in pairs(Guda_DB.characters) do
		local bagCount, bankCount, equippedCount = CountItemsForCharacter(itemID, charData)

		if bagCount > 0 or bankCount > 0 or equippedCount > 0 then
			hasAnyItems = true
			totalBags = totalBags + bagCount
			totalBank = totalBank + bankCount
			totalEquipped = totalEquipped + equippedCount
			table.insert(characterCounts, {
				name = charData.name or charName,
				classToken = charData.classToken,
				bagCount = bagCount,
				bankCount = bankCount,
				equippedCount = equippedCount
			})
		end
	end

	local totalCount = totalBags + totalBank + totalEquipped

	if hasAnyItems then
		tooltip:AddLine(" ")

		-- Inventory label in exact bag frame title color (from your XML: |cFF00FF96)
		tooltip:AddLine("|cFFFFD200Inventory|r")  -- Exact bag frame title color

		-- Total line with cyan label and white count
		local totalText = "|cFF00FFFFTotal|r: |cFFFFFFFF" .. totalCount .. "|r"  -- Cyan label, white count
		local breakdownText = "(|cFF00FFFFBags|r: |cFFFFFFFF" .. totalBags .. "|r | |cFF00FFFFBank|r: |cFFFFFFFF" .. totalBank .. "|r)"  -- Cyan labels, white counts

		tooltip:AddDoubleLine(totalText, breakdownText, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0)

		table.sort(characterCounts, function(a, b)
			return a.name < b.name
		end)

		for _, charInfo in ipairs(characterCounts) do
			local r, g, b = GetClassColor(charInfo.classToken)
			local countText = ""

			local parts = {}
			if charInfo.bagCount > 0 then
				table.insert(parts, "|cFF00FFFFBags|r: |cFFFFFFFF" .. charInfo.bagCount .. "|r")
			end
			if charInfo.bankCount > 0 then
				table.insert(parts, "|cFF00FFFFBank|r: |cFFFFFFFF" .. charInfo.bankCount .. "|r")
			end
			if charInfo.equippedCount > 0 then
				table.insert(parts, "|cFF00FFFFEquipped|r: |cFFFFFFFF" .. charInfo.equippedCount .. "|r")
			end

			if getn(parts) > 0 then
				countText = table.concat(parts, " | ")
			end

			tooltip:AddDoubleLine(charInfo.name, countText, r, g, b, 1.0, 1.0, 1.0)
		end

		-- Add small gap between inventory data and vendor sell price
		tooltip:AddLine(" ")

		tooltip:Show()
	end
end

function Tooltip:Initialize()
	addon:Print("Initializing tooltip module...")

	-- Helper function to defer vendor money so we can insert our Inventory block above it
	local Orig_SetTooltipMoney = SetTooltipMoney
	local function WithDeferredMoney(tooltip, buildFunc)
		local queue = {}
		-- Temporarily override global SetTooltipMoney
		SetTooltipMoney = function(frame, money, a1, a2, a3, a4, a5)
			if frame == tooltip then
				tinsert(queue, {frame, money, a1, a2, a3, a4, a5})
			else
				Orig_SetTooltipMoney(frame, money, a1, a2, a3, a4, a5)
			end
		end

		-- Perform the original population + our Inventory augmentation
		local ret = buildFunc()

		-- Restore and flush queued money so it appears after our Inventory block
		SetTooltipMoney = Orig_SetTooltipMoney
		for i = 1, getn(queue) do
			local q = queue[i]
			Orig_SetTooltipMoney(q[1], q[2], q[3], q[4], q[5], q[6], q[7])
		end
		return ret
	end

	-- Hook SetBagItem
	local oldSetBagItem = GameTooltip.SetBagItem
	function GameTooltip:SetBagItem(bag, slot)
		return WithDeferredMoney(self, function()
			local ret = oldSetBagItem(self, bag, slot)
			local link = GetContainerItemLink(bag, slot)
			if link then
				Tooltip:AddInventoryInfo(self, link)
			end
			return ret
		end)
	end

	-- Hook SetHyperlink for chat links
	local oldSetHyperlink = GameTooltip.SetHyperlink
	function GameTooltip:SetHyperlink(link)
		return WithDeferredMoney(self, function()
			local ret = oldSetHyperlink(self, link)
			if link and strfind(link, "item:") then
				Tooltip:AddInventoryInfo(self, link)
			end
			return ret
		end)
	end

	-- Hook SetInventoryItem for character paperdoll
	local oldSetInventoryItem = GameTooltip.SetInventoryItem
	function GameTooltip:SetInventoryItem(unit, slot)
		return WithDeferredMoney(self, function()
			local ret = oldSetInventoryItem(self, unit, slot)
			local link = GetInventoryItemLink(unit, slot)
			if link then
				Tooltip:AddInventoryInfo(self, link)
			end
			return ret
		end)
	end

	-- Hook SetLootItem for loot windows
	local oldSetLootItem = GameTooltip.SetLootItem
	function GameTooltip:SetLootItem(slot)
		return WithDeferredMoney(self, function()
			local ret = oldSetLootItem(self, slot)
			local link = GetLootSlotLink(slot)
			if link then
				Tooltip:AddInventoryInfo(self, link)
			end
			return ret
		end)
	end

	-- Hook SetQuestItem for quest rewards
	local oldSetQuestItem = GameTooltip.SetQuestItem
	function GameTooltip:SetQuestItem(itemType, index)
		return WithDeferredMoney(self, function()
			local ret = oldSetQuestItem(self, itemType, index)
			local link = GetQuestItemLink(itemType, index)
			if link then
				Tooltip:AddInventoryInfo(self, link)
			end
			return ret
		end)
	end

	-- Hook SetMerchantItem for vendor items
	local oldSetMerchantItem = GameTooltip.SetMerchantItem
	function GameTooltip:SetMerchantItem(index)
		return WithDeferredMoney(self, function()
			local ret = oldSetMerchantItem(self, index)
			local link = GetMerchantItemLink(index)
			if link then
				Tooltip:AddInventoryInfo(self, link)
			end
			return ret
		end)
	end

	-- Hook SetAuctionItem for auction house
	local oldSetAuctionItem = GameTooltip.SetAuctionItem
	function GameTooltip:SetAuctionItem(type, index)
		return WithDeferredMoney(self, function()
			local ret = oldSetAuctionItem(self, type, index)
			local link = GetAuctionItemLink(type, index)
			if link then
				Tooltip:AddInventoryInfo(self, link)
			end
			return ret
		end)
	end

	-- Also hook ItemRefTooltip for chat links
	if ItemRefTooltip then
		local oldItemRefSetHyperlink = ItemRefTooltip.SetHyperlink
		function ItemRefTooltip:SetHyperlink(link)
			return WithDeferredMoney(self, function()
				local ret = oldItemRefSetHyperlink(self, link)
				if link and strfind(link, "item:") then
					Tooltip:AddInventoryInfo(self, link)
				end
				return ret
			end)
		end
	end

	-- Clear cache function
	function Tooltip:ClearCache()
		addon:Debug("Tooltip cache cleared")
	end

	-- Clear cache on bag updates
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("BAG_UPDATE")
	frame:SetScript("OnEvent", function()
		if event == "BAG_UPDATE" then
			Tooltip:ClearCache()
		end
	end)

	addon:Print("Tooltip integration enabled - Inventory displays above vendor price")
end