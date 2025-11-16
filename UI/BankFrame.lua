-- Guda Bank Frame
-- Bank viewing UI

local addon = Guda

local BankFrame = {}
addon.Modules.BankFrame = BankFrame

local currentViewChar = nil
local searchText = ""

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

-- Show specific character's bank
function BankFrame:ShowCharacter(fullName)
    currentViewChar = fullName
    self:Update()
end

-- Show current character's bank
function BankFrame:ShowCurrentCharacter()
    currentViewChar = nil
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

    local bankData
    local isOtherChar = false
    local charName = ""

    if currentViewChar then
        bankData = addon.Modules.DB:GetCharacterBank(currentViewChar)
        isOtherChar = true
        charName = currentViewChar
        getglobal("Guda_BankFrame_Title"):SetText("Bank - " .. currentViewChar)
    else
        bankData = addon.Modules.DB:GetCharacterBank(addon.Modules.DB:GetPlayerFullName())
        if not bankData or not next(bankData) then
            -- No saved bank data, use live scan if bank is open
            if addon.Modules.BankScanner:IsBankOpen() then
                bankData = addon.Modules.BankScanner:ScanBank()
            end
        end
        getglobal("Guda_BankFrame_Title"):SetText("Guda Bank")
    end

    self:DisplayItems(bankData, isOtherChar, charName)
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
                Guda_ItemButton_SetItem(button, bagID, slot, itemData, true, isOtherChar and charName or nil, matchesFilter)

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

-- Check if item passes search filter
function BankFrame:PassesSearchFilter(itemData)
    if searchText == "" or searchText == "Search..." then
        return true
    end

    if not itemData or not itemData.name then
        return false
    end

    return string.find(string.lower(itemData.name), string.lower(searchText)) ~= nil
end

-- Search changed handler
function Guda_BankFrame_OnSearchChanged(self)
    local text = self:GetText()
    if text ~= searchText then
        searchText = text
        BankFrame:Update()
    end
end

-- Sort button handler
function Guda_BankFrame_Sort()
    if currentViewChar then
        addon:Print("Cannot sort another character's bank!")
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

-- Initialize
function BankFrame:Initialize()
    -- Update when bank is opened
    addon.Modules.Events:OnBankOpen(function()
        BankFrame:Update()
    end, "BankFrameUI")

    -- Update on bag changes while bank is open
    addon.Modules.Events:OnBagUpdate(function()
        if addon.Modules.BankScanner:IsBankOpen() and not currentViewChar then
            BankFrame:Update()
        end
    end, "BankFrameUI")

    addon:Debug("Bank frame initialized")
end
