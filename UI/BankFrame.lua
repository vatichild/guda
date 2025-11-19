-- Bank Frame
-- Bank viewing UI

local addon = Guda

local BankFrame = {}
addon.Modules.BankFrame = BankFrame

local currentViewChar = nil
local searchText = ""
local isReadOnlyMode = false  -- Track if viewing saved bank (read-only) or live bank (interactive)
local hiddenBankBags = {} -- Track which bank bags are hidden (bagID -> true/false)

-- OnLoad
function Guda_BankFrame_OnLoad(self)
    -- Set up search box placeholder
    local searchBox = getglobal(self:GetName().."_SearchBar_SearchBox")
    if searchBox then
        searchBox:SetText("Search bank...")
        searchBox:SetTextColor(0.5, 0.5, 0.5, 1)
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

    BankFrame:Update()
end

-- OnHide
function Guda_BankFrame_OnHide(self)
    -- Only release buttons that belong to this frame
    local itemContainer = getglobal("Guda_BankFrame_ItemContainer")
    if itemContainer then
        -- Hide only the buttons that are children of this container
        local children = { itemContainer:GetChildren() }
        for _, child in ipairs(children) do
            if child.hasItem ~= nil then -- It's an item button
                child:Hide()
                child:ClearAllPoints()
            end
        end
    end
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

-- Update display
function BankFrame:Update()
    if not Guda_BankFrame:IsShown() then
        return
    end

    -- Only release buttons that belong to this frame
    local itemContainer = getglobal("Guda_BankFrame_ItemContainer")
    if itemContainer then
        local children = { itemContainer:GetChildren() }
        for _, child in ipairs(children) do
            if child.hasItem ~= nil then -- It's an item button
                child:Hide()
                child:ClearAllPoints()
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
        getglobal("Guda_BankFrame_Title"):SetText("Bank - " .. currentViewChar)
    else
        -- Viewing current character's bank
        if bankIsOpen then
            -- Bank is actually open - use live data (interactive mode)
            bankData = addon.Modules.BankScanner:ScanBank()
            -- Use current character's name for the title
            local playerName = addon.Modules.DB:GetPlayerFullName()
            getglobal("Guda_BankFrame_Title"):SetText("Bank - " .. playerName)
        else
            -- Bank is closed - use saved data (read-only mode)
            local playerName = addon.Modules.DB:GetPlayerFullName()
            bankData = addon.Modules.DB:GetCharacterBank(playerName)
            getglobal("Guda_BankFrame_Title"):SetText("Bank - " .. playerName)
        end
    end

    self:DisplayItems(bankData, isOtherChar, charName)

    -- Update money
    self:UpdateMoney()

    -- Update bank slots info
    self:UpdateBankSlotsInfo(bankData, isOtherChar)
end

-- Display items
function BankFrame:DisplayItems(bankData, isOtherChar, charName)
    local x, y = 10, -10
    local row = 0
    local col = 0
    local buttonSize = addon.Modules.DB:GetSetting("iconSize") or addon.Constants.BUTTON_SIZE
    local spacing = addon.Modules.DB:GetSetting("iconSpacing") or addon.Constants.BUTTON_SPACING
    local perRow = addon.Modules.DB:GetSetting("bankColumns") or 10
    local itemContainer = getglobal("Guda_BankFrame_ItemContainer")

    for _, bagID in ipairs(addon.Constants.BANK_BAGS) do
        -- Skip bags that are hidden
        if not hiddenBankBags[bagID] then
            local bag = bankData[bagID]

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
            for slot = 1, numSlots do
                local itemData = bag and bag.slots and bag.slots[slot] or nil

                -- Check if item matches search filter
                local matchesFilter = self:PassesSearchFilter(itemData)

                local button = Guda_GetItemButton(itemContainer)

                -- Ensure this is NOT a bag slot button
                if button.isBagSlot then
                    break
                end

                -- Position button
                local xPos = x + (col * (buttonSize + spacing))
                local yPos = y - (row * (buttonSize + spacing))

                button:ClearAllPoints()
                button:SetPoint("TOPLEFT", itemContainer, "TOPLEFT", xPos, yPos)

                -- Set item data with filter match info
                -- Pass isReadOnlyMode to disable interaction for saved banks
                Guda_ItemButton_SetItem(button, bagID, slot, itemData, true, isOtherChar and charName or nil, matchesFilter, isReadOnlyMode)

                -- Advance position
                col = col + 1
                if col >= perRow then
                    col = 0
                    row = row + 1
                end
            end
            end
        end
    end

    -- Resize frame dynamically based on content
    self:ResizeFrame(row, col, perRow)
end

