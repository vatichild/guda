-- Guda Equipment Scanner
-- Scans and stores character equipment information

local addon = Guda

local EquipmentScanner = {}
addon.Modules.EquipmentScanner = EquipmentScanner

local playerLoggedIn = false

-- Scan all equipment and return data
function EquipmentScanner:ScanAll()
	local equipmentData = {
		equipped = self:ScanEquippedItems(),
		character = self:ScanCharacterInfo(),
		lastUpdated = time()
	}

	return equipmentData
end

-- Scan all equipped items
function EquipmentScanner:ScanEquippedItems()
	local equipped = {}

	-- List of equipment slots to scan
	local equipmentSlots = {
		"HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "ShirtSlot",
		"TabardSlot", "WristSlot", "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot",
		"Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot",
		"MainHandSlot", "SecondaryHandSlot", "RangedSlot", "AmmoSlot"
	}

	for _, slotName in ipairs(equipmentSlots) do
		local slotID = GetInventorySlotInfo(slotName)
		local itemLink = GetInventoryItemLink("player", slotID)

		if itemLink then
			local itemName = GetItemInfo(itemLink)
			equipped[slotName] = {
				link = itemLink,
				name = itemName,
				texture = GetInventoryItemTexture("player", slotID)
			}
		end
	end

	return equipped
end

-- Scan character info (level, class, etc.) - Lua 5.0 compatible
function EquipmentScanner:ScanCharacterInfo()
	local name = UnitName("player")
	local realm = GetRealmName()

	-- Lua 5.0: UnitClass returns multiple values, not a table
	local class, classToken = UnitClass("player")
	local level = UnitLevel("player")
	local race = UnitRace("player")

	return {
		name = name,
		realm = realm,
		class = class,
		classToken = classToken,
		level = level,
		race = race,
		lastSeen = time()
	}
end

-- Save current equipment to database
function EquipmentScanner:SaveToDatabase()
	if not playerLoggedIn then
		return
	end

	local equipmentData = self:ScanAll()
	addon.Modules.DB:SaveEquipment(equipmentData)
	addon:Debug("Equipment data saved")
end

-- Initialize equipment scanner
function EquipmentScanner:Initialize()
	-- Player logged in - save equipment data
	addon.Modules.Events:OnPlayerLogin(function()
		playerLoggedIn = true
		addon:Print("Scanning equipped items...")

		-- Delay scan to ensure character is fully loaded
		local frame = CreateFrame("Frame")
		local elapsed = 0
		frame:SetScript("OnUpdate", function()
			elapsed = elapsed + arg1
			if elapsed >= 2.0 then
				frame:SetScript("OnUpdate", nil)
				EquipmentScanner:SaveToDatabase()
				addon:Print("Equipped items scanned and saved!")
			end
		end)
	end, "EquipmentScanner")

	-- Equipment changed
	addon.Modules.Events:Register("PLAYER_EQUIPMENT_CHANGED", function()
		if playerLoggedIn then
			EquipmentScanner:SaveToDatabase()
		end
	end, "EquipmentScanner")

	addon:Print("EquipmentScanner initialized successfully")
end

-- Check if player is logged in
function EquipmentScanner:IsPlayerLoggedIn()
	return playerLoggedIn
end