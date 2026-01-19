-- Guda Category Manager
-- Handles custom category definitions and rule-based item categorization

local addon = Guda

local CategoryManager = {}
addon.Modules.CategoryManager = CategoryManager

-- Rule Types:
-- itemType: Match by GetItemInfo type (Armor, Weapon, Consumable, etc.)
-- itemSubtype: Match by subtype (Cloth, Potion, Herb, etc.)
-- namePattern: Lua pattern match on item name
-- quality: Match by quality level (0=Gray, 1=White, 2=Green, 3=Blue, 4=Purple, 5=Orange)
-- isBoE: Boolean for Bind on Equip items
-- isQuestItem: Boolean for quest items
-- texturePattern: Match icon texture path
-- itemID: Specific item IDs (table of IDs)

-- Default category definitions that replicate the existing hardcoded behavior
local DEFAULT_CATEGORIES = {
    order = {
        "Home", "BoE", "Weapon", "Armor", "Consumable", "Food", "Drink",
        "Trade Goods", "Reagent", "Recipe", "Quiver", "Container",
        "Soul Bag", "Miscellaneous", "Quest", "Junk", "Class Items", "Keyring"
    },
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
        },
        ["Class Items"] = {
            name = "Class Items",
            icon = "Interface\\Icons\\INV_Misc_Ammo_Arrow_01",
            rules = {
                { type = "itemType", value = "Projectile" }
            },
            matchMode = "any",
            priority = 90,
            enabled = true,
            isBuiltIn = true,
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
        },
        ["Home"] = {
            name = "Home",
            icon = "Interface\\Icons\\INV_Misc_Rune_01",
            rules = {},
            matchMode = "all",
            priority = 0,
            enabled = true,
            isBuiltIn = true,
            hideControls = true,
        },
    }
}

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
end

-- Add a new custom category
function CategoryManager:AddCategory(categoryId, definition)
    local cats = self:GetCategories()

    if cats.definitions[categoryId] then
        addon:Debug("CategoryManager: Category already exists: " .. categoryId)
        return false
    end

    definition.isBuiltIn = false
    cats.definitions[categoryId] = definition
    table.insert(cats.order, categoryId)

    self:SaveCategories(cats)
    return true
end

-- Update an existing category
function CategoryManager:UpdateCategory(categoryId, definition)
    local cats = self:GetCategories()

    if not cats.definitions[categoryId] then
        addon:Debug("CategoryManager: Category not found: " .. categoryId)
        return false
    end

    -- Preserve isBuiltIn flag
    definition.isBuiltIn = cats.definitions[categoryId].isBuiltIn
    cats.definitions[categoryId] = definition

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

-- Move category up in order
function CategoryManager:MoveCategoryUp(categoryId)
    local cats = self:GetCategories()

    for i, id in ipairs(cats.order) do
        if id == categoryId and i > 1 then
            cats.order[i] = cats.order[i - 1]
            cats.order[i - 1] = categoryId
            self:SaveCategories(cats)
            return true
        end
    end
    return false
end

-- Move category down in order
function CategoryManager:MoveCategoryDown(categoryId)
    local cats = self:GetCategories()
    local count = table.getn(cats.order)

    for i, id in ipairs(cats.order) do
        if id == categoryId and i < count then
            cats.order[i] = cats.order[i + 1]
            cats.order[i + 1] = categoryId
            self:SaveCategories(cats)
            return true
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
        -- Use consolidated quest detection from Utils
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

    elseif ruleType == "isJunk" then
        -- Junk items: gray items (quality 0) OR white equippable items (quality 1 + Weapon/Armor)
        local quality = itemData.quality
        local isGray = false
        local isWhiteEquip = false

        -- Check for gray items (quality 0)
        if quality == 0 then
            isGray = true
        elseif not isOtherChar and addon.Modules.Utils and addon.Modules.Utils.IsItemGrayTooltip then
            -- Tooltip fallback for gray detection
            isGray = addon.Modules.Utils:IsItemGrayTooltip(bagID, slotID, itemData.link)
        end

        -- Check for white equippable items (quality 1 + Weapon/Armor)
        if quality == 1 then
            local itemClass = itemData.class or ""
            if itemClass == "Weapon" or itemClass == "Armor" then
                isWhiteEquip = true
            end
        end

        local isJunk = isGray or isWhiteEquip
        return isJunk == ruleValue
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
    local sortedCats = self:GetCategoriesByPriority()

    for _, entry in ipairs(sortedCats) do
        if not entry.def.isFallback then
            if self:EvaluateCategoryRules(entry.def, itemData, bagID, slotID, isOtherChar) then
                return entry.id
            end
        end
    end

    return "Miscellaneous"
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
