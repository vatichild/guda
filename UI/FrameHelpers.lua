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
    local cat = "Miscellaneous"

    -- Detect consumable restore/eat/drink tag for current character only.
    -- Gated on class == "Consumable": the "while eating"/"while drinking"/"use:
    -- restores" patterns only appear on consumables, so scanning other items
    -- just wastes a tooltip roundtrip per bag on the cold-cache path.
    if not isOtherChar and itemData.class == "Consumable"
       and addon.Modules.Utils and addon.Modules.Utils.GetConsumableRestoreTag then
        local tag = addon.Modules.Utils:GetConsumableRestoreTag(bagID, slotID)
        if tag then
            itemData.restoreTag = tag
        end
    end

    -- Special items: only Mounts are handled separately now
    -- Home and Tools are real categories handled by CategoryManager rules
    if addon.Modules.SortEngine and addon.Modules.SortEngine.IsMount and addon.Modules.SortEngine.IsMount(itemData.texture) then
        table.insert(specialItems.Mount, {bagID = bagID, slotID = slotID, itemData = itemData})
        return
    end

    -- Use CategoryManager rule engine if available, otherwise fall back to legacy logic.
    -- Fast path: cache-only lookup. CacheWarmer populates categoryCache in the
    -- background; on cold miss we skip rule evaluation (which would otherwise
    -- trigger tooltip scans per item) and use itemData.class as a rough bucket.
    -- CacheWarmer's completion marker re-triggers BagFrame:Update so items land
    -- in their real categories once warmup finishes.
    if addon.Modules.CategoryManager then
        if addon.Modules.CategoryManager.CategorizeItemCached then
            cat = addon.Modules.CategoryManager:CategorizeItemCached(itemData, isOtherChar)
        end
        if not cat then
            cat = itemData.class or "Miscellaneous"
        end
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
-- For arrays, iterate backwards to safely remove all elements
local function WipeTable(t)
    if not t then return end
    -- For arrays (numeric keys), remove from end to start
    local n = table.getn(t)
    if n > 0 then
        for i = n, 1, -1 do
            table.remove(t, i)
        end
    end
    -- Also clear any non-numeric keys (hash part)
    for k in pairs(t) do
        if type(k) ~= "number" then
            t[k] = nil
        end
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
    local totalItemsBeforeWipe = 0
    for cat, items in pairs(categoriesCache) do
        totalItemsBeforeWipe = totalItemsBeforeWipe + table.getn(items)
        WipeTable(items)
    end

    -- Verify wipe worked
    local totalItemsAfterWipe = 0
    for cat, items in pairs(categoriesCache) do
        totalItemsAfterWipe = totalItemsAfterWipe + table.getn(items)
    end
    addon:DebugCategory("InitCategories: beforeWipe=%d, afterWipe=%d", totalItemsBeforeWipe, totalItemsAfterWipe)

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

    -- Always ensure Soul Bag exists (handled specially in BagFrame)
    if not categoriesCache["Soul Bag"] then
        categoriesCache["Soul Bag"] = {}
    end

    -- Reuse or create specialItems table
    -- Only Mount remains as a special item; Home and Tools are now real categories
    if not specialItemsCache then
        specialItemsCache = {
            Mount = {},
        }
    else
        WipeTable(specialItemsCache.Mount)
    end

    return categoriesCache, specialItemsCache
end

-- Sort items within a category (or merged group)
-- Items may have a categoryOrderIndex field set by merged group display
function Guda_SortCategoryItems(items)
    if not items then return end
    table.sort(items, function(a, b)
        -- Guard against nil entries
        if not a then return false end
        if not b then return true end
        if not a.itemData then return false end
        if not b.itemData then return true end

        -- Primary: category order index (for merged groups)
        local oa = a.categoryOrderIndex or 0
        local ob = b.categoryOrderIndex or 0
        if oa ~= ob then
            return oa < ob
        end

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
        local pa = a.itemData.restoreTag
        local pb = b.itemData.restoreTag
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
        if (a.itemData.quality or 0) ~= (b.itemData.quality or 0) then
            return (a.itemData.quality or 0) > (b.itemData.quality or 0)
        end
        return (a.itemData.name or "") < (b.itemData.name or "")
    end)
end

-- Increase font size on Blizzard UIDropDownMenu buttons after ToggleDropDownMenu
function Guda_ScaleDropdownFonts(size)
    for level = 1, 3 do
        local listName = "DropDownList" .. level
        local list = getglobal(listName)
        if not list then break end
        for i = 1, 20 do
            local ntxt = getglobal(listName .. "Button" .. i .. "NormalText")
            if ntxt then
                local f, _, fl = ntxt:GetFont()
                if f then ntxt:SetFont(f, size, fl) end
            end
        end
    end
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

        -- Category name text
        local text = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", header, "LEFT", 0, 0)
        header.text = text

        -- Item count text
        local countText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        countText:SetPoint("LEFT", text, "RIGHT", 4, 0)
        countText:SetTextColor(0.6, 0.6, 0.6)
        header.countText = countText

        -- Separator line extending from count/text to the right edge
        local line = header:CreateTexture(nil, "ARTWORK")
        line:SetHeight(1)
        line:SetPoint("LEFT", countText, "RIGHT", 6, 0)
        line:SetPoint("RIGHT", header, "RIGHT", 0, 0)
        line:SetTexture(0.6, 0.6, 0.6, 0.3)
        header.separatorLine = line

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
-- Supports space-separated tokens, each of one of three kinds:
--   ~t:<keyword>   — tooltip text substring (case-insensitive)
--   ~<category>    — category shortcut (equipment, consumable, quest, ...)
--   <plain text>   — item name substring
-- All tokens must match (AND) for the item to pass.
local function TokenizeSearch(text)
    local tokens = {}
    local s = string.lower(text)
    local pos = 1
    local len = string.len(s)
    while pos <= len do
        local startPos, endPos = string.find(s, "%S+", pos)
        if not startPos then break end
        table.insert(tokens, string.sub(s, startPos, endPos))
        pos = endPos + 1
    end
    return tokens
