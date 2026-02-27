-- Guda Category Manager
-- Handles custom category definitions and rule-based item categorization

local addon = Guda

local CategoryManager = {}
addon.Modules.CategoryManager = CategoryManager

--=====================================================
-- Category Result Caching
-- Caches CategorizeItem results to avoid repeated evaluations
--=====================================================
local categoryCache = {}
local cacheHits = 0
local cacheMisses = 0

-- Clear the category cache (call when categories change or on full refresh)
function CategoryManager:ClearCache()
    categoryCache = {}
    cacheHits = 0
    cacheMisses = 0
    addon:Debug("CategoryManager cache cleared")
end

-- Get cache statistics (for debugging/performance monitoring)
function CategoryManager:GetCacheStats()
    local total = cacheHits + cacheMisses
    local hitRate = total > 0 and (cacheHits / total * 100) or 0
    return {
        hits = cacheHits,
        misses = cacheMisses,
        total = total,
        hitRate = hitRate,
        size = 0, -- Will count below
    }
end

-- Generate cache key for an item
local function GetCacheKey(itemLink, isOtherChar)
    if not itemLink then return nil end
    -- Include isOtherChar flag since categorization may differ
    return itemLink .. (isOtherChar and ":other" or ":current")
end

-- Rule Types:
-- itemType: Match by GetItemInfo type (Armor, Weapon, Consumable, etc.)
-- itemSubtype: Match by subtype (Cloth, Potion, Herb, etc.)
-- namePattern: Lua pattern match on item name
-- quality: Match by quality level (0=Gray, 1=White, 2=Green, 3=Blue, 4=Purple, 5=Orange)
-- isBoE: Boolean for Bind on Equip items
-- isQuestItem: Boolean for quest items
-- texturePattern: Match icon texture path
-- itemID: Specific item IDs (table of IDs)

-- Group constants
local GROUP_MAIN = "Main"
local GROUP_OTHER = "Other"
local GROUP_CLASS = "Class"

