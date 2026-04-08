-- Guda Localization
--
-- Pattern mirrored from GudaPlates_Locale.lua: a single Guda_L table holding the
-- English defaults, then per-locale override blocks. Call sites use
-- Guda_L["English string"] (or `local L = Guda_L`). Missing keys gracefully
-- render English, since the keys ARE the English strings.
--
-- Supported locales: enUS (default), zhCN, esES, ptBR, deDE, ruRU.
-- Translators: copy any L[...] line into the matching locale block below and
-- replace the right-hand value.

Guda_L = {}
local L = Guda_L

-- ============================================================================
-- Keybindings (WoW-conventional globals — must stay as BINDING_*)
-- ============================================================================
BINDING_HEADER_GUDA = "Guda"
BINDING_NAME_GUDA_TOGGLE_BAGS = "Toggle Bags"
BINDING_NAME_GUDA_TOGGLE_BANK = "Toggle Bank"
BINDING_NAME_GUDA_USE_QUEST_ITEM_1 = "Quest Bar 1"
BINDING_NAME_GUDA_USE_QUEST_ITEM_2 = "Quest Bar 2"

-- ============================================================================
-- Settings tooltips (legacy L_* globals — referenced from SettingsPopup.lua)
-- Kept as globals for compatibility; do not remove.
-- ============================================================================
L_SHOW_TOOLTIP_COUNTS = "Tooltip Extension"
L_SHOW_TOOLTIP_COUNTS_TT = "Show how many of this item you have across all your characters in the item tooltip."
L_LOCK_BAGS_TT = "Lock the bag frames in place so they cannot be moved by dragging."
L_HIDE_BORDERS_TT = "Hide the thick borders around the bag and bank frames for a cleaner look."
L_QUALITY_BORDER_EQ_TT = "Show a color-coded border around equipped items based on their quality (Common, Rare, Epic, etc.)."
L_QUALITY_BORDER_OTHER_TT = "Show a color-coded border around non-equipped items in your bags and bank based on their quality."
L_SHOW_SEARCH_BAR_TT = "Show a search bar at the top of your bags to quickly find items."
L_SHOW_QUEST_BAR_TT = "Show a bar for quickly accessing quest-related items."
L_HOVER_BAGLINE_TT = "Minimizes the bag container to show only the main bag and keyring. Hover over the main bag to view the other bags."
L_HIDE_BAGLINE_TT = "Hides bag slots 1-4 from the footer. Click the main bag to show a flyout with all bag slots."
L_HIDE_FOOTER_TT = "Hide the bottom section of the bag frame containing money and bag slots."

-- ============================================================================
-- English (default / enUS)
-- ============================================================================

-- Init / lifecycle (Core/Main.lua, Data/EquipmentScanner.lua, Core/Tooltip.lua)
L["Initializing..."] = "Initializing..."
L["Initializing UI..."] = "Initializing UI..."
L["Ready! Type /guda to open bags"] = "Ready! Type /guda to open bags"
L["Initializing tooltip module..."] = "Initializing tooltip module..."
L["Tooltip integration enabled - Inventory displays above vendor price"] = "Tooltip integration enabled - Inventory displays above vendor price"
L["Scanning equipped items..."] = "Scanning equipped items..."
L["Equipped items scanned and saved!"] = "Equipped items scanned and saved!"

-- Slash command help (Core/Main.lua)
L["Commands:"] = "Commands:"
L["/guda - Toggle bags"] = "/guda - Toggle bags"
L["/guda bank - Toggle bank"] = "/guda bank - Toggle bank"
L["/guda mail - Toggle mailbox"] = "/guda mail - Toggle mailbox"
L["/guda settings - Open settings"] = "/guda settings - Open settings"
L["/guda sort - Sort bags"] = "/guda sort - Sort bags"
L["/guda sortbank - Sort bank"] = "/guda sortbank - Sort bank"
L["/guda track - Toggle item tracking"] = "/guda track - Toggle item tracking"
L["/guda debug - Toggle debug mode"] = "/guda debug - Toggle debug mode"
L["/guda debugsort - Toggle sort debug output"] = "/guda debugsort - Toggle sort debug output"
L["/guda cleanup - Remove old characters"] = "/guda cleanup - Remove old characters"
L["/guda perf - Show performance stats"] = "/guda perf - Show performance stats"
L["/guda perfreset - Reset performance stats"] = "/guda perfreset - Reset performance stats"
L["/guda poolreset - Reset button pool (debug)"] = "/guda poolreset - Reset button pool (debug)"
L["Unknown command. Type /guda help for commands"] = "Unknown command. Type /guda help for commands"
L["Debug mode: %s"] = "Debug mode: %s"
L["Debug sort mode: %s"] = "Debug sort mode: %s"
L["Debug category mode: %s"] = "Debug category mode: %s"
L["Quest bar: %s"] = "Quest bar: %s"
L["ON"] = "ON"
L["OFF"] = "OFF"
L["Settings window not available"] = "Settings window not available"
L["Performance stats not available"] = "Performance stats not available"
L["Performance stats reset"] = "Performance stats reset"
L["Cannot reset pool while bag/bank frames are open. Close them first."] = "Cannot reset pool while bag/bank frames are open. Close them first."
L["Button pool reset. Pool is now empty."] = "Button pool reset. Pool is now empty."
L["Button pool reset function not available."] = "Button pool reset function not available."