-- Resize bank frame based on number of rows and columns
function BankFrame:ResizeFrame(currentRow, currentCol, columns)
    local buttonSize = addon.Modules.DB:GetSetting("iconSize") or addon.Constants.BUTTON_SIZE
    local spacing = addon.Modules.DB:GetSetting("iconSpacing") or addon.Constants.BUTTON_SPACING

    -- Calculate actual number of rows used
    local totalRows = currentRow + 1
    if totalRows < 1 then
        totalRows = 1
    end

    -- Ensure at least 1 column
    if not columns or columns < 1 then
        columns = 1
    end

    -- Calculate required dimensions
    local containerWidth = (columns * (buttonSize + spacing)) + 20
    local containerHeight = (totalRows * (buttonSize + spacing)) + 20
    local frameWidth = containerWidth + 30
    local frameHeight = containerHeight + 100  -- Title (40) + search (30) + footer (30)

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
    if containerWidth > 800 then
        containerWidth = 800
        frameWidth = 830
    end
    if containerHeight > 600 then
        containerHeight = 600
    end
    if frameHeight > 800 then
        frameHeight = 800
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
    local moneyFrame = getglobal("Guda_BankFrame_MoneyFrame")

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
    moneyFrame:SetPoint("BOTTOMRIGHT", Guda_BankFrame, "BOTTOMRIGHT", -15, 7)
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

    -- Get all characters and total
    local chars = addon.Modules.DB:GetAllCharacters(true)
    local totalMoney = addon.Modules.DB:GetTotalMoney(true)

    -- Header with faction/realm total - use colored money
    GameTooltip:AddLine(
        "Faction/realm-wide gold: " .. addon.Modules.Utils:FormatMoney(totalMoney, false, true),
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
    itemName = string.lower(itemName)
    local search = string.lower(searchText)

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

-- Sort button handler with auto-repeat
function Guda_BankFrame_Sort()
    if isReadOnlyMode or currentViewChar then
        addon:Print("Cannot sort in read-only mode!")
        return
    end

    addon:Print("Sorting bank...")

    local passCount = 0
    local maxPasses = 10  -- Safety limit

    local function DoSortPass()
        passCount = passCount + 1

        -- Perform one sort pass
        local moveCount = addon.Modules.SortEngine:SortBank()

        -- If items were moved and we haven't hit the limit, do another pass
        if moveCount > 0 and passCount < maxPasses then
            -- Wait for items to settle, then sort again (longer delay for many items)
            local frame = CreateFrame("Frame")
            local elapsed = 0
            frame:SetScript("OnUpdate", function()
                elapsed = elapsed + arg1
                if elapsed >= 0.7 then
                    frame:SetScript("OnUpdate", nil)
                    DoSortPass()  -- Recursive call for next pass
                end
            end)
        else
            -- Sorting complete
            if passCount >= maxPasses then
                addon:Print("Bank sort complete! (reached max passes)")
            else
                addon:Print("Bank sort complete! (%d passes)", passCount)
            end

            -- Final update
            local frame = CreateFrame("Frame")
            local elapsed = 0
            frame:SetScript("OnUpdate", function()
                elapsed = elapsed + arg1
                if elapsed >= 0.7 then
                    frame:SetScript("OnUpdate", nil)
                    BankFrame:Update()
                end
            end)
        end
    end

    -- Start the first pass
    DoSortPass()
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
                btn:SetSize(24, 24)
                btn:SetPoint("LEFT", toolbar, "LEFT", 13, 0)
            else
                -- Determine previous button
                local prev
                if bagID == 5 then prev = getglobal("Guda_BankFrame_Toolbar_BankBagMain")
                else prev = getglobal("Guda_BankFrame_Toolbar_BankBag"..tostring(bagID-1)) end
                btn:SetSize(24, 24)
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

    if hideBorders then
        -- Hide decorative borders but add thin white border
        frame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 2,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        frame:SetBackdropColor(0, 0, 0, 0.9)
        frame:SetBackdropBorderColor(1, 1, 1, 1)
    else
        frame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        frame:SetBackdropColor(0, 0, 0, 0.9)
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

                -- Show and update custom bank frame
                local customBankFrame = getglobal("Guda_BankFrame")
                if customBankFrame then
                    customBankFrame:Show()
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
    local itemContainer = getglobal("Guda_BankFrame_ItemContainer")
    if not itemContainer then
        return
    end

    local highlightCount = 0
    local dimCount = 0

    -- Iterate through all children (item buttons)
    local children = { itemContainer:GetChildren() }
    for _, button in ipairs(children) do
        -- Check if this is an item button
        if button.hasItem ~= nil and button:IsShown() and not button.isBagSlot then
            if button.bagID == bagID then
                -- This button belongs to the hovered bag - keep it bright
                button:SetAlpha(1.0)
                highlightCount = highlightCount + 1
            else
                -- This button belongs to a different bag - dim it
                button:SetAlpha(0.25)
                dimCount = dimCount + 1
            end
        end
    end

    addon:Debug(string.format("BankFrame HighlightBagSlots: Highlighted %d slots, dimmed %d slots for bagID %d", highlightCount, dimCount, bagID))
end

-- Clear all highlighting by restoring full opacity to all slots
function Guda_BankFrame_ClearHighlightedSlots()
    local itemContainer = getglobal("Guda_BankFrame_ItemContainer")
    if not itemContainer then return end

    -- Iterate through all children (item buttons)
    local children = { itemContainer:GetChildren() }
    for _, button in ipairs(children) do
        -- Check if this is an item button
        if button.hasItem ~= nil and button:IsShown() and not button.isBagSlot then
            -- Restore full opacity
            button:SetAlpha(1.0)
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

    -- Get all characters
    local chars = addon.Modules.DB:GetAllCharacters(true)

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
