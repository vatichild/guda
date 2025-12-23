-- Bank Frame
-- Bank viewing UI

local addon = Guda

local BankFrame = {}
addon.Modules.BankFrame = BankFrame

local currentViewChar = nil
local searchText = ""
local isReadOnlyMode = false  -- Track if viewing saved bank (read-only) or live bank (interactive)
local hiddenBankBags = {} -- Track which bank bags are hidden (bagID -> true/false)
local bankBagParents = {} -- Parent frames per bank bag (same approach as BagFrame)
-- Global click catcher for clearing bank search focus
local bankClickCatcher = nil

-- OnLoad
function Guda_BankFrame_OnLoad(self)
    -- Set up initial backdrop
    addon:ApplyBackdrop(self, "DEFAULT_FRAME")

    -- Set up search box placeholder
    local searchBox = getglobal(self:GetName().."_SearchBar_SearchBox")
    if searchBox then
        searchBox:SetText("Search bank...")
        searchBox:SetTextColor(0.5, 0.5, 0.5, 1)
    end

    -- Create invisible full-screen frame to catch clicks outside the bank frame while typing in search
    if not bankClickCatcher then
        bankClickCatcher = CreateFrame("Frame", "Guda_BankClickCatcher", UIParent)
        bankClickCatcher:SetFrameStrata("BACKGROUND")
        bankClickCatcher:SetAllPoints(UIParent)
        bankClickCatcher:EnableMouse(true)
        bankClickCatcher:Hide()

        bankClickCatcher:SetScript("OnMouseDown", function()
            if Guda_BankFrame_ClearSearch then
                Guda_BankFrame_ClearSearch()
            end
        end)
    end

end

-- OnShow
function Guda_BankFrame_OnShow(self)
    if BankFrame.EnsureBagButtonsInitialized then
        BankFrame:EnsureBagButtonsInitialized()
    end
    -- Enforce MoneyFrame bottom margin in case any runtime code repositions it
    local moneyFrame = getglobal("Guda_BankFrame_MoneyFrame")
    if moneyFrame and moneyFrame.ClearAllPoints and moneyFrame.SetPoint then
        moneyFrame:ClearAllPoints()
        moneyFrame:SetPoint("BOTTOMRIGHT", Guda_BankFrame, "BOTTOMRIGHT", -15, 10)
    end

    -- Apply border visibility setting
    if BankFrame.UpdateBorderVisibility then
        BankFrame:UpdateBorderVisibility()
    end

   	-- Apply search bar visibility setting
   	if BankFrame.UpdateSearchBarVisibility then
   		BankFrame:UpdateSearchBarVisibility()
   	end

   	-- Apply footer visibility setting
   	if BankFrame.UpdateFooterVisibility then
   		BankFrame:UpdateFooterVisibility()
   	end

	-- Apply frame transparency
	if Guda_ApplyBackgroundTransparency then
		Guda_ApplyBackgroundTransparency()
	end

   	BankFrame:Update()
   end

-- Toggle visibility
function BankFrame:Toggle()
    if Guda_BankFrame:IsShown() then
        Guda_BankFrame:Hide()
    else
        Guda_BankFrame:Show()
    end
end

-- Show specific character's bank (read-only mode)
function BankFrame:ShowCharacter(fullName)
    currentViewChar = fullName
    isReadOnlyMode = true  -- Viewing saved bank data (read-only)
    self:Update()
end

-- Show current character's bank (interactive mode)
function BankFrame:ShowCurrentCharacter()
    currentViewChar = nil
    isReadOnlyMode = false  -- Viewing live bank (interactive)
    self:Update()
end

-- Update lock states of existing buttons (lightweight, used during drag)
function BankFrame:UpdateLockStates()
    for _, bankBagParent in pairs(bankBagParents) do
        if bankBagParent then
            local buttons = { bankBagParent:GetChildren() }
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

