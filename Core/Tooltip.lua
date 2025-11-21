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
local function CountCurrentCharacterItems(itemID)
	local bagCount = 0
	local bankCount = 0
	local equippedCount = 0

	-- Count current character's bags in real-time
	for bagID = 0, 4 do
		local numSlots = GetContainerNumSlots(bagID)
		for slot = 1, numSlots do
			local link = GetContainerItemLink(bagID, slot)
			if link then
				local slotItemID = GetItemIDFromLink(link)
				if slotItemID == itemID then
					local _, count = GetContainerItemInfo(bagID, slot)
					bagCount = bagCount + (count or 1)
				end
			end
		end
	end

	-- Count current character's bank in real-time if bank is open
	local bankFrame = getglobal("BankFrame")
	if bankFrame and bankFrame:IsVisible() then
	-- Main bank slots (-1)
		local numMainSlots = GetContainerNumSlots(-1) or 24
		for slot = 1, numMainSlots do
			local link = GetContainerItemLink(-1, slot)
			if link then
				local slotItemID = GetItemIDFromLink(link)
				if slotItemID == itemID then
					local _, count = GetContainerItemInfo(-1, slot)
					bankCount = bankCount + (count or 1)
				end
			end
		end

		-- Bank bags (5-11)
		for bagID = 5, 11 do
			local numSlots = GetContainerNumSlots(bagID)
			if numSlots and numSlots > 0 then
				for slot = 1, numSlots do
					local link = GetContainerItemLink(bagID, slot)
					if link then
						local slotItemID = GetItemIDFromLink(link)
						if slotItemID == itemID then
							local _, count = GetContainerItemInfo(bagID, slot)
							bankCount = bankCount + (count or 1)
						end
					end
				end
			end
		end
	else
	-- Bank not open - use saved data for bank counts
		local playerName = addon.Modules.DB:GetPlayerFullName()
		local charData = Guda_DB and Guda_DB.characters and Guda_DB.characters[playerName]
		if charData and charData.bank and type(charData.bank) == "table" then
			for bagID, bagData in pairs(charData.bank) do
				if bagData and type(bagData) == "table" and bagData.slots and type(bagData.slots) == "table" then
					for slotID, itemData in pairs(bagData.slots) do
						if itemData and type(itemData) == "table" and itemData.link then
							local slotItemID = GetItemIDFromLink(itemData.link)
							if slotItemID == itemID then
								bankCount = bankCount + (itemData.count or 1)
							end
						end
					end
				end
			end
		end
	end

	-- Count equipped items in real-time
	for slotID = 1, 19 do  -- All equipment slots
		local link = GetInventoryItemLink("player", slotID)
		if link then
			local slotItemID = GetItemIDFromLink(link)
			if slotItemID == itemID then
				equippedCount = equippedCount + 1
			end
		end
	end

	return bagCount, bankCount, equippedCount
end

-- Count items for a specific character with real-time data for current character
local function CountItemsForCharacter(itemID, characterData, isCurrentChar)
-- For current character, use real-time counting to avoid database sync issues
	if isCurrentChar then
		return CountCurrentCharacterItems(itemID)
	end

	-- For other characters, use saved data
	local bagCount = 0
	local bankCount = 0
	local equippedCount = 0

	-- Count bags from saved data
	if characterData.bags and type(characterData.bags) == "table" then
		for bagID, bagData in pairs(characterData.bags) do
			if bagData and type(bagData) == "table" and bagData.slots and type(bagData.slots) == "table" then
				for slotID, itemData in pairs(bagData.slots) do
					if itemData and type(itemData) == "table" and itemData.link then
						local slotItemID = GetItemIDFromLink(itemData.link)
						if slotItemID == itemID then
							bagCount = bagCount + (itemData.count or 1)
						end
					end
				end
			end
		end
	end

	-- Count bank from saved data
	if characterData.bank and type(characterData.bank) == "table" then
		for bagID, bagData in pairs(characterData.bank) do
			if bagData and type(bagData) == "table" and bagData.slots and type(bagData.slots) == "table" then
				for slotID, itemData in pairs(bagData.slots) do
					if itemData and type(itemData) == "table" and itemData.link then
						local slotItemID = GetItemIDFromLink(itemData.link)
						if slotItemID == itemID then
							bankCount = bankCount + (itemData.count or 1)
						end
					end
				end
			end
		end
	end

	-- Count equipped items from saved data
	if characterData.equipped and type(characterData.equipped) == "table" then
		for slotName, itemData in pairs(characterData.equipped) do
			if itemData and type(itemData) == "table" and itemData.link then
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

