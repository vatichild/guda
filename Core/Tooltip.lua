-- Guda Tooltip Module - Lua 5.0 Compatible
local addon = Guda

local Tooltip = {}
addon.Modules.Tooltip = Tooltip

-- Helper function to get item ID from link (Lua 5.0 compatible)
local function GetItemIDFromLink(link)
	if not link then return nil end
    if type(link) == "number" then return link end
    
    -- Try to find itemID in a standard link or a raw item:ID string
	local _, _, itemID = string.find(link, "item:(%d+)")
	return itemID and tonumber(itemID) or nil
end
local function CountCurrentCharacterItems(itemID)
	local bagCount = 0
	local bankCount = 0
	local mailCount = 0
	local equippedCount = 0

	-- Count current character's bags in real-time
	local bagsToCount = {0, 1, 2, 3, 4, -2}
	for _, bagID in ipairs(bagsToCount) do
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

	-- Count current character's mailbox in real-time if mailbox is open
	if addon.Modules.MailboxScanner and addon.Modules.MailboxScanner:IsMailboxOpen() then
		local numInboxItems = GetInboxNumItems()
		for i = 1, numInboxItems do
			local _, _, _, _, _, _, _, hasItem = GetInboxHeaderInfo(i)
			if hasItem then
				-- Turtle WoW supports up to 12 attachments per mail.
				-- We use GetInboxNumAttachments if available to avoid over-scanning.
				local numAttachments = 0
				if GetInboxNumAttachments then
					numAttachments = GetInboxNumAttachments(i) or 0
				end

				-- Fallback: if we don't have the count but header says there's an item, assume at least 1.
				if numAttachments == 0 and hasItem then
					numAttachments = 1
				end

				for j = 1, numAttachments do -- Turtle WoW supports up to 12 attachments
					local name, _, count = GetInboxItem(i, j)
					if name then
						local itemLink = addon.Modules.Utils:GetInboxItemLink(i, j)
						if itemLink then
							local slotItemID = GetItemIDFromLink(itemLink)
							if slotItemID == itemID then
								mailCount = mailCount + (count or 1)
							end
						end
					end
				end
			end
		end
	else
		-- Mailbox not open - use saved data
		local playerName = addon.Modules.DB:GetPlayerFullName()
		local charData = Guda_DB and Guda_DB.characters and Guda_DB.characters[playerName]
		if charData and charData.mailbox and type(charData.mailbox) == "table" then
			for _, mail in ipairs(charData.mailbox) do
				if mail.items then
					for _, item in ipairs(mail.items) do
						local slotItemID = item.link and GetItemIDFromLink(item.link)
						if slotItemID == itemID then
							mailCount = mailCount + (item.count or 1)
						elseif not slotItemID and item.name then
							-- Fallback to name matching if link is missing
							local targetName = GetItemInfo(itemID)
							if targetName == item.name then
								mailCount = mailCount + (item.count or 1)
							end
						end
					end
				elseif mail.item then -- Fallback for single item data structure
					local item = mail.item
					local slotItemID = item.link and GetItemIDFromLink(item.link)
					if slotItemID == itemID then
						mailCount = mailCount + (item.count or 1)
					elseif not slotItemID and item.name then
						-- Fallback to name matching if link is missing
						local targetName = GetItemInfo(itemID)
						if targetName == item.name then
							mailCount = mailCount + (item.count or 1)
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

	return bagCount, bankCount, equippedCount, mailCount
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
	local mailCount = 0
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

	-- Count mailbox from saved data
	if characterData.mailbox and type(characterData.mailbox) == "table" then
		for _, mail in ipairs(characterData.mailbox) do
			if mail.items then
				for _, item in ipairs(mail.items) do
					local slotItemID = item.link and GetItemIDFromLink(item.link)
					if slotItemID == itemID then
						mailCount = mailCount + (item.count or 1)
					elseif not slotItemID and item.name then
						-- Fallback to name matching if link is missing
						local targetName = GetItemInfo(itemID)
						if targetName == item.name then
							mailCount = mailCount + (item.count or 1)
						end
					end
				end
			elseif mail.item then -- Fallback for single item data structure
				local item = mail.item
				local slotItemID = item.link and GetItemIDFromLink(item.link)
				if slotItemID == itemID then
					mailCount = mailCount + (item.count or 1)
				elseif not slotItemID and item.name then
					-- Fallback to name matching if link is missing
					local targetName = GetItemInfo(itemID)
					if targetName == item.name then
						mailCount = mailCount + (item.count or 1)
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

	return bagCount, bankCount, equippedCount, mailCount