-- Update display
function BankFrame:Update()
    if not Guda_BankFrame:IsShown() then
        return
    end

    -- If cursor is holding an item (mid-drag), only update lock states, don't rebuild UI
    if CursorHasItem and CursorHasItem() then
        self:UpdateLockStates()
        return
    end

    -- Mark all existing buttons as not in use (we'll mark active ones during display)
    for _, bankBagParent in pairs(bankBagParents) do
        if bankBagParent then
            local buttons = { bankBagParent:GetChildren() }
            for _, button in ipairs(buttons) do
                if button.hasItem ~= nil then
                    button.inUse = false
                end
            end
        end
    end

    -- Determine if we're in read-only mode:
    -- - If viewing another character → read-only
    -- - If bank is actually open → interactive (live)
    -- - Otherwise → read-only (viewing saved data)
    local bankIsOpen = addon.Modules.BankScanner:IsBankOpen()
    isReadOnlyMode = currentViewChar ~= nil or not bankIsOpen

    local bankData
    local isOtherChar = false
    local charName = ""

    if currentViewChar then
        -- Viewing another character's saved bank
        bankData = addon.Modules.DB:GetCharacterBank(currentViewChar)
        isOtherChar = true
        charName = currentViewChar
        getglobal("Guda_BankFrame_Title"):SetText(currentViewChar .. "'s Bank")
    else
        -- Viewing current character's bank
        if bankIsOpen then
            -- Bank is actually open - use live data (interactive mode)
            bankData = addon.Modules.BankScanner:ScanBank()
            -- Use current character's name for the title
            local playerName = addon.Modules.DB:GetPlayerFullName()
            getglobal("Guda_BankFrame_Title"):SetText(playerName .. "'s Bank")
        else
            -- Bank is closed - use saved data (read-only mode)
            local playerName = addon.Modules.DB:GetPlayerFullName()
            bankData = addon.Modules.DB:GetCharacterBank(playerName)
            getglobal("Guda_BankFrame_Title"):SetText(playerName .. "'s Bank")
        end
    end

    local viewType = addon.Modules.DB:GetSetting("bankViewType") or "single"
    
    -- Reset all section headers before displaying items
    local i = 1
    while true do
        local header = getglobal("Guda_BankFrame_SectionHeader" .. i)
        if not header then break end
        header.inUse = false
        header:Hide()
        i = i + 1
    end

    if viewType == "category" then
        self:DisplayItemsByCategory(bankData, isOtherChar, charName)
    else
        self:DisplayItems(bankData, isOtherChar, charName)
    end

    -- Update money
    self:UpdateMoney()

    -- Update bank slots info
    self:UpdateBankSlotsInfo(bankData, isOtherChar)

    -- Clean up unused buttons AFTER display is complete (prevents drag/drop issues)
    for _, bankBagParent in pairs(bankBagParents) do
        if bankBagParent then
            local buttons = { bankBagParent:GetChildren() }
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
function BankFrame:GetSectionHeader(index)
    local name = "Guda_BankFrame_SectionHeader" .. index
    local header = getglobal(name)
    if not header then
        header = CreateFrame("Frame", name, getglobal("Guda_BankFrame_ItemContainer"))
        header:SetHeight(20)
        local text = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", header, "LEFT", 5, 0)
        header.text = text
    end
    header.inUse = true
    return header
end

-- Helper to get or create bank bag parent frame
function BankFrame:GetBagParent(bagID)
    local itemContainer = getglobal("Guda_BankFrame_ItemContainer")
    if not bankBagParents[bagID] then
        bankBagParents[bagID] = CreateFrame("Frame", "Guda_BankFrame_BagParent"..bagID, itemContainer)
        bankBagParents[bagID]:SetAllPoints(itemContainer)
        if bankBagParents[bagID].SetID then
            bankBagParents[bagID]:SetID(bagID)
        end
    end
    return bankBagParents[bagID]
end

-- Display items by category
function BankFrame:DisplayItemsByCategory(bankData, isOtherChar, charName)
    local buttonSize = addon.Modules.DB:GetSetting("iconSize") or addon.Constants.BUTTON_SIZE
    local spacing = addon.Modules.DB:GetSetting("iconSpacing") or addon.Constants.BUTTON_SPACING
    local perRow = addon.Modules.DB:GetSetting("bankColumns") or 10
    local itemContainer = getglobal("Guda_BankFrame_ItemContainer")

    -- Group items by category
    local categories = {}
    local categoryList = {
        "Equipment", "Consumable", "Quest", "Trade Goods", "Reagent", "Recipe", "Quiver", "Container", "Miscellaneous"
    }
    for _, cat in ipairs(categoryList) do categories[cat] = {} end

    -- Bank main slots (bagID -1)
    local bankMain = bankData[-1]
    if bankMain and bankMain.slots then
        for slotID, itemData in pairs(bankMain.slots) do
            if itemData then
                local cat = itemData.class or "Miscellaneous"
                if itemData.equipSlot and itemData.equipSlot ~= "" then cat = "Equipment" end
                if not categories[cat] then categories[cat] = {} end
                table.insert(categories[cat], {bagID = -1, slotID = slotID, itemData = itemData})
            end
        end
    end

    -- Bank bags
    for _, bagID in ipairs(addon.Constants.BANK_BAGS) do
        if not hiddenBankBags[bagID] then
            local bag = bankData[bagID]
            if bag and bag.slots then
                for slotID, itemData in pairs(bag.slots) do
                    if itemData then
                        local cat = itemData.class or "Miscellaneous"
                        if itemData.equipSlot and itemData.equipSlot ~= "" then cat = "Equipment" end
                        if not categories[cat] then categories[cat] = {} end
                        table.insert(categories[cat], {bagID = bagID, slotID = slotID, itemData = itemData})
                    end
                end
            end
        end
    end

    -- Layout
    local x, y = 5, -10
    local headerIdx = 1
    
    for _, catName in ipairs(categoryList) do
        local items = categories[catName]
        if items and table.getn(items) > 0 then
            -- Sort items in category
            table.sort(items, function(a, b)
                if a.itemData.quality ~= b.itemData.quality then
                    return a.itemData.quality > b.itemData.quality
                end
                return (a.itemData.name or "") < (b.itemData.name or "")
            end)

            -- Add Header
            local header = self:GetSectionHeader(headerIdx)
            headerIdx = headerIdx + 1
            header:SetPoint("TOPLEFT", itemContainer, "TOPLEFT", 0, y)
            header:SetWidth(perRow * (buttonSize + spacing))
            header.text:SetText(catName)
            header:Show()
            
            y = y - 20
            
            local col = 0
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
                button:SetPoint("TOPLEFT", itemContainer, "TOPLEFT", x + (col * (buttonSize + spacing)), y)
                button:Show()
                
                local matchesFilter = self:PassesSearchFilter(itemData)
                
                Guda_ItemButton_SetItem(button, bagID, slot, itemData, true, isOtherChar and charName or nil, matchesFilter, true)
                button.inUse = true
                
                col = col + 1
                if col >= perRow then
                    col = 0
                    y = y - (buttonSize + spacing)
                end
            end
            
            if col > 0 then
                y = y - (buttonSize + spacing)
            end
            y = y - 5 -- Padding between sections
        end
    end

    -- Update container height
    local finalHeight = math.abs(y) + 20
    itemContainer:SetHeight(finalHeight)
    self:ResizeFrame(nil, nil, perRow, finalHeight)
end

-- Display items
function BankFrame:DisplayItems(bankData, isOtherChar, charName)
    local x, y = 5, -10
    local row = 0
    local col = 0
    local buttonSize = addon.Modules.DB:GetSetting("iconSize") or addon.Constants.BUTTON_SIZE
    local spacing = addon.Modules.DB:GetSetting("iconSpacing") or addon.Constants.BUTTON_SPACING
    local perRow = addon.Modules.DB:GetSetting("bankColumns") or 10
    local itemContainer = getglobal("Guda_BankFrame_ItemContainer")

    -- Separate bank bags into regular, enchant, herb, soul, quiver, and ammo types
    local regularBags = {}
    local enchantBags = {}
    local herbBags = {}
    local soulBags = {}
    local quiverBags = {}
    local ammoBags = {}

    for _, bagID in ipairs(addon.Constants.BANK_BAGS) do
        if not hiddenBankBags[bagID] then
            local bagType
            if isOtherChar then
                -- Use saved bag type for other characters
                local bagSaved = bankData and bankData[bagID]
                bagType = bagSaved and bagSaved.bagType or "regular"
            else
                -- Unified live detection for current character when bank is open
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

    -- Build display order: regular -> enchant -> herb -> soul -> quiver -> ammo
    local bagsToShow = {}
    for _, bagID in ipairs(regularBags) do
        table.insert(bagsToShow, { bagID = bagID, needsSpacing = false })
    end
    if table.getn(enchantBags) > 0 then
        for i, bagID in ipairs(enchantBags) do
            table.insert(bagsToShow, { bagID = bagID, needsSpacing = (i == 1) })
        end
    end
    if table.getn(herbBags) > 0 then
        for i, bagID in ipairs(herbBags) do
            table.insert(bagsToShow, { bagID = bagID, needsSpacing = (i == 1) })
        end
    end
    if table.getn(soulBags) > 0 then
        for i, bagID in ipairs(soulBags) do
            table.insert(bagsToShow, { bagID = bagID, needsSpacing = (i == 1) })
        end
    end
    if table.getn(quiverBags) > 0 then
        for i, bagID in ipairs(quiverBags) do
            table.insert(bagsToShow, { bagID = bagID, needsSpacing = (i == 1) })
        end
    end
    if table.getn(ammoBags) > 0 then
        for i, bagID in ipairs(ammoBags) do
            table.insert(bagsToShow, { bagID = bagID, needsSpacing = (i == 1) })
        end
    end

    for _, bagInfo in ipairs(bagsToShow) do
        local bagID = bagInfo.bagID
        local bag = bankData and bankData[bagID]

        -- Add spacing before first of each specialized section
        if bagInfo.needsSpacing then
            if col > 0 then
                col = 0
                row = row + 1
            end
            row = row + 0.5
        end

        -- Get slot count for this bag
        local numSlots
        if isOtherChar and bag and bag.numSlots then
            numSlots = bag.numSlots
        else
            numSlots = addon.Modules.Utils:GetBagSlotCount(bagID)
        end

        if numSlots and numSlots > 0 then
            for slot = 1, numSlots do
                local itemData = bag and bag.slots and bag.slots[slot] or nil

                local matchesFilter = self:PassesSearchFilter(itemData)

                -- Ensure a per-bag parent frame exists and carries the bag ID
                local bankBagParent = self:GetBagParent(bagID)

                local button = Guda_GetItemButton(bankBagParent)
                if button.isBagSlot then break end

                button.inUse = true

                local xPos = x + (col * (buttonSize + spacing))
                local yPos = y - (row * (buttonSize + spacing))

                button:ClearAllPoints()
                button:SetPoint("TOPLEFT", itemContainer, "TOPLEFT", xPos, yPos)

                Guda_ItemButton_SetItem(button, bagID, slot, itemData, true, isOtherChar and charName or nil, matchesFilter, isReadOnlyMode)

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
end

-- Resize bank frame based on number of rows and columns
function BankFrame:ResizeFrame(currentRow, currentCol, columns, overrideHeight)
    local buttonSize = addon.Modules.DB:GetSetting("iconSize") or addon.Constants.BUTTON_SIZE
    local spacing = addon.Modules.DB:GetSetting("iconSpacing") or addon.Constants.BUTTON_SPACING

    -- Calculate actual number of rows used
    local totalRows = (currentRow or 0) + 1
    if totalRows < 1 then
        totalRows = 1
    end

    -- Ensure at least 1 column
    if not columns or columns < 1 then
        columns = 1
    end

    -- Calculate required dimensions
    local containerWidth = (columns * (buttonSize + spacing)) + 10
    local containerHeight = overrideHeight or ((totalRows * (buttonSize + spacing)) + 20)
    local frameWidth = containerWidth + 30

    -- Check if search bar is visible
    local showSearchBar = addon.Modules.DB:GetSetting("showSearchBar")
    if showSearchBar == nil then
        showSearchBar = true
    end

    -- Adjust frame height based on search bar visibility
    -- Footer height varies: less space when search bar is hidden
    local titleHeight = 40
    local searchBarHeight = 30
    local footerHeight = 40
    local frameHeight

    local hideFooter = addon.Modules.DB:GetSetting("hideFooter")

    if hideFooter then
        footerHeight = 10 -- Small padding at bottom
        frameHeight = containerHeight + titleHeight + (showSearchBar and searchBarHeight or 0) + footerHeight
    elseif showSearchBar then
        frameHeight = containerHeight + titleHeight + searchBarHeight + footerHeight  -- 125 total
    else
        frameHeight = containerHeight + titleHeight + footerHeight  -- 80 total
    end

    -- Minimum sizes
    if containerWidth < 200 then
        containerWidth = 200
        frameWidth = 230
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
        frameWidth = 1280
    end
    if containerHeight > 1000 then
        containerHeight = 1000
    end
    if frameHeight > 1200 then
        frameHeight = 1200
    end

    local bankFrame = getglobal("Guda_BankFrame")
    local itemContainer = getglobal("Guda_BankFrame_ItemContainer")

    if bankFrame then
        bankFrame:SetWidth(frameWidth)
        bankFrame:SetHeight(frameHeight)
    end

    if itemContainer then
        itemContainer:SetWidth(containerWidth)
        itemContainer:SetHeight(containerHeight)
    end

    -- Resize search bar to match container width
    local searchBar = getglobal("Guda_BankFrame_SearchBar")
    if searchBar then
        searchBar:SetWidth(containerWidth)
    end
end

-- Update bank slots info text
function BankFrame:UpdateBankSlotsInfo(bankData, isOtherChar)
    local infoText = getglobal("Guda_BankFrame_Toolbar_BankSlotsInfo_Text")
    if not infoText then return end

    local totalSlots = 0
    local usedSlots = 0

    -- Count slots in bank bags
    for _, bagID in ipairs(addon.Constants.BANK_BAGS) do
        local bag = bankData[bagID]

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

-- Update money display
function BankFrame:UpdateMoney()
    local hideFooter = addon.Modules.DB:GetSetting("hideFooter")
    local moneyFrame = getglobal("Guda_BankFrame_MoneyFrame")

    if hideFooter then
        if moneyFrame then moneyFrame:Hide() end
        return
    end

    if not moneyFrame then
        addon:Debug("Bank MoneyFrame not found! Checking parent...")
        addon:Debug("Guda_BankFrame exists: " .. tostring(getglobal("Guda_BankFrame") ~= nil))

        -- Try to create it manually
        self:CreateMoneyFrame()
        moneyFrame = getglobal("Guda_BankFrame_MoneyFrame")
    end

    if moneyFrame then
        MoneyFrame_Update("Guda_BankFrame_MoneyFrame", GetMoney())
        moneyFrame:Show()

        -- Ensure tooltip overlay exists
        self:EnsureMoneyTooltipOverlay()
    else
        addon:Debug("Still couldn't find or create Bank MoneyFrame!")
    end
end

-- Create MoneyFrame if it doesn't exist
function BankFrame:CreateMoneyFrame()
    local moneyFrame = CreateFrame("Frame", "Guda_BankFrame_MoneyFrame", Guda_BankFrame, "SmallMoneyFrameTemplate")
    moneyFrame:SetPoint("BOTTOMRIGHT", Guda_BankFrame, "BOTTOMRIGHT", -10, 10)
    moneyFrame:SetWidth(180)
    moneyFrame:SetHeight(35)

    -- Set up OnLoad handler
    Guda_BankFrame_MoneyFrame_OnLoad(moneyFrame)

    addon:Debug("Bank MoneyFrame created via CreateMoneyFrame")
end

-- Money frame OnLoad handler
function Guda_BankFrame_MoneyFrame_OnLoad(self)
    addon:Debug("Bank MoneyFrame OnLoad called for: " .. self:GetName())

    -- Set tooltip handlers on money denomination buttons
    local buttons = {"GoldButton", "SilverButton", "CopperButton"}

    for _, buttonName in ipairs(buttons) do
        local fullName = self:GetName() .. buttonName
        local button = getglobal(fullName)
        if button then
            button:SetScript("OnEnter", function()
                Guda_BankFrame_MoneyOnEnter(this:GetParent())
            end)
            button:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        end
    end

    -- Also set handlers on parent frame
    self:EnableMouse(true)
    self:SetScript("OnEnter", function()
        Guda_BankFrame_MoneyOnEnter(this)
    end)
    self:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

-- Money tooltip handler
function Guda_BankFrame_MoneyOnEnter(self)
    if not self then return end

    -- Anchor tooltip to TOPRIGHT
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

-- Create transparent overlay for money tooltip
function BankFrame:EnsureMoneyTooltipOverlay()
    local overlayName = "Guda_BankFrame_MoneyTooltipOverlay"
    local overlay = getglobal(overlayName)

    if not overlay then
        local moneyFrame = getglobal("Guda_BankFrame_MoneyFrame")
        if not moneyFrame then return end

        -- Create transparent overlay frame
        overlay = CreateFrame("Frame", overlayName, moneyFrame)
        overlay:SetAllPoints(moneyFrame)
        overlay:SetFrameLevel(moneyFrame:GetFrameLevel() + 1)
        overlay:EnableMouse(true)

        -- Set tooltip handlers on overlay
        overlay:SetScript("OnEnter", function()
            Guda_BankFrame_MoneyOnEnter(moneyFrame)
        end)

        overlay:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        addon:Debug("Bank money tooltip overlay created")
    end

    overlay:Show()
end

-- Check if search is currently active
function BankFrame:IsSearchActive()
    return searchText and searchText ~= "" and searchText ~= "Search bank..."
end

-- Check if item passes search filter (pfUI style)
function BankFrame:PassesSearchFilter(itemData)
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
    end

    if not itemName then
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
    return string.find(itemName, search, 1, true) ~= nil
end

-- Search changed handler
function Guda_BankFrame_OnSearchChanged(self)
    local text = self:GetText()
    -- Ignore placeholder text
    if text == "Search bank..." then
        text = ""
    end
    if text ~= searchText then
        searchText = text
        BankFrame:Update()
    end
end

-- Clear bank search and restore placeholder
function Guda_BankFrame_ClearSearch()
    local searchBox = getglobal("Guda_BankFrame_SearchBar_SearchBox")
    if searchBox then
        searchBox:SetText("Search bank...")
        searchBox:SetTextColor(0.5, 0.5, 0.5, 1)
        if searchBox.ClearFocus then searchBox:ClearFocus() end
    end

    -- Reset search state
    searchText = ""

    -- Update display
    BankFrame:Update()

    -- Hide click catcher if present
    if bankClickCatcher and bankClickCatcher.Hide then
        bankClickCatcher:Hide()
    end
end

-- Bank button handler
function Guda_BankFrame_Sort()
	if isReadOnlyMode or currentViewChar then
		addon:Print("Cannot sort in read-only mode!")
		return
	end

	if not addon.Modules.BankScanner:IsBankOpen() then
		addon:Print("Bank must be open to sort!")
		return
	end

 local success, message = addon.Modules.SortEngine:ExecuteSort(
        function() return addon.Modules.SortEngine:SortBankPass() end,
        function() return addon.Modules.SortEngine:AnalyzeBank() end,
        function() BankFrame:Update() end,
        "bank"
    )

	if not success and message == "already sorted" then
		addon:Print("Bank is already sorted!")
	end
end

-- Switch to Blizzard bank UI
function Guda_BankFrame_SwitchToBlizzardUI()
    -- Hide custom bank frame
    local customBankFrame = getglobal("Guda_BankFrame")
    if customBankFrame then
        customBankFrame:Hide()
    end

    -- Restore Blizzard bank frame
    local blizzardBankFrame = getglobal("BankFrame")
    if blizzardBankFrame then
        blizzardBankFrame:SetScale(1.0)
        blizzardBankFrame:SetAlpha(1.0)
        blizzardBankFrame:ClearAllPoints()
        blizzardBankFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104)
        blizzardBankFrame:Show()
        
        -- Show the Guda button if it exists
        BankFrame:ShowGudaButton()
    end