-- Default category definitions that replicate the existing hardcoded behavior
local DEFAULT_CATEGORIES = {
    order = {
        "BoE", "Weapon", "Armor", "Consumable", "Food", "Drink",
        "Trade Goods", "Reagent", "Recipe", "Quiver", "Container",
        "Soul Bag", "Miscellaneous", "Quest", "Junk",
        "Class Items", "Keyring",
        "Home", "Tools", "Empty"
    },
    itemOverrides = {},  -- flat map: [itemID] = categoryId
    definitions = {
        ["BoE"] = {
            name = "BoE",
            icon = "Interface\\Icons\\INV_Misc_Orb_01",
            rules = {
                { type = "isBoE", value = true }
            },
            matchMode = "all",
            priority = 75,
            enabled = true,
            isBuiltIn = true,
            group = GROUP_MAIN,
        },
        ["Weapon"] = {
            name = "Weapon",
            icon = "Interface\\Icons\\INV_Sword_04",
            rules = {
                { type = "itemType", value = "Weapon" }
            },
            matchMode = "all",
            priority = 70,
            enabled = true,
            isBuiltIn = true,
            group = GROUP_MAIN,
        },
        ["Armor"] = {
            name = "Armor",
            icon = "Interface\\Icons\\INV_Chest_Chain",
            rules = {
                { type = "itemType", value = "Armor" }
            },
            matchMode = "all",
            priority = 70,
            enabled = true,
            isBuiltIn = true,
            group = GROUP_MAIN,
        },
        ["Consumable"] = {
            name = "Consumable",
            icon = "Interface\\Icons\\INV_Potion_54",
            rules = {
                { type = "itemType", value = "Consumable" }
            },
            matchMode = "all",
            priority = 50,
            enabled = true,
            isBuiltIn = true,
            group = GROUP_MAIN,
        },
        ["Food"] = {
            name = "Food",
            icon = "Interface\\Icons\\INV_Misc_Food_14",
            rules = {
                { type = "itemType", value = "Consumable" },
                { type = "restoreTag", value = "eat" }
            },
            matchMode = "all",
            priority = 55,
            enabled = true,
            isBuiltIn = true,
            group = GROUP_MAIN,
        },
        ["Drink"] = {
            name = "Drink",
            icon = "Interface\\Icons\\INV_Drink_07",
            rules = {
                { type = "itemType", value = "Consumable" },
                { type = "restoreTag", value = "drink" }
            },
            matchMode = "all",
            priority = 55,
            enabled = true,
            isBuiltIn = true,
            group = GROUP_MAIN,
        },
        ["Trade Goods"] = {
            name = "Trade Goods",
            icon = "Interface\\Icons\\INV_Fabric_Silk_02",
            rules = {
                { type = "itemType", value = "Trade Goods" }
            },
            matchMode = "all",
            priority = 40,
            enabled = true,
            isBuiltIn = true,
            group = GROUP_MAIN,
        },
        ["Reagent"] = {
            name = "Reagent",
            icon = "Interface\\Icons\\INV_Misc_Dust_02",
            rules = {
                { type = "itemType", value = "Reagent" }
            },
            matchMode = "all",
            priority = 40,
            enabled = true,
            isBuiltIn = true,
            group = GROUP_MAIN,
        },
        ["Recipe"] = {
            name = "Recipe",
            icon = "Interface\\Icons\\INV_Scroll_03",
            rules = {
                { type = "itemType", value = "Recipe" }
            },
            matchMode = "all",
            priority = 40,
            enabled = true,
            isBuiltIn = true,
            group = GROUP_MAIN,
        },
        ["Quiver"] = {
            name = "Quiver",
            icon = "Interface\\Icons\\INV_Misc_Quiver_03",
            rules = {
                { type = "itemType", value = "Quiver" }
            },
            matchMode = "all",
            priority = 40,
            enabled = true,
            isBuiltIn = true,
            group = GROUP_MAIN,
        },
        ["Container"] = {
            name = "Container",
            icon = "Interface\\Icons\\INV_Misc_Bag_07",
            rules = {
                { type = "itemType", value = "Container" }
            },
            matchMode = "all",
            priority = 40,
            enabled = true,
            isBuiltIn = true,
            group = GROUP_MAIN,
        },
        ["Soul Bag"] = {
            name = "Soul Bag",
            icon = "Interface\\Icons\\INV_Misc_Bag_EnchantedMageweave",
            rules = {
                { type = "itemSubtype", value = "Soul Bag" }
            },
            matchMode = "all",
            priority = 45,
            enabled = true,
            isBuiltIn = true,
            group = GROUP_MAIN,
        },
        ["Miscellaneous"] = {
            name = "Miscellaneous",
            icon = "Interface\\Icons\\INV_Misc_Rune_01",
            rules = {},
            matchMode = "any",
            priority = 0,
            enabled = true,
            isBuiltIn = true,
            isFallback = true,
            group = GROUP_MAIN,
        },
        ["Quest"] = {
            name = "Quest",
            icon = "Interface\\Icons\\INV_Misc_Book_08",
            rules = {
                { type = "isQuestItem", value = true }
            },
            matchMode = "all",
            priority = 80,
            enabled = true,
            isBuiltIn = true,
            group = GROUP_MAIN,
        },
        ["Junk"] = {
            name = "Junk",
            icon = "Interface\\Icons\\INV_Misc_Gear_06",
            rules = {
                { type = "isJunk", value = true }
            },
            matchMode = "any",
            priority = 85,
            enabled = true,
            isBuiltIn = true,
            group = GROUP_MAIN,
        },
        ["Class Items"] = {
            name = "Class Items",
            icon = "Interface\\Icons\\INV_Misc_Ammo_Arrow_01",
            rules = {
                { type = "itemType", value = "Projectile" },
                { type = "isSoulShard", value = true }
            },
            matchMode = "any",
            priority = 90,
            enabled = true,
            isBuiltIn = true,
            group = GROUP_CLASS,
        },
        ["Keyring"] = {
            name = "Keyring",
            icon = "Interface\\Icons\\INV_Misc_Key_04",
            rules = {
                { type = "itemType", value = "Key" }
            },
            matchMode = "all",
            priority = 40,
            enabled = true,
            isBuiltIn = true,
            group = GROUP_CLASS,
        },
        ["Home"] = {
            name = "Home",
            icon = "Interface\\Icons\\INV_Misc_Rune_01",
            rules = {
                { type = "itemID", value = {6948} }
            },
            matchMode = "all",
            priority = 100,
            enabled = true,
            isBuiltIn = true,
            group = GROUP_OTHER,
        },
        ["Tools"] = {
            name = "Tools",
            icon = "Interface\\Icons\\Trade_BlackSmithing",
            rules = {
                { type = "isProfessionTool", value = true }
            },
            matchMode = "all",
            priority = 72,
            enabled = true,
            isBuiltIn = true,
            group = GROUP_OTHER,
        },
        ["Empty"] = {
            name = "Empty",
            icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag",
            rules = {},
            matchMode = "all",
            priority = -10,
            enabled = true,
            isBuiltIn = true,
            hideControls = true,
            isEmptyCategory = true,
            group = GROUP_OTHER,
        },
    }
}

-- Group definitions for display order and built-in group mapping
local GROUP_ORDER = { GROUP_MAIN, GROUP_CLASS, GROUP_OTHER }

-- Map of built-in category IDs to their default groups (for migration)
local BUILTIN_GROUP_MAP = {}
for id, def in pairs(DEFAULT_CATEGORIES.definitions) do
    BUILTIN_GROUP_MAP[id] = def.group
end

-- Deep copy a table
local function deepCopy(orig)
    local copy
    if type(orig) == "table" then
        copy = {}
        for k, v in pairs(orig) do
            copy[k] = deepCopy(v)
        end
    else
        copy = orig
    end
    return copy
end

-- Get default categories (returns a deep copy)
function CategoryManager:GetDefaultCategories()
    return deepCopy(DEFAULT_CATEGORIES)
end

-- Initialize categories from database or defaults
function CategoryManager:Initialize()
    if not Guda_CharDB then return end

    if not Guda_CharDB.categories then
        Guda_CharDB.categories = self:GetDefaultCategories()
        addon:Debug("CategoryManager: Initialized with default categories")
    else
        -- Ensure all built-in categories exist (migration support)
        self:MigrateCategories()
    end
end