end


-- Get class color
local function GetClassColor(classToken)
	if not classToken then return 1.0, 1.0, 1.0 end
	local color = RAID_CLASS_COLORS[classToken]
	if color then return color.r, color.g, color.b end
	return 1.0, 1.0, 1.0
end

function Tooltip:AddInventoryInfo(tooltip, link)
-- Check if the setting is enabled
	if not addon.Modules.DB:GetSetting("showTooltipCounts") then
		return
	end

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

	-- Guard against double-adding for the same item on the same tooltip
	if tooltip.GudaInventoryAdded == itemID then
		return
	end
	tooltip.GudaInventoryAdded = itemID

	local totalBags = 0
	local totalBank = 0
	local totalMail = 0
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
			local bagCount, bankCount, equippedCount, mailCount = CountItemsForCharacter(itemID, charData, isCurrentChar)

			if bagCount > 0 or bankCount > 0 or equippedCount > 0 or mailCount > 0 then
				hasAnyItems = true
				totalBags = totalBags + bagCount
				totalBank = totalBank + bankCount
				totalMail = totalMail + mailCount
				totalEquipped = totalEquipped + equippedCount
				table.insert(characterCounts, {
					name = charData.name or charName,
					classToken = charData.classToken,
					bagCount = bagCount,
					bankCount = bankCount,
					mailCount = mailCount,
					equippedCount = equippedCount,
					isCurrent = isCurrentChar
				})
			end
		end
	-- If charData is not a table (string, number, etc.), just skip it
	end

	local totalCount = totalBags + totalBank + totalMail + totalEquipped

	if hasAnyItems then

		-- Top padding above the Inventory block (~10-12px visually)
		tooltip:AddLine(" ")

		-- Inventory label in exact bag frame title color
		tooltip:AddLine("|cFFFFD200Inventory|r")

		-- Total line with cyan label and white count
		local totalText = "|cFF00FFFFTotal|r: |cFFFFFFFF" .. totalCount .. "|r"
		local breakdownParts = {}
		if totalBags > 0 then table.insert(breakdownParts, "|cFF00FFFFBags|r: |cFFFFFFFF" .. totalBags .. "|r") end
		if totalBank > 0 then table.insert(breakdownParts, "|cFF00FFFFBank|r: |cFFFFFFFF" .. totalBank .. "|r") end
		if totalMail > 0 then table.insert(breakdownParts, "|cFF00FFFFMail|r: |cFFFFFFFF" .. totalMail .. "|r") end
		if totalEquipped > 0 then table.insert(breakdownParts, "|cFF00FFFFEquipped|r: |cFFFFFFFF" .. totalEquipped .. "|r") end
		
		local breakdownText = ""
		if table.getn(breakdownParts) > 0 then
			breakdownText = "(" .. table.concat(breakdownParts, " | ") .. ")"
		end
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
			if charInfo.mailCount > 0 then
				table.insert(parts, "|cFF00FFFFMail|r: |cFFFFFFFF" .. charInfo.mailCount .. "|r")
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

		-- Bottom padding below the Inventory block (~10-12px visually)
		--tooltip:AddLine(" ")

	end
end

