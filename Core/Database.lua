-- Guda Database Module
-- Handles saving and loading character data

local addon = Guda

local DB = {}
addon.Modules.DB = DB

-- Current player info
local playerName, playerRealm, playerFaction

-- Initialize database
function DB:Initialize()
-- Get player info
	playerName = UnitName("player")
	playerRealm = GetRealmName()
	playerFaction = UnitFactionGroup("player")

	local fullName = playerName .. "-" .. playerRealm

	-- Initialize global DB
	if not Guda_DB then
		Guda_DB = {
			version = addon.VERSION,
			characters = {},
		}
	end

	-- Initialize character DB
	if not Guda_CharDB then
		Guda_CharDB = {
			settings = {
				showBankInBags = true,
				showOtherChars = true,
				bagColumns = 10,
				bankBagColumns = 8,
				bankColumns = 10,
				sortMethod = "quality", -- quality, name, type
				iconSize = 37,
				iconSpacing = 4,
				iconFontSize = 12,
				showQualityBorderEquipment = true,
				showQualityBorderOther = true,
				showSearchBar = true,
				hideBagline = true,
				hideFooter = false,
				bgTransparency = 0.15,
				showTrackedItems = true,
				showTooltipCounts = true,
				markUnusableItems = true,
				bagViewType = "single", -- single, category
				bankViewType = "single", -- single, category
				trackedItems = {},
			},
		}
	end

	-- Ensure new settings exist for existing installations
	if Guda_CharDB.settings.bagViewType == nil then
		Guda_CharDB.settings.bagViewType = "single"
	end
	if Guda_CharDB.settings.bankViewType == nil then
		Guda_CharDB.settings.bankViewType = "single"
	end
	if Guda_CharDB.settings.showTooltipCounts == nil then
		Guda_CharDB.settings.showTooltipCounts = true
	end
	if Guda_CharDB.settings.bgTransparency == nil then
		if Guda_CharDB.settings.frameOpacity ~= nil then
			Guda_CharDB.settings.bgTransparency = 1.0 - Guda_CharDB.settings.frameOpacity
			Guda_CharDB.settings.frameOpacity = nil -- Clean up old setting
		else
			Guda_CharDB.settings.bgTransparency = 0.15
		end
	end
	if Guda_CharDB.settings.hideFooter == nil then
		Guda_CharDB.settings.hideFooter = false
	end
	if Guda_CharDB.settings.hideBagline == nil then
		Guda_CharDB.settings.hideBagline = true
	end
	if Guda_CharDB.settings.showQuestBar == nil then
		Guda_CharDB.settings.showQuestBar = true
	end
	if Guda_CharDB.settings.showTrackedItems == nil then
		Guda_CharDB.settings.showTrackedItems = true
	end
	if Guda_CharDB.settings.trackedItems == nil then
		Guda_CharDB.settings.trackedItems = {}
	end
	if not Guda_CharDB.settings.bagColumns then
		Guda_CharDB.settings.bagColumns = 10
	end
	if not Guda_CharDB.settings.bankBagColumns then
		Guda_CharDB.settings.bankBagColumns = 8
	end
	if not Guda_CharDB.settings.bankColumns then
		Guda_CharDB.settings.bankColumns = 10
	end
	if not Guda_CharDB.settings.iconSize then
		Guda_CharDB.settings.iconSize = 37
	end
	if not Guda_CharDB.settings.iconSpacing then
		Guda_CharDB.settings.iconSpacing = 4
	end
	if not Guda_CharDB.settings.iconFontSize then
		Guda_CharDB.settings.iconFontSize = 12
	end
	if Guda_CharDB.settings.showQualityBorderEquipment == nil then
		Guda_CharDB.settings.showQualityBorderEquipment = true
	end
	if Guda_CharDB.settings.showQualityBorderOther == nil then
		Guda_CharDB.settings.showQualityBorderOther = true
	end
	if Guda_CharDB.settings.showSearchBar == nil then
		Guda_CharDB.settings.showSearchBar = true
	end
	if Guda_CharDB.settings.questBarPinnedItems == nil then
		Guda_CharDB.settings.questBarPinnedItems = {}
	end
	if Guda_CharDB.settings.markUnusableItems == nil then
		Guda_CharDB.settings.markUnusableItems = true
	end
	if Guda_CharDB.settings.mergedGroups == nil then
		Guda_CharDB.settings.mergedGroups = {}
	end
	if Guda_CharDB.settings.showEquipSetCategories == nil then
		Guda_CharDB.settings.showEquipSetCategories = true
	end
	if Guda_CharDB.settings.markEquipmentSets == nil then
		Guda_CharDB.settings.markEquipmentSets = true
	end
	if Guda_CharDB.settings.showCategoryCount == nil then
		Guda_CharDB.settings.showCategoryCount = true
	end
	if Guda_CharDB.settings.autoVendorJunk == nil then
		Guda_CharDB.settings.autoVendorJunk = true
	end
	if Guda_CharDB.settings.whiteItemsJunk == nil then
		Guda_CharDB.settings.whiteItemsJunk = false
	end
	if Guda_CharDB.settings.autoLockSetItems == nil then
		Guda_CharDB.settings.autoLockSetItems = true
	end

	-- Auto-detect pfUI on first load (theme not yet set)
	if Guda_CharDB.settings.theme == nil then
		if pfUI then
			Guda_CharDB.settings.theme = "pfui"
			Guda_CharDB.settings.hideBorders = true
			Guda_CharDB.settings.bgTransparency = Guda.Constants.PFUI_DEFAULT_BG_TRANSPARENCY
			Guda_CharDB.settings.iconSpacing = 8
		end
	end

	-- Initialize locked items storage
	if not Guda_CharDB.lockedItems then
		Guda_CharDB.lockedItems = {}
	end

	-- Initialize set protection exceptions storage
	if not Guda_CharDB.setProtectionExceptions then
		Guda_CharDB.setProtectionExceptions = {}
	end

	-- Initialize pinned slots storage
	if not Guda_CharDB.pinnedSlots then
		Guda_CharDB.pinnedSlots = {}
	end

	-- Initialize CategoryManager for custom categories
	if addon.Modules.CategoryManager then
		addon.Modules.CategoryManager:Initialize()
	end

	-- Initialize this character's data
	if not Guda_DB.characters[fullName] then
		local localizedClass, englishClass = UnitClass("player")
		Guda_DB.characters[fullName] = {
			name = playerName,
			realm = playerRealm,
			faction = playerFaction,
			class = localizedClass,
			classToken = englishClass, -- English uppercase token for RAID_CLASS_COLORS
			level = UnitLevel("player"),
			money = 0,
			bags = {},
			bank = {},
			mailbox = {},   -- Add mailbox storage
			equipped = {},  -- Add equipped items storage
			character = {}, -- Add character info storage
			lastUpdate = time(),
		}
	else
	-- Migration: Add classToken to existing characters
		local char = Guda_DB.characters[fullName]
		if not char.classToken then
			local localizedClass, englishClass = UnitClass("player")
			char.classToken = englishClass
			addon:Debug("Added classToken to existing character")
		end

		-- Migration: Add equipped and character fields if they don't exist
		if not char.equipped then
			char.equipped = {}
			addon:Debug("Added equipped field to existing character")
		end
		if not char.character then
			char.character = {}
			addon:Debug("Added character field to existing character")
		end
		if not char.mailbox then
			char.mailbox = {}
			addon:Debug("Added mailbox field to existing character")
		end
	end

	addon:Debug("Database initialized for %s", fullName)