end

-- Switch from Blizzard bank UI back to Guda UI
function Guda_BankFrame_SwitchToGudaUI()
    -- Hide Blizzard bank frame visually (but keep it functional)
    local blizzardBankFrame = getglobal("BankFrame")
    if blizzardBankFrame then
        blizzardBankFrame:SetScale(0.001)
        blizzardBankFrame:SetPoint("TOPLEFT", 0, 0)
        blizzardBankFrame:SetAlpha(0)
    end
    
    -- Hide the Guda button
    local gudaButton = getglobal("BankFrame_GudaButton")
    if gudaButton then
        gudaButton:Hide()
    end

    -- Show custom bank frame
    local customBankFrame = getglobal("Guda_BankFrame")
    if customBankFrame then
        customBankFrame:Show()
    end

    -- Update the custom bank frame in interactive mode
    BankFrame:ShowCurrentCharacter()
    
    addon:Print("Switched to Guda bank UI")
end

-- Create button on Blizzard BankFrame to switch to Guda UI
function BankFrame:CreateGudaButtonOnBlizzardUI()
    local blizzardBankFrame = getglobal("BankFrame")
    if not blizzardBankFrame then return end

    -- Check if button already exists
    if getglobal("BankFrame_GudaButton") then return end

    -- Create the button next to close button
    local gudaButton = CreateFrame("Button", "BankFrame_GudaButton", blizzardBankFrame)
    gudaButton:SetWidth(20)
    gudaButton:SetHeight(20)
    
    -- Position next to close button (to the left of it)
    local closeButton = getglobal("BankFrameCloseButton")
    if closeButton then
        gudaButton:SetPoint("RIGHT", closeButton, "LEFT", -2, 0)
    else
        gudaButton:SetPoint("TOPRIGHT", blizzardBankFrame, "TOPRIGHT", -61, -14)
    end

    -- Create button texture
    local texture = gudaButton:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints(gudaButton)
    texture:SetTexture("Interface\\AddOns\\Guda\\Assets\\Chest")
    texture:SetTexCoord(0, 1, 0, 1)

    -- Create highlight texture
    local highlight = gudaButton:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(gudaButton)
    highlight:SetTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    highlight:SetBlendMode("ADD")

    -- Set scripts
    gudaButton:SetScript("OnClick", function()
        Guda_BankFrame_SwitchToGudaUI()
    end)

    gudaButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:SetText("Use Guda Bank UI")
        GameTooltip:Show()
    end)

    gudaButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Initially hide the button
    gudaButton:Hide()
    