function Tooltip:Initialize()
	addon:Print("Initializing tooltip module...")

	-- Helper function to defer vendor money so we can insert our Inventory block above it
	local Orig_SetTooltipMoney = SetTooltipMoney
	-- Move the tooltip money frame(s) vertically to fine-tune their position under our custom block
	local function AdjustMoneyFrames(tooltip, yOffset)
		if not tooltip or not tooltip.GetName then return end
		local baseName = tooltip:GetName()
		if not baseName then return end

		-- Collect potential money frame names used by WoW tooltips
		local candidates = {}
		-- Primary money frame
		tinsert(candidates, baseName .. "MoneyFrame")
		-- Sometimes multiple money frames are created with numeric suffixes
		for i = 1, 8 do
			tinsert(candidates, baseName .. "MoneyFrame" .. i)
			tinsert(candidates, baseName .. "SmallMoneyFrame" .. i)
		end

		for i = 1, getn(candidates) do
			local f = getglobal(candidates[i])
			if f and f:IsShown() and f.GetPoint then
				local point, relTo, relPoint, xOfs, yOfs = f:GetPoint(1)
				if point then
					f:SetPoint(point, relTo, relPoint, xOfs or 0, (yOfs or 0) + (yOffset or 0))
				end
			end
		end
	end
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

		-- Ensure the tooltip background resizes to include both our block and the money frame
		tooltip:Show()

		-- Add ~5px more space below the Inventory block by reducing the upward nudge from 15px to 10px
		--AdjustMoneyFrames(tooltip, 12)
		return ret
	end

	-- Hook SetBagItem
	local oldSetBagItem = GameTooltip.SetBagItem
	local oldSetInventoryItem = GameTooltip.SetInventoryItem
	function GameTooltip:SetBagItem(bag, slot)
		return WithDeferredMoney(self, function()
			local bankFrame = getglobal("BankFrame")
			if bag == -1 and bankFrame and bankFrame:IsVisible() then
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
				return nil
			else
				local ret = oldSetBagItem(self, bag, slot)
				local link = GetContainerItemLink(bag, slot)
				if link then
					Tooltip:AddInventoryInfo(self, link)
				end
				return ret
			end
		end)
	end

 	-- Hook SetHyperlink for hyperlinks from chat and cached links
 	local oldSetHyperlink = GameTooltip.SetHyperlink
	function GameTooltip:SetHyperlink(link)
		return WithDeferredMoney(self, function()
			local _, _, inner = string.find(link or "", "|H(.+)|h")
			local forwarded = link
			local itemLinkForCounts = link
			if inner then
				forwarded = inner
				if strfind(inner, "^item:") then
					itemLinkForCounts = inner
				end
			end
			local ret = oldSetHyperlink(self, forwarded)
			if itemLinkForCounts and strfind(itemLinkForCounts, "item:") then
				Tooltip:AddInventoryInfo(self, itemLinkForCounts)
			end

			return ret
		end)
	end

	-- Hook SetInventoryItem for character paperdoll
	oldSetInventoryItem = GameTooltip.SetInventoryItem
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

	-- Hook SetInboxItem for mailbox
	local oldSetInboxItem = GameTooltip.SetInboxItem
	function GameTooltip:SetInboxItem(index, itemIndex)
		return WithDeferredMoney(self, function()
			local ret = oldSetInboxItem(self, index, itemIndex)
			local link = addon.Modules.Utils:GetInboxItemLink(index, itemIndex)
			if link then
				Tooltip:AddInventoryInfo(self, link)
			end
			return ret
		end)
	end

	-- Hook SetTradeSkillItem for profession reagents and items
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

	-- Hook SetCraftItem for professions like Enchanting (Crafts)
	local oldSetCraftItem = GameTooltip.SetCraftItem
	function GameTooltip:SetCraftItem(skillIndex, reagentIndex)
		return WithDeferredMoney(self, function()
			local ret = oldSetCraftItem(self, skillIndex, reagentIndex)
			local link
			if reagentIndex then
				link = GetCraftReagentItemLink(skillIndex, reagentIndex)
			else
				link = GetCraftItemLink(skillIndex)
			end
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