-- Bag/Bank/Mail frame chrome (UI/BagFrame.lua, UI/BankFrame.lua, UI/MailboxFrame.lua)
L["%s's Bags"] = "%s's Bags"
L["%s's Bank"] = "%s's Bank"
L["%s's Mailbox"] = "%s's Mailbox"
L["Bank"] = "Bank"
L["Bank Bag Slot %d"] = "Bank Bag Slot %d"
L["Backpack"] = "Backpack"
L["Keyring"] = "Keyring"
L["Bag %d"] = "Bag %d"
L["Bag Slots"] = "Bag Slots"
L["Search, try ~equipment"] = "Search, try ~equipment"
L["Search bank..."] = "Search bank..."
L["Search mailbox..."] = "Search mailbox..."
L["Use Guda Bank UI"] = "Use Guda Bank UI"
L["Switched to Guda bank UI"] = "Switched to Guda bank UI"
L["No Mail"] = "No Mail"
L["No mailbox data found for this character.\n\nVisit a mailbox in-game to save your mail data."] = "No mailbox data found for this character.\n\nVisit a mailbox in-game to save your mail data."
L["Current realm gold"] = "Current realm gold"

-- Sort / sell prints (UI/BagFrame.lua, UI/BankFrame.lua, Sorting/SortEngine.lua, Sorting/BagReplacer.lua)
L["Cannot sort another character's bags!"] = "Cannot sort another character's bags!"
L["Cannot sort in read-only mode!"] = "Cannot sort in read-only mode!"
L["Bags are already sorted!"] = "Bags are already sorted!"
L["Bank is already sorted!"] = "Bank is already sorted!"
L["Bank must be open to sort!"] = "Bank must be open to sort!"
L["Sorting already in progress, please wait..."] = "Sorting already in progress, please wait..."
L["Restacked %d stack(s)"] = "Restacked %d stack(s)"
L["Sold %d junk item(s)"] = "Sold %d junk item(s)"
L["Bag replaced successfully!"] = "Bag replaced successfully!"
L["Cannot replace bag: another replacement is in progress."] = "Cannot replace bag: another replacement is in progress."
L["Cannot replace bag while sorting is in progress."] = "Cannot replace bag while sorting is in progress."
L["Cannot replace bag during combat."] = "Cannot replace bag during combat."

-- Item-button protection prints (UI/ItemButton.lua)
L["Cannot sell %s — item is protected"] = "Cannot sell %s — item is protected"
L["Cannot disenchant %s — item is protected"] = "Cannot disenchant %s — item is protected"
L["Cannot delete %s — item is protected"] = "Cannot delete %s — item is protected"
L["Slot pinned %s (skipped during sort)"] = "Slot pinned %s (skipped during sort)"
L["Slot unpinned %s"] = "Slot unpinned %s"
L["%s set protection removed"] = "%s set protection removed"
L["%s set protection restored"] = "%s set protection restored"
L["%s locked"] = "%s locked"
L["%s unlocked"] = "%s unlocked"

-- Quest item bar (UI/QuestItemBar.lua)
L["Item is not currently in your bags (loading from database)."] = "Item is not currently in your bags (loading from database)."

-- Tooltip integration (Core/Tooltip.lua)
L["Inventory"] = "Inventory"
L["Other Accounts"] = "Other Accounts"
L["Total"] = "Total"
L["Bags"] = "Bags"
L["Mail"] = "Mail"
L["Equipped"] = "Equipped"

-- SharedData (Core/SharedData.lua)
L["Imported %d character(s) from other accounts"] = "Imported %d character(s) from other accounts"

