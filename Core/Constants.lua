-- Guda Constants Module
-- Centralized location for all magic numbers and hardcoded values

local addon = Guda

-- Extend the existing Constants table from Init.lua
local C = addon.Constants

--=============================================================================
-- Bag IDs
--=============================================================================
C.BAG_BACKPACK = 0
C.BAG_FIRST = 1
C.BAG_LAST = 4
C.BANK_FIRST = 5
C.BANK_LAST = 11
C.KEYRING_BAG = -2
C.BANK_CONTAINER = -1

-- Bag ID ranges for iteration
C.BAG_IDS = {0, 1, 2, 3, 4}
C.BANK_BAG_IDS = {5, 6, 7, 8, 9, 10, 11}
C.ALL_BAG_IDS = {0, 1, 2, 3, 4, -2}  -- Including keyring

--=============================================================================
-- Equipment Slots
--=============================================================================
C.EQUIPMENT_SLOT_FIRST = 1
C.EQUIPMENT_SLOT_LAST = 19

--=============================================================================
-- Item IDs
--=============================================================================
C.SOUL_SHARD_ID = 6265
C.HEARTHSTONE_ID = 6948

-- Profession tool item IDs that should NOT be marked as junk
-- even though they are white quality equippable items
C.PROFESSION_TOOL_IDS = {
    -- Skinning
    [7005] = true,   -- Skinning Knife
    [7812] = true,   -- Simple Skinning Knife
    [12709] = true,  -- Finkle's Skinner
    [19901] = true,  -- Zulian Slicer

    -- Mining
    [2901] = true,   -- Mining Pick
    [778] = true,    -- Kobold Mining Shovel
    [1959] = true,   -- Cold Iron Pick
    [9465] = true,   -- Digmaster 5000

    -- Blacksmithing
    [5956] = true,   -- Blacksmith Hammer

    -- Engineering
    [6219] = true,   -- Arclight Spanner
    [10498] = true,  -- Gyromatic Micro-Adjuster
    [11590] = true,  -- Mechanical Repair Kit

    -- Enchanting Rods
    [6218] = true,   -- Runed Copper Rod
    [6339] = true,   -- Runed Silver Rod
    [11130] = true,  -- Runed Golden Rod
    [11145] = true,  -- Runed Truesilver Rod
    [16207] = true,  -- Runed Arcanite Rod

    -- Fishing (by ID, in case subtype detection fails)
    [6256] = true,   -- Fishing Pole
    [6365] = true,   -- Strong Fishing Pole
    [6366] = true,   -- Darkwood Fishing Pole
    [6367] = true,   -- Big Iron Fishing Pole
    [12225] = true,  -- Blump Family Fishing Pole
    [19022] = true,  -- Nat Pagle's Extreme Angler FC-5000
    [19970] = true,  -- Arcanite Fishing Pole
    [84660] = true,  -- Pandaren Fishing Pole (Turtle WoW)

    -- Jewelcrafting (if applicable)
    [55155] = true,  -- Jewelers Kit
    [41328] = true,  -- Precision Jewelry Kit
    [20815] = true,  -- Jeweler's Kit
    [20824] = true,  -- Simple Grinder
}

-- Weapon subtypes that should NOT be marked as junk
C.PROFESSION_TOOL_SUBTYPES = {
    ["Fishing Pole"] = true,
    ["Fishing Poles"] = true,
}

--=============================================================================
-- Colors (r, g, b tables for easy unpacking)
--=============================================================================
C.COLORS = {
    -- Special item borders
    KEYRING_CYAN = {r = 0.2, g = 0.8, b = 1.0},
    QUEST_GOLD = {r = 1.0, g = 0.82, b = 0},

    -- Text colors
    GRAY_TEXT = {r = 0.5, g = 0.5, b = 0.5},
    WHITE_TEXT = {r = 1.0, g = 1.0, b = 1.0},
    GOLD_TITLE = {r = 1.0, g = 0.82, b = 0},
    CYAN_LABEL = {r = 0, g = 1.0, b = 1.0},

    -- Unusable item tint
    UNUSABLE_RED = {r = 0.9, g = 0.2, b = 0.2, a = 0.45},

    -- Lock/desaturate
    LOCKED_GRAY = {r = 0.5, g = 0.5, b = 0.5},
}

--=============================================================================
-- UI Thresholds
--=============================================================================
C.ICON_SIZE_THRESHOLD = 44  -- Below this, use smaller insets/padding
C.ICON_INSET_SMALL = 10     -- Inset for small icons
C.ICON_INSET_LARGE = 15     -- Inset for large icons
C.ICON_TEXCOORD_CROP = 0.08 -- Texture coordinate crop amount

--=============================================================================
-- Database / Cleanup
--=============================================================================
C.CLEANUP_OLD_CHARS_DAYS = 90

--=============================================================================
-- Tooltip Scanning
--=============================================================================
C.QUEST_TOOLTIP_PATTERNS = {
    "quest starter",
    "this item begins a quest",
    "starts a quest",
    "quest item",
    "manual",
}

C.BIND_ON_EQUIP_PATTERN = "binds when equipped"

--=============================================================================
-- Specialized Bag Types
--=============================================================================
C.BAG_TYPES = {
    SOUL = "soul",
    HERB = "herb",
    ENCHANT = "enchant",
    QUIVER = "quiver",
    AMMO = "ammo",
}

-- Tooltip patterns for bag type detection
C.BAG_TYPE_PATTERNS = {
    soul = {"soul bag", "soul pouch"},
    herb = {"herb bag"},
    enchant = {"enchanting bag"},
    quiver = {"quiver"},
    ammo = {"ammo pouch"},
}

--=============================================================================
-- Item Categories (for GetItemInfo)
--=============================================================================
C.ITEM_CATEGORIES = {
    WEAPON = "Weapon",
    ARMOR = "Armor",
    CONSUMABLE = "Consumable",
    CONTAINER = "Container",
    TRADE_GOODS = "Trade Goods",
    PROJECTILE = "Projectile",
    QUIVER = "Quiver",
    REAGENT = "Reagent",
    RECIPE = "Recipe",
    KEY = "Key",
    MISCELLANEOUS = "Miscellaneous",
    QUEST = "Quest",
}

--=============================================================================
-- Money Formatting
--=============================================================================
C.MONEY = {
    COPPER_PER_SILVER = 100,
    SILVER_PER_GOLD = 100,
    COPPER_PER_GOLD = 10000,
}

-- Color codes for money display
C.MONEY_COLORS = {
    GOLD = "|cFFFFD700",
    SILVER = "|cFFC7C7CF",
    COPPER = "|cFFEDA55F",
    WHITE = "|cFFFFFFFF",
}

--=============================================================================
-- Frame Constants
--=============================================================================
C.FRAME = {
    TITLE_HEIGHT = 40,
    SEARCH_BAR_HEIGHT = 30,
    FOOTER_HEIGHT = 45,
    FOOTER_HEIGHT_HIDDEN = 10,
    MIN_WIDTH = 200,
    MIN_HEIGHT = 150,
    MAX_WIDTH = 1250,
    MAX_HEIGHT = 1000,
}

--=============================================================================
-- Bank Slots
--=============================================================================
C.BANK_MAIN_SLOTS = 24  -- Number of slots in main bank container

--=============================================================================
-- Tooltip Hook Settings
--=============================================================================
C.TOOLTIP = {
    DEBOUNCE_TIME = 0.2,  -- Seconds to wait before clearing cache
    MAX_MONEY_FRAMES = 8, -- Maximum number of money frames to search
}

addon:Debug("Constants module loaded")
