-- FrameHelpers: central utilities for frame headers and bag parents
local addon = Guda

local FrameHelpers = {}
addon.Modules.FrameHelpers = FrameHelpers

-- Create or return a section header for a given frame prefix and container
function Guda_GetSectionHeader(framePrefix, containerName, index)
    local name = framePrefix .. "_SectionHeader" .. index
    local header = getglobal(name)
    if not header then
        local container = getglobal(containerName)
        header = CreateFrame("Frame", name, container)
        header:SetHeight(20)
        header:EnableMouse(true)
        local text = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", header, "LEFT", 0, 0)
        header.text = text

        header:SetScript("OnEnter", function()
            if this.fullName and this.isShortened then
                GameTooltip:SetOwner(this, "ANCHOR_TOP")
                GameTooltip:SetText(this.fullName)
                GameTooltip:Show()
            end
        end)
        header:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end
    header.inUse = true
    return header
end

-- Create or return a bag parent frame for a frame prefix and bag parents table
function Guda_GetBagParent(framePrefix, parentsTable, bagID, containerName)
    local container = getglobal(containerName)
    if not parentsTable[bagID] then
        local name = framePrefix .. "_BagParent" .. bagID
        parentsTable[bagID] = CreateFrame("Frame", name, container)
        parentsTable[bagID]:SetAllPoints(container)
        if parentsTable[bagID].SetID then
            parentsTable[bagID]:SetID(bagID)
        end
    end
    return parentsTable[bagID]
end

-- Update lock/desaturation states for a table of parent frames
function Guda_UpdateLockStates(parentsTable)
    if not parentsTable then return end
    for _, parent in pairs(parentsTable) do
        if parent then
            local buttons = { parent:GetChildren() }
            for _, button in ipairs(buttons) do
                if button.hasItem ~= nil and button:IsShown() and button.bagID and button.slotID then
                    -- GetContainerItemInfo returns: texture, itemCount, locked, quality, readable
                    -- The 3rd return value is the lock state (boolean or nil)
                    local _, _, locked = GetContainerItemInfo(button.bagID, button.slotID)
                    if not button.otherChar and not button.isReadOnly and SetItemButtonDesaturated then
                        -- locked can be true/1 (locked) or nil/false (unlocked)
                        SetItemButtonDesaturated(button, locked, 0.5, 0.5, 0.5)
                    end
                end
            end
        end
    end
end

-- Shared search filter used by BagFrame and BankFrame
function Guda_PassesSearchFilter(itemData, searchText)
    -- If no search text, everything matches
    if not searchText or searchText == "" then
        return true
    end

    -- Ignore common placeholders
    if searchText == "Search, try ~equipment" or searchText == "Search bank..." then
        return true
    end

    -- Empty slots don't match when searching
    if not itemData then
        return false
    end

    local itemName = itemData.name
    if not itemName and itemData.link then
        local _, _, name = string.find(itemData.link, "%[(.+)%]")
        itemName = name
    end

    if not itemName then return false end

    local search = string.lower(searchText)

    if string.sub(search, 1, 1) == "~" then
        local category = string.sub(search, 2)
        local itemType = itemData.class or ""
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
    return string.find(itemName, string.lower(searchText), 1, true) ~= nil
end

-- Generic ResizeFrame for Bag/Bank frames
function Guda_ResizeFrame(frameName, containerName, currentRow, currentCol, columns, overrideHeight)
    local buttonSize = addon.Modules.DB:GetSetting("iconSize") or addon.Constants.BUTTON_SIZE
    local spacing = addon.Modules.DB:GetSetting("iconSpacing") or addon.Constants.BUTTON_SPACING

    local totalRows = (currentRow or 0) + 1
    if totalRows < 1 then totalRows = 1 end

    local containerWidth = (columns * (buttonSize + spacing)) + 20
    local containerHeight = overrideHeight or ((totalRows * (buttonSize + spacing)) + 20)
    local frameWidth = containerWidth + 20

    local showSearchBar = addon.Modules.DB:GetSetting("showSearchBar")
    if showSearchBar == nil then showSearchBar = true end

    local titleHeight = 40
    local searchBarHeight = 30
    local footerHeight = 45
    local frameHeight

    local hideFooter = addon.Modules.DB:GetSetting("hideFooter")
    if hideFooter then
        footerHeight = 10
        frameHeight = containerHeight + titleHeight + (showSearchBar and searchBarHeight or 0) + footerHeight
    elseif showSearchBar then
        frameHeight = containerHeight + titleHeight + searchBarHeight + footerHeight
    else
        frameHeight = containerHeight + titleHeight + footerHeight
    end

    if containerWidth < 200 then
        containerWidth = 200
        frameWidth = 220
    end
    if containerHeight < 150 then containerHeight = 150 end
    if frameHeight < 250 then frameHeight = 250 end

    if containerWidth > 1250 then containerWidth = 1250; frameWidth = 1270 end
    if containerHeight > 1000 then containerHeight = 1000 end
    if frameHeight > 1200 then frameHeight = 1200 end

    local frame = getglobal(frameName)
    local itemContainer = getglobal(containerName)

    if frame then
        frame:SetWidth(frameWidth)
        frame:SetHeight(frameHeight)
        frame:ClearAllPoints()
        -- Try to preserve saved position if present (saved only for Bag frame)
        if addon and addon.Modules and addon.Modules.DB then
            local settingName = (frameName == "Guda_BagFrame") and "bagFramePosition" or nil
            if settingName then
                local pos = addon.Modules.DB:GetSetting(settingName)
                if pos and pos.point == "BOTTOMRIGHT" and pos.x and pos.y then
                    frame:SetPoint("BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", pos.x, pos.y)
                else
                    frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -50, 100)
                end
            else
                frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -50, 100)
            end
        else
            frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -50, 100)
        end
    end

    if itemContainer then
        itemContainer:SetWidth(containerWidth)
        itemContainer:SetHeight(containerHeight)
    end

    -- Resize search bar and toolbar to match container width
    local searchBar = getglobal(frameName .. "_SearchBar")
    if searchBar then searchBar:SetWidth(containerWidth) end
    local toolbar = getglobal(frameName .. "_Toolbar")
    if toolbar then toolbar:SetWidth(containerWidth) end
end
