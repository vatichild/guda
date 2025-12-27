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
                    local ok, name, texture, count, quality, canUse = pcall(function() return GetContainerItemInfo(button.bagID, button.slotID) end)
                    local _, _, locked = nil, nil, nil
                    if ok then
                        -- older GetContainerItemInfo returns texture, count, locked etc in different orders; try to call a safe wrapper if available
                        local infoOk, iName, iTexture, iCount, iQuality, iCanUse, iLocked = pcall(function() return GetContainerItemInfo(button.bagID, button.slotID) end)
                        if infoOk then
                            -- Try to find 'locked' boolean among returned values (best-effort)
                            for _, val in ipairs({iName, iTexture, iCount, iQuality, iCanUse, iLocked}) do
                                if type(val) == "boolean" then locked = val; break end
                            end
                        end
                    end
                    if not button.otherChar and not button.isReadOnly and SetItemButtonDesaturated and locked ~= nil then
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

