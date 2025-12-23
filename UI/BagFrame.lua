-- Guda Bag Frame
-- Main bag viewing UI

local addon = Guda

local BagFrame = {}
addon.Modules.BagFrame = BagFrame

local currentViewChar = nil -- nil = current character
local searchText = ""
local itemButtons = {}
local showKeyring = false -- Toggle for keyring display
local hiddenBags = {} -- Track which bags are hidden (bagID -> true/false)
local bagParents = {} -- Per-bag parent frames to carry bagID for Blizzard item button templates
local isMerchantOpen = false -- Track whether a vendor window is currently open to prevent auto-closing bags

-- Global click catcher for clearing search focus
local clickCatcher = nil

-- Get player race icon path (using racial ability icons)
function Guda_GetPlayerRaceIcon()
	local _, race = UnitRace("player")

	-- Use racial ability icons that exist in vanilla
	local raceIcons = {
		Human = "Interface\\Icons\\Spell_Magic_PolymorphPig",
		Dwarf = "Interface\\Icons\\Spell_Shadow_UnholyFrenzy",
		NightElf = "Interface\\Icons\\Spell_Nature_Invisibility",
		Gnome = "Interface\\Icons\\Ability_Repair",
		Orc = "Interface\\Icons\\Ability_Racial_BloodRage",
		Undead = "Interface\\Icons\\Spell_Shadow_RaiseDead",
		Tauren = "Interface\\Icons\\Ability_Thunderclap",
		Troll = "Interface\\Icons\\Ability_Racial_Avatar",
	}

	return raceIcons[race] or "Interface\\Icons\\INV_Misc_GroupNeedMore"
end

-- OnLoad
function Guda_BagFrame_OnLoad(self)
    -- Set up initial backdrop
    addon:ApplyBackdrop(self, "DEFAULT_FRAME")

-- Set up search box placeholder
	local searchBox = getglobal(self:GetName().."_SearchBar_SearchBox")
	if searchBox then
		searchBox:SetText("Search, try ~equipment")
		searchBox:SetTextColor(0.5, 0.5, 0.5, 1)
	end

	-- Create invisible full-screen frame to catch clicks outside bag
	if not clickCatcher then
		clickCatcher = CreateFrame("Frame", "Guda_ClickCatcher", UIParent)
		clickCatcher:SetFrameStrata("BACKGROUND")
		clickCatcher:SetAllPoints(UIParent)
		clickCatcher:EnableMouse(true)
		clickCatcher:Hide()

		clickCatcher:SetScript("OnMouseDown", function()
			Guda_BagFrame_ClearSearch()
		end)
	end

end


-- OnShow
function Guda_BagFrame_OnShow(self)
-- Save bag data when opening bags
	addon.Modules.BagScanner:SaveToDatabase()
	addon.Modules.MoneyTracker:Update()

	-- Restore saved position if it exists (only if saved as BOTTOMRIGHT)
	if addon and addon.Modules and addon.Modules.DB then
		local pos = addon.Modules.DB:GetSetting("bagFramePosition")
		if pos and pos.point == "BOTTOMRIGHT" and pos.x and pos.y then
			self:ClearAllPoints()
			self:SetPoint("BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", pos.x, pos.y)
		end
	end

	-- Set lock state when frame is shown (ensures all child frames are loaded)
	if BagFrame.UpdateLockState then
		BagFrame:UpdateLockState()
	end

	-- Apply border visibility setting
	if BagFrame.UpdateBorderVisibility then
		BagFrame:UpdateBorderVisibility()
	end

	-- Apply search bar visibility setting
	if BagFrame.UpdateSearchBarVisibility then
		BagFrame:UpdateSearchBarVisibility()
	end

	-- Apply footer visibility setting
	if BagFrame.UpdateFooterVisibility then
		BagFrame:UpdateFooterVisibility()
	end

	-- Apply frame transparency
	if Guda_ApplyBackgroundTransparency then
		Guda_ApplyBackgroundTransparency()
	end

	BagFrame:Update()
end