end

-- Show the Guda button on Blizzard UI
function BankFrame:ShowGudaButton()
    local gudaButton = getglobal("BankFrame_GudaButton")
    if gudaButton then
        gudaButton:Show()
    end
end

-- Ensure bank bag buttons are present; create them if XML did not
function BankFrame:EnsureBagButtonsInitialized()
    local toolbar = getglobal("Guda_BankFrame_Toolbar")
    if not toolbar then return end

    local function ensureButton(suffix, bagID)
        local name = "Guda_BankFrame_Toolbar_" .. suffix
        local btn = getglobal(name)
        if not btn then
            btn = CreateFrame("Button", name, toolbar, "ItemButtonTemplate")
            -- Anchor sequenced to the left; position similar to XML
            if suffix == "BankBagMain" then
                btn:SetWidth(24)
                btn:SetHeight(24)
                btn:SetPoint("LEFT", toolbar, "LEFT", 13, 0)
            else
                -- Determine previous button
                local prev
                if bagID == 5 then prev = getglobal("Guda_BankFrame_Toolbar_BankBagMain")
                else prev = getglobal("Guda_BankFrame_Toolbar_BankBag"..tostring(bagID-1)) end
                btn:SetWidth(24)
                btn:SetHeight(24)
                if prev then
                    btn:SetPoint("LEFT", prev, "RIGHT", 2, 0)
                else
                    btn:SetPoint("LEFT", toolbar, "LEFT", 13, 0)
                end
            end

            -- Hook mouseover tooltip like XML
            btn:SetScript("OnEnter", function()
                Guda_BankBagSlot_OnEnter(this, bagID)
                Guda_BankFrame_HighlightBagSlots(bagID)
            end)
            btn:SetScript("OnLeave", function()
                GameTooltip:Hide()
                Guda_BankFrame_ClearHighlightedSlots()
            end)
            -- Handle clicks (Right-Click toggles visibility)
            if btn.RegisterForClicks then
                btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            end
            btn:SetScript("OnClick", function()
                Guda_BankBagSlot_OnClick(this, bagID, arg1)
            end)
            
            -- Enable dragging with left button
            if btn.RegisterForDrag then
                btn:RegisterForDrag("LeftButton")
            end
            btn:SetScript("OnDragStart", function()
                Guda_BankBagSlot_OnDragStart(this, bagID)
            end)
            btn:SetScript("OnDragStop", function()
                Guda_BankBagSlot_OnDragStop(this, bagID)
            end)
            
            -- Accept drops to equip bag into this slot
            btn:SetScript("OnReceiveDrag", function()
                Guda_BankBagSlot_OnReceiveDrag(this, bagID)
            end)
        end

        -- Run our OnLoad logic (will also register events and initial update)
        Guda_BankBagSlot_OnLoad(btn, bagID)
        return btn
    end

    -- Main (-1) and 5..10
    ensureButton("BankBagMain", -1)
    for bagID=5,10 do
        ensureButton("BankBag"..tostring(bagID), bagID)
    end
