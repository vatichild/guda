-- Guda Bag Frame
-- Main bag viewing UI

local addon = Guda

local BagFrame = {}
addon.Modules.BagFrame = BagFrame

local currentViewChar = nil -- nil = current character
local searchText = ""
local itemButtons = {}

-- Global click catcher for clearing search focus
local clickCatcher = nil

-- OnLoad
function Guda_BagFrame_OnLoad(self)
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
            local searchBox = getglobal("Guda_BagFrame_SearchBar_SearchBox")
            if searchBox then
                searchBox:ClearFocus()
            end
        end)
    end

    addon:Debug("Bag frame loaded")
end


-- OnShow
function Guda_BagFrame_OnShow(self)
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
    BagFrame:Update()
end

-- OnHide
function Guda_BagFrame_OnHide(self)
    -- Release buttons
    Guda_ReleaseAllButtons()
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

-- Update display
function BagFrame:Update()
    if not Guda_BagFrame:IsShown() then
        return
    end

    -- Clear existing buttons
    Guda_ReleaseAllButtons()

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
    self:DisplayItems(bagData, isOtherChar, charName)

    -- Update money
    self:UpdateMoney()
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

    for _, bagID in ipairs(addon.Constants.BAGS) do
        -- Get slot count for this bag
        local numSlots = addon.Modules.Utils:GetBagSlotCount(bagID)

        -- Only show bags that have slots
        if numSlots and numSlots > 0 then
            local bag = bagData[bagID]

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
                Guda_ItemButton_SetItem(button, bagID, slot, itemData, false, isOtherChar and charName or nil, matchesFilter)

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
end

-- Resize frame based on number of rows and columns
function BagFrame:ResizeFrame(currentRow, currentCol, columns)
    local buttonSize = addon.Modules.DB:GetSetting("iconSize") or addon.Constants.BUTTON_SIZE
    local spacing = addon.Modules.DB:GetSetting("iconSpacing") or addon.Constants.BUTTON_SPACING

    -- Calculate actual number of rows used
    local totalRows = currentRow + 1

    -- Ensure at least 1 row
    if totalRows < 1 then
        totalRows = 1
    end

    -- Calculate required dimensions based on columns
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
    itemName = string.lower(itemName)
    local search = string.lower(searchText)

    -- Check if item name contains search text
    local matches = string.find(itemName, search, 1, true) ~= nil

    -- Debug: print first match found
    if matches and not self.foundFirstMatch then
        addon:Print("DEBUG: Found match! Item: '" .. itemName .. "' matches search: '" .. searchText .. "'")
        self.foundFirstMatch = true
    end

    return matches
end

-- Update money display
function BagFrame:UpdateMoney()
    local currentMoney = addon.Modules.MoneyTracker:GetCurrentMoney()
    local moneyFrame = getglobal("Guda_BagFrame_MoneyFrame")

    -- Current character money only
    if not moneyFrame.text then
        moneyFrame.text = moneyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        moneyFrame.text:SetPoint("CENTER", moneyFrame, "CENTER", 0, 0)
    end

    moneyFrame.text:SetText(addon.Modules.Utils:FormatMoney(currentMoney))
end

-- Money tooltip handler
function Guda_BagFrame_MoneyOnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:ClearLines()

    -- Get all characters and total
    local chars = addon.Modules.DB:GetAllCharacters(true)
    local totalMoney = addon.Modules.DB:GetTotalMoney(true)
    local currentPlayerName = addon.Modules.DB:GetPlayerFullName()

    -- Header with faction/realm total
    GameTooltip:AddLine("Faction/realm-wide gold:", 1, 0.82, 0, 1)
    GameTooltip:AddLine(addon.Modules.Utils:FormatMoney(totalMoney), 1, 1, 1, 1)
    GameTooltip:AddLine(" ")

    -- List each character
    for _, char in ipairs(chars) do
        local colorR, colorG, colorB = 0.7, 0.7, 0.7

        -- Highlight current character
        if char.fullName == currentPlayerName then
            colorR, colorG, colorB = 0, 1, 0.6
        end

        GameTooltip:AddDoubleLine(
            char.name,
            addon.Modules.Utils:FormatMoney(char.money or 0),
            colorR, colorG, colorB,
            1, 1, 1
        )
    end

    GameTooltip:Show()
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
        addon:Print("Search text changed to: '" .. (searchText or "empty") .. "'")
        BagFrame:Update()
    end
end

-- Sort button handler
function Guda_BagFrame_Sort()
    if currentViewChar then
        addon:Print("Cannot sort another character's bags!")
        return
    end

    addon.Modules.SortEngine:SortBags()

    -- Update after a delay to allow items to move
    local frame = CreateFrame("Frame")
    local elapsed = 0
    frame:SetScript("OnUpdate", function()
        elapsed = elapsed + arg1
        if elapsed >= 0.5 then
            frame:SetScript("OnUpdate", nil)
            BagFrame:Update()
        end
    end)
end

-- Hook to default bag opening
local function HookDefaultBags()
    -- Override ToggleBackpack
    local originalToggleBackpack = ToggleBackpack
    function ToggleBackpack()
        BagFrame:Toggle()
    end

    -- Override OpenAllBags
    local originalOpenAllBags = OpenAllBags
    function OpenAllBags()
        Guda_BagFrame:Show()
    end

    -- Override CloseAllBags
    local originalCloseAllBags = CloseAllBags
    function CloseAllBags()
        Guda_BagFrame:Hide()
    end
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

        -- Disable dragging on money frame (preserve tooltip handlers)
        if moneyFrame and moneyFrame.SetScript then
            moneyFrame:SetScript("OnMouseDown", function()
                local searchBox = getglobal("Guda_BagFrame_SearchBar_SearchBox")
                if searchBox then
                    searchBox:ClearFocus()
                end
            end)
            moneyFrame:SetScript("OnMouseUp", nil)
            -- Preserve tooltip handlers with safety checks
            moneyFrame:SetScript("OnEnter", function()
                if Guda_BagFrame_MoneyOnEnter and addon and addon.Modules and addon.Modules.DB and addon.Modules.Utils then
                    Guda_BagFrame_MoneyOnEnter(this)
                end
            end)
            moneyFrame:SetScript("OnLeave", function()
                if GameTooltip then
                    GameTooltip:Hide()
                end
            end)
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

        -- Enable dragging on money frame (preserve tooltip handlers)
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
            -- Preserve tooltip handlers with safety checks
            moneyFrame:SetScript("OnEnter", function()
                if Guda_BagFrame_MoneyOnEnter and addon and addon.Modules and addon.Modules.DB and addon.Modules.Utils then
                    Guda_BagFrame_MoneyOnEnter(this)
                end
            end)
            moneyFrame:SetScript("OnLeave", function()
                if GameTooltip then
                    GameTooltip:Hide()
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

-- Initialize
function BagFrame:Initialize()
    -- Hook default bag functions
    HookDefaultBags()

    -- Update on bag changes
    addon.Modules.Events:OnBagUpdate(function()
        if not currentViewChar then
            BagFrame:Update()
        end
    end, "BagFrame")

    -- Update on money changes
    addon.Modules.Events:OnMoneyChanged(function()
        BagFrame:UpdateMoney()
    end, "BagFrame")

    addon:Debug("Bag frame initialized")
end