-- Migrate/update categories to ensure all built-ins exist
function CategoryManager:MigrateCategories()
    local cats = Guda_CharDB.categories
    if not cats then return end

    -- Ensure definitions table exists
    if not cats.definitions then
        cats.definitions = {}
    end

    -- Ensure order table exists
    if not cats.order then
        cats.order = {}
    end

    -- Add any missing built-in categories
    for id, def in pairs(DEFAULT_CATEGORIES.definitions) do
        if not cats.definitions[id] then
            cats.definitions[id] = deepCopy(def)
            -- Add to end of order if not present
            local found = false
            for _, orderId in ipairs(cats.order) do
                if orderId == id then
                    found = true
                    break
                end
            end
            if not found then
                table.insert(cats.order, id)
            end
            addon:Debug("CategoryManager: Added missing built-in category: " .. id)
        end
    end

    -- Migrate Food/Drink categories to use restoreTag instead of itemSubtype
    -- This fixes the issue where subtype "Food & Drink" matched both categories
    local foodCat = cats.definitions["Food"]
    if foodCat and foodCat.isBuiltIn then
        local needsUpdate = false
        if foodCat.rules then
            for _, rule in ipairs(foodCat.rules) do
                if rule.type == "itemSubtype" then
                    needsUpdate = true
                    break
                end
            end
        end
        if needsUpdate then
            foodCat.rules = {
                { type = "itemType", value = "Consumable" },
                { type = "restoreTag", value = "eat" }
            }
            addon:Debug("CategoryManager: Migrated Food category to use restoreTag")
        end
    end

    local drinkCat = cats.definitions["Drink"]
    if drinkCat and drinkCat.isBuiltIn then
        local needsUpdate = false
        if drinkCat.rules then
            for _, rule in ipairs(drinkCat.rules) do
                if rule.type == "itemSubtype" then
                    needsUpdate = true
                    break
                end
            end
        end
        if needsUpdate then
            drinkCat.rules = {
                { type = "itemType", value = "Consumable" },
                { type = "restoreTag", value = "drink" }
            }
            addon:Debug("CategoryManager: Migrated Drink category to use restoreTag")
        end
    end

    -- Migrate BoE priority to be higher than Weapon/Armor (75 > 70)
    local boeCat = cats.definitions["BoE"]
    if boeCat and boeCat.isBuiltIn and boeCat.priority and boeCat.priority < 75 then
        boeCat.priority = 75
        addon:Debug("CategoryManager: Migrated BoE priority to 75")
    end

    -- Migrate Junk category to use isJunk rule type
    local junkCat = cats.definitions["Junk"]
    if junkCat and junkCat.isBuiltIn then
        local needsUpdate = false
        -- Check if priority is too low
        if not junkCat.priority or junkCat.priority < 85 then
            junkCat.priority = 85
            needsUpdate = true
        end
        -- Migrate from quality=0 rule to isJunk rule
        if junkCat.rules then
            for i, rule in ipairs(junkCat.rules) do
                if rule.type == "quality" and rule.value == 0 then
                    junkCat.rules = { { type = "isJunk", value = true } }
                    needsUpdate = true
                    break
                end
            end
        end
        -- Check if rules are missing or wrong
        if not junkCat.rules or table.getn(junkCat.rules) == 0 then
            junkCat.rules = { { type = "isJunk", value = true } }
            needsUpdate = true
        end
        if needsUpdate then
            addon:Debug("CategoryManager: Migrated Junk category to use isJunk rule")
        end
    end

    -- Migrate: Add group to all categories that lack it
    for id, def in pairs(cats.definitions) do
        if not def.group then
            -- Use built-in mapping if available, otherwise default to Main
            def.group = BUILTIN_GROUP_MAP[id] or GROUP_MAIN
            addon:Debug("CategoryManager: Added group '%s' to category: %s", def.group, id)
        end
    end

    -- Ensure savedEquipSetProps table exists
    if not cats.savedEquipSetProps then
        cats.savedEquipSetProps = {}
    end

    -- Migrate: Convert per-category itemOverrides arrays to flat map at categories level
    if not cats.itemOverrides then
        cats.itemOverrides = {}
    end
    local migratedOverrides = false
    for catId, def in pairs(cats.definitions) do
        if def.itemOverrides and type(def.itemOverrides) == "table" then
            -- Check if it's an array (old format) by looking for numeric keys
            local isArray = false
            for k, v in pairs(def.itemOverrides) do
                if type(k) == "number" then
                    isArray = true
                    break
                end
            end
            if isArray then
                for _, itemID in ipairs(def.itemOverrides) do
                    cats.itemOverrides[itemID] = catId
                    migratedOverrides = true
                end
                def.itemOverrides = nil
            end
        end
    end
    if migratedOverrides then
        addon:Debug("CategoryManager: Migrated per-category itemOverrides to flat map")
    end

    -- Migrate Home category: add rules and remove hideControls
    local homeCat = cats.definitions["Home"]
    if homeCat and homeCat.isBuiltIn then
        -- Remove hideControls
        if homeCat.hideControls then
            homeCat.hideControls = nil
            addon:Debug("CategoryManager: Removed hideControls from Home")
        end
        -- Add rules if empty
        if not homeCat.rules or table.getn(homeCat.rules) == 0 then
            homeCat.rules = { { type = "itemID", value = {6948} } }
            homeCat.priority = 100
            addon:Debug("CategoryManager: Added itemID rule to Home category")
        end
        -- Ensure group is Other
        if homeCat.group ~= GROUP_OTHER then
            homeCat.group = GROUP_OTHER
        end
    end

    -- Migrate Class Items: add isSoulShard rule if missing
    local classItemsCat = cats.definitions["Class Items"]
    if classItemsCat and classItemsCat.isBuiltIn then
        local hasSoulShard = false
        if classItemsCat.rules then
            for _, rule in ipairs(classItemsCat.rules) do
                if rule.type == "isSoulShard" then
                    hasSoulShard = true
                    break
                end
            end
        end
        if not hasSoulShard then
            if not classItemsCat.rules then classItemsCat.rules = {} end
            table.insert(classItemsCat.rules, { type = "isSoulShard", value = true })
            classItemsCat.matchMode = "any"
            addon:Debug("CategoryManager: Added isSoulShard rule to Class Items")
        end
    end

    -- Migrate Tools priority: must be above Weapon (70) to catch fishing poles, skinning knives, etc.
    local toolsCat = cats.definitions["Tools"]
    if toolsCat and toolsCat.isBuiltIn and toolsCat.priority and toolsCat.priority < 72 then
        toolsCat.priority = 72
        addon:Debug("CategoryManager: Updated Tools priority to 72 (above Weapon/Armor)")
    end

    -- Ensure new categories in the order list are in correct positions
    -- Check if order needs rebuilding to include new group-based ordering
    local hasTools, hasEmpty = false, false
    for _, id in ipairs(cats.order) do
        if id == "Tools" then hasTools = true end
        if id == "Empty" then hasEmpty = true end
    end

    -- If Tools or Empty were just added by the built-in migration above,
    -- they're already at end of order. Move them to the Other group area.
    if hasTools or hasEmpty then
        -- Rebuild order to respect groups: Other, Main, Class
        local grouped = {}
        for _, g in ipairs(GROUP_ORDER) do
            grouped[g] = {}
        end
        grouped["_ungrouped"] = {}

        for _, id in ipairs(cats.order) do
            local def = cats.definitions[id]
            if def then
                local g = def.group or GROUP_MAIN
                if grouped[g] then
                    table.insert(grouped[g], id)
                else
                    table.insert(grouped["_ungrouped"], id)
                end
            end
        end

        -- Rebuild order
        local newOrder = {}
        for _, g in ipairs(GROUP_ORDER) do
            if grouped[g] then
                for _, id in ipairs(grouped[g]) do
                    table.insert(newOrder, id)
                end
            end
        end
        for _, id in ipairs(grouped["_ungrouped"]) do
            table.insert(newOrder, id)
        end

        cats.order = newOrder
        addon:Debug("CategoryManager: Rebuilt category order for group ordering")
    end
