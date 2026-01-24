-- FrameHelpers: central utilities for frame headers and bag parents
local addon = Guda

local FrameHelpers = {}
addon.Modules.FrameHelpers = FrameHelpers

-- Standard category list used by both Bag and Bank frames
-- Now dynamically built from CategoryManager if available
Guda_CategoryList = {
    "BoE", "Weapon", "Armor", "Consumable", "Food", "Drink", "Trade Goods", "Reagent", "Recipe", "Quiver", "Container", "Soul Bag", "Miscellaneous", "Quest", "Junk", "Class Items", "Keyring"
}

-- Rebuild category list from CategoryManager
function Guda_RefreshCategoryList()
    if addon.Modules.CategoryManager then
        Guda_CategoryList = addon.Modules.CategoryManager:BuildCategoryList()
    end
end

-- Categorize a single item into categories and specialItems tables
-- Returns nothing, modifies tables in place
function Guda_CategorizeItem(itemData, bagID, slotID, categories, specialItems, isOtherChar)
    local itemName = itemData.name or ""
    local itemType = itemData.type or ""
    local cat = "Miscellaneous"

    -- Detect consumable restore/eat/drink tag for current character only
    if not isOtherChar and addon.Modules.Utils and addon.Modules.Utils.GetConsumableRestoreTag then
        local tag = addon.Modules.Utils:GetConsumableRestoreTag(bagID, slotID)
        if tag then
            itemData.restoreTag = tag
        end
    end

    -- Priority 1: Special items (Hearthstone, Mounts, Tools)
    -- These are handled separately and go into specialItems table, not categories
    if string.find(itemName, "Hearthstone") then
        -- Only show in Home section if Home category is enabled
        local showHome = true
        if addon.Modules.CategoryManager then
            local homeCat = addon.Modules.CategoryManager:GetCategory("Home")
            if homeCat then
                showHome = homeCat.enabled
            end
        end
        if showHome then
            table.insert(specialItems.Hearthstone, {bagID = bagID, slotID = slotID, itemData = itemData})
        end
        -- Always return - if Home is disabled, Hearthstone is hidden completely
        return
    elseif addon.Modules.SortEngine and addon.Modules.SortEngine.IsMount and addon.Modules.SortEngine.IsMount(itemData.texture) then
        table.insert(specialItems.Mount, {bagID = bagID, slotID = slotID, itemData = itemData})
        return
    elseif string.find(itemName, "Runed .* Rod") or
       itemType == "Fishing Pole" or
       string.find(itemName, "Mining Pick") or
       string.find(itemName, "Blacksmith Hammer") or
       itemName == "Arclight Spanner" or
       itemName == "Gyromatic Micro-Adjustor" or
       itemName == "Philosopher's Stone" or
       string.find(itemName, "Skinning Knife") or
       itemName == "Blood Scythe" or
       string.find(itemName, "Jeweler") or
       string.find(itemName, "Jewelry Kit") then
        table.insert(specialItems.Tools, {bagID = bagID, slotID = slotID, itemData = itemData})
        return
    end

    -- Use CategoryManager rule engine if available, otherwise fall back to legacy logic
    if addon.Modules.CategoryManager then
        cat = addon.Modules.CategoryManager:CategorizeItem(itemData, bagID, slotID, isOtherChar)
        if not categories[cat] then cat = "Miscellaneous" end
        table.insert(categories[cat], {bagID = bagID, slotID = slotID, itemData = itemData})
        return
    end

    -- Legacy categorization logic (fallback if CategoryManager not available)
    -- Priority 2: Class Items (Soul Shards, Arrows, Bullets)
    if addon.Modules.Utils:IsSoulShard(itemData.link) or
       itemData.class == "Projectile" or
       itemData.subclass == "Arrow" or
       itemData.subclass == "Bullet" then
        table.insert(categories["Class Items"], {bagID = bagID, slotID = slotID, itemData = itemData})
        return
    end

    -- Priority 3: Quest Items (use consolidated detection)
    local isQuestItem, _ = addon.Modules.Utils:IsQuestItem(bagID, slotID, itemData, isOtherChar, false)
    if isQuestItem then
        table.insert(categories["Quest"], {bagID = bagID, slotID = slotID, itemData = itemData})
        return
    end

    -- Priority 4: Junk (Gray items)
    if itemData.quality == 0 or addon.Modules.Utils:IsItemGrayTooltip(bagID, slotID, itemData.link) then
        table.insert(categories["Junk"], {bagID = bagID, slotID = slotID, itemData = itemData})
        return
    end

    -- Priority 5: Food and Drink
    if itemData.class == "Consumable" then
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
        return
    end

    -- Priority 6: BoE Equipment
    if (itemData.class == "Weapon" or itemData.class == "Armor") and not isOtherChar then
        local isBoE = addon.Modules.Utils:IsBindOnEquip(bagID, slotID, itemData.link)
        if isBoE then
            table.insert(categories["BoE"], {bagID = bagID, slotID = slotID, itemData = itemData})
        else
            table.insert(categories[itemData.class], {bagID = bagID, slotID = slotID, itemData = itemData})
        end
        return
    end

    -- Priority 7: Equipment for other characters
    if (itemData.class == "Weapon" or itemData.class == "Armor") and isOtherChar then
        table.insert(categories[itemData.class], {bagID = bagID, slotID = slotID, itemData = itemData})
        return
    end

    -- Priority 8: Other Categories
    cat = itemData.class or "Miscellaneous"
    if not categories[cat] then cat = "Miscellaneous" end
    table.insert(categories[cat], {bagID = bagID, slotID = slotID, itemData = itemData})