end

-- Helper: map bank bagID (5..10) to bankButtonID (1..6) and inventory slot id (Vanilla requires second arg = 1)
function BankFrame:GetBankInvSlotForBagID(bagID)
    if not bagID or bagID == -1 then return nil, nil end
    local bankButtonID = bagID - 4
    -- TurtleWoW (and your environment) expect passing bagID (5..10) with isBank=1
    local invSlot = BankButtonIDToInvSlotID(bagID, 1)
    return invSlot, bankButtonID
end

-- Update border visibility based on setting
function BankFrame:UpdateBorderVisibility()
    if not addon or not addon.Modules or not addon.Modules.DB then return end

    local frame = getglobal("Guda_BankFrame")
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
function BankFrame:UpdateSearchBarVisibility()
    if not addon or not addon.Modules or not addon.Modules.DB then return end

    local searchBar = getglobal("Guda_BankFrame_SearchBar")
    local itemContainer = getglobal("Guda_BankFrame_ItemContainer")
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
        itemContainer:SetPoint("TOP", "Guda_BankFrame", "TOP", 0, -40)
    end
end

-- Update footer visibility based on settings
function BankFrame:UpdateFooterVisibility()
    local hideFooter = addon.Modules.DB:GetSetting("hideFooter")
    local toolbar = getglobal("Guda_BankFrame_Toolbar")
    local moneyFrame = getglobal("Guda_BankFrame_MoneyFrame")

    if hideFooter then
        if toolbar then toolbar:Hide() end
        if moneyFrame then moneyFrame:Hide() end
    else
        if toolbar then toolbar:Show() end
        if moneyFrame then moneyFrame:Show() end
        
        -- Trigger layout updates to ensure they are correctly positioned
        self:UpdateMoney()
    end