end

-- Get all categories
function CategoryManager:GetCategories()
    if not Guda_CharDB or not Guda_CharDB.categories then
        return self:GetDefaultCategories()
    end
    return Guda_CharDB.categories
end

-- Get category order
function CategoryManager:GetCategoryOrder()
    local cats = self:GetCategories()
    return cats.order or {}
end

-- Get category definition by ID
function CategoryManager:GetCategory(categoryId)
    local cats = self:GetCategories()
    if cats.definitions then
        return cats.definitions[categoryId]
    end
    return nil
end

-- Save categories to database
function CategoryManager:SaveCategories(categories)
    if not Guda_CharDB then return end
    Guda_CharDB.categories = categories
    -- Clear cache when categories change
    self:ClearCache()
end

-- Add a new custom category
-- If categoryId is nil, auto-generates a unique ID like "Custom_<time>_<random>"
function CategoryManager:AddCategory(categoryId, definition)
    local cats = self:GetCategories()

    -- Auto-generate ID if not provided
    if not categoryId then
        categoryId = "Custom_" .. time() .. "_" .. math.random(1000, 9999)
        -- Ensure unique
        while cats.definitions[categoryId] do
            categoryId = "Custom_" .. time() .. "_" .. math.random(1000, 9999)
        end
    end

    if cats.definitions[categoryId] then
        addon:Debug("CategoryManager: Category already exists: " .. categoryId)
        return false
    end

    definition.isBuiltIn = definition.isBuiltIn or false
    if not definition.group then
        definition.group = GROUP_MAIN
    end
    cats.definitions[categoryId] = definition

    -- Insert at end of the category's group in the order list
    local insertPos = nil
    local group = definition.group
    -- Find last category in the same group
    for i = table.getn(cats.order), 1, -1 do
        local existDef = cats.definitions[cats.order[i]]
        if existDef and existDef.group == group then
            insertPos = i + 1
            break
        end
    end
    if insertPos then
        -- Lua 5.0 table.insert with position
        table.insert(cats.order, insertPos, categoryId)
    else
        table.insert(cats.order, categoryId)
    end

    self:SaveCategories(cats)
    return true, categoryId
end

-- Update an existing category
function CategoryManager:UpdateCategory(categoryId, definition)
    local cats = self:GetCategories()

    if not cats.definitions[categoryId] then
        addon:Debug("CategoryManager: Category not found: " .. categoryId)
        return false
    end

    -- Shallow merge: update existing definition with new fields
    -- This preserves fields the caller didn't pass (group, priority, categoryMark, etc.)
    local existing = cats.definitions[categoryId]
    for k, v in pairs(definition) do
        existing[k] = v
    end
    -- Always preserve isBuiltIn from original
    existing.isBuiltIn = existing.isBuiltIn

    self:SaveCategories(cats)
    return true
end

-- Delete a category (only custom categories can be deleted)
function CategoryManager:DeleteCategory(categoryId)
    local cats = self:GetCategories()
    local def = cats.definitions[categoryId]

    if not def then
        return false
    end

    if def.isBuiltIn then
        addon:Debug("CategoryManager: Cannot delete built-in category: " .. categoryId)
        return false
    end

    cats.definitions[categoryId] = nil

    -- Remove from order
    for i, id in ipairs(cats.order) do
        if id == categoryId then
            table.remove(cats.order, i)
            break
        end
    end

    self:SaveCategories(cats)
    return true
end