end

-- Get current player's full name
function DB:GetPlayerFullName()
	return playerName .. "-" .. playerRealm
end

-- Get current character data
function DB:GetCurrentCharacter()
	local fullName = self:GetPlayerFullName()
	return Guda_DB.characters[fullName]
end

-- Get current character data (alias for compatibility)
function DB:GetCurrentCharacterData()
	return self:GetCurrentCharacter()
end

-- Save bag data
function DB:SaveBags(bagData)
	local char = self:GetCurrentCharacter()
	if char then
		char.bags = bagData
		char.lastUpdate = time()
		addon:Debug("Saved bag data")
	end
end

-- Save bank data
function DB:SaveBank(bankData)
	local char = self:GetCurrentCharacter()
	if char then
		char.bank = bankData
		char.lastUpdate = time()
		addon:Debug("Saved bank data")
	end
end

-- Save equipment data
function DB:SaveEquipment(equipmentData)
	local char = self:GetCurrentCharacter()
	if char then
		char.equipped = equipmentData.equipped
		char.character = equipmentData.character
		char.lastUpdate = time()
		addon:Debug("Saved equipment data")
	end
end

-- Save money
function DB:SaveMoney(copper)
	local char = self:GetCurrentCharacter()
	if char then
		char.money = copper
		char.level = UnitLevel("player")
		addon:Debug("Saved money: %d copper", copper)
	end
end

-- Save mailbox data
function DB:SaveMailbox(mailboxData)
	local char = self:GetCurrentCharacter()
	if char then
		char.mailbox = mailboxData
		char.lastUpdate = time()
		addon:Debug("Saved mailbox data")
	end
end