end

-- Initialize
function BankFrame:Initialize()
    -- Hide Blizzard bank frame on load (pfUI style)
    local blizzardBankFrame = getglobal("BankFrame")
    if blizzardBankFrame then
        blizzardBankFrame:SetScale(0.001)
        blizzardBankFrame:SetPoint("TOPLEFT", 0, 0)
        blizzardBankFrame:SetAlpha(0)
    end
    
    -- Create Guda button on Blizzard BankFrame
    self:CreateGudaButtonOnBlizzardUI()

    -- Ensure our bank bag buttons exist even if XML failed to create them
    if self.EnsureBagButtonsInitialized then
        self:EnsureBagButtonsInitialized()
    end

    -- Update when bank is opened
    addon.Modules.Events:OnBankOpen(function()
        -- Delay showing custom bank to let TransmogUI finish processing
        local frame = CreateFrame("Frame")
        local elapsed = 0
        frame:SetScript("OnUpdate", function()
            elapsed = elapsed + arg1
            if elapsed >= 0.2 then
                frame:SetScript("OnUpdate", nil)

                -- Show current character's bank in interactive mode
                currentViewChar = nil

                -- Do not auto-hide BagFrame when opening BankFrame
                -- Previously, we hid BagFrame to prevent button overlap:
                -- local bagFrame = getglobal("Guda_BagFrame")
                -- if bagFrame and bagFrame:IsShown() then
                --     bagFrame:Hide()
                -- end
                -- Users may want both frames visible simultaneously; layout issues, if any,
                -- should be addressed via positioning rather than auto-hiding.

                -- Show and update custom bank frame
                local customBankFrame = getglobal("Guda_BankFrame")
                if customBankFrame then
                    customBankFrame:Show()
                end

                -- Force disable pfUI banks if enabled (pfUI uses pfBank for its bank frame)
                if pfUI and pfUI.bag and pfUI.bag.left and pfUI.bag.left.Hide then
                    pfUI.bag.left:Hide()
                end

                addon.Modules.BankFrame:EnsureBagButtonsInitialized()
                addon.Modules.BankFrame:Update()
            end
        end)
    end, "BankFrameUI")

    -- Hide custom bank when bank is closed
    addon.Modules.Events:OnBankClose(function()
        local customBankFrame = getglobal("Guda_BankFrame")
        if customBankFrame and customBankFrame:IsShown() and not currentViewChar then
            -- Only auto-close if viewing current character's bank (not saved banks)
            customBankFrame:Hide()
        end
    end, "BankFrameUI")

    -- Update on bag changes while bank is open
    addon.Modules.Events:OnBagUpdate(function()
        if addon.Modules.BankScanner:IsBankOpen() and not currentViewChar then
            addon.Modules.BankFrame:Update()
        end
    end, "BankFrameUI")

    -- Update when items get locked/unlocked (for trading, mailing, etc.)
    addon.Modules.Events:Register("ITEM_LOCK_CHANGED", function()
        if addon.Modules.BankScanner:IsBankOpen() and not currentViewChar then
            addon.Modules.BankFrame:Update()
        end
    end, "BankFrameUI")

    -- Register bank-specific update events (pfUI style)
    local updateFrame = CreateFrame("Frame")
    updateFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
    updateFrame:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED")
    updateFrame:SetScript("OnEvent", function()
        if addon.Modules.BankScanner:IsBankOpen() and not currentViewChar then
            addon.Modules.BankFrame:Update()
        end
    end)

end

-- Bank Bag Slot Button Handlers

-- OnLoad handler for bank bag slot buttons
function Guda_BankBagSlot_OnLoad(button, bagID)
    -- Configure border and icon inset for consistent look with main bank bag
    local buttonName = button:GetName()

    -- Ensure the normal texture (border) is visible and uses the default quickslot border
    local normalTexture = getglobal(buttonName .. "NormalTexture")
    if normalTexture then
        normalTexture:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        normalTexture:ClearAllPoints()
        normalTexture:SetPoint("CENTER", button, "CENTER", 0, -1)
        normalTexture:SetWidth(35)
        normalTexture:SetHeight(35)
        normalTexture:Show()
    end

    -- If the template has an IconBorder, show it as well (some clients/templates provide this)
    local iconBorder = getglobal(buttonName .. "IconBorder")
    if iconBorder then
        iconBorder:Show()
    end

    -- Inset the icon slightly so equipped bag icons appear a bit smaller (match main bag feel)
    local icon = getglobal(buttonName .. "IconTexture") or getglobal(buttonName .. "Icon")
    if icon then
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
        icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end

    -- Mark this as a bag slot button, NOT an item button
    button.isBagSlot = true
    button.hasItem = nil

    -- Set up the button with proper ID
    button.bagID = bagID

    -- Set the inventory slot ID so the button knows which slot it represents
    if bagID ~= -1 then
        local invSlot = addon.Modules.BankFrame:GetBankInvSlotForBagID(bagID)
        if invSlot then
            button:SetID(invSlot)
        end
    end

    -- Register for updates
    button:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED")
    button:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
    button:RegisterEvent("ITEM_LOCK_CHANGED")
    button:RegisterEvent("PLAYER_MONEY")
    button:RegisterEvent("CURSOR_UPDATE")
    button:RegisterEvent("UNIT_INVENTORY_CHANGED")
    button:SetScript("OnEvent", function()
        Guda_BankBagSlot_Update(this, this.bagID)
    end)

    -- Ensure we respond to right-click for hide/show
    if button.RegisterForClicks then
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    end
    button:SetScript("OnClick", function()
        Guda_BankBagSlot_OnClick(this, this.bagID, arg1)
    end)

    -- Enable dragging with left button
    if button.RegisterForDrag then
        button:RegisterForDrag("LeftButton")
    end
    button:SetScript("OnDragStart", function()
        Guda_BankBagSlot_OnDragStart(this, this.bagID)
    end)
    button:SetScript("OnDragStop", function()
        Guda_BankBagSlot_OnDragStop(this, this.bagID)
    end)

    -- Accept drops to equip bag into this slot
    button:SetScript("OnReceiveDrag", function()
        Guda_BankBagSlot_OnReceiveDrag(this, this.bagID)
    end)

    -- Initial update
    Guda_BankBagSlot_Update(button, bagID)
end