-- Check if a category can move up within its group
function CategoryManager:CanMoveUp(categoryId)
    local cats = self:GetCategories()
    local def = cats.definitions[categoryId]
    if not def or def.hideControls then return false end

    for i, id in ipairs(cats.order) do
        if id == categoryId then
            -- Find any previous non-hideControls category (can cross group boundaries)
            for j = i - 1, 1, -1 do
                local prevDef = cats.definitions[cats.order[j]]
                if prevDef and not prevDef.hideControls then
                    return true
                end
            end
            return false -- very first movable category
        end
    end
    return false
end

-- Check if a category can move down (crosses group boundaries)
function CategoryManager:CanMoveDown(categoryId)
    local cats = self:GetCategories()
    local def = cats.definitions[categoryId]
    if not def or def.hideControls then return false end

    local count = table.getn(cats.order)
    for i, id in ipairs(cats.order) do
        if id == categoryId then
            -- Find any next non-hideControls category (can cross group boundaries)
            for j = i + 1, count do
                local nextDef = cats.definitions[cats.order[j]]
                if nextDef and not nextDef.hideControls then
                    return true
                end
            end
            return false -- very last movable category
        end
    end
    return false
end

-- Move category up in order (crosses group boundaries, changes group when crossing)
function CategoryManager:MoveCategoryUp(categoryId)
    local cats = self:GetCategories()
    local def = cats.definitions[categoryId]
    if not def or def.hideControls then return false end

    for i, id in ipairs(cats.order) do
        if id == categoryId then
            -- Find previous non-hideControls category
            for j = i - 1, 1, -1 do
                local prevDef = cats.definitions[cats.order[j]]
                if prevDef and not prevDef.hideControls then
                    -- Swap positions
                    cats.order[i] = cats.order[j]
                    cats.order[j] = categoryId
                    -- If crossing into a different group, adopt that group
                    local prevGroup = prevDef.group or GROUP_MAIN
                    if (def.group or GROUP_MAIN) ~= prevGroup then
                        def.group = prevGroup
                    end
                    self:SaveCategories(cats)
                    return true
                end
            end
            return false
        end
    end
    return false
end

-- Move category down in order (crosses group boundaries, changes group when crossing)
function CategoryManager:MoveCategoryDown(categoryId)
    local cats = self:GetCategories()
    local def = cats.definitions[categoryId]
    if not def or def.hideControls then return false end

    local count = table.getn(cats.order)

    for i, id in ipairs(cats.order) do
        if id == categoryId then
            -- Find next non-hideControls category
            for j = i + 1, count do
                local nextDef = cats.definitions[cats.order[j]]
                if nextDef and not nextDef.hideControls then
                    -- Swap positions
                    cats.order[i] = cats.order[j]
                    cats.order[j] = categoryId
                    -- If crossing into a different group, adopt that group
                    local nextGroup = nextDef.group or GROUP_MAIN
                    if (def.group or GROUP_MAIN) ~= nextGroup then
                        def.group = nextGroup
                    end
                    self:SaveCategories(cats)
                    return true
                end
            end
            return false
        end
    end
    return false
end

-- Toggle category enabled state
function CategoryManager:ToggleCategory(categoryId)
    local cats = self:GetCategories()
    local def = cats.definitions[categoryId]

    if def then
        def.enabled = not def.enabled
        self:SaveCategories(cats)
        return true
    end
    return false
end

-- Reset all categories to defaults
function CategoryManager:ResetToDefaults()
    Guda_CharDB.categories = self:GetDefaultCategories()
    addon:Debug("CategoryManager: Reset to default categories")
end

-------------------------------------------
-- Rule Evaluation Engine
-------------------------------------------

