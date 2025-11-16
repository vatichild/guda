-- Bank Frame
-- Bank viewing UI

local addon = Guda

local BankFrame = {}
addon.Modules.BankFrame = BankFrame

local currentViewChar = nil
local searchText = ""
local isReadOnlyMode = false  -- Track if viewing saved bank (read-only) or live bank (interactive)

-- OnLoad
function Guda_BankFrame_OnLoad(self)
    -- Set up search box placeholder
    local searchBox = getglobal(self:GetName().."_SearchBar_SearchBox")
    if searchBox then
        searchBox:SetText("Search bank...")
        searchBox:SetTextColor(0.5, 0.5, 0.5, 1)
    end

    addon:Debug("Bank frame loaded")
end

-- OnShow
function Guda_BankFrame_OnShow(self)
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
    moneyFrame:SetPoint("BOTTOMRIGHT", Guda_BankFrame, "BOTTOMRIGHT", -15, 5)
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

-- Sort button handler
function Guda_BankFrame_Sort()
    if isReadOnlyMode or currentViewChar then
        addon:Print("Cannot sort in read-only mode!")
        return
    end

    addon.Modules.SortEngine:SortBank()

    local frame = CreateFrame("Frame")
    local elapsed = 0
    frame:SetScript("OnUpdate", function()
        elapsed = elapsed + arg1
        if elapsed >= 0.5 then
            frame:SetScript("OnUpdate", nil)
            BankFrame:Update()
        end
    end)
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
    gudaButton:SetWidth(15)
    gudaButton:SetHeight(15)
    
    -- Position next to close button (to the left of it)
    local closeButton = getglobal("BankFrameCloseButton")
    if closeButton then
        gudaButton:SetPoint("RIGHT", closeButton, "LEFT", -2, 0)
    else
        gudaButton:SetPoint("TOPRIGHT", blizzardBankFrame, "TOPRIGHT", -61, -17)
    end

    -- Create button texture
    local texture = gudaButton:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints(gudaButton)
    texture:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
    texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

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
    
    addon:Debug("Guda button created on Blizzard BankFrame")
end

-- Show the Guda button on Blizzard UI
function BankFrame:ShowGudaButton()
    local gudaButton = getglobal("BankFrame_GudaButton")
    if gudaButton then
        gudaButton:Show()
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

    addon:Debug("Bank frame initialized")
end