-- Performance stats (Core/Utils.lua)
L["=== Guda Performance Stats ==="] = "=== Guda Performance Stats ==="
L["Frame Budget: %.0fms"] = "Frame Budget: %.0fms"
L["Last Update: %.1fms"] = "Last Update: %.1fms"
L["Total Updates: %d"] = "Total Updates: %d"
L["Budget Exceeded: %d times"] = "Budget Exceeded: %d times"

-- Settings popup (UI/SettingsPopup.lua) — labels, sliders, checkboxes, buttons
L["Guda Settings"] = "Guda Settings"
L["Appearance"] = "Appearance"
L["Options"] = "Options"
L["Automation"] = "Automation"
L["View"] = "View"
L["Columns"] = "Columns"
L["Icon"] = "Icon"
L["Icon Options"] = "Icon Options"
L["Quest Bar"] = "Quest Bar"
L["Tracked"] = "Tracked"
L["Theme"] = "Theme"
L["Bag View"] = "Bag View"
L["Bank View"] = "Bank View"
L["Bag columns"] = "Bag columns"
L["Bank columns"] = "Bank columns"
L["Background Transparency"] = "Background Transparency"
L["Icon size"] = "Icon size"
L["Icon font size"] = "Icon font size"
L["Icon spacing"] = "Icon spacing"
L["Quest bar size"] = "Quest bar size"
L["Tracked bar size"] = "Tracked bar size"
L["Junk item opacity"] = "Junk item opacity"
L["Lock Window"] = "Lock Window"
L["Hide Frame Borders"] = "Hide Frame Borders"
L["Equipment Borders"] = "Equipment Borders"
L["Other Item Borders"] = "Other Item Borders"
L["Show Search Bar"] = "Show Search Bar"
L["Show Quest Bar"] = "Show Quest Bar"
L["Show All Bags"] = "Show All Bags"
L["Hide Footer"] = "Hide Footer"
L["Reverse Stack Sort"] = "Reverse Stack Sort"
L["Merge"] = "Merge"
L["Group:"] = "Group:"
L["Mark:"] = "Mark:"
L["Any rule"] = "Any rule"
L["All rules"] = "All rules"
L["Edit Category (Built-in)"] = "Edit Category (Built-in)"
L["Edit Category"] = "Edit Category"
L["Rules (%d/%d):"] = "Rules (%d/%d):"
L["Mark Unusable Items"] = "Mark Unusable Items"
L["Equip Set Categories"] = "Equip Set Categories"
L["Mark Equipment Sets"] = "Mark Equipment Sets"
L["Auto Lock Set Items"] = "Auto Lock Set Items"
L["Show Category Count"] = "Show Category Count"
L["Auto Sell Junk"] = "Auto Sell Junk"
L["Auto Open Bags"] = "Auto Open Bags"
L["Auto Close Bags"] = "Auto Close Bags"
L["White Items as Junk"] = "White Items as Junk"
L["pfUI Transparency"] = "pfUI Transparency"
L["Edit"] = "Edit"
L["Save"] = "Save"
L["Cancel"] = "Cancel"
L["+ Add Category"] = "+ Add Category"
L["+ Add Rule"] = "+ Add Rule"
L["Reset Defaults"] = "Reset Defaults"
L["Select Type"] = "Select Type"
L["Select Value"] = "Select Value"
L["Tracking Items:"] = "Tracking Items:"
L["Locked Items:"] = "Locked Items:"
L["Pin Slot:"] = "Pin Slot:"
L["Moving Bars:"] = "Moving Bars:"

-- ============================================================================
-- Locale overrides
-- Translators: copy any L["..."] = "..." line above into the matching block
-- below and replace the right-hand value with the translation.
-- ============================================================================
local locale = GetLocale and GetLocale() or "enUS"

if locale == "zhCN" then
    -- Chinese (Simplified) — translations go here
    -- L["Guda Settings"] = "Guda 设置"

elseif locale == "esES" then
    -- Spanish — translations go here
    -- L["Guda Settings"] = "Ajustes de Guda"

elseif locale == "ptBR" then
    -- Portuguese (Brazilian) — translations go here
    -- L["Guda Settings"] = "Configurações Guda"

elseif locale == "deDE" then
    -- German — translations go here
    -- L["Guda Settings"] = "Guda Einstellungen"

elseif locale == "ruRU" then
    -- Russian — translations go here
    -- L["Guda Settings"] = "Настройки Guda"

end