-- Evaluate a single rule against item data
function CategoryManager:EvaluateRule(rule, itemData, bagID, slotID, isOtherChar)
    local ruleType = rule.type
    local ruleValue = rule.value

    if ruleType == "itemType" then
        return (itemData.class == ruleValue) or (itemData.type == ruleValue)

    elseif ruleType == "itemSubtype" then
        local subclass = itemData.subclass or ""
        -- Check for partial match (e.g., "Food" matches "Food & Drink")
        if string.find(subclass, ruleValue) then
            return true
        end
        return subclass == ruleValue

    elseif ruleType == "namePattern" then
        local itemName = itemData.name or ""
        return string.find(itemName, ruleValue) ~= nil

    elseif ruleType == "quality" then
        -- For quality 0 (gray/junk), also check tooltip as fallback
        if ruleValue == 0 then
            if itemData.quality == 0 then
                return true
            end
            -- Tooltip fallback for gray detection (current character only)
            if not isOtherChar and addon.Modules.Utils and addon.Modules.Utils.IsItemGrayTooltip then
                return addon.Modules.Utils:IsItemGrayTooltip(bagID, slotID, itemData.link)
            end
            return false
        end
        return itemData.quality == ruleValue

    elseif ruleType == "qualityMin" then
        -- Minimum quality check (item quality >= ruleValue)
        return (itemData.quality or 0) >= (ruleValue or 0)

    elseif ruleType == "isBoE" then
        if isOtherChar then return false end
        if itemData.class ~= "Weapon" and itemData.class ~= "Armor" then
            return false
        end
        local isBoE = addon.Modules.Utils:IsBindOnEquip(bagID, slotID, itemData.link)
        return isBoE == ruleValue

    elseif ruleType == "isQuestItem" then
        -- Use centralized ItemDetection for quest item detection
        if addon.Modules.ItemDetection then
            local props = addon.Modules.ItemDetection:GetItemProperties(itemData, bagID, slotID)
            return props.isQuestItem == ruleValue
        end
        -- Fallback to Utils if ItemDetection not available
        local isQuestItem, _ = addon.Modules.Utils:IsQuestItem(bagID, slotID, itemData, isOtherChar, false)
        return isQuestItem == ruleValue

    elseif ruleType == "texturePattern" then
        local texture = itemData.texture or ""
        return string.find(string.lower(texture), string.lower(ruleValue)) ~= nil

    elseif ruleType == "itemID" then
        if not itemData.link then return false end
        local itemID = addon.Modules.Utils:ExtractItemID(itemData.link)
        if not itemID then return false end

        -- ruleValue can be a single ID or a table of IDs
        if type(ruleValue) == "table" then
            for _, id in ipairs(ruleValue) do
                if itemID == tonumber(id) then return true end
            end
            return false
        else
            -- Convert string to number if needed
            return itemID == tonumber(ruleValue)
        end

    elseif ruleType == "isSoulShard" then
        return addon.Modules.Utils:IsSoulShard(itemData.link) == ruleValue

    elseif ruleType == "isProjectile" then
        local isProj = (itemData.class == "Projectile" or
                        itemData.subclass == "Arrow" or
                        itemData.subclass == "Bullet")
        return isProj == ruleValue

    elseif ruleType == "restoreTag" then
        -- restoreTag is set by tooltip scanning: "eat", "drink", or "restore"
        local tag = itemData.restoreTag
        if not tag then return false end
        return tag == ruleValue

    elseif ruleType == "isProfessionTool" then
        -- Check if item is a profession tool by ID or subtype
        local isProfessionTool = false

        -- Check by item ID
        if itemData.link then
            local itemID = addon.Modules.Utils:ExtractItemID(itemData.link)
            if itemID and addon.Constants.PROFESSION_TOOL_IDS and addon.Constants.PROFESSION_TOOL_IDS[itemID] then
                isProfessionTool = true
            end
        end

        -- Check by subtype (e.g., Fishing Pole)
        if not isProfessionTool then
            local itemSubclass = itemData.subclass or ""
            if addon.Constants.PROFESSION_TOOL_SUBTYPES and addon.Constants.PROFESSION_TOOL_SUBTYPES[itemSubclass] then
                isProfessionTool = true
            end
        end

        return isProfessionTool == ruleValue

    elseif ruleType == "isJunk" then
        -- Use centralized ItemDetection for junk detection
        if addon.Modules.ItemDetection then
            local props = addon.Modules.ItemDetection:GetItemProperties(itemData, bagID, slotID)
            return props.isJunk == ruleValue
        end
        -- Fallback: gray items are always junk
        return (itemData.quality == 0) == ruleValue
    end

    return false
end

-- Evaluate all rules for a category
function CategoryManager:EvaluateCategoryRules(categoryDef, itemData, bagID, slotID, isOtherChar)
    if not categoryDef.enabled then
        return false
    end

    local rules = categoryDef.rules or {}

    -- No rules = fallback category (matches everything)
    if table.getn(rules) == 0 then
        return categoryDef.isFallback == true
    end

    local matchMode = categoryDef.matchMode or "any"

    if matchMode == "all" then
        -- All rules must match
        for _, rule in ipairs(rules) do
            if not self:EvaluateRule(rule, itemData, bagID, slotID, isOtherChar) then
                return false
            end
        end
        return true
    else
        -- Any rule must match
        for _, rule in ipairs(rules) do
            if self:EvaluateRule(rule, itemData, bagID, slotID, isOtherChar) then
                return true
            end
        end
        return false
    end
end

-- Get sorted categories by priority (highest first)
function CategoryManager:GetCategoriesByPriority()
    local cats = self:GetCategories()
    local sorted = {}

    for id, def in pairs(cats.definitions) do
        if def.enabled then
            table.insert(sorted, { id = id, def = def })
        end
    end

    table.sort(sorted, function(a, b)
        return (a.def.priority or 0) > (b.def.priority or 0)
    end)

    return sorted
end

-- Categorize an item using the rule engine
-- Returns category ID or "Miscellaneous" as fallback
function CategoryManager:CategorizeItem(itemData, bagID, slotID, isOtherChar)
    -- Check cache first
    local cacheKey = GetCacheKey(itemData and itemData.link, isOtherChar)
    if cacheKey and categoryCache[cacheKey] then
        cacheHits = cacheHits + 1
        return categoryCache[cacheKey]
    end
    cacheMisses = cacheMisses + 1

    -- Check item overrides first (flat map: itemID -> categoryId)
    local itemID
    if itemData and itemData.link then
        itemID = addon.Modules.Utils:ExtractItemID(itemData.link)
        if itemID then
            local cats = self:GetCategories()
            if cats.itemOverrides then
                local overrideCatId = cats.itemOverrides[itemID]
                if overrideCatId then
                    local overrideDef = cats.definitions[overrideCatId]
                    if overrideDef and overrideDef.enabled then
                        if cacheKey then
                            categoryCache[cacheKey] = overrideCatId
                        end
                        return overrideCatId
                    end
                end
            end
        end
    end

    -- Equipment set categories (higher priority than rule-based matching)
    if itemID and addon.Modules.EquipmentSets then
        local showEquipSets = addon.Modules.DB:GetSetting("showEquipSetCategories")
        if showEquipSets ~= false then
            if addon.Modules.EquipmentSets:IsInSet(itemID) then
                local setNames = addon.Modules.EquipmentSets:GetSetNames(itemID)
                if setNames and table.getn(setNames) > 0 then
                    table.sort(setNames)
                    local catId = "EquipSet:" .. setNames[1]
                    local catDef = self:GetCategory(catId)
                    if catDef and catDef.enabled then
                        if cacheKey then
                            categoryCache[cacheKey] = catId
                        end
                        return catId
                    end
                end
            end
        end
    end

    local sortedCats = self:GetCategoriesByPriority()

    -- Debug: show white item categorization
    if itemData.quality == 1 and (itemData.class == "Weapon" or itemData.class == "Armor") then
        addon:Debug("Categorizing white equip: %s (class=%s, quality=%s)", tostring(itemData.name), tostring(itemData.class), tostring(itemData.quality))
        for i, entry in ipairs(sortedCats) do
            addon:Debug("  Cat %d: %s (priority=%s, enabled=%s)", i, entry.id, tostring(entry.def.priority), tostring(entry.def.enabled))
            if i > 10 then break end  -- Limit debug output
        end
    end

    local result = "Miscellaneous"
    for _, entry in ipairs(sortedCats) do
        if not entry.def.isFallback then
            local matches = self:EvaluateCategoryRules(entry.def, itemData, bagID, slotID, isOtherChar)
            -- Debug: show which category matched for white equip
            if itemData.quality == 1 and (itemData.class == "Weapon" or itemData.class == "Armor") and matches then
                addon:Debug("  -> MATCHED: %s", entry.id)
            end
            if matches then
                result = entry.id
                break
            end
        end
    end

    -- Cache the result
    if cacheKey then
        categoryCache[cacheKey] = result
    end

    return result
