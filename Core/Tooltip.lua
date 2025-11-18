-- Guda Tooltip Module - Lua 5.0 Compatible
local addon = Guda

local Tooltip = {}
addon.Modules.Tooltip = Tooltip

-- Helper function to get item ID from link (Lua 5.0 compatible)
local function GetItemIDFromLink(link)
	if not link then return nil end
	-- Use strfind instead of string.match
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

	return bagCount, bankCount, equippedCount  -- FIXED: Now returns all three counts
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
function Tooltip:AddInventoryInfo(tooltip, link)
	if not Guda_DB or not Guda_DB.characters then
		addon:Debug("No Guda_DB or characters found")
		return
	end

	local itemID = GetItemIDFromLink(link)
	if not itemID then
		addon:Debug("Could not get item ID from link: " .. tostring(link))
		return
	end

	addon:Debug("Processing item ID: " .. itemID)

	local totalBags = 0
	local totalBank = 0
	local totalEquipped = 0
	local characterCounts = {}
	local hasAnyItems = false

	-- Count items across all characters
	for charName, charData in pairs(Guda_DB.characters) do
		local bagCount, bankCount, equippedCount = CountItemsForCharacter(itemID, charData)

		-- Check if this character has any of this item
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
			addon:Debug("Found " .. (bagCount + bankCount + equippedCount) .. " items on " .. charName .. " (Bags: " .. bagCount .. ", Bank: " .. bankCount .. ", Equipped: " .. equippedCount .. ")")
		end
	end

	local totalCount = totalBags + totalBank + totalEquipped

	-- Only add to tooltip if we found items on any character
	if hasAnyItems then
		addon:Debug("Adding inventory info - Total: " .. totalCount)

		tooltip:AddLine(" ")
		tooltip:AddLine("Inventory", 0.7, 0.7, 0.7)

		-- Simplified total line - just show total count without breakdown
		tooltip:AddDoubleLine("Total: " .. totalCount, "(Bags: " .. totalBags .. " | Bank: " .. totalBank .. ")", 1, 1, 1, 0.7, 0.7, 0.7)

		-- Sort characters by name
		table.sort(characterCounts, function(a, b)
			return a.name < b.name
		end)

		-- Add character lines with bag, bank, and equipped breakdown
		for _, charInfo in ipairs(characterCounts) do
			local r, g, b = GetClassColor(charInfo.classToken)
			local countText = ""

			-- Build count text showing all locations where items are found
			local parts = {}
			if charInfo.bagCount > 0 then
				table.insert(parts, "Bags: " .. charInfo.bagCount)
			end
			if charInfo.bankCount > 0 then
				table.insert(parts, "Bank: " .. charInfo.bankCount)
			end
			if charInfo.equippedCount > 0 then
				table.insert(parts, "Equipped: " .. charInfo.equippedCount)
			end

			if getn(parts) > 0 then
				countText = table.concat(parts, " | ")
			else
				countText = "None"
			end

			tooltip:AddDoubleLine(charInfo.name, countText, r, g, b, 0.7, 0.7, 0.7)
		end

		tooltip:Show()
	else
		addon:Debug("No items found for ID: " .. itemID .. " on any character")
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

	-- Hook SetQuestLogItem for quest log items
	local oldSetQuestLogItem = GameTooltip.SetQuestLogItem
	function GameTooltip:SetQuestLogItem(itemType, index)
		return WithDeferredMoney(self, function()
			local ret = oldSetQuestLogItem(self, itemType, index)
			local link = GetQuestLogItemLink(itemType, index)
			if link then
				Tooltip:AddInventoryInfo(self, link)
			end
			return ret
		end)
	end

	-- Hook SetTradeSkillItem for tradeskill windows
	local oldSetTradeSkillItem = GameTooltip.SetTradeSkillItem
	function GameTooltip:SetTradeSkillItem(skillIndex, reagentIndex)
		return WithDeferredMoney(self, function()
			local ret = oldSetTradeSkillItem(self, skillIndex, reagentIndex)
			local link
			if reagentIndex then
				link = GetTradeSkillReagentItemLink(skillIndex, reagentIndex)
			else
				link = GetTradeSkillItemLink(skillIndex)
			end
			if link then
				Tooltip:AddInventoryInfo(self, link)
			end
			return ret
		end)
	end

	-- Hook SetCraftItem for craft windows
	local oldSetCraftItem = GameTooltip.SetCraftItem
	function GameTooltip:SetCraftItem(skillIndex, reagentIndex)
		return WithDeferredMoney(self, function()
			local ret = oldSetCraftItem(self, skillIndex, reagentIndex)
			local link = GetCraftReagentItemLink(skillIndex, reagentIndex)
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

	-- Hook SetInboxItem for mail
	local oldSetInboxItem = GameTooltip.SetInboxItem
	function GameTooltip:SetInboxItem(index)
		return WithDeferredMoney(self, function()
			local ret = oldSetInboxItem(self, index)
			local link = GetInboxItemLink(index)
			if link then
				Tooltip:AddInventoryInfo(self, link)
			end
			return ret
		end)
	end

	-- Hook SetSendMailItem for sending mail
	local oldSetSendMailItem = GameTooltip.SetSendMailItem
	function GameTooltip:SetSendMailItem(index)
		return WithDeferredMoney(self, function()
			local ret = oldSetSendMailItem(self, index)
			local link = GetSendMailItemLink(index)
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

	-- Hook SetBuybackItem for buyback items
	local oldSetBuybackItem = GameTooltip.SetBuybackItem
	function GameTooltip:SetBuybackItem(index)
		return WithDeferredMoney(self, function()
			local ret = oldSetBuybackItem(self, index)
			local link = GetBuybackItemLink(index)
			if link then
				Tooltip:AddInventoryInfo(self, link)
			end
			return ret
		end)
	end

	-- Hook SetTradePlayerItem for trade window (player side)
	local oldSetTradePlayerItem = GameTooltip.SetTradePlayerItem
	function GameTooltip:SetTradePlayerItem(index)
		return WithDeferredMoney(self, function()
			local ret = oldSetTradePlayerItem(self, index)
			local link = GetTradePlayerItemLink(index)
			if link then
				Tooltip:AddInventoryInfo(self, link)
			end
			return ret
		end)
	end

	-- Hook SetTradeTargetItem for trade window (target side)
	local oldSetTradeTargetItem = GameTooltip.SetTradeTargetItem
	function GameTooltip:SetTradeTargetItem(index)
		return WithDeferredMoney(self, function()
			local ret = oldSetTradeTargetItem(self, index)
			local link = GetTradeTargetItemLink(index)
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

	addon:Print("Tooltip item-count integration enabled")
end