-- OnHide
function Guda_BagFrame_OnHide(self)
	-- Clean up all buttons when frame is hidden (safe since we're not displaying)
	for _, bagParent in pairs(bagParents) do
		if bagParent then
			local buttons = { bagParent:GetChildren() }
			for _, button in ipairs(buttons) do
				if button.hasItem ~= nil then
					button:Hide()
					button:ClearAllPoints()
				end
			end
		end
	end
end

-- Toggle visibility
function BagFrame:Toggle()
	if Guda_BagFrame:IsShown() then
		Guda_BagFrame:Hide()
	else
		Guda_BagFrame:Show()
	end
end

-- Show specific character's bags
function BagFrame:ShowCharacter(fullName)
	currentViewChar = fullName
	self:Update()
end

-- Show current character
function BagFrame:ShowCurrentCharacter()
	currentViewChar = nil
	self:Update()
end

-- Update lock states of existing buttons (lightweight, used during drag)
function BagFrame:UpdateLockStates()
	for _, bagParent in pairs(bagParents) do
		if bagParent then
			local buttons = { bagParent:GetChildren() }
			for _, button in ipairs(buttons) do
				if button.hasItem ~= nil and button:IsShown() and button.bagID and button.slotID then
					-- Get live lock state
					local _, _, locked = GetContainerItemInfo(button.bagID, button.slotID)
					-- Update desaturation (gray out locked items)
					if not button.otherChar and not button.isReadOnly and SetItemButtonDesaturated then
						SetItemButtonDesaturated(button, locked, 0.5, 0.5, 0.5)
					end
				end
			end
		end
	end
end

-- Update bagline layout (hover option)
function BagFrame:UpdateBaglineLayout()
	local hideFooter = addon.Modules.DB:GetSetting("hideFooter")
	local toolbar = getglobal("Guda_BagFrame_Toolbar")
	if not toolbar then return end

	if hideFooter then
		toolbar:Hide()
		return
	end

	local hoverBagline = addon.Modules.DB:GetSetting("hoverBagline")
	
	local bag0 = getglobal("Guda_BagFrame_Toolbar_BagSlot0")
	local bag1 = getglobal("Guda_BagFrame_Toolbar_BagSlot1")
	local bag2 = getglobal("Guda_BagFrame_Toolbar_BagSlot2")
	local bag3 = getglobal("Guda_BagFrame_Toolbar_BagSlot3")
	local bag4 = getglobal("Guda_BagFrame_Toolbar_BagSlot4")
	local keyring = getglobal("Guda_BagFrame_Toolbar_KeyringButton")
	local info = getglobal("Guda_BagFrame_Toolbar_BagSlotsInfo")

	if hoverBagline then
		-- Hide extra bags by default if not hovering
		if not toolbar.isHovered then
			if bag1 then bag1:Hide() end
			if bag2 then bag2:Hide() end
			if bag3 then bag3:Hide() end
			if bag4 then bag4:Hide() end
		end

		-- Re-anchor Keyring to BagSlot0
		if keyring and bag0 then
			keyring:ClearAllPoints()
			keyring:SetPoint("LEFT", bag0, "RIGHT", 2, 0)
		end

		-- Keep info visible and anchor it to Keyring
		if info then
			info:Show()
			info:ClearAllPoints()
			info:SetPoint("LEFT", keyring, "RIGHT", 8, 0)
		end

		-- If hovered, show and position vertically above Bag0
		if toolbar.isHovered then
			if bag1 then
				bag1:Show()
				bag1:SetFrameLevel(bag0:GetFrameLevel() + 10)
				bag1:ClearAllPoints()
				bag1:SetPoint("BOTTOM", bag0, "TOP", 0, 2)
			end
			if bag2 then
				bag2:Show()
				bag2:SetFrameLevel(bag0:GetFrameLevel() + 10)
				bag2:ClearAllPoints()
				bag2:SetPoint("BOTTOM", bag1, "TOP", 0, 2)
			end
			if bag3 then
				bag3:Show()
				bag3:SetFrameLevel(bag0:GetFrameLevel() + 10)
				bag3:ClearAllPoints()
				bag3:SetPoint("BOTTOM", bag2, "TOP", 0, 2)
			end
			if bag4 then
				bag4:Show()
				bag4:SetFrameLevel(bag0:GetFrameLevel() + 10)
				bag4:ClearAllPoints()
				bag4:SetPoint("BOTTOM", bag3, "TOP", 0, 2)
			end
		end
	else
		-- Restore standard horizontal layout
		if bag1 then
			bag1:Show()
			bag1:ClearAllPoints()
			bag1:SetPoint("LEFT", bag0, "RIGHT", 2, 0)
		end
		if bag2 then
			bag2:Show()
			bag2:ClearAllPoints()
			bag2:SetPoint("LEFT", bag1, "RIGHT", 2, 0)
		end
		if bag3 then
			bag3:Show()
			bag3:ClearAllPoints()
			bag3:SetPoint("LEFT", bag2, "RIGHT", 2, 0)
		end
		if bag4 then
			bag4:Show()
			bag4:ClearAllPoints()
			bag4:SetPoint("LEFT", bag3, "RIGHT", 2, 0)
		end
		if keyring then
			keyring:Show()
			keyring:ClearAllPoints()
			keyring:SetPoint("LEFT", bag4, "RIGHT", 2, 0)
		end
		if info then
			info:Show()
			info:ClearAllPoints()
			info:SetPoint("LEFT", keyring, "RIGHT", 8, 0)
		end
	end
end

-- Update display
function BagFrame:Update()
	if not Guda_BagFrame:IsShown() then
		return
	end

	-- If cursor is holding an item (mid-drag), only update lock states, don't rebuild UI
	if CursorHasItem and CursorHasItem() then
		self:UpdateLockStates()
		return
	end

	-- Mark all existing buttons as not in use (we'll mark active ones during display)
	for _, bagParent in pairs(bagParents) do
		if bagParent then
			local buttons = { bagParent:GetChildren() }
			for _, button in ipairs(buttons) do
				if button.hasItem ~= nil then
					button.inUse = false
				end
			end
		end
	end

	local bagData
	local isOtherChar = false
	local charName = ""

	local titleFont = getglobal("Guda_BagFrame_Title")
	local displayName

	if currentViewChar then
	-- Viewing another character
		bagData = addon.Modules.DB:GetCharacterBags(currentViewChar)
		isOtherChar = true
		charName = currentViewChar

		local dash = string.find(currentViewChar, "-")
		if dash then
			displayName = string.sub(currentViewChar, 1, dash - 1)
		else
			displayName = currentViewChar
		end
	else
	-- Viewing current character
		bagData = addon.Modules.BagScanner:ScanBags()
		displayName = UnitName("player") or "Character"
	end

	if titleFont and displayName then
		titleFont:SetText(string.format("%s's Bags", displayName))
	end

	-- Display items
	local viewType = addon.Modules.DB:GetSetting("bagViewType") or "single"
	
    -- Reset all section headers before displaying items
    local i = 1
    while true do
        local header = getglobal("Guda_BagFrame_SectionHeader" .. i)
        if not header then break end
        header.inUse = false
        header:Hide()
        i = i + 1
    end

	if viewType == "category" then
		self:DisplayItemsByCategory(bagData, isOtherChar, charName)
		if getglobal("Guda_BagFrame_SortButton") then getglobal("Guda_BagFrame_SortButton"):Hide() end
	else
		self:DisplayItems(bagData, isOtherChar, charName)
		if getglobal("Guda_BagFrame_SortButton") then getglobal("Guda_BagFrame_SortButton"):Show() end
	end

	-- Update money
	self:UpdateMoney()

	-- Update bag slots info
	self:UpdateBagSlotsInfo(bagData, isOtherChar)

	-- Update bagline layout (hover option)
	self:UpdateBaglineLayout()

	-- Clean up unused buttons AFTER display is complete (prevents drag/drop issues)
	for _, bagParent in pairs(bagParents) do
		if bagParent then
			local buttons = { bagParent:GetChildren() }
			for _, button in ipairs(buttons) do
				if button.hasItem ~= nil and not button.inUse then
					button:Hide()
					button:ClearAllPoints()
				end
			end
		end
	end
end

-- Helper to get or create section header
function BagFrame:GetSectionHeader(index)
    local name = "Guda_BagFrame_SectionHeader" .. index
    local header = getglobal(name)
    if not header then
        header = CreateFrame("Frame", name, getglobal("Guda_BagFrame_ItemContainer"))
        header:SetHeight(20)
        local text = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", header, "LEFT", 0, 0)
        header.text = text
    end
    header.inUse = true
    return header
end

-- Helper to get or create bag parent frame
function BagFrame:GetBagParent(bagID)
    local itemContainer = getglobal("Guda_BagFrame_ItemContainer")
    if not bagParents[bagID] then
        bagParents[bagID] = CreateFrame("Frame", "Guda_BagFrame_BagParent"..bagID, itemContainer)
        bagParents[bagID]:SetAllPoints(itemContainer)
        if bagParents[bagID].SetID then
            bagParents[bagID]:SetID(bagID)
        end
    end
    return bagParents[bagID]
end

-- Display items by category
function BagFrame:DisplayItemsByCategory(bagData, isOtherChar, charName)
    local buttonSize = addon.Modules.DB:GetSetting("iconSize") or addon.Constants.BUTTON_SIZE
    local spacing = addon.Modules.DB:GetSetting("iconSpacing") or addon.Constants.BUTTON_SPACING
    local perRow = addon.Modules.DB:GetSetting("bagColumns") or 10
    local itemContainer = getglobal("Guda_BagFrame_ItemContainer")

    -- Group items by category
    local categories = {}
    local categoryList = {
        "Weapon", "Armor", "Consumable", "Food", "Drink", "Quest", "Trade Goods", "Reagent", "Recipe", "Quiver", "Container", "Soul Bag", "Keyring", "Miscellaneous"
    }
    for _, cat in ipairs(categoryList) do categories[cat] = {} end
    
    local specialItems = {
        Hearthstone = {},
        Mount = {},
        Tools = {}
    }

    for _, bagID in ipairs(addon.Constants.BAGS) do
        if not hiddenBags[bagID] then
            local bag = bagData[bagID]
            if bag and bag.slots then
                for slotID, itemData in pairs(bag.slots) do
                    if itemData then
                        local cat = "Miscellaneous"
                        local itemName = itemData.name or ""

                        -- Priority 1: Special items (Hearthstone, Mounts, Tools)
                        if string.find(itemName, "Hearthstone") then
                            table.insert(specialItems.Hearthstone, {bagID = bagID, slotID = slotID, itemData = itemData})
                        elseif addon.Modules.SortEngine and addon.Modules.SortEngine.IsMount and addon.Modules.SortEngine.IsMount(itemData.texture) then
                             table.insert(specialItems.Mount, {bagID = bagID, slotID = slotID, itemData = itemData})
                        elseif string.find(itemName, "Runed .* Rod") or
                           string.find(itemName, "Fishing Pole") or
                           string.find(itemName, "Mining Pick") or
                           string.find(itemName, "Blacksmith Hammer") or
                           itemName == "Arclight Spanner" or
                           itemName == "Gyromatic Micro-Adjustor" or
                           itemName == "Philosopher's Stone" or
                           string.find(itemName, "Skinning Knife") or
                           itemName == "Blood Scythe" then
                            table.insert(specialItems.Tools, {bagID = bagID, slotID = slotID, itemData = itemData})
                        
                        -- Priority 2: Quest Items
                        elseif (not isOtherChar and addon.Modules.Utils:IsQuestItemTooltip(bagID, slotID)) or itemData.class == "Quest" then
                            table.insert(categories["Quest"], {bagID = bagID, slotID = slotID, itemData = itemData})
                        
                        -- Priority 3: Food and Drink
                        elseif itemData.class == "Consumable" then
                            cat = "Consumable"
                            local sub = itemData.subclass or ""
                            if sub == "Food & Drink" or string.find(sub, "Food") or string.find(sub, "Drink") then
                                if string.find(sub, "Drink") then
                                    cat = "Drink"
                                else
                                    cat = "Food"
                                end
                            end
                            table.insert(categories[cat], {bagID = bagID, slotID = slotID, itemData = itemData})

                        -- Priority 4: Equipment (Weapon and Armor)
                        elseif itemData.equipSlot and itemData.equipSlot ~= "" then
                            if itemData.class == "Weapon" or itemData.class == "Armor" then
                                cat = itemData.class
                            else
                                cat = "Armor"
                            end
                            table.insert(categories[cat], {bagID = bagID, slotID = slotID, itemData = itemData})
                        
                        -- Priority 5: Other Categories
                        else
                            cat = itemData.class or "Miscellaneous"
                            if not categories[cat] then cat = "Miscellaneous" end
                            table.insert(categories[cat], {bagID = bagID, slotID = slotID, itemData = itemData})
                        end
                    end
                end
            end
        end
    end

    -- Calculate total empty slots and find first available one for drop target
    local totalFreeSlots = 0
    local firstFreeBag, firstFreeSlot
    for _, bagID in ipairs(addon.Constants.BAGS) do
        if not hiddenBags[bagID] then
            local bag = bagData[bagID]
            if bag then
                totalFreeSlots = totalFreeSlots + (bag.freeSlots or 0)
                if not firstFreeBag and (bag.freeSlots or 0) > 0 then
                    for s = 1, (bag.numSlots or 0) do
                        if not bag.slots or not bag.slots[s] then
                            firstFreeBag = bagID
                            firstFreeSlot = s
                            break
                        end
                    end
                end
            end
        end
    end

    -- Handle Keyring if visible
    if showKeyring and not hiddenBags[-2] then
        local bag = bagData[-2]
        if bag and bag.slots then
            for slotID, itemData in pairs(bag.slots) do
                if itemData then
                    table.insert(categories["Keyring"], {bagID = -2, slotID = slotID, itemData = itemData})
                end
            end
        end
    end

    -- Layout
    local startX, startY = 10, -10
    local currentX, currentY = 0, 0
    local rowMaxHeight = 0
    local headerIdx = 1
    local totalWidth = perRow * (buttonSize + spacing)

    for _, catName in ipairs(categoryList) do
        local items = categories[catName]
        local numItems = items and table.getn(items) or 0
        if numItems > 0 then
            -- Sort items in category: Subclass > Quality > Name
            table.sort(items, function(a, b)
                if a.itemData.subclass ~= b.itemData.subclass then
                    return (a.itemData.subclass or "") < (b.itemData.subclass or "")
                end
                if a.itemData.quality ~= b.itemData.quality then
                    return a.itemData.quality > b.itemData.quality
                end
                return (a.itemData.name or "") < (b.itemData.name or "")
            end)

            local blockCols = numItems
            if blockCols > perRow then blockCols = perRow end
            local blockRows = math.ceil(numItems / perRow)
            local blockWidth = blockCols * (buttonSize + spacing)
            local blockHeight = 20 + (blockRows * (buttonSize + spacing)) + 5 -- 20 header, 5 padding

            -- Check if it fits in current row
            if currentX > 0 and currentX + blockWidth + 20 > totalWidth + 5 then
                currentX = 0
                currentY = currentY + rowMaxHeight
                rowMaxHeight = 0
            end

            -- Add Header
            local header = self:GetSectionHeader(headerIdx)
            headerIdx = headerIdx + 1
            header:SetPoint("TOPLEFT", itemContainer, "TOPLEFT", startX + currentX, startY - currentY)
            header:SetWidth(blockWidth)
            header.text:SetText(catName)
            header:Show()
            
            local itemY = currentY + 20
            local col = 0
            local row = 0
            for _, item in ipairs(items) do
                local bagID = item.bagID
                local slot = item.slotID
                local itemData = item.itemData
                
                local bagParent = self:GetBagParent(bagID)
                local button = Guda_GetItemButton(bagParent)
                
                button:SetParent(bagParent)
                button:SetWidth(buttonSize)
                button:SetHeight(buttonSize)
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT", itemContainer, "TOPLEFT", startX + currentX + (col * (buttonSize + spacing)), startY - (itemY + (row * (buttonSize + spacing))))
                button:Show()
                
                local matchesFilter = self:PassesSearchFilter(itemData)
                Guda_ItemButton_SetItem(button, bagID, slot, itemData, false, isOtherChar and charName or nil, matchesFilter, isOtherChar)
                button.inUse = true
                
                col = col + 1
                if col >= blockCols then
                    col = 0
                    row = row + 1
                end
            end
            
            if blockHeight > rowMaxHeight then rowMaxHeight = blockHeight end
            currentX = currentX + blockWidth + 20 -- 20px gap between categories
        end
    end

    -- Update Y for bottom sections
    local y = currentY + rowMaxHeight
    
    -- Special sections at bottom (Hearthstone, Mount, Tools, Empty)
    local bottomSections = {
        { name = "Home", items = specialItems.Hearthstone },
        { name = "Mounts", items = specialItems.Mount },
        { name = "Tools", items = specialItems.Tools },
        { name = "Empty", items = {} }
    }
    
    local x = startX
    y = startY - y -- convert to coordinate relative to TOPLEFT
    
    -- Add spacing before special section
    local hasAnyBottom = false
    for _, sec in ipairs(bottomSections) do
        if table.getn(sec.items) > 0 then
            hasAnyBottom = true
            break
        end
    end

    if hasAnyBottom then
        y = y - 10
        local currentBottomX = 0
        local sectionMaxHeight = 0

        for _, sec in ipairs(bottomSections) do
            local items = sec.items
            local numItems = table.getn(items)
            if sec.name == "Empty" then
                numItems = (totalFreeSlots > 0) and 1 or 0
            end
            if numItems > 0 then
                -- Sort Tools (Hearthstone/Mounts don't usually need it but good for consistency)
                if sec.name == "Tools" then
                    table.sort(items, function(a, b)
                        if a.itemData.quality ~= b.itemData.quality then
                            return a.itemData.quality > b.itemData.quality
                        end
                        return (a.itemData.name or "") < (b.itemData.name or "")
                    end)
                end

                local blockCols = numItems
                if blockCols > perRow then blockCols = perRow end
                local blockRows = math.ceil(numItems / perRow)
                local blockWidth = blockCols * (buttonSize + spacing)
                local blockHeight = 20 + (blockRows * (buttonSize + spacing))

                -- Check if it fits in current row (Inline block for bottom sections too)
                if currentBottomX > 0 and currentBottomX + blockWidth + 20 > totalWidth + 5 then
                    currentBottomX = 0
                    y = y - sectionMaxHeight - 5
                    sectionMaxHeight = 0
                end

                -- Add Header
                local header = self:GetSectionHeader(headerIdx)
                headerIdx = headerIdx + 1
                header:SetPoint("TOPLEFT", itemContainer, "TOPLEFT", x + currentBottomX, y)
                header:SetWidth(blockWidth)
                header.text:SetText(sec.name)
                header:Show()

                local itemY = y - 20
                local sCol = 0
                local sRow = 0
                
                if sec.name == "Empty" then
                    -- Display one empty slot button with count
                    local bagID = firstFreeBag or 0
                    local slotID = firstFreeSlot or 1
                    local bagParent = self:GetBagParent(bagID)
                    local button = Guda_GetItemButton(bagParent)
                    button:SetParent(bagParent)
                    button:SetWidth(buttonSize)
                    button:SetHeight(buttonSize)
                    button:ClearAllPoints()
                    button:SetPoint("TOPLEFT", itemContainer, "TOPLEFT", x + currentBottomX, itemY)
                    button:Show()
                    
                    local emptyItemData = { 
                        texture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag", 
                        count = totalFreeSlots, 
                        name = "Empty Slots" 
                    }
                    -- Use fake data but real IDs for drop handling
                    Guda_ItemButton_SetItem(button, bagID, slotID, emptyItemData, false, isOtherChar and charName or nil, true, true)
                    -- Ensure it's not actually read-only for drop behavior (it should still receive clicks/drops)
                    button.isReadOnly = false
                    button.inUse = true
                else
                    for _, item in ipairs(items) do
                        local bagParent = self:GetBagParent(item.bagID)
                        local button = Guda_GetItemButton(bagParent)
                        button:SetParent(bagParent)
                        button:SetWidth(buttonSize)
                        button:SetHeight(buttonSize)
                        button:ClearAllPoints()
                        button:SetPoint("TOPLEFT", itemContainer, "TOPLEFT", x + currentBottomX + (sCol * (buttonSize + spacing)), itemY - (sRow * (buttonSize + spacing)))
                        button:Show()
                        Guda_ItemButton_SetItem(button, item.bagID, item.slotID, item.itemData, false, isOtherChar and charName or nil, self:PassesSearchFilter(item.itemData), isOtherChar)
                        button.inUse = true
                        
                        sCol = sCol + 1
                        if sCol >= blockCols then
                            sCol = 0
                            sRow = sRow + 1
                        end
                    end
                end

                if blockHeight > sectionMaxHeight then sectionMaxHeight = blockHeight end
                currentBottomX = currentBottomX + blockWidth + 20 -- Match the 20px gap used in top categories
                
                -- If we wrapped exactly at the end of a block
                if currentBottomX >= totalWidth then
                    currentBottomX = 0
                    y = y - sectionMaxHeight - 5
                    sectionMaxHeight = 0
                end
            end
        end
        
        if currentBottomX > 0 then
            y = y - sectionMaxHeight
        end
    end

    -- Update container height
    local finalHeight = math.abs(y) + 20
    itemContainer:SetHeight(finalHeight)
    self:ResizeFrame(nil, nil, perRow, finalHeight)
end

-- Display items
function BagFrame:DisplayItems(bagData, isOtherChar, charName)
	local x, y = 10, -10
	local row = 0
	local col = 0
	local buttonSize = addon.Modules.DB:GetSetting("iconSize") or addon.Constants.BUTTON_SIZE
	local spacing = addon.Modules.DB:GetSetting("iconSpacing") or addon.Constants.BUTTON_SPACING
	local perRow = addon.Modules.DB:GetSetting("bagColumns") or 10
	local itemContainer = getglobal("Guda_BagFrame_ItemContainer")

 -- Separate bags into regular, enchant, herb, soul, quiver, and ammo types
 local regularBags = {}
 local enchantBags = {}
 local herbBags = {}
 local soulBags = {}
 local quiverBags = {}
 local ammoBags = {}

	for _, bagID in ipairs(addon.Constants.BAGS) do
	-- Skip hidden bags
		if not hiddenBags[bagID] then
            local bagType
            if isOtherChar then
                -- For other characters, use saved bag type
                local bag = bagData[bagID]
                bagType = bag and bag.bagType or "regular"
            else
                -- For current character, detect bag type in real-time using unified detector
                bagType = addon.Modules.Utils:GetSpecializedBagType(bagID) or "regular"
            end

            if bagType == "enchant" then
                table.insert(enchantBags, bagID)
            elseif bagType == "herb" then
                table.insert(herbBags, bagID)
            elseif bagType == "soul" then
                table.insert(soulBags, bagID)
            elseif bagType == "quiver" then
                table.insert(quiverBags, bagID)
            elseif bagType == "ammo" then
                table.insert(ammoBags, bagID)
            else
                table.insert(regularBags, bagID)
            end
        end
    end

    -- Build display order: regular -> enchant -> herb -> soul -> quiver -> ammo -> keyring
    local bagsToShow = {}
    for _, bagID in ipairs(regularBags) do
        table.insert(bagsToShow, {bagID = bagID, needsSpacing = false})
    end

    -- Enchant
    if table.getn(enchantBags) > 0 then
        for i, bagID in ipairs(enchantBags) do
            table.insert(bagsToShow, {bagID = bagID, needsSpacing = (i == 1)})
        end
    end
    -- Herb
    if table.getn(herbBags) > 0 then
        for i, bagID in ipairs(herbBags) do
            table.insert(bagsToShow, {bagID = bagID, needsSpacing = (i == 1)})
        end
    end
    -- Soul
    if table.getn(soulBags) > 0 then
        for i, bagID in ipairs(soulBags) do
            table.insert(bagsToShow, {bagID = bagID, needsSpacing = (i == 1)})
        end
    end
    -- Quiver
    if table.getn(quiverBags) > 0 then
        for i, bagID in ipairs(quiverBags) do
            table.insert(bagsToShow, {bagID = bagID, needsSpacing = (i == 1)})
        end
    end
    -- Ammo
    if table.getn(ammoBags) > 0 then
        for i, bagID in ipairs(ammoBags) do
            table.insert(bagsToShow, {bagID = bagID, needsSpacing = (i == 1)})
        end
    end

	-- Add keyring at the end if toggled on and not hidden
	if showKeyring and not hiddenBags[-2] then
		table.insert(bagsToShow, {bagID = -2, needsSpacing = true})
	end

	for _, bagInfo in ipairs(bagsToShow) do
		local bagID = bagInfo.bagID
		local bag = bagData[bagID]

  -- Add spacing before enchant, herb, soul, quiver, ammo, or keyring sections
  if bagInfo.needsSpacing then
			if col > 0 then
			-- Move to next row if not at start of row
				col = 0
				row = row + 1
			end
			-- Add extra spacing (0.5 row for tighter spacing)
			row = row + 0.5
		end

		-- Get slot count for this bag
		local numSlots
		if isOtherChar and bag and bag.numSlots then
		-- Use stored slot count for other characters
			numSlots = bag.numSlots
		else
		-- Use current character's bag slot count
			numSlots = addon.Modules.Utils:GetBagSlotCount(bagID)
		end

		-- Only show bags that have slots
		if numSlots and numSlots > 0 then
		-- Iterate through ALL slots (1 to numSlots) to show empty slots too
		-- Ensure a per-bag parent frame exists and carries the bag ID (Blizzard expects parent:GetID() == bagID)
			local bagParent = self:GetBagParent(bagID)

			for slot = 1, numSlots do
				local itemData = bag and bag.slots and bag.slots[slot] or nil

				-- Check if item matches search filter
				local matchesFilter = self:PassesSearchFilter(itemData)

				local button = Guda_GetItemButton(bagParent)
				button.inUse = true  -- Mark this button as actively in use

				-- Position button
				local xPos = x + (col * (buttonSize + spacing))
				local yPos = y - (row * (buttonSize + spacing))

				button:ClearAllPoints()
				button:SetPoint("TOPLEFT", itemContainer, "TOPLEFT", xPos, yPos)

				-- Set item data with filter match info
				-- isReadOnly = true when viewing other characters (can't interact with their items)
				Guda_ItemButton_SetItem(button, bagID, slot, itemData, false, isOtherChar and charName or nil, matchesFilter, isOtherChar)

				table.insert(itemButtons, button)

				-- Advance position
				col = col + 1
				if col >= perRow then
					col = 0
					row = row + 1
				end
			end
		end
	end

    -- Resize frame dynamically based on content
    self:ResizeFrame(row, col, perRow)
    
    -- Ensure cooldown visuals are current after (re)building buttons
    if self.RefreshCooldowns then
        self:RefreshCooldowns()
    end
end

-- Resize frame based on number of rows and columns
function BagFrame:ResizeFrame(currentRow, currentCol, columns, overrideHeight)
	local buttonSize = addon.Modules.DB:GetSetting("iconSize") or addon.Constants.BUTTON_SIZE
	local spacing = addon.Modules.DB:GetSetting("iconSpacing") or addon.Constants.BUTTON_SPACING

	-- Calculate actual number of rows used
	local totalRows = (currentRow or 0) + 1

	-- Ensure at least 1 row
	if totalRows < 1 then
		totalRows = 1
	end

	-- Calculate required dimensions based on columns
	local containerWidth = (columns * (buttonSize + spacing)) + 20
	local containerHeight = overrideHeight or ((totalRows * (buttonSize + spacing)) + 20)
	local frameWidth = containerWidth + 20

	-- Check if search bar is visible
	local showSearchBar = addon.Modules.DB:GetSetting("showSearchBar")
	if showSearchBar == nil then
		showSearchBar = true
	end

	-- Adjust frame height based on search bar visibility
	-- Footer height varies: more space needed when search bar is visible
	local titleHeight = 40
	local searchBarHeight = 30
	local footerHeight
	local frameHeight

	local hideFooter = addon.Modules.DB:GetSetting("hideFooter")

	if hideFooter then
		footerHeight = 10 -- Small padding at bottom
		frameHeight = containerHeight + titleHeight + (showSearchBar and searchBarHeight or 0) + footerHeight
	elseif showSearchBar then
		footerHeight = 55  -- Increased footer height when search bar is visible (toolbar 40px + spacing 15px)
		frameHeight = containerHeight + titleHeight + searchBarHeight + footerHeight  -- 125 total
	else
		footerHeight = 45  -- Normal footer height (toolbar 40px + spacing 5px)
		frameHeight = containerHeight + titleHeight + footerHeight  -- 85 total
	end

	-- Minimum sizes
	if containerWidth < 200 then
		containerWidth = 200
		frameWidth = 220
	end
	if containerHeight < 150 then
		containerHeight = 150
	end
	if frameHeight < 250 then
		frameHeight = 250
	end

	-- Maximum sizes
	if containerWidth > 1250 then
		containerWidth = 1250
		frameWidth = 1270
	end
	if containerHeight > 1000 then
		containerHeight = 1000
	end
	if frameHeight > 1200 then
		frameHeight = 1200
	end

	-- Resize frames
	local bagFrame = getglobal("Guda_BagFrame")
	local itemContainer = getglobal("Guda_BagFrame_ItemContainer")

	if bagFrame then
		bagFrame:SetWidth(frameWidth)
		bagFrame:SetHeight(frameHeight)

		-- Always use BOTTOMRIGHT anchor to make frame grow left
		bagFrame:ClearAllPoints()

		if addon and addon.Modules and addon.Modules.DB then
			local pos = addon.Modules.DB:GetSetting("bagFramePosition")
			-- Only use saved position if it was saved as BOTTOMRIGHT
			if pos and pos.point == "BOTTOMRIGHT" and pos.x and pos.y then
				bagFrame:SetPoint("BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", pos.x, pos.y)
			else
			-- Default position: bottom right corner
				bagFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -50, 100)
			end
		else
		-- Fallback to default if DB not available
			bagFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -50, 100)
		end
	end

	if itemContainer then
		itemContainer:SetWidth(containerWidth)
		itemContainer:SetHeight(containerHeight)
	end

	-- Resize search bar and toolbar to match container width
	local searchBar = getglobal("Guda_BagFrame_SearchBar")
	if searchBar then
		searchBar:SetWidth(containerWidth)
	end

	local toolbar = getglobal("Guda_BagFrame_Toolbar")
	if toolbar then
		toolbar:SetWidth(containerWidth)
	end
end

-- Check if search is currently active
function BagFrame:IsSearchActive()
	return searchText and searchText ~= "" and searchText ~= "Search, try ~equipment"
end

-- Check if item passes search filter (pfUI style)
function BagFrame:PassesSearchFilter(itemData)
-- If no search text, everything matches
	if not self:IsSearchActive() then
		return true
	end

	-- Empty slots don't match when searching (pfUI style - they get dimmed)
	if not itemData then
		return false
	end

	-- Get item name from itemData.name or parse from link
	local itemName = itemData.name
	if not itemName and itemData.link then
	-- Parse name from item link: |cffffffff|Hitem:...|h[Item Name]|h|r
		local _, _, name = string.find(itemData.link, "%[(.+)%]")
		itemName = name
		if not self.warnedAboutParsing then
			addon:Print("DEBUG: Had to parse item name from link: " .. (itemName or "FAILED"))
			self.warnedAboutParsing = true
		end
	end

	if not itemName then
		if not self.warnedAboutNoName then
			addon:Print("DEBUG: Item has no name and no link! texture = " .. tostring(itemData.texture))
			self.warnedAboutNoName = true
		end
		return false
	end

	-- Case-insensitive search in item name
	local search = string.lower(searchText)

	-- Advanced search (pfUI style categories)
	if string.sub(search, 1, 1) == "~" then
		local category = string.sub(search, 2)
		local itemType = itemData.type or ""
		local itemQuality = itemData.quality or -1

		if category == "equipment" or category == "armor" or category == "weapon" then
			if itemType == "Armor" or itemType == "Weapon" then return true end
		elseif category == "consumable" then
			if itemType == "Consumable" then return true end
		elseif category == "tradegoods" or category == "trades" then
			if itemType == "Trade Goods" then return true end
		elseif category == "quest" then
			local isQuest, isQuestStarter = Guda_GetQuestInfo(itemData.bagID, itemData.slotID, itemData.isBank)
			if isQuest or isQuestStarter or itemType == "Quest" then return true end
		elseif category == "reagent" then
			if itemType == "Reagent" then return true end
		elseif category == "common" then if itemQuality == 1 then return true end
		elseif category == "uncommon" then if itemQuality == 2 then return true end
		elseif category == "rare" then if itemQuality == 3 then return true end
		elseif category == "epic" then if itemQuality == 4 then return true end
		elseif category == "legendary" then if itemQuality == 5 then return true end
		end
	end

	itemName = string.lower(itemName)
	-- Check if item name contains search text
	local matches = string.find(itemName, search, 1, true) ~= nil

	-- Debug: print first match found
	if matches and not self.foundFirstMatch then
		self.foundFirstMatch = true
	end

	return matches
end

function BagFrame:UpdateMoney()
	local hideFooter = addon.Modules.DB:GetSetting("hideFooter")
	local moneyFrame = getglobal("Guda_BagFrame_MoneyFrame")

	if hideFooter then
		if moneyFrame then moneyFrame:Hide() end
		return
	end

	if not moneyFrame then
		addon:Debug("Guda_BagFrame exists: " .. tostring(getglobal("Guda_BagFrame") ~= nil))

		-- Try to create it manually
		self:CreateMoneyFrame()
		moneyFrame = getglobal("Guda_BagFrame_MoneyFrame")
	end

	if moneyFrame then
		MoneyFrame_Update("Guda_BagFrame_MoneyFrame", GetMoney())
		moneyFrame:Show()

		-- Ensure tooltip overlay exists
		self:EnsureMoneyTooltipOverlay()

		-- Also add tooltip to toolbar empty space
		self:SetupToolbarTooltip()
	else
		addon:Debug("Still couldn't find or create MoneyFrame!")
	end
end

-- Update bag slots info text (excluding keyring)
function BagFrame:UpdateBagSlotsInfo(bagData, isOtherChar)
	local infoText = getglobal("Guda_BagFrame_Toolbar_BagSlotsInfo_Text")
	if not infoText then return end

	local totalSlots = 0
	local usedSlots = 0

	-- Count slots in regular bags only (0-4), exclude keyring (-2)
	for _, bagID in ipairs(addon.Constants.BAGS) do
		local bag = bagData[bagID]

		-- Get slot count for this bag
		local numSlots
		if isOtherChar and bag and bag.numSlots then
			numSlots = bag.numSlots
		else
			numSlots = addon.Modules.Utils:GetBagSlotCount(bagID)
		end

		if numSlots and numSlots > 0 then
			totalSlots = totalSlots + numSlots

			-- Count used slots
			if bag and bag.slots then
				for slot = 1, numSlots do
					if bag.slots[slot] then
						usedSlots = usedSlots + 1
					end
				end
			end
		end
	end

	-- Format: "24 / 80" (used / total)
	infoText:SetText(string.format("%d / %d", usedSlots, totalSlots))
	infoText:SetTextColor(0.7, 0.7, 0.7)
end

function BagFrame:CreateMoneyFrame()
	local moneyFrame = CreateFrame("Frame", "Guda_BagFrame_MoneyFrame", Guda_BagFrame, "SmallMoneyFrameTemplate")
	moneyFrame:SetPoint("BOTTOMRIGHT", Guda_BagFrame, "BOTTOMRIGHT", -15, 10)
	moneyFrame:SetWidth(180)
	moneyFrame:SetHeight(35)
	addon:Debug("MoneyFrame created via CreateMoneyFrame")
end

-- Setup tooltip on toolbar empty space
function BagFrame:SetupToolbarTooltip()
	local toolbar = getglobal("Guda_BagFrame_Toolbar")
	if not toolbar then return end

	-- Only set up once
	if toolbar.tooltipSetup then return end

	-- Get the existing OnEnter script (if any)
	local originalOnEnter = toolbar:GetScript("OnEnter")

	-- Set new OnEnter that shows money tooltip
	toolbar:SetScript("OnEnter", function()
	-- Call original if it exists
		if originalOnEnter then
			originalOnEnter()
		end

		-- Show money tooltip
		addon:Debug("Toolbar OnEnter - showing money tooltip")
		Guda_BagFrame_MoneyOnEnter(getglobal("Guda_BagFrame_MoneyFrame"))
	end)

	-- Set OnLeave to hide tooltip
	toolbar:SetScript("OnLeave", function()
		addon:Debug("Toolbar OnLeave - hiding tooltip")
		GameTooltip:Hide()
	end)

	toolbar.tooltipSetup = true
	addon:Debug("Toolbar tooltip handlers set up")
end

-- Save bag frame position (always as BOTTOMRIGHT)
local function SaveBagFramePosition()
	local frame = getglobal("Guda_BagFrame")
	if not frame or not addon or not addon.Modules or not addon.Modules.DB then return end

	-- Always save as BOTTOMRIGHT coordinates
	local right = frame:GetRight()
	local bottom = frame:GetBottom()
	local screenWidth = GetScreenWidth()

	if right and bottom and screenWidth then
		local xOffset = right - screenWidth
		local yOffset = bottom

		addon.Modules.DB:SetSetting("bagFramePosition", {
			point = "BOTTOMRIGHT",
			x = xOffset,
			y = yOffset
		})
	end
end

-- Create transparent overlay for money tooltip
function BagFrame:EnsureMoneyTooltipOverlay()
	local overlayName = "Guda_BagFrame_MoneyTooltipOverlay"
	local overlay = getglobal(overlayName)

	if not overlay then
		local moneyFrame = getglobal("Guda_BagFrame_MoneyFrame")
		if not moneyFrame then return end

		-- Create transparent overlay frame
		overlay = CreateFrame("Frame", overlayName, moneyFrame)
		overlay:SetAllPoints(moneyFrame)
		overlay:SetFrameLevel(moneyFrame:GetFrameLevel() + 1)
		overlay:EnableMouse(true)

		-- Set tooltip handlers on overlay
		overlay:SetScript("OnEnter", function()
			addon:Debug("Money overlay OnEnter triggered")
			Guda_BagFrame_MoneyOnEnter(moneyFrame)
		end)

		overlay:SetScript("OnLeave", function()
			addon:Debug("Money overlay OnLeave triggered")
			GameTooltip:Hide()
		end)

		-- Forward drag events to bag frame (if not locked)
		overlay:SetScript("OnMouseDown", function()
			local searchBox = getglobal("Guda_BagFrame_SearchBar_SearchBox")
			if searchBox then
				searchBox:ClearFocus()
			end

			local bagFrame = getglobal("Guda_BagFrame")
			local isLocked = addon.Modules.DB and addon.Modules.DB:GetSetting("lockBags")

			if bagFrame and not isLocked and arg1 == "LeftButton" then
				bagFrame:StartMoving()
			end
		end)

		overlay:SetScript("OnMouseUp", function()
			local bagFrame = getglobal("Guda_BagFrame")
			local isLocked = addon.Modules.DB and addon.Modules.DB:GetSetting("lockBags")

			if bagFrame and not isLocked then
				bagFrame:StopMovingOrSizing()
				SaveBagFramePosition()
			end
		end)

		addon:Debug("Money tooltip overlay created")
	end

	overlay:Show()
end

-- Money frame OnLoad handler
function Guda_BagFrame_MoneyFrame_OnLoad(self)
	addon:Debug("MoneyFrame OnLoad called for: " .. self:GetName())

	-- Set tooltip handlers on all money denomination buttons
	local buttons = {"GoldButton", "SilverButton", "CopperButton"}

	for _, buttonName in ipairs(buttons) do
		local fullName = self:GetName() .. buttonName
		local button = getglobal(fullName)
		addon:Debug("Looking for button: " .. fullName .. " - Found: " .. tostring(button ~= nil))
		if button then
			button:SetScript("OnEnter", function()
				addon:Debug("Money button OnEnter triggered")
				Guda_BagFrame_MoneyOnEnter(this:GetParent())
			end)
			button:SetScript("OnLeave", function()
				GameTooltip:Hide()
			end)
		end
	end

	-- Also try setting handlers directly on the parent frame
	addon:Debug("Setting handlers on parent frame as fallback")
	self:EnableMouse(true)
	self:SetScript("OnEnter", function()
		addon:Debug("Parent frame OnEnter triggered")
		Guda_BagFrame_MoneyOnEnter(this)
	end)
	self:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end

-- Money tooltip handler
function Guda_BagFrame_MoneyOnEnter(self)
	if not self then return end

	-- Anchor tooltip to TOPRIGHT - aligns tooltip's right edge with money container's right edge
	GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT", 0, 0)
	GameTooltip:ClearLines()

	-- Get all characters and total (realm filtered, all factions)
	local chars = addon.Modules.DB:GetAllCharacters(false, true)
	local totalMoney = addon.Modules.DB:GetTotalMoney(false, true)

	-- Header with current realm total - use colored money
	GameTooltip:AddLine(
		"Current realm gold: " .. addon.Modules.Utils:FormatMoney(totalMoney, false, true),
		1, 0.82, 0
	)
	GameTooltip:AddLine(" ")

	-- List each character with class-colored names
	for _, char in ipairs(chars) do
	-- Get class color from WoW's built-in table using English class token
		local classToken = char.classToken
		local classColor = classToken and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[classToken]
		local colorR, colorG, colorB = 0.7, 0.7, 0.7

		if classColor then
			colorR, colorG, colorB = classColor.r, classColor.g, classColor.b
		end

		-- Create colored name
		local coloredName = addon.Modules.Utils:ColorText(char.name, colorR, colorG, colorB)

		GameTooltip:AddLine(
			coloredName .. ": " .. addon.Modules.Utils:FormatMoney(char.money or 0, false, true)
		)
	end

	GameTooltip:Show()
end

-- Dropdown management
local characterDropdown = nil
local bankDropdown = nil

-- Toggle character dropdown
function Guda_BagFrame_ToggleCharacterDropdown(button)
-- Hide bank dropdown if it's shown
	if bankDropdown and bankDropdown:IsShown() then
		bankDropdown:Hide()
	end

	if characterDropdown and characterDropdown:IsShown() then
		characterDropdown:Hide()
		return
	end

	if not characterDropdown then
	-- Create dropdown frame
		characterDropdown = CreateFrame("Frame", "Guda_CharacterDropdown", UIParent)
		characterDropdown:SetFrameStrata("DIALOG")
		characterDropdown:SetWidth(200)
		characterDropdown:SetBackdrop({
			bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true,
			tileSize = 16,
			edgeSize = 16,
			insets = { left = 4, right = 4, top = 4, bottom = 4 }
		})
		characterDropdown:SetBackdropColor(0, 0, 0, 0.95)
		characterDropdown:EnableMouse(true)
		characterDropdown:Hide()

		characterDropdown.buttons = {}
	end

	-- Position dropdown below the button
	characterDropdown:ClearAllPoints()
	characterDropdown:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)

	-- Clear existing buttons
	for _, btn in ipairs(characterDropdown.buttons) do
		btn:Hide()
	end
	characterDropdown.buttons = {}

	-- Get all characters on current realm
	local chars = addon.Modules.DB:GetAllCharacters(false, true)

	-- Add "Current Character" option at the top
	local yOffset = -8
	local currentCharButton = CreateFrame("Button", nil, characterDropdown)
	currentCharButton:SetWidth(188)
	currentCharButton:SetHeight(20)
	currentCharButton:SetPoint("TOP", characterDropdown, "TOP", 0, yOffset)

	-- Button background on hover
	local currentCharBg = currentCharButton:CreateTexture(nil, "BACKGROUND")
	currentCharBg:SetAllPoints()
	currentCharBg:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
	currentCharBg:SetBlendMode("ADD")
	currentCharBg:SetAlpha(0)

	-- Button text
	local currentCharText = currentCharButton:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	currentCharText:SetPoint("LEFT", currentCharButton, "LEFT", 8, 0)
	currentCharText:SetText("Characters")

	-- Button scripts
	currentCharButton:SetScript("OnEnter", function()
		currentCharBg:SetAlpha(0.3)
	end)
	currentCharButton:SetScript("OnLeave", function()
		currentCharBg:SetAlpha(0)
	end)
	currentCharButton:SetScript("OnClick", function()
		addon.Modules.BagFrame:ShowCurrentCharacter()
		characterDropdown:Hide()
	end)

	table.insert(characterDropdown.buttons, currentCharButton)
	yOffset = yOffset - 20

	-- Add separator
	local separator = characterDropdown:CreateTexture(nil, "ARTWORK")
	separator:SetHeight(1)
	separator:SetWidth(180)
	separator:SetPoint("TOP", characterDropdown, "TOP", 0, yOffset)
	separator:SetTexture(1, 1, 1, 0.2)
	yOffset = yOffset - 4

	-- Get current player's full name for comparison
	local currentPlayerFullName = addon.Modules.DB:GetPlayerFullName()

	-- Add character buttons
	for _, char in ipairs(chars) do
	-- Capture variables in local scope for closure
		local charFullName = char.fullName
		local charName = char.name
		local charMoney = char.money or 0
		local charClassToken = char.classToken
		local isCurrentChar = (charFullName == currentPlayerFullName)

		local charButton = CreateFrame("Button", nil, characterDropdown)
		charButton:SetWidth(188)
		charButton:SetHeight(20)
		charButton:SetPoint("TOP", characterDropdown, "TOP", 0, yOffset)

		-- Button background on hover
		local charBg = charButton:CreateTexture(nil, "BACKGROUND")
		charBg:SetAllPoints()
		charBg:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
		charBg:SetBlendMode("ADD")
		charBg:SetAlpha(0)

		-- Get class color
		local classColor = charClassToken and RAID_CLASS_COLORS[charClassToken]
		local r, g, b = 1, 1, 1
		if classColor then
			r, g, b = classColor.r, classColor.g, classColor.b
		end

		-- Button text
		local charText = charButton:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		charText:SetPoint("LEFT", charButton, "LEFT", 8, 0)
		charText:SetText(charName)
		charText:SetTextColor(r, g, b)

		-- Money text
		local moneyText = charButton:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		moneyText:SetPoint("RIGHT", charButton, "RIGHT", -8, 0)
		moneyText:SetText(addon.Modules.Utils:FormatMoney(charMoney))
		moneyText:SetTextColor(0.7, 0.7, 0.7)

		-- Button scripts
		charButton:SetScript("OnEnter", function()
			charBg:SetAlpha(0.3)
		end)
		charButton:SetScript("OnLeave", function()
			charBg:SetAlpha(0)
		end)
		charButton:SetScript("OnClick", function()
			if charFullName then
				if isCurrentChar then
				-- Clicking current character - show current live view
					addon.Modules.BagFrame:ShowCurrentCharacter()
				else
				-- Clicking different character - show their stored bags
					addon.Modules.BagFrame:ShowCharacter(charFullName)
				end
				characterDropdown:Hide()
			else
				addon:Print("Error: Character fullName is nil")
			end
		end)

		table.insert(characterDropdown.buttons, charButton)
		yOffset = yOffset - 20
	end

	-- Set dropdown height based on content
	characterDropdown:SetHeight(math.abs(yOffset) + 8)

	-- Show dropdown
	characterDropdown:Show()
end

-- Hide dropdown when clicking elsewhere
local function HideCharacterDropdown()
	if characterDropdown then
		characterDropdown:Hide()
	end
end

-- Toggle bank dropdown
function Guda_BagFrame_ToggleBankDropdown(button)
-- Hide character dropdown if it's shown
	if characterDropdown and characterDropdown:IsShown() then
		characterDropdown:Hide()
	end

	if bankDropdown and bankDropdown:IsShown() then
		bankDropdown:Hide()
		return
	end

	if not bankDropdown then
	-- Create dropdown frame
		bankDropdown = CreateFrame("Frame", "Guda_BankDropdown", UIParent)
		bankDropdown:SetFrameStrata("DIALOG")
		bankDropdown:SetWidth(200)
		bankDropdown:SetBackdrop({
			bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true,
			tileSize = 16,
			edgeSize = 16,
			insets = { left = 4, right = 4, top = 4, bottom = 4 }
		})
		bankDropdown:SetBackdropColor(0, 0, 0, 0.95)
		bankDropdown:EnableMouse(true)
		bankDropdown:Hide()

		bankDropdown.buttons = {}
	end

	-- Position dropdown below the button
	bankDropdown:ClearAllPoints()
	bankDropdown:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
	-- Clear existing buttons
	for _, btn in ipairs(bankDropdown.buttons) do
		btn:Hide()
	end
	bankDropdown.buttons = {}

	-- Get all characters on current realm
	local chars = addon.Modules.DB:GetAllCharacters(false, true)

	local yOffset = -8

	-- Add character buttons
	for _, char in ipairs(chars) do
	-- Capture variables in local scope for closure
		local charFullName = char.fullName
		local charName = char.name
		local charMoney = char.money or 0
		local charClassToken = char.classToken

		local charButton = CreateFrame("Button", nil, bankDropdown)
		charButton:SetWidth(188)
		charButton:SetHeight(20)
		charButton:SetPoint("TOP", bankDropdown, "TOP", 0, yOffset)

		-- Button background on hover
		local charBg = charButton:CreateTexture(nil, "BACKGROUND")
		charBg:SetAllPoints()
		charBg:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
		charBg:SetBlendMode("ADD")
		charBg:SetAlpha(0)

		-- Get class color
		local classColor = charClassToken and RAID_CLASS_COLORS[charClassToken]
		local r, g, b = 1, 1, 1
		if classColor then
			r, g, b = classColor.r, classColor.g, classColor.b
		end

		-- Button text
		local charText = charButton:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		charText:SetPoint("LEFT", charButton, "LEFT", 8, 0)
		charText:SetText(charName)
		charText:SetTextColor(r, g, b)

		-- Money text
		local moneyText = charButton:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		moneyText:SetPoint("RIGHT", charButton, "RIGHT", -8, 0)
		moneyText:SetText(addon.Modules.Utils:FormatMoney(charMoney))
		moneyText:SetTextColor(0.7, 0.7, 0.7)

		-- Button scripts
		charButton:SetScript("OnEnter", function()
			charBg:SetAlpha(0.3)
		end)
		charButton:SetScript("OnLeave", function()
			charBg:SetAlpha(0)
		end)
		charButton:SetScript("OnClick", function()
			if charFullName then
			-- Show bank for this character
				Guda_BagFrame_ShowCharacterBank(charFullName, charName)
				bankDropdown:Hide()
			else
				addon:Print("Error: Character fullName is nil")
			end
		end)

		table.insert(bankDropdown.buttons, charButton)
		yOffset = yOffset - 20
	end

	-- Set dropdown height based on content
	bankDropdown:SetHeight(math.abs(yOffset) + 8)

	-- Show dropdown
	bankDropdown:Show()
end

-- Show character's bank
function Guda_BagFrame_ShowCharacterBank(fullName, displayName)
-- Use the existing BankFrame module
	if not addon.Modules.BankFrame then
		addon:Print("Bank frame module not available")
		return
	end

	-- Position bank frame at center of screen
	if Guda_BankFrame then
		Guda_BankFrame:ClearAllPoints()
		Guda_BankFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end

	-- Show the character's bank
	addon.Modules.BankFrame:ShowCharacter(fullName)

	-- Make sure frame is shown
	if Guda_BankFrame then
		Guda_BankFrame:Show()
	end
end

-- Clear search and restore placeholder
function Guda_BagFrame_ClearSearch()
	local searchBox = getglobal("Guda_BagFrame_SearchBar_SearchBox")
	if searchBox then
		searchBox:SetText("Search, try ~equipment")
		searchBox:SetTextColor(0.5, 0.5, 0.5, 1)
		searchBox:ClearFocus()
	end

	-- Reset search state
	searchText = ""
	BagFrame.foundFirstMatch = false
	BagFrame.warnedAboutParsing = false
	BagFrame.warnedAboutNoName = false

	-- Update display
	BagFrame:Update()
end

-- Search changed handler
function Guda_BagFrame_OnSearchChanged(self)
	local text = self:GetText()
	-- Ignore placeholder text
	if text == "Search, try ~equipment" then
		text = ""
	end
	if text ~= searchText then
		searchText = text
		BagFrame.foundFirstMatch = false  -- Reset debug flags
		BagFrame.warnedAboutParsing = false
		BagFrame.warnedAboutNoName = false
		BagFrame:Update()
	end
end

-- Keyring toggle handler
function Guda_BagFrame_ToggleKeyring()
	showKeyring = not showKeyring

	-- Update button appearance to show toggle state
	local button = getglobal("Guda_BagFrame_Toolbar_KeyringButton")
	if button then
		local icon = getglobal(button:GetName().."_Icon")
		if icon then
			if showKeyring then
			-- Highlighted when active
				icon:SetVertexColor(1.0, 1.0, 0.5)
			else
			-- Normal color when inactive
				icon:SetVertexColor(0.8, 0.8, 0.8)
			end
		end
	end

	-- Refresh display
	BagFrame:Update()
end

function Guda_BagFrame_Sort()
	if currentViewChar then
		addon:Print("Cannot sort another character's bags!")
		return
	end

 local success, message = addon.Modules.SortEngine:ExecuteSort(
        function() return addon.Modules.SortEngine:SortBagsPass() end,
        function() return addon.Modules.SortEngine:AnalyzeBags() end,
        function() BagFrame:Update() end,
        "bags"
    )

	if not success and message == "already sorted" then
		addon:Print("Bags are already sorted!")
	end
end

-- Hook bag container buttons to open Guda Bag View
local function HookBagContainers()
-- Hook the main bag container buttons (bags 1-4)
	for i = 1, 4 do
		local buttonName = "CharacterBag"..i.."Slot"
		local button = getglobal(buttonName)

		if button then
			local originalOnClick = button:GetScript("OnClick")
			button:SetScript("OnClick", function()
				local mouseButton = arg1 or "LeftButton" -- Vanilla uses global arg1
				if mouseButton == "LeftButton" then
				-- Open Guda Bag View instead of default bag
					BagFrame:Toggle()
				else
				-- Allow right-click and other buttons to work normally
					if originalOnClick then
						originalOnClick()
					end
				end
			end)
		end
	end

	-- Also hook the backpack button
	local backpackButton = getglobal("MainMenuBarBackpackButton")
	if backpackButton then
		local originalOnClick = backpackButton:GetScript("OnClick")
		backpackButton:SetScript("OnClick", function()
			local mouseButton = arg1 or "LeftButton" -- Vanilla uses global arg1
			if mouseButton == "LeftButton" then
			-- Open Guda Bag View instead of default bag
				BagFrame:Toggle()
			else
			-- Allow right-click and other buttons to work normally
				if originalOnClick then
					originalOnClick()
				end
			end
		end)
	end

	-- Hook keyring button if it exists
	local keyringButton = getglobal("KeyRingButton")
	if keyringButton then
		local originalOnClick = keyringButton:GetScript("OnClick")
		keyringButton:SetScript("OnClick", function()
			local mouseButton = arg1 or "LeftButton" -- Vanilla uses global arg1
			if mouseButton == "LeftButton" then
			-- Toggle keyring in Guda Bag View
				Guda_BagFrame_ToggleKeyring()
				BagFrame:Toggle() -- Also open the bag frame
			else
			-- Allow right-click and other buttons to work normally
				if originalOnClick then
					originalOnClick()
				end
			end
		end)
	end
end

-- Alternative approach: Completely replace the bag open functions
local function ReplaceBagOpenFunctions()
-- Override OpenBag (if it exists)
	if OpenBag then
		local originalOpenBag = OpenBag
		function OpenBag(bagId)
			if bagId and bagId >= 0 and bagId <= 4 then
			-- For regular bags, open Guda Bag View
				BagFrame:Toggle()
			else
			-- For other containers, use original function
				if originalOpenBag then
					originalOpenBag(bagId)
				end
			end
		end
	end

	-- Override ToggleBag (if it exists)
	if ToggleBag then
		local originalToggleBag = ToggleBag
		function ToggleBag(bagId)
			if bagId and bagId >= 0 and bagId <= 4 then
			-- For regular bags, toggle Guda Bag View
				BagFrame:Toggle()
			else
			-- For other containers, use original function
				if originalToggleBag then
					originalToggleBag(bagId)
				end
			end
		end
	end
end

-- Hook to default bag opening
local function HookDefaultBags()
-- Override ToggleBackpack (if it exists)
	if ToggleBackpack then
		local originalToggleBackpack = ToggleBackpack
		function ToggleBackpack()
			BagFrame:Toggle()

			-- Force disable pfUI bags if enabled
			if pfUI and pfUI.bag and pfUI.bag.right and pfUI.bag.right.Hide then
				pfUI.bag.right:Hide()
			end
		end
	end

	-- Override OpenAllBags (if it exists)
	if OpenAllBags then
		local originalOpenAllBags = OpenAllBags
		function OpenAllBags()
			Guda_BagFrame:Show()

			-- Force disable pfUI bags if enabled
			if pfUI and pfUI.bag and pfUI.bag.right and pfUI.bag.right.Hide then
				pfUI.bag.right:Hide()
			end
		end
	end

	-- Override CloseAllBags (if it exists)
	if CloseAllBags then
		local originalCloseAllBags = CloseAllBags
		function CloseAllBags()
			-- Do not auto-close our bags when interacting with a vendor
			if isMerchantOpen then
				return
			end
			Guda_BagFrame:Hide()
		end
	end

	-- Hook individual bag opening functions (for bag slot buttons)
	ReplaceBagOpenFunctions()

	-- Hook the bag slot button clicks directly
	HookBagContainers()
end

-- Update lock state (controls whether frame is draggable)
function BagFrame:UpdateLockState()
-- Safety check: ensure addon and modules exist
	if not addon or not addon.Modules then return end

	local frame = getglobal("Guda_BagFrame")
	if not frame then return end

	-- Check if DB module is available
	if not addon.Modules.DB or not addon.Modules.DB.GetSetting then return end

	local success, isLocked = pcall(function()
		return addon.Modules.DB:GetSetting("lockBags")
	end)

	if not success then return end

	if isLocked == nil then
		isLocked = false
	end

	-- Get draggable areas
	local toolbar = getglobal("Guda_BagFrame_Toolbar")
	local moneyFrame = getglobal("Guda_BagFrame_MoneyFrame")
	local itemContainer = getglobal("Guda_BagFrame_ItemContainer")

	if isLocked then
	-- Disable dragging on main frame
		if frame.SetScript then
			frame:SetScript("OnMouseDown", function()
				local searchBox = getglobal("Guda_BagFrame_SearchBar_SearchBox")
				if searchBox then
					searchBox:ClearFocus()
				end
			end)
			frame:SetScript("OnMouseUp", nil)
		end

		-- Disable dragging on toolbar
		if toolbar and toolbar.SetScript then
			toolbar:SetScript("OnMouseDown", function()
				local searchBox = getglobal("Guda_BagFrame_SearchBar_SearchBox")
				if searchBox then
					searchBox:ClearFocus()
				end
			end)
			toolbar:SetScript("OnMouseUp", nil)
		end

		-- Disable dragging on money frame (preserve tooltip handlers on child buttons)
		if moneyFrame and moneyFrame.SetScript then
			moneyFrame:SetScript("OnMouseDown", function()
				local searchBox = getglobal("Guda_BagFrame_SearchBar_SearchBox")
				if searchBox then
					searchBox:ClearFocus()
				end
			end)
			moneyFrame:SetScript("OnMouseUp", nil)
		end

		-- Disable dragging on item container
		if itemContainer and itemContainer.SetScript then
			itemContainer:SetScript("OnMouseDown", function()
				local searchBox = getglobal("Guda_BagFrame_SearchBar_SearchBox")
				if searchBox then
					searchBox:ClearFocus()
				end
			end)
			itemContainer:SetScript("OnMouseUp", nil)
		end
	else
	-- Enable dragging on main frame
		if frame and frame.SetScript then
			frame:SetScript("OnMouseDown", function()
				local searchBox = getglobal("Guda_BagFrame_SearchBar_SearchBox")
				if searchBox then
					searchBox:ClearFocus()
				end

				local bagFrame = getglobal("Guda_BagFrame")
				if bagFrame and arg1 == "LeftButton" then
					bagFrame:StartMoving()
				end
			end)
			frame:SetScript("OnMouseUp", function()
				local bagFrame = getglobal("Guda_BagFrame")
				if bagFrame then
					bagFrame:StopMovingOrSizing()
					SaveBagFramePosition()
				end
			end)
		end

		-- Enable dragging on toolbar (title area)
		if toolbar and toolbar.SetScript then
			toolbar:SetScript("OnMouseDown", function()
				local searchBox = getglobal("Guda_BagFrame_SearchBar_SearchBox")
				if searchBox then
					searchBox:ClearFocus()
				end

				local bagFrame = getglobal("Guda_BagFrame")
				if bagFrame and arg1 == "LeftButton" then
					bagFrame:StartMoving()
				end
			end)
			toolbar:SetScript("OnMouseUp", function()
				local bagFrame = getglobal("Guda_BagFrame")
				if bagFrame then
					bagFrame:StopMovingOrSizing()
					SaveBagFramePosition()
				end
			end)
		end

		-- Enable dragging on money frame (preserve tooltip handlers on child buttons)
		if moneyFrame and moneyFrame.SetScript then
			moneyFrame:SetScript("OnMouseDown", function()
				local searchBox = getglobal("Guda_BagFrame_SearchBar_SearchBox")
				if searchBox then
					searchBox:ClearFocus()
				end

				local bagFrame = getglobal("Guda_BagFrame")
				if bagFrame and arg1 == "LeftButton" then
					bagFrame:StartMoving()
				end
			end)
			moneyFrame:SetScript("OnMouseUp", function()
				local bagFrame = getglobal("Guda_BagFrame")
				if bagFrame then
					bagFrame:StopMovingOrSizing()
					SaveBagFramePosition()
				end
			end)
		end

		-- Enable dragging on item container
		if itemContainer and itemContainer.SetScript then
			itemContainer:SetScript("OnMouseDown", function()
				local searchBox = getglobal("Guda_BagFrame_SearchBar_SearchBox")
				if searchBox then
					searchBox:ClearFocus()
				end

				local bagFrame = getglobal("Guda_BagFrame")
				if bagFrame and arg1 == "LeftButton" then
					bagFrame:StartMoving()
				end
			end)
			itemContainer:SetScript("OnMouseUp", function()
				local bagFrame = getglobal("Guda_BagFrame")
				if bagFrame then
					bagFrame:StopMovingOrSizing()
					SaveBagFramePosition()
				end
			end)
		end
	end
end

-- Update border visibility based on setting
function BagFrame:UpdateBorderVisibility()
	if not addon or not addon.Modules or not addon.Modules.DB then return end

	local frame = getglobal("Guda_BagFrame")
	if not frame then return end

	local hideBorders = addon.Modules.DB:GetSetting("hideBorders")
	if hideBorders == nil then
		hideBorders = false
	end

	-- Use helper function with constants
	if hideBorders then
		addon:ApplyBackdrop(frame, "MINIMALIST_BORDER", "DEFAULT")
	else
		addon:ApplyBackdrop(frame, "DEFAULT_FRAME", "DEFAULT")
	end
end

-- Update search bar visibility based on setting
function BagFrame:UpdateSearchBarVisibility()
	if not addon or not addon.Modules or not addon.Modules.DB then return end

	local searchBar = getglobal("Guda_BagFrame_SearchBar")
	local itemContainer = getglobal("Guda_BagFrame_ItemContainer")
	if not searchBar or not itemContainer then return end

	local showSearchBar = addon.Modules.DB:GetSetting("showSearchBar")
	if showSearchBar == nil then
		showSearchBar = true
	end

	if showSearchBar then
		searchBar:Show()
		-- Anchor ItemContainer to SearchBar's bottom
		itemContainer:ClearAllPoints()
		itemContainer:SetPoint("TOP", searchBar, "BOTTOM", 0, -5)
	else
		searchBar:Hide()
		-- Anchor ItemContainer directly to frame top (skip search bar space)
		itemContainer:ClearAllPoints()
		itemContainer:SetPoint("TOP", "Guda_BagFrame", "TOP", 0, -40)
	end
end

-- Update footer visibility based on settings
function BagFrame:UpdateFooterVisibility()
	local hideFooter = addon.Modules.DB:GetSetting("hideFooter")
	local toolbar = getglobal("Guda_BagFrame_Toolbar")
	local moneyFrame = getglobal("Guda_BagFrame_MoneyFrame")

	if hideFooter then
		if toolbar then toolbar:Hide() end
		if moneyFrame then moneyFrame:Hide() end
	else
		if toolbar then toolbar:Show() end
		if moneyFrame then moneyFrame:Show() end
		
		-- Trigger layout updates to ensure they are correctly positioned
		self:UpdateBaglineLayout()
		self:UpdateMoney()
	end
end

-- Bag Slot Button Handlers

-- OnLoad handler for bag slot buttons
function Guda_BagSlot_OnLoad(button, bagID)
-- Hide borders from ItemButtonTemplate
	local buttonName = button:GetName()

	-- Hide the normal texture border
	local normalTexture = getglobal(buttonName .. "NormalTexture")
	if normalTexture then
		normalTexture:SetTexture(nil)
		normalTexture:Hide()
	end

	-- Hide icon border
	local iconBorder = getglobal(buttonName .. "IconBorder")
	if iconBorder then
		iconBorder:Hide()
	end

	-- Set up the button with proper ID
	if bagID == 0 then
	-- Backpack (bag 0)
		button.bagID = 0
		button.hasItem = 1
		SetItemButtonTexture(button, "Interface\\Buttons\\Button-Backpack-Up")
	else
	-- Bags 1-4
		local invSlot = ContainerIDToInventoryID(bagID)
		button:SetID(invSlot)
		button.bagID = bagID

		-- REGISTER FOR DRAG - This is crucial for Classic
		button:RegisterForDrag("LeftButton")

		-- Register for updates
		button:RegisterEvent("BAG_UPDATE")
		button:RegisterEvent("ITEM_LOCK_CHANGED")
		button:RegisterEvent("CURSOR_UPDATE")
		button:RegisterEvent("UNIT_INVENTORY_CHANGED")

		-- Accept drops (equip when a bag is dropped on this slot)
		button:SetScript("OnReceiveDrag", function()
			if this and this.bagID and this.bagID ~= 0 and CursorHasItem and CursorHasItem() then
				local inv = ContainerIDToInventoryID(this.bagID)
				if EquipCursorItem then
					EquipCursorItem(inv)
				elseif PutItemInBag then
					PutItemInBag(inv)
				end
				Guda_BagSlot_Update(this, this.bagID)
				if BagFrame and BagFrame.Update then BagFrame:Update() end
			end
		end)
	end

	-- Ensure we handle right-click toggling like BankFrame
	if button.RegisterForClicks then
		button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	end

	-- Initial update
	Guda_BagSlot_Update(button, bagID)
end

function Guda_BagSlot_OnDragStart(frame, bagID)
	if bagID == 0 then return end

	-- Check if we should start dragging (only if there's an item)
	local invSlot = ContainerIDToInventoryID(bagID)
	local texture = GetInventoryItemTexture("player", invSlot)

	if texture then
		frame:SetAlpha(0.6)
		-- Immediate pickup for Classic
		PickupInventoryItem(invSlot)
		-- Instantly reflect the change in UI (slot is now empty on cursor pickup)
		Guda_BagSlot_Update(frame, bagID)
		if BagFrame and BagFrame.Update then BagFrame:Update() end
	end
-- If no texture (empty slot), do nothing - drag won't start
end

function Guda_BagSlot_OnDragStop(frame, bagID)
	frame:SetAlpha(1.0)
end

-- Update bag slot button texture
function Guda_BagSlot_Update(button, bagID)
	local isHidden = hiddenBags[bagID]

	if bagID == 0 then
	-- Backpack always has the same texture
		SetItemButtonTexture(button, "Interface\\Buttons\\Button-Backpack-Up")
		-- Dim if hidden
		if isHidden then
			SetItemButtonTextureVertexColor(button, 0.4, 0.4, 0.4)
		else
			SetItemButtonTextureVertexColor(button, 1.0, 1.0, 1.0)
		end
		return
	end

	-- Get the inventory slot ID for this bag
	local invSlot = ContainerIDToInventoryID(bagID)
	local texture = GetInventoryItemTexture("player", invSlot)

	if texture then
	-- Bag is equipped
		SetItemButtonTexture(button, texture)
		-- Dim if hidden
		if isHidden then
			SetItemButtonTextureVertexColor(button, 0.4, 0.4, 0.4)
		else
			SetItemButtonTextureVertexColor(button, 1.0, 1.0, 1.0)
		end
	else
	-- No bag in this slot
		SetItemButtonTexture(button, "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
		SetItemButtonTextureVertexColor(button, 0.5, 0.5, 0.5)
	end
end

-- OnEvent handler
function Guda_BagSlot_OnEvent(button, event, arg1)
	local bagID = button.bagID
	if not bagID then
		return
	end

	if event == "BAG_UPDATE" then
		if arg1 == bagID then
			Guda_BagSlot_Update(button, bagID)
		end
	elseif event == "UNIT_INVENTORY_CHANGED" then
		if arg1 == "player" then
			Guda_BagSlot_Update(button, bagID)
		end
	elseif event == "ITEM_LOCK_CHANGED" or event == "CURSOR_UPDATE" then
		Guda_BagSlot_Update(button, bagID)
	end
end

-- OnClick handler
function Guda_BagSlot_OnClick(button, bagID)
	local which = arg1 -- Vanilla uses global arg1 for mouse button name

	-- Right-Click: toggle visibility
	if which == "RightButton" then
		hiddenBags[bagID] = not hiddenBags[bagID]

		-- Update bag slot visual (dim/undim)
		Guda_BagSlot_Update(button, bagID)

		-- Refresh the bag display
		BagFrame:Update()

		return
	end

	-- Left-Click: equip bag from cursor into this slot (bags 1-4 only)
	if which == "LeftButton" then
		if bagID ~= 0 and CursorHasItem and CursorHasItem() then
			local invSlot = ContainerIDToInventoryID(bagID)
			if EquipCursorItem then
				EquipCursorItem(invSlot)
			else
				if PutItemInBag then PutItemInBag(invSlot) end
			end
			-- Update visuals after attempted equip
			Guda_BagSlot_Update(button, bagID)
			BagFrame:Update()
		end
		return
	end
end

-- OnEnter handler for tooltip
function Guda_BagSlot_OnEnter(button, bagID)
	-- Handle hover bagline
	local hoverBagline = addon.Modules.DB:GetSetting("hoverBagline")
	if hoverBagline then
		local toolbar = getglobal("Guda_BagFrame_Toolbar")
		if toolbar then
			toolbar.isHovered = true
			toolbar.hoverTimer = nil -- Cancel any pending hide
			BagFrame:UpdateBaglineLayout()
		end
	end

	GameTooltip:SetOwner(button, "ANCHOR_TOP")

	if bagID == 0 then
	-- Backpack tooltip
		GameTooltip:SetText("Backpack", 1.0, 1.0, 1.0)
		local numSlots = GetContainerNumSlots(0)
		GameTooltip:AddLine(string.format("%d Slots", numSlots), 0.8, 0.8, 0.8)
		if hiddenBags[bagID] then
			GameTooltip:AddLine("(Hidden - Right-Click to show)", 0.8, 0.5, 0.5)
		else
			GameTooltip:AddLine("(Right-Click to hide)", 0.5, 0.8, 0.5)
		end
	else
	-- Bag slot tooltip
		local invSlot = ContainerIDToInventoryID(bagID)
		local hasItem = GetInventoryItemTexture("player", invSlot)

		if hasItem then
		-- Show bag item tooltip
			GameTooltip:SetInventoryItem("player", invSlot)
			if hiddenBags[bagID] then
				GameTooltip:AddLine("(Hidden - Right-Click to show)", 0.8, 0.5, 0.5)
			else
				GameTooltip:AddLine("(Right-Click to hide)", 0.5, 0.8, 0.5)
			end
		else
		-- Empty slot
			GameTooltip:SetText(string.format("Bag %d", bagID), 1.0, 1.0, 1.0)
			GameTooltip:AddLine("Empty", 0.5, 0.5, 0.5)
			if hiddenBags[bagID] then
				GameTooltip:AddLine("(Hidden - Right-Click to show)", 0.8, 0.5, 0.5)
			else
				GameTooltip:AddLine("(Right-Click to hide)", 0.5, 0.8, 0.5)
			end
		end
	end

	GameTooltip:Show()
end

-- OnLeave handler for tooltip
function Guda_BagSlot_OnLeave(button, bagID)
	-- Handle hover bagline
	local hoverBagline = addon.Modules.DB:GetSetting("hoverBagline")
	if hoverBagline then
		local toolbar = getglobal("Guda_BagFrame_Toolbar")
		if toolbar then
			-- Start a small timer to hide, so we can move mouse between bags
			toolbar.hoverTimer = 0.1
			if not toolbar.hasOnUpdate then
				toolbar:SetScript("OnUpdate", function()
					if this.hoverTimer then
						this.hoverTimer = this.hoverTimer - arg1
						if this.hoverTimer <= 0 then
							this.hoverTimer = nil
							this.isHovered = false
							BagFrame:UpdateBaglineLayout()
						end
					end
				end)
				toolbar.hasOnUpdate = true
			end
		end
	end
end

-- Highlight all item slots belonging to a specific bag by dimming others
function Guda_BagFrame_HighlightBagSlots(bagID)
    -- Use the tracked itemButtons list because actual buttons are parented under per-bag parents
    if not itemButtons or type(itemButtons) ~= "table" then return end

    local highlightCount, dimCount = 0, 0

    for _, button in ipairs(itemButtons) do
        if button and button:IsShown() and button.hasItem ~= nil and not button.isBagSlot then
            if button.bagID == bagID then
                button:SetAlpha(1.0)
                highlightCount = highlightCount + 1
            else
                button:SetAlpha(0.25)
                dimCount = dimCount + 1
            end
        end
    end
end

-- Clear all highlighting by restoring full opacity to all slots
function Guda_BagFrame_ClearHighlightedSlots()
    -- Restore alpha to whatever the search filter dictates (pfUI style). If no search, full opacity.
    if not itemButtons or type(itemButtons) ~= "table" then return end

    local searchActive = BagFrame and BagFrame.IsSearchActive and BagFrame:IsSearchActive()
    for _, button in ipairs(itemButtons) do
        if button and button:IsShown() and button.hasItem ~= nil and not button.isBagSlot then
            if searchActive and BagFrame and BagFrame.PassesSearchFilter then
                local matches = BagFrame:PassesSearchFilter(button.itemData)
                button:SetAlpha(matches and 1.0 or 0.25)
            else
                button:SetAlpha(1.0)
            end
        end
    end
end

-- Highlight a specific bag button in the toolbar
function Guda_BagFrame_HighlightBagButton(bagID)
	if not bagID then return end

	local buttonName
	if bagID == -2 then
	-- Keyring button
		buttonName = "Guda_BagFrame_Toolbar_KeyringButton"
	elseif bagID >= 0 and bagID <= 4 then
	-- Bag buttons 0-4 (0 is backpack)
		buttonName = "Guda_BagFrame_Toolbar_BagSlot" .. bagID
	else
		return
	end

	local button = getglobal(buttonName)
	if button then
	-- Set the button's pushed texture to highlight it
		button:LockHighlight()
	end
end

-- Clear bag button highlighting
function Guda_BagFrame_ClearBagButtonHighlight()
-- Clear highlight from all bag buttons (0-4)
	for bagID = 0, 4 do
		local buttonName = "Guda_BagFrame_Toolbar_BagSlot" .. bagID
		local button = getglobal(buttonName)
		if button then
			button:UnlockHighlight()
		end
	end

	-- Clear keyring button highlight
	local keyringButton = getglobal("Guda_BagFrame_Toolbar_KeyringButton")
	if keyringButton then
		keyringButton:UnlockHighlight()
	end
end

-- Initialize
function BagFrame:Initialize()
-- Hook default bag functions (with slight delay to ensure UI is loaded)
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("PLAYER_LOGIN")
	frame:SetScript("OnEvent", function()
		HookDefaultBags()

		-- Re-hook when character frame is opened (for safety)
		local charFrame = getglobal("CharacterFrame")
		if charFrame then
			local originalShow = charFrame:GetScript("OnShow")
			charFrame:SetScript("OnShow", function()
				HookBagContainers()
				if originalShow then
					originalShow()
				end
			end)
		end
	end)

 -- Update on bag changes
 addon.Modules.Events:OnBagUpdate(function()
     if not currentViewChar then
         BagFrame:Update()
     end
 end, "BagFrame")

 -- Update item cooldown overlays when item cooldowns change
 addon.Modules.Events:Register("BAG_UPDATE_COOLDOWN", function()
     if not currentViewChar then
         if BagFrame.RefreshCooldowns then
             BagFrame:RefreshCooldowns()
         end
     end
 end, "BagFrame")

	-- Update on money changes
	addon.Modules.Events:OnMoneyChanged(function()
		BagFrame:UpdateMoney()
	end, "BagFrame")

	-- Update when items get locked/unlocked (for trading, mailing, etc.)
	addon.Modules.Events:Register("ITEM_LOCK_CHANGED", function()
		if not currentViewChar then
			BagFrame:Update()
		end
	end, "BagFrame")

	-- Auto-open bag frame when mail is opened
	addon.Modules.Events:Register("MAIL_SHOW", function()
		Guda_BagFrame:Show()
	end, "BagFrame")

	-- Track vendor interactions to avoid closing bags when a vendor is opened
	addon.Modules.Events:Register("MERCHANT_SHOW", function()
		isMerchantOpen = true
		-- Optional: ensure bags are visible when a vendor is opened
		local frameRef = getglobal("Guda_BagFrame")
		if frameRef and not frameRef:IsShown() then
			frameRef:Show()
		end
	end, "BagFrame")

	addon.Modules.Events:Register("MERCHANT_CLOSED", function()
		isMerchantOpen = false
	end, "BagFrame")

	-- Hide character dropdown when clicking on bag frame
	local bagFrame = getglobal("Guda_BagFrame")
	if bagFrame then
		local originalOnMouseDown = bagFrame:GetScript("OnMouseDown")
		bagFrame:SetScript("OnMouseDown", function()
			HideCharacterDropdown()
			if originalOnMouseDown then
				originalOnMouseDown()
			end
		end)
	end

    addon:Debug("Bag frame initialized")
end

-- Refresh cooldown overlays for all visible item buttons
function BagFrame:RefreshCooldowns()
    local itemContainer = getglobal("Guda_BagFrame_ItemContainer")
    if not itemContainer then return end

    -- Iterate through all children; our item buttons are direct children of per-bag parents inside the container,
    -- so iterate all descendants by scanning children of children as well.
    local function refreshChildren(parent)
        local children = { parent:GetChildren() }
        for _, child in ipairs(children) do
            if child and child.hasItem ~= nil then
                if child:IsShown() and Guda_ItemButton_UpdateCooldown then
                    Guda_ItemButton_UpdateCooldown(child)
                end
            end
            -- Recurse one level to reach actual buttons under bag parents
            local grandChildren = { child:GetChildren() }
            if table.getn(grandChildren) > 0 then
                for _, gc in ipairs(grandChildren) do
                    if gc and gc.hasItem ~= nil then
                        if gc:IsShown() and Guda_ItemButton_UpdateCooldown then
                            Guda_ItemButton_UpdateCooldown(gc)
                        end
                    end
                end
            end
        end
    end

    refreshChildren(itemContainer)
end