end

local function MatchesCategoryShortcut(itemData, category)
    local itemType = itemData.class or ""
    local itemQuality = itemData.quality or -1
    if category == "equipment" or category == "armor" or category == "weapon" then
        return (itemType == "Armor" or itemType == "Weapon")
    elseif category == "consumable" then
        return itemType == "Consumable"
    elseif category == "tradegoods" or category == "trades" then
        return itemType == "Trade Goods"
    elseif category == "quest" then
        local isQuest, isQuestStarter = Guda_GetQuestInfo(itemData.bagID, itemData.slotID, itemData.isBank)
        return (isQuest or isQuestStarter or itemType == "Quest") and true or false
    elseif category == "reagent" then
        return itemType == "Reagent"
    elseif category == "common"    then return itemQuality == 1
    elseif category == "uncommon"  then return itemQuality == 2
    elseif category == "rare"      then return itemQuality == 3
    elseif category == "epic"      then return itemQuality == 4
    elseif category == "legendary" then return itemQuality == 5
    end
    return nil  -- unknown shortcut — caller falls back to name-match
end

function Guda_PassesSearchFilter(itemData, searchText)
    if not searchText or searchText == "" then return true end
    if searchText == "Search, try ~equipment" or searchText == "Search bank..." then
        return true
    end
    if not itemData then return false end

    local itemName = itemData.name
    if not itemName and itemData.link then
        local _, _, name = string.find(itemData.link, "%[(.+)%]")
        itemName = name
    end
    if not itemName then return false end
    local lowerName = string.lower(itemName)

    local Utils = Guda and Guda.Modules and Guda.Modules.Utils

    for _, tok in ipairs(TokenizeSearch(searchText)) do
        local matched = false

        if string.sub(tok, 1, 3) == "~t:" then
            -- Tooltip-text filter.
            local keyword = string.sub(tok, 4)
            if keyword == "" then
                matched = true   -- bare ~t: is a no-op, skip this token
            elseif Utils and Utils.GetTooltipText then
                local text = Utils:GetTooltipText(itemData.bagID, itemData.slotID, itemData.link)
                if text and string.find(text, keyword, 1, true) then
                    matched = true
                end
            end
        elseif string.sub(tok, 1, 1) == "~" then
            -- Category shortcut. Unknown shortcuts fall back to name-match.
            local category = string.sub(tok, 2)
            local shortcut = MatchesCategoryShortcut(itemData, category)
            if shortcut == true then
                matched = true
            elseif shortcut == nil then
                -- unknown shortcut — behave like a plain name substring
                matched = string.find(lowerName, tok, 1, true) ~= nil
            end
        else
            matched = string.find(lowerName, tok, 1, true) ~= nil
        end

        if not matched then return false end
    end

    return true
end

-- Generic ResizeFrame for Bag/Bank frames
function Guda_ResizeFrame(frameName, containerName, currentRow, currentCol, columns, overrideHeight)
    local buttonSize = addon.Modules.DB:GetSetting("iconSize") or addon.Constants.BUTTON_SIZE
    local spacing = addon.Modules.DB:GetSetting("iconSpacing") or addon.Constants.BUTTON_SPACING

    -- currentRow/currentCol reflect position after last item:
    -- if col==0, row was already incremented (full row), so totalRows = row
    -- if col>0, partial row, so totalRows = row + 1
    local totalRows = (currentRow or 0)
    if (currentCol or 0) > 0 then
        totalRows = totalRows + 1
    end
    if totalRows < 1 then totalRows = 1 end

    -- Get theme-aware padding
    local pad = { containerExtra = 20, frameExtra = 20, titleHeight = 40, searchBarHeight = 30, footerHeight = 45, footerHiddenHeight = 10 }
    if addon.Modules and addon.Modules.Theme and addon.Modules.Theme.GetFramePadding then
        pad = addon.Modules.Theme:GetFramePadding()
    end

    local containerWidth = columns * (buttonSize + spacing) - spacing + 2 * pad.startX
    local containerHeight = overrideHeight or (totalRows * (buttonSize + spacing) - spacing + 2 * math.abs(pad.startY))
    local frameWidth = containerWidth + pad.frameExtra

    -- Effective shown state for the search bar: "shown" always, "hidden" never,
    -- "toggle" only when the bag frame has expanded the bar via its icon button.
    local mode = addon.Modules.DB:GetSetting("searchBarMode")
    if mode ~= "shown" and mode ~= "hidden" and mode ~= "toggle" then
        local legacy = addon.Modules.DB:GetSetting("showSearchBar")
        mode = (legacy == false) and "hidden" or "shown"
    end
    local showSearchBar
    if mode == "shown" then
        showSearchBar = true
    elseif mode == "hidden" then
        showSearchBar = false
    else
        local BF = addon.Modules and addon.Modules.BagFrame
        showSearchBar = BF and BF.searchBarExpanded and true or false
    end

    local titleHeight = pad.titleHeight
    local searchBarHeight = pad.searchBarHeight
    local footerHeight = pad.footerHeight
    local frameHeight

    local hideFooter = addon.Modules.DB:GetSetting("hideFooter")
    if hideFooter then
        footerHeight = pad.footerHiddenHeight
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