-- Add a single mail entry to a character's mailbox
function DB:AddMailToCharacter(name, realm, mailRow)
	local fullName = name .. "-" .. (realm or playerRealm)
	local char = Guda_DB.characters[fullName]
	
	if char then
		if not char.mailbox then
			char.mailbox = {}
		end
		
		-- Check if this exact mail already exists (simplistic check)
		local exists = false
		for _, m in ipairs(char.mailbox) do
			if m.sender == mailRow.sender and m.subject == mailRow.subject and m.money == mailRow.money then
				if (not m.item and not mailRow.item) or (m.item and mailRow.item and m.item.name == mailRow.item.name and m.item.count == mailRow.item.count) then
					exists = true
					-- Update link/itemID if missing in existing but present in new
					if mailRow.item and m.item then
						if not m.item.link and mailRow.item.link then
							m.item.link = mailRow.item.link
							addon:Debug("Updated link for existing mail item")
						end
						if not m.item.itemID and mailRow.item.itemID then
							m.item.itemID = mailRow.item.itemID
							addon:Debug("Updated itemID for existing mail item")
						end
					end
					break
				end
			end
		end
		
		if not exists then
			table.insert(char.mailbox, 1, mailRow) -- Add to beginning
			char.lastUpdate = time()
			addon:Debug("Added outgoing mail to %s's mailbox", fullName)
			return true
		end
	end
	return false
end

-- Get all characters (optionally filter by faction and/or realm)
function DB:GetAllCharacters(sameFactionOnly, currentRealmOnly)
	local chars = {}
	for fullName, data in pairs(Guda_DB.characters) do
		local factionMatch = not sameFactionOnly or data.faction == playerFaction
		local realmMatch = not currentRealmOnly or data.realm == playerRealm
		if factionMatch and realmMatch then
			table.insert(chars, {
				fullName = fullName,
				name = data.name,
				realm = data.realm,
				class = data.class,
				classToken = data.classToken, -- English uppercase token for colors
				level = data.level,
				faction = data.faction,
				money = data.money,
				lastUpdate = data.lastUpdate,
			})
		end
	end

	-- Sort by name
	table.sort(chars, function(a, b)
		return a.name < b.name
	end)

	return chars
end

-- Get character's bags
function DB:GetCharacterBags(fullName)
	local char = Guda_DB.characters[fullName]
	return char and char.bags or {}
end

-- Get character's bank
function DB:GetCharacterBank(fullName)
	local char = Guda_DB.characters[fullName]
	return char and char.bank or {}
end

-- Get character's mailbox
function DB:GetCharacterMailbox(fullName)
	local char = Guda_DB.characters[fullName]
	return char and char.mailbox or {}
end

-- Find an item ID and link by name in any character's data
function DB:FindItemByName(name)
	if not name or name == "" or not Guda_DB or not Guda_DB.characters then return nil, nil end
	
	for fullName, char in pairs(Guda_DB.characters) do
		-- Check bags
		if char.bags then
			for bagID, bagData in pairs(char.bags) do
				if type(bagData) == "table" and bagData.slots then
					for slotID, item in pairs(bagData.slots) do
						if item and item.name == name and item.link then
							local itemID = addon.Modules.Utils:ExtractItemID(item.link)
							if itemID then return itemID, item.link end
						end
					end
				end
			end
		end
		-- Check bank
		if char.bank then
			for bagID, bagData in pairs(char.bank) do
				if type(bagData) == "table" and bagData.slots then
					for slotID, item in pairs(bagData.slots) do
						if item and item.name == name and item.link then
							local itemID = addon.Modules.Utils:ExtractItemID(item.link)
							if itemID then return itemID, item.link end
						end
					end
				end
			end
		end
		-- Check equipped
		if char.equipped then
			for slot, item in pairs(char.equipped) do
				if item and item.name == name and item.link then
					local itemID = addon.Modules.Utils:ExtractItemID(item.link)
					if itemID then return itemID, item.link end
				end
			end
		end
		-- Check mailbox
		if char.mailbox then
			for _, mail in ipairs(char.mailbox) do
				if mail.item and mail.item.name == name and mail.item.link then
					local itemID = addon.Modules.Utils:ExtractItemID(mail.item.link)
					if itemID then return itemID, mail.item.link end
				end
			end
		end
	end
	return nil, nil
end

-- Get character's equipped items
function DB:GetCharacterEquipped(fullName)
	local char = Guda_DB.characters[fullName]
	return char and char.equipped or {}
end

-- Get character info
function DB:GetCharacterInfo(fullName)
	local char = Guda_DB.characters[fullName]
	return char and char.character or {}
end

-- Get total money across all characters (optionally filter by faction and/or realm)
function DB:GetTotalMoney(sameFactionOnly, currentRealmOnly)
	local total = 0
	for fullName, data in pairs(Guda_DB.characters) do
		local factionMatch = not sameFactionOnly or data.faction == playerFaction
		local realmMatch = not currentRealmOnly or data.realm == playerRealm
		if factionMatch and realmMatch then
			total = total + (data.money or 0)
		end
	end
	return total
end