function Tooltip:AddInventoryInfo(tooltip, link)
-- Check if database is properly initialized and has the expected structure
	if not Guda_DB or type(Guda_DB) ~= "table" then
		return
	end

	-- Safely check characters - it might be nil or a string during early initialization
	if not Guda_DB.characters or type(Guda_DB.characters) ~= "table" then
	-- If characters is a string or nil, just return silently
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

	local currentPlayerName = addon.Modules.DB:GetPlayerFullName()
	local currentRealm = GetRealmName()

	-- Count items across characters on current realm only
	for charName, charData in pairs(Guda_DB.characters) do
	-- Ensure charData is actually a table and on current realm
		if type(charData) == "table" and charData.realm == currentRealm then
			local isCurrentChar = (charName == currentPlayerName)
			local bagCount, bankCount, equippedCount = CountItemsForCharacter(itemID, charData, isCurrentChar)

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
					equippedCount = equippedCount,
					isCurrent = isCurrentChar
				})
			end
		end
	-- If charData is not a table (string, number, etc.), just skip it
	end

	local totalCount = totalBags + totalBank + totalEquipped

	if hasAnyItems then
		tooltip:AddLine(" ")

		-- Inventory label in exact bag frame title color
		tooltip:AddLine("|cFFFFD200Inventory|r")

		-- Total line with cyan label and white count
		local totalText = "|cFF00FFFFTotal|r: |cFFFFFFFF" .. totalCount .. "|r"
		local breakdownText = "(|cFF00FFFFBags|r: |cFFFFFFFF" .. totalBags .. "|r | |cFF00FFFFBank|r: |cFFFFFFFF" .. totalBank .. "|r)"
		tooltip:AddDoubleLine(totalText, breakdownText, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0)

		-- Sort with current character first
		table.sort(characterCounts, function(a, b)
			if a.isCurrent and not b.isCurrent then return true end
			if not a.isCurrent and b.isCurrent then return false end
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

			-- Mark current character
			local displayName = charInfo.name
			if charInfo.isCurrent then
				displayName = displayName .. " |cFFFFFF00(*)|r"
			end

			tooltip:AddDoubleLine(displayName, countText, r, g, b, 1.0, 1.0, 1.0)
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
	local oldSetInventoryItem = GameTooltip.SetInventoryItem
	local oldSetHyperlink = GameTooltip.SetHyperlink
	function GameTooltip:SetBagItem(bag, slot)
		return WithDeferredMoney(self, function()
			local bankFrame = getglobal("BankFrame")

			if bag == -1 and bankFrame and bankFrame:IsVisible() then
				addon:Print('BANK FRAME:')
				local invSlot = BankButtonIDToInvSlotID(slot)
				if invSlot then
					-- Use the inventory item method for bank main bag
					local ret = oldSetInventoryItem(self, "player", invSlot)
					local link = GetInventoryItemLink("player", invSlot)
					if link then
						Tooltip:AddInventoryInfo(self, link)
					end
					return ret
				end
			else
				-- Bank is closed or readonly mode - try to get cached link
				if bag == -1 then
					-- Get cached link from database for main bank bag
					local playerName = addon.Modules.DB:GetPlayerFullName()
					local bankData = addon.Modules.DB:GetCharacterBank(playerName)
					if bankData and bankData[-1] and bankData[-1].slots and bankData[-1].slots[slot] then
						local itemData = bankData[-1].slots[slot]
						if itemData.link and string.find(itemData.link, "|H") then
							-- Extract hyperlink from full colored string: |cFFFFFFFF|Hitem:...|h[Name]|h|r
							-- SetHyperlink needs just the item:... part
							local _, _, hyperlink = string.find(itemData.link, "|H(.+)|h")
							if hyperlink then
								local ret = oldSetHyperlink(self, hyperlink)
								Tooltip:AddInventoryInfo(self, itemData.link)
								return ret
							end
						end
					end
					-- No cached data found
					return nil
				else
					-- Regular bags and bank bags (not main bag) - use normal SetBagItem
					local ret = oldSetBagItem(self, bag, slot)
					local link = GetContainerItemLink(bag, slot)
					if link then
						Tooltip:AddInventoryInfo(self, link)
					end
					return ret
				end
			end
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