end

--=====================================================
-- Category Table Pooling (memory optimization)
-- Reuses category tables instead of creating new ones
--=====================================================
local categoriesCache = nil
local specialItemsCache = nil

-- Clear a table without creating a new one (Lua 5.0 compatible)
local function WipeTable(t)
    if not t then return end
    for k in pairs(t) do
        t[k] = nil
    end
end

-- Initialize empty category tables (reuses cached tables)
function Guda_InitCategories()
    -- Refresh category list from CategoryManager (enabled categories only for display)
    Guda_RefreshCategoryList()

    -- Reuse or create categories table
    if not categoriesCache then
        categoriesCache = {}
    end

    -- Clear existing category arrays (don't recreate the main table)
    for cat, items in pairs(categoriesCache) do
        WipeTable(items)
    end

    if addon.Modules.CategoryManager then
        -- Get full category order (all categories, not just enabled)
        local allCategories = addon.Modules.CategoryManager:GetCategoryOrder()
        for _, cat in ipairs(allCategories) do
            if not categoriesCache[cat] then
                categoriesCache[cat] = {}
            end
        end
    else
        -- Fallback: use the display list
        for _, cat in ipairs(Guda_CategoryList) do
            if not categoriesCache[cat] then
                categoriesCache[cat] = {}
            end
        end
    end

    -- Always ensure Miscellaneous exists as fallback
    if not categoriesCache["Miscellaneous"] then
        categoriesCache["Miscellaneous"] = {}
    end

    -- Always ensure Keyring exists (handled specially in BagFrame)
    if not categoriesCache["Keyring"] then
        categoriesCache["Keyring"] = {}
    end

    -- Reuse or create specialItems table
    if not specialItemsCache then
        specialItemsCache = {
            Hearthstone = {},
            Mount = {},
            Tools = {}
        }
    else
        WipeTable(specialItemsCache.Hearthstone)
        WipeTable(specialItemsCache.Mount)
        WipeTable(specialItemsCache.Tools)
    end

    return categoriesCache, specialItemsCache
end

-- Sort items within a category
function Guda_SortCategoryItems(items)
    if not items then return end
    table.sort(items, function(a, b)
        -- Nil guards for sort stability
        if not a then return false end
        if not b then return true end
        if not a.itemData then return false end
        if not b.itemData then return true end
        -- Rank Trade Goods: meat (name ends with 'meat') = 2, egg (contains 'egg') = 1, others = 0
        local function tgRank(d)
            if not d or not d.name then return 0 end
            local t = d.type or d.class or ""
            if t ~= "Trade Goods" then return 0 end
            local n = string.lower(d.name)
            if string.find(n, "meat$") then return 2 end
            if string.find(n, "egg") then return 1 end
            return 0
        end
        local ra = tgRank(a.itemData)
        local rb = tgRank(b.itemData)
        if ra ~= rb then
            return ra > rb
        end
        -- Priority: consumable restore tags (eat > drink > restore > nil)
        local pa = a.itemData and a.itemData.restoreTag or nil
        local pb = b.itemData and b.itemData.restoreTag or nil
        local function pr(t)
            if t == "eat" then return 3 end
            if t == "drink" then return 2 end
            if t == "restore" then return 1 end
            return 0
        end
        if pr(pa) ~= pr(pb) then
            return pr(pa) > pr(pb)
        end
        -- Fallback: subclass, quality, name
        if a.itemData.subclass ~= b.itemData.subclass then
            return (a.itemData.subclass or "") < (b.itemData.subclass or "")
        end
        if a.itemData.quality ~= b.itemData.quality then
            return a.itemData.quality > b.itemData.quality
        end
        return (a.itemData.name or "") < (b.itemData.name or "")
    end)
end

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
        -- Track item buttons to avoid GetChildren() table allocation
        parentsTable[bagID].itemButtons = {}
    end
    return parentsTable[bagID]
end

-- Register an item button with its parent for tracking
function Guda_RegisterItemButton(parent, button)
    if parent and parent.itemButtons and button then
        parent.itemButtons[button] = true
    end
end

-- Update lock/desaturation states for a table of parent frames
-- Uses itemButtons tracking to avoid GetChildren() table allocation
function Guda_UpdateLockStates(parentsTable)
    if not parentsTable then return end
    for _, parent in pairs(parentsTable) do
        if parent and parent.itemButtons then
            for button in pairs(parent.itemButtons) do
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