-- Get character setting
function DB:GetSetting(key)
-- SavedVariables may not be initialized yet when some UI OnLoad scripts run
	if not Guda_CharDB or not Guda_CharDB.settings then
		return nil
	end
	return Guda_CharDB.settings[key]
end

-- Set character setting
function DB:SetSetting(key, value)
-- Ensure tables exist even if called early
	if not Guda_CharDB then
		Guda_CharDB = { settings = {} }
	elseif not Guda_CharDB.settings then
		Guda_CharDB.settings = {}
	end
	Guda_CharDB.settings[key] = value
end

-------------------------------------------------
-- Locked Items (per-character, itemID-based)
-------------------------------------------------

function DB:IsItemLocked(itemID)
	if not itemID or not Guda_CharDB or not Guda_CharDB.lockedItems then return false end
	return Guda_CharDB.lockedItems[itemID] and true or false
end

function DB:ToggleItemLock(itemID)
	if not itemID or not Guda_CharDB then return false end
	if not Guda_CharDB.lockedItems then
		Guda_CharDB.lockedItems = {}
	end
	if Guda_CharDB.lockedItems[itemID] then
		Guda_CharDB.lockedItems[itemID] = nil
		return false
	else
		Guda_CharDB.lockedItems[itemID] = true
		return true
	end
end

-------------------------------------------------
-- Set Protection Exceptions (per-character)
-- Items in equipment sets that the user explicitly
-- chose to unprotect via Ctrl+Right-Click
-------------------------------------------------

function DB:IsSetProtectionException(itemID)
	if not itemID or not Guda_CharDB or not Guda_CharDB.setProtectionExceptions then return false end
	return Guda_CharDB.setProtectionExceptions[itemID] and true or false
end

function DB:ToggleSetProtectionException(itemID)
	if not itemID or not Guda_CharDB then return false end
	if not Guda_CharDB.setProtectionExceptions then
		Guda_CharDB.setProtectionExceptions = {}
	end
	if Guda_CharDB.setProtectionExceptions[itemID] then
		Guda_CharDB.setProtectionExceptions[itemID] = nil
		return false  -- protection restored
	else
		Guda_CharDB.setProtectionExceptions[itemID] = true
		return true   -- protection removed (excepted)
	end
end

-- Remove exceptions for items no longer in any equipment set
function DB:PruneSetProtectionExceptions()
	if not Guda_CharDB or not Guda_CharDB.setProtectionExceptions then return end
	local EquipSets = addon.Modules.EquipmentSets
	if not EquipSets or not EquipSets.IsInSet then return end
	for itemID in pairs(Guda_CharDB.setProtectionExceptions) do
		if not EquipSets:IsInSet(itemID) then
			Guda_CharDB.setProtectionExceptions[itemID] = nil
		end
	end
end

-- Check if an item is protected (user-locked or in equipment set with autoLockSetItems)
function DB:IsItemProtected(itemID)
	if not itemID then return false end
	if self:IsItemLocked(itemID) then return true end
	if self:GetSetting("autoLockSetItems") then
		local EquipSets = addon.Modules.EquipmentSets
		if EquipSets and EquipSets.IsInSet and EquipSets:IsInSet(itemID)
		   and not self:IsSetProtectionException(itemID) then
			return true
		end
	end
	return false
end

-------------------------------------------------
-- Pinned Slots (per-character, slot-based)
-- Slots pinned by the user are skipped during sorting.
-- Key format: bagID * 1000 + slot
-------------------------------------------------

function DB:IsPinnedSlot(bagID, slot)
	if not bagID or not slot or not Guda_CharDB or not Guda_CharDB.pinnedSlots then return false end
	return Guda_CharDB.pinnedSlots[bagID * 1000 + slot] and true or false
end

function DB:TogglePinnedSlot(bagID, slot)
	if not bagID or not slot or not Guda_CharDB then return false end
	if not Guda_CharDB.pinnedSlots then
		Guda_CharDB.pinnedSlots = {}
	end
	local key = bagID * 1000 + slot
	if Guda_CharDB.pinnedSlots[key] then
		Guda_CharDB.pinnedSlots[key] = nil
		return false  -- unpinned
	else
		Guda_CharDB.pinnedSlots[key] = true
		return true   -- pinned
	end
end

function DB:GetPinnedSlotSet()
	if not Guda_CharDB or not Guda_CharDB.pinnedSlots then return {} end
	return Guda_CharDB.pinnedSlots
end

-- Cleanup old characters (not updated in 90 days)
function DB:CleanupOldCharacters()
	local cutoff = time() - (90 * 24 * 60 * 60) -- 90 days
	local removed = 0

	for fullName, data in pairs(Guda_DB.characters) do
		if data.lastUpdate and data.lastUpdate < cutoff then
			Guda_DB.characters[fullName] = nil
			removed = removed + 1
		end
	end

	if removed > 0 then
		addon:Print("Cleaned up %d old character(s)", removed)
	end
end