-- Update bank bag slot button texture
function Guda_BankBagSlot_Update(button, bagID)
    local isHidden = hiddenBankBags[bagID]

    if bagID == -1 then
        -- Main bank bag - use bank icon
        SetItemButtonTexture(button, "Interface\\Buttons\\Button-Backpack-Up")
        -- Dim if hidden
        if isHidden then
            SetItemButtonTextureVertexColor(button, 0.4, 0.4, 0.4)
        else
            SetItemButtonTextureVertexColor(button, 1.0, 1.0, 1.0)
        end
        button:Show()
        return
    end

    -- Bank bag slots 5-10 correspond to bank buttons 1-6
    local bankButtonID = bagID - 4
    -- Centralized mapping to inventory slot (TurtleWoW: pass bagID; helper also returns bankButtonID)
    local invSlot = BankFrame:GetBankInvSlotForBagID(bagID)

    -- Check if this slot is purchased
    local numSlots = GetNumBankSlots()
    local isPurchased = (bankButtonID <= numSlots)

    -- Get bag texture directly from inventory (more reliable on 1.12)
    local texture = invSlot and GetInventoryItemTexture("player", invSlot) or nil


    if texture then
        -- Bag is equipped in this slot and we have the texture
        SetItemButtonTexture(button, texture)
        -- Dim if hidden
        if isHidden then
            SetItemButtonTextureVertexColor(button, 0.4, 0.4, 0.4)
        else
            SetItemButtonTextureVertexColor(button, 1.0, 1.0, 1.0)
        end

        -- Set texture coordinates to crop the icon (1.12 uses IconTexture)
        local icon = getglobal(button:GetName() .. "IconTexture") or getglobal(button:GetName() .. "Icon")
        if icon then
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end

        button:Show()
    elseif isPurchased then
        -- Slot is purchased but no bag equipped
        SetItemButtonTexture(button, "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
        SetItemButtonTextureVertexColor(button, 1.0, 1.0, 1.0)
        button:Show()
    else
        -- Slot not purchased - show locked/greyed placeholder
        SetItemButtonTexture(button, "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
        SetItemButtonTextureVertexColor(button, 0.5, 0.5, 0.5)
        button:Show()
    end
end

-- OnClick handler for bank bag slots
function Guda_BankBagSlot_OnClick(button, bagID, which)
    local which = which or arg1 -- Vanilla uses global arg1 for mouse button name

    -- Handle main bank container (bagID -1)
    if bagID == -1 then
        if which == "RightButton" then
            -- Toggle visibility for main bank container
            hiddenBankBags[bagID] = not hiddenBankBags[bagID]
            Guda_BankBagSlot_Update(button, bagID)
            BankFrame:Update()
        end
        return
    end

    if bagID and bagID ~= -1 then
        local invSlot, bankButtonID = BankFrame:GetBankInvSlotForBagID(bagID)
        if invSlot and bankButtonID then
            local numSlots = GetNumBankSlots()
            local isPurchased = (bankButtonID <= numSlots)
            local hasCursorItem = CursorHasItem()

            -- Handle unpurchased slots: both left and right click show purchase dialog
            if not isPurchased then
                if not hasCursorItem then
                    -- Show purchase dialog for both left and right click
                    local cost = GetBankSlotCost(numSlots)
                    local gudaBankFrame = getglobal("Guda_BankFrame")
                    if gudaBankFrame then
                        gudaBankFrame.nextSlotCost = cost
                    end
                    StaticPopup_Show("CONFIRM_BUY_BANK_SLOT")
                end
                return
            end

            -- Handle purchased slots
            if which == "RightButton" then
                -- Toggle visibility for purchased slots
                hiddenBankBags[bagID] = not hiddenBankBags[bagID]
                Guda_BankBagSlot_Update(button, bagID)
                BankFrame:Update()
                return
            end

            if which == "LeftButton" then
                if hasCursorItem then
                    -- Equip bag from cursor into this purchased bank bag slot
                    EquipCursorItem(invSlot)
                    Guda_BankBagSlot_Update(button, bagID)
                    BankFrame:Update()
                end
                return
            end
        end
    end
end

-- OnEnter handler for tooltip
function Guda_BankBagSlot_OnEnter(button, bagID)
    GameTooltip:SetOwner(button, "ANCHOR_TOP")

    if bagID == -1 then
        -- Main bank bag tooltip
        GameTooltip:SetText("Bank", 1.0, 1.0, 1.0)
        local numSlots = 24
        GameTooltip:AddLine(string.format("%d Slots", numSlots), 0.8, 0.8, 0.8)
        if hiddenBankBags[bagID] then
            GameTooltip:AddLine("(Hidden - Right-Click to show)", 0.8, 0.5, 0.5)
        else
            GameTooltip:AddLine("(Right-Click to hide)", 0.5, 0.8, 0.5)
        end
    else
        local invSlot, bankButtonID = BankFrame:GetBankInvSlotForBagID(bagID)
        local numSlots = GetNumBankSlots()
        local isPurchased = (bankButtonID and bankButtonID <= numSlots)
        local hasItem = invSlot and GetInventoryItemTexture("player", invSlot)

        if hasItem then
            -- Show bag item tooltip (with hide/show text)
            GameTooltip:SetInventoryItem("player", invSlot)
            if hiddenBankBags[bagID] then
                GameTooltip:AddLine("(Hidden - Right-Click to show)", 0.8, 0.5, 0.5)
            else
                GameTooltip:AddLine("(Right-Click to hide)", 0.5, 0.8, 0.5)
            end
            -- Reset cursor for purchased slots with items
            ResetCursor()
        elseif isPurchased then
            -- Empty purchased slot (no hide/show text, no purchase cursor)
            GameTooltip:SetText(string.format("Bank Bag Slot %d", bankButtonID or -1), 1.0, 1.0, 1.0)
            GameTooltip:AddLine("Empty", 0.8, 0.8, 0.8)
            -- Reset cursor for empty purchased slots
            ResetCursor()
        else
            -- Unpurchased slot (no hide/show text, show purchase cursor)
            GameTooltip:SetText(string.format("Bank Bag Slot %d", bankButtonID or -1), 1.0, 1.0, 1.0)
            local cost = GetBankSlotCost(numSlots)
            GameTooltip:AddLine(addon.Modules.Utils:FormatMoney(cost, false, true), 1, 1, 1)
            -- Show purchase cursor (coin icon)
            SetCursor("BUY_CURSOR")
        end
    end

    GameTooltip:Show()
end

-- OnLeave handler for bank bag slots
function Guda_BankBagSlot_OnLeave(button, bagID)
    GameTooltip:Hide()
    ResetCursor()
end

-- Highlight all item slots belonging to a specific bank bag by dimming others
function Guda_BankFrame_HighlightBagSlots(bagID)
    -- Buttons are parented under per-bag parents, not directly under the item container
    local highlightCount, dimCount = 0, 0

    for _, bankBagParent in pairs(bankBagParents) do
        if bankBagParent then
            local children = { bankBagParent:GetChildren() }
            for _, button in ipairs(children) do
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
    end

    if addon and addon.Debug then
        addon:Debug(string.format("BankFrame HighlightBagSlots: Highlighted %d slots, dimmed %d slots for bagID %d", highlightCount, dimCount, bagID))
    end
end

-- Clear all highlighting by restoring full opacity to all slots
function Guda_BankFrame_ClearHighlightedSlots()
    -- Restore alpha to search-filter state (pfUI style). If no search, full opacity.
    local searchActive = BankFrame and BankFrame.IsSearchActive and BankFrame:IsSearchActive()

    for _, bankBagParent in pairs(bankBagParents) do
        if bankBagParent then
            local children = { bankBagParent:GetChildren() }
            for _, button in ipairs(children) do
                if button and button:IsShown() and button.hasItem ~= nil and not button.isBagSlot then
                    if searchActive and BankFrame and BankFrame.PassesSearchFilter then
                        local matches = BankFrame:PassesSearchFilter(button.itemData)
                        button:SetAlpha(matches and 1.0 or 0.25)
                    else
                        button:SetAlpha(1.0)
                    end
                end
            end
        end
    end
end

-- Highlight a specific bank bag button in the toolbar
function Guda_BankFrame_HighlightBagButton(bagID)
    if not bagID then return end

    local buttonName
    if bagID == -1 then
        -- Main bank container
        buttonName = "Guda_BankFrame_Toolbar_BankBagMain"
    else
        -- Bank bags are bagID 5-10
        buttonName = "Guda_BankFrame_Toolbar_BankBag" .. bagID
    end

    local button = getglobal(buttonName)
    if button then
        button:LockHighlight()
    end
end

-- Clear bank bag button highlighting
function Guda_BankFrame_ClearBagButtonHighlight()
    -- Clear highlight from main bank button
    local mainButton = getglobal("Guda_BankFrame_Toolbar_BankBagMain")
    if mainButton then
        mainButton:UnlockHighlight()
    end

    -- Clear highlight from bank bag buttons (5-10)
    for bagID = 5, 10 do
        local buttonName = "Guda_BankFrame_Toolbar_BankBag" .. bagID
        local button = getglobal(buttonName)
        if button then
            button:UnlockHighlight()
        end
    end
end

-- Bank character dropdown (similar to BagFrame's bank dropdown)
local bankCharDropdown

function Guda_BankFrame_ToggleBankDropdown(button)
    if bankCharDropdown and bankCharDropdown:IsShown() then
        bankCharDropdown:Hide()
        return
    end

    if not bankCharDropdown then
        -- Create dropdown frame
        bankCharDropdown = CreateFrame("Frame", "Guda_BankCharDropdown", UIParent)
        bankCharDropdown:SetFrameStrata("DIALOG")
        bankCharDropdown:SetWidth(200)
        bankCharDropdown:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        bankCharDropdown:SetBackdropColor(0, 0, 0, 0.95)
        bankCharDropdown:EnableMouse(true)
        bankCharDropdown:Hide()

        bankCharDropdown.buttons = {}
    end

    -- Position dropdown below the button
    bankCharDropdown:ClearAllPoints()
    bankCharDropdown:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)

    -- Clear existing buttons
    for _, btn in ipairs(bankCharDropdown.buttons) do
        btn:Hide()
    end
    bankCharDropdown.buttons = {}

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

        local charButton = CreateFrame("Button", nil, bankCharDropdown)
        charButton:SetWidth(188)
        charButton:SetHeight(20)
        charButton:SetPoint("TOP", bankCharDropdown, "TOP", 0, yOffset)

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
                -- Show bank for this character using the BankFrame module
                addon.Modules.BankFrame:ShowCharacter(charFullName)
                bankCharDropdown:Hide()
            else
                addon:Print("Error: Character fullName is nil")
            end
        end)

        table.insert(bankCharDropdown.buttons, charButton)
        yOffset = yOffset - 20
    end

    -- Set dropdown height based on content
    bankCharDropdown:SetHeight(math.abs(yOffset) + 8)

    -- Show dropdown
    bankCharDropdown:Show()
end

-- Drag handlers for bank bag slots
function Guda_BankBagSlot_OnDragStart(button, bagID)
    if not bagID or bagID == -1 then return end
    if not addon.Modules.BankScanner:IsBankOpen() then return end

    local invSlot = addon.Modules.BankFrame:GetBankInvSlotForBagID(bagID)
    if not invSlot then return end

    local texture = GetInventoryItemTexture("player", invSlot)
    if texture then
        button:SetAlpha(0.6)
        PickupInventoryItem(invSlot)
        -- Instantly refresh visuals to reflect the slot is now on cursor
        Guda_BankBagSlot_Update(button, bagID)
        if BankFrame and BankFrame.Update then BankFrame:Update() end
    end
end

function Guda_BankBagSlot_OnDragStop(button, bagID)
    button:SetAlpha(1.0)
end

function Guda_BankBagSlot_OnReceiveDrag(button, bagID)
    if not bagID or bagID == -1 then return end
    if not CursorHasItem or not CursorHasItem() then return end
    if not addon.Modules.BankScanner:IsBankOpen() then return end

    local invSlot, bankButtonID = addon.Modules.BankFrame:GetBankInvSlotForBagID(bagID)
    if not invSlot then return end

    local purchased = (bankButtonID and bankButtonID <= GetNumBankSlots())
    if not purchased then return end

    if EquipCursorItem then
        EquipCursorItem(invSlot)
    elseif PutItemInBag then
        PutItemInBag(invSlot)
    end

    Guda_BankBagSlot_Update(button, bagID)
    if BankFrame and BankFrame.Update then BankFrame:Update() end
end