end

-- Build the Guda_CategoryList from current category order (for compatibility)
function CategoryManager:BuildCategoryList()
    local order = self:GetCategoryOrder()
    local list = {}

    for _, id in ipairs(order) do
        local def = self:GetCategory(id)
        if def and def.enabled then
            table.insert(list, id)
        end
    end

    return list
end

-------------------------------------------
-- Group Management
-------------------------------------------

-- Get ordered list of unique groups from the category order
function CategoryManager:GetGroups()
    local cats = self:GetCategories()
    local seen = {}
    local groups = {}
    for _, id in ipairs(cats.order) do
        local def = cats.definitions[id]
        if def then
            local g = def.group or GROUP_MAIN
            if not seen[g] then
                seen[g] = true
                table.insert(groups, g)
            end
        end
    end
    return groups
end

-- Get categories organized by group: { groupName => {catIds} }
-- Also returns ungrouped list for any categories without a group
function CategoryManager:GetCategoriesByGroup()
    local cats = self:GetCategories()
    local result = {}
    local ungrouped = {}

    for _, id in ipairs(cats.order) do
        local def = cats.definitions[id]
        if def then
            local g = def.group
            if g then
                if not result[g] then result[g] = {} end
                table.insert(result[g], id)
            else
                table.insert(ungrouped, id)
            end
        end
    end

    return result, ungrouped
end

-- Change a category's group
function CategoryManager:SetCategoryGroup(categoryId, groupName)
    local cats = self:GetCategories()
    local def = cats.definitions[categoryId]
    if not def then return false end

    local oldGroup = def.group or GROUP_MAIN
    if oldGroup == groupName then return true end

    def.group = groupName

    -- Remove from current position in order
    local currentPos = nil
    for i, id in ipairs(cats.order) do
        if id == categoryId then
            currentPos = i
            break
        end
    end
    if currentPos then
        table.remove(cats.order, currentPos)
    end

    -- Insert at end of new group
    local insertPos = nil
    for i = table.getn(cats.order), 1, -1 do
        local existDef = cats.definitions[cats.order[i]]
        if existDef and (existDef.group or GROUP_MAIN) == groupName then
            insertPos = i + 1
            break
        end
    end
    if insertPos then
        table.insert(cats.order, insertPos, categoryId)
    else
        table.insert(cats.order, categoryId)
    end

    self:SaveCategories(cats)
    return true
end

-- Get the group order (unique groups in display order)
function CategoryManager:GetGroupOrder()
    return self:GetGroups()
end


-- Get group constants
function CategoryManager:GetGroupMain() return GROUP_MAIN end
function CategoryManager:GetGroupOther() return GROUP_OTHER end
function CategoryManager:GetGroupClass() return GROUP_CLASS end

-------------------------------------------
-- Item Override System
-------------------------------------------

-- Assign an item to a specific category by item ID
-- Uses flat map at categories level: cats.itemOverrides[itemID] = categoryId
function CategoryManager:AssignItemToCategory(itemID, categoryId)
    if not itemID or not categoryId then return false end
    local cats = self:GetCategories()
    local def = cats.definitions[categoryId]
    if not def then return false end

    if not cats.itemOverrides then
        cats.itemOverrides = {}
    end

    cats.itemOverrides[itemID] = categoryId
    self:SaveCategories(cats)
    self:ClearCache()
    return true
end

-- Remove an item from a specific category's overrides
function CategoryManager:RemoveItemFromCategory(itemID, categoryId)
    if not itemID or not categoryId then return false end
    local cats = self:GetCategories()
    if not cats.itemOverrides then return false end

    if cats.itemOverrides[itemID] == categoryId then
        cats.itemOverrides[itemID] = nil
        self:SaveCategories(cats)
        self:ClearCache()
        return true
    end
    return false
end

-- Remove an item override regardless of category
function CategoryManager:RemoveItemOverride(itemID)
    if not itemID then return end
    local cats = self:GetCategories()
    if cats.itemOverrides then
        cats.itemOverrides[itemID] = nil
    end
end

-------------------------------------------
-- Equipment Set Category Sync
-------------------------------------------

-- Note: savedEquipSetProps is stored in cats.savedEquipSetProps (persisted in SavedVariables)
-- Preserves user changes (enabled state, group, mark, order position) when sets are deleted/recreated

-- Sync equipment set categories with current set data from EquipmentSets module
function CategoryManager:SyncEquipmentSetCategories()
    local equipSets = addon.Modules.EquipmentSets
    if not equipSets then return end

    local showEquipSets = addon.Modules.DB:GetSetting("showEquipSetCategories")
    if showEquipSets == false then return end

    local setNames = equipSets:GetAllSetNames()
    if not setNames then return end

    local cats = self:GetCategories()
    local existingSetCats = {}

    -- Ensure savedEquipSetProps table exists (persisted in SavedVariables)
    if not cats.savedEquipSetProps then
        cats.savedEquipSetProps = {}
    end

    -- Find existing EquipSet categories
    for id, def in pairs(cats.definitions) do
        if string.find(id, "^EquipSet:") then
            existingSetCats[id] = true
        end
    end

    -- Create/update categories for current sets
    for _, setName in ipairs(setNames) do
        local catId = "EquipSet:" .. setName
        if not cats.definitions[catId] then
            -- Check for saved properties from a previously deleted set
            local props = cats.savedEquipSetProps[catId]
            local defaultMark = "Interface\\AddOns\\Guda\\Assets\\equipment"
            local newDef = {
                name = setName,
                icon = "Interface\\Icons\\INV_Chest_Chain_04",
                rules = {},
                matchMode = "all",
                priority = props and props.priority or 65,
                enabled = props and props.enabled or true,
                isBuiltIn = false,
                isEquipSetCategory = true,
                group = props and props.group or GROUP_MAIN,
                categoryMark = props and props.categoryMark or defaultMark,
            }
            cats.definitions[catId] = newDef

            -- Restore saved order position or insert at end of Main group
            local insertPos = nil
            if props and props.orderPos then
                -- Clamp to valid range
                insertPos = props.orderPos
                if insertPos > table.getn(cats.order) + 1 then
                    insertPos = table.getn(cats.order) + 1
                end
            end
            if not insertPos then
                for i = table.getn(cats.order), 1, -1 do
                    local existDef = cats.definitions[cats.order[i]]
                    if existDef and (existDef.group or GROUP_MAIN) == GROUP_MAIN then
                        insertPos = i + 1
                        break
                    end
                end
            end
            if insertPos then
                table.insert(cats.order, insertPos, catId)
            else
                table.insert(cats.order, catId)
            end

            addon:Debug("CategoryManager: Created equipment set category: " .. catId)
        end
        existingSetCats[catId] = nil -- Mark as still active
    end

    -- Remove categories for sets that no longer exist
    for catId in pairs(existingSetCats) do
        local def = cats.definitions[catId]
        if def then
            -- Find current order position before removal
            local orderPos = nil
            for i, id in ipairs(cats.order) do
                if id == catId then
                    orderPos = i
                    break
                end
            end
            -- Save user-edited properties before deletion (persisted across reloads)
            cats.savedEquipSetProps[catId] = {
                enabled = def.enabled,
                categoryMark = def.categoryMark,
                group = def.group,
                priority = def.priority,
                orderPos = orderPos,
            }
        end
        cats.definitions[catId] = nil
        for i, id in ipairs(cats.order) do
            if id == catId then
                table.remove(cats.order, i)
                break
            end
        end
        addon:Debug("CategoryManager: Removed equipment set category: " .. catId)
    end

    self:SaveCategories(cats)
end

-- Get available rule types for UI
function CategoryManager:GetRuleTypes()
    return {
        { id = "itemType", name = "Item Type", description = "Match by item class (Armor, Weapon, etc.)" },
        { id = "itemSubtype", name = "Item Subtype", description = "Match by item subclass (Cloth, Potion, etc.)" },
        { id = "namePattern", name = "Name Pattern", description = "Match item name (supports Lua patterns)" },
        { id = "quality", name = "Quality", description = "Match by item quality (0=Gray to 5=Legendary)" },
        { id = "qualityMin", name = "Quality (min)", description = "Match items with at least this quality" },
        { id = "isBoE", name = "Bind on Equip", description = "Match items that bind when equipped" },
        { id = "isQuestItem", name = "Quest Item", description = "Match quest items" },
        { id = "isJunk", name = "Is Junk", description = "Match junk items (gray + white equippable)" },
        { id = "isProfessionTool", name = "Profession Tool", description = "Match profession tools (skinning knife, mining pick, etc.)" },
        { id = "texturePattern", name = "Icon Pattern", description = "Match icon texture path" },
        { id = "itemID", name = "Item ID", description = "Match specific item IDs" },
        { id = "isSoulShard", name = "Soul Shard", description = "Match soul shards" },
        { id = "isProjectile", name = "Projectile", description = "Match arrows and bullets" },
        { id = "restoreTag", name = "Restore Type", description = "Match by consumable type (eat, drink, restore)" },
    }
end

-- Get common item types for UI dropdowns
function CategoryManager:GetItemTypes()
    return {
        "Armor", "Weapon", "Consumable", "Container", "Trade Goods",
        "Projectile", "Quiver", "Reagent", "Recipe", "Key", "Miscellaneous", "Quest"
    }
end

-- Get quality names for UI
function CategoryManager:GetQualityNames()
    return {
        [0] = "Poor (Gray)",
        [1] = "Common (White)",
        [2] = "Uncommon (Green)",
        [3] = "Rare (Blue)",
        [4] = "Epic (Purple)",
        [5] = "Legendary (Orange)",
    }
end
