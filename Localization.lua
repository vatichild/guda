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
L["/guda openclams - Open all clams in bags"] = "/guda openclams - Open all clams in bags"
L["Auto Loot"] = "Auto Loot"
L["Automatically loot all items when looting a corpse or container."] = "Automatically loot all items when looting a corpse or container."
L["Auto Loot requires the SuperWoW client mod. Install SuperWoW to enable this option."] = "Auto Loot requires the SuperWoW client mod. Install SuperWoW to enable this option, or apply the launcher's 'Always auto-loot' tweak (which makes the client autoloot independently of this addon)."
L["Auto Open Clams"] = "Auto Open Clams"
L["Automatically open clams in your bags when you loot one."] = "Automatically open clams in your bags when you loot one."
L["Opening clams..."] = "Opening clams..."
L["No clams found in your bags."] = "No clams found in your bags."
L["No more clams to open."] = "No more clams to open."
L["Clam opener is already running."] = "Clam opener is already running."
L["Clam opener stopped: %s"] = "Clam opener stopped: %s"
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
L["Total gold"] = "Total gold"
L["Settings"] = "Settings"
L["Sort Bags"] = "Sort Bags"
L["Lockpicking"] = "Lockpicking"
L["Click to cast Pick Lock"] = "Click to cast Pick Lock"
L["Requires Thieves' Tools"] = "Requires Thieves' Tools"
L["My Characters"] = "My Characters"
L["View Bank"] = "View Bank"
L["View Mailbox"] = "View Mailbox"
L["Right-click to manage characters"] = "Right-click to manage characters"
L["(Right-Click to hide)"] = "(Right-Click to hide)"
L["%d Slots"] = "%d Slots"
L["Regular Bags:"] = "Regular Bags:"
L["Sort Bank"] = "Sort Bank"
L["Use Blizzard Bank UI"] = "Use Blizzard Bank UI"

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

-- Settings tab labels
L["General"] = "General"
L["Layout"] = "Layout"
L["Icons"] = "Icons"
L["Bar"] = "Bar"
L["Categories"] = "Categories"
L["Guide"] = "Guide"

-- Slider value-display formats (the live "label: value" strings)
L["Bag columns: %d"] = "Bag columns: %d"
L["Bank columns: %d"] = "Bank columns: %d"
L["Background Transparency: %d%%"] = "Background Transparency: %d%%"
L["Icon size: %dpx"] = "Icon size: %dpx"
L["Icon font size: %dpx"] = "Icon font size: %dpx"
L["Icon spacing: %s"] = "Icon spacing: %s"
L["Quest bar size: %dpx"] = "Quest bar size: %dpx"
L["Tracked bar size: %dpx"] = "Tracked bar size: %dpx"
L["Junk item opacity: %d%%"] = "Junk item opacity: %d%%"

-- Tooltip extension checkbox + tooltip text
L["Show Item Counts in Tooltip"] = "Show Item Counts in Tooltip"
L["Tooltip Extension"] = "Tooltip Extension"
L["Show how many of this item you have across all your characters in the item tooltip."] = "Show how many of this item you have across all your characters in the item tooltip."

-- Settings tooltip text (used for L_*_TT)
L["Lock the bag frames in place so they cannot be moved by dragging."] = "Lock the bag frames in place so they cannot be moved by dragging."
L["Hide the thick borders around the bag and bank frames for a cleaner look."] = "Hide the thick borders around the bag and bank frames for a cleaner look."
L["Show a color-coded border around equipped items based on their quality (Common, Rare, Epic, etc.)."] = "Show a color-coded border around equipped items based on their quality (Common, Rare, Epic, etc.)."
L["Show a color-coded border around non-equipped items in your bags and bank based on their quality."] = "Show a color-coded border around non-equipped items in your bags and bank based on their quality."
L["Show a search bar at the top of your bags to quickly find items."] = "Show a search bar at the top of your bags to quickly find items."
L["Show a bar for quickly accessing quest-related items."] = "Show a bar for quickly accessing quest-related items."
L["Minimizes the bag container to show only the main bag and keyring. Hover over the main bag to view the other bags."] = "Minimizes the bag container to show only the main bag and keyring. Hover over the main bag to view the other bags."
L["Hides bag slots 1-4 from the footer. Click the main bag to show a flyout with all bag slots."] = "Hides bag slots 1-4 from the footer. Click the main bag to show a flyout with all bag slots."
L["Hide the bottom section of the bag frame containing money and bag slots."] = "Hide the bottom section of the bag frame containing money and bag slots."
L["Show a red tint on items that your character cannot use (wrong class, level, etc.)."] = "Show a red tint on items that your character cannot use (wrong class, level, etc.)."
L["Show equipment set categories in category view."] = "Show equipment set categories in category view."
L["Show a special icon on items that belong to an equipment set."] = "Show a special icon on items that belong to an equipment set."
L["Prevent selling and deleting items saved in equipment sets."] = "Prevent selling and deleting items saved in equipment sets."
L["Show the item count next to each category header in category view."] = "Show the item count next to each category header in category view."
L["Automatically sell gray (junk) items when you visit a vendor."] = "Automatically sell gray (junk) items when you visit a vendor."
L["Automatically open bags when interacting with bank, auction house, mail, or trade."] = "Automatically open bags when interacting with bank, auction house, mail, or trade."
L["Automatically close bags when closing bank, auction house, mail, trade, or vendor."] = "Automatically close bags when closing bank, auction house, mail, trade, or vendor."
L["Treat white (common) equippable items as junk. They will be dimmed and auto-sold if auto-sell is enabled."] = "Treat white (common) equippable items as junk. They will be dimmed and auto-sold if auto-sell is enabled."
L["When enabled, uses pfUI's background transparency instead of the slider below."] = "When enabled, uses pfUI's background transparency instead of the slider below."
L["When enabled, smaller stacks of the same item will be sorted before larger stacks (e.g., stack of 16 before stack of 20)."] = "When enabled, smaller stacks of the same item will be sorted before larger stacks (e.g., stack of 16 before stack of 20)."

-- Categories tab + Guide tab
L["GUIDE_TEXT"] = "|cffffd100Tracking Items:|r\n" ..
    "Alt + Left Click on any item in your bags to track it.\n" ..
    "Tracked items will appear in the Tracked Item Bar.\n" ..
    "Left Click on an item in the bar to use it.\n" ..
    "Alt + Left Click on an item in the bar to untrack it.\n\n" ..
    "|cffffd100Locked Items:|r\n" ..
    "Ctrl + Right Click on any item to lock/unlock it.\n" ..
    "Locked items cannot be sold at vendors, deleted, or disenchanted.\n" ..
    "Equipment set items are automatically protected.\n" ..
    "Ctrl + Right Click a set item to toggle its protection.\n" ..
    "A lock icon appears on the bottom-right corner.\n\n" ..
    "|cffffd100Pin Slot:|r\n" ..
    "Alt + Right Click on any bag slot to pin/unpin it.\n" ..
    "Pinned slots are skipped during sorting.\n" ..
    "The pin stays on the slot, not the item.\n" ..
    "A pin icon appears on the top-left corner.\n\n" ..
    "|cffffd100Moving Bars:|r\n" ..
    "Shift + Left Click and drag any item on the Quest Item Bar or Tracked Item Bar to move the bar.\n"

L["Manage item categories and their display order:"] = "Manage item categories and their display order:"
L["(Built-in)"] = "(Built-in)"
L["(Drop Item)"] = "(Drop Item)"
L["Name:"] = "Name:"
L["Match Mode:"] = "Match Mode:"
L["Rules:"] = "Rules:"

-- ============================================================================
-- Item subType strings (locale-specific) used by Sorting/SortEngine and
-- Core/Utils.lua to identify specialized bags and projectiles WITHOUT relying
-- on GetItemInfo cache cold-start. These are the raw strings WoW returns from
-- GetItemInfo position 6 (subType) for each bag/projectile family. All bags
-- in one family share the same subType string, so one entry per family is
-- enough. Unknown locales fall back to enUS.
-- ============================================================================
Guda_LSubtypes = {
    enUS = {
        quiver  = "Quiver",        ammo    = "Ammo Pouch",
        soul    = "Soul Bag",      herb    = "Herb Bag",      enchant = "Enchanting Bag",
        arrow   = "Arrow",         bullet  = "Bullet",
    },
    deDE = {
        quiver  = "Köcher",        ammo    = "Munitionsbeutel",
        soul    = "Seelentasche",  herb    = "Kräutertasche", enchant = "Verzauberertasche",
        arrow   = "Pfeil",         bullet  = "Kugel",
    },
    frFR = {
        quiver  = "Carquois",      ammo    = "Giberne",
        soul    = "Sac d'âmes",    herb    = "Sacoche d'herboriste", enchant = "Sac d'enchanteur",
        arrow   = "Flèche",        bullet  = "Balle",
    },
    esES = {
        quiver  = "Carcaj",        ammo    = "Bolsa de munición",
        soul    = "Bolsa de almas",herb    = "Bolsa de hierbas",     enchant = "Bolsa de encantamiento",
        arrow   = "Flecha",        bullet  = "Bala",
    },
    zhCN = {
        quiver  = "箭袋",          ammo    = "弹药袋",
        soul    = "灵魂袋",        herb    = "草药袋",        enchant = "附魔袋",
        arrow   = "箭",            bullet  = "子弹",
    },
    ruRU = {
        quiver  = "Колчан",        ammo    = "Подсумок",
        soul    = "Сумка для душ", herb    = "Сумка травника",enchant = "Сумка зачарователя",
        arrow   = "Стрела",        bullet  = "Пуля",
    },
}

-- ============================================================================
-- Locale overrides
-- Translators: copy any L["..."] = "..." line above into the matching block
-- below and replace the right-hand value with the translation.
-- ============================================================================
local locale = GetLocale and GetLocale() or "enUS"

if locale == "zhCN" then
    -- Chinese (Simplified)

    L["Auto Loot"] = "自动拾取"
    L["Automatically loot all items when looting a corpse or container."] = "拾取尸体或容器时自动拾取所有物品。"
    L["Auto Loot requires the SuperWoW client mod. Install SuperWoW to enable this option."] = "自动拾取需要 SuperWoW 客户端模组。安装 SuperWoW 以启用此选项,或应用启动器的 'Always auto-loot' 调整(客户端将独立于此插件自动拾取)。"
    L["Auto Open Clams"] = "自动打开蚌壳"
    L["Automatically open clams in your bags when you loot one."] = "拾取蚌壳后自动打开背包中的蚌壳。"
    L["/guda openclams - Open all clams in bags"] = "/guda openclams - 打开背包中所有蚌壳"
    L["Opening clams..."] = "正在打开蚌壳..."
    L["No clams found in your bags."] = "背包中没有找到蚌壳。"
    L["No more clams to open."] = "没有更多蚌壳可打开。"
    L["Clam opener is already running."] = "蚌壳打开器已在运行。"
    L["Clam opener stopped: %s"] = "蚌壳打开器已停止:%s"

    -- Init / lifecycle
    L["Initializing..."] = "正在初始化..."
    L["Initializing UI..."] = "正在初始化界面..."
    L["Ready! Type /guda to open bags"] = "就绪!输入 /guda 打开背包"
    L["Scanning equipped items..."] = "正在扫描装备物品..."
    L["Equipped items scanned and saved!"] = "装备物品已扫描并保存!"

    -- Slash command help
    L["Commands:"] = "命令:"
    L["/guda - Toggle bags"] = "/guda - 切换背包"
    L["/guda bank - Toggle bank"] = "/guda bank - 切换银行"
    L["/guda mail - Toggle mailbox"] = "/guda mail - 切换邮箱"
    L["/guda settings - Open settings"] = "/guda settings - 打开设置"
    L["/guda sort - Sort bags"] = "/guda sort - 整理背包"
    L["/guda sortbank - Sort bank"] = "/guda sortbank - 整理银行"
    L["/guda track - Toggle item tracking"] = "/guda track - 切换物品追踪"
    L["/guda debug - Toggle debug mode"] = "/guda debug - 切换调试模式"
    L["/guda debugsort - Toggle sort debug output"] = "/guda debugsort - 切换排序调试输出"
    L["/guda cleanup - Remove old characters"] = "/guda cleanup - 移除旧角色"
    L["/guda perf - Show performance stats"] = "/guda perf - 显示性能统计"
    L["/guda perfreset - Reset performance stats"] = "/guda perfreset - 重置性能统计"
    L["/guda poolreset - Reset button pool (debug)"] = "/guda poolreset - 重置按钮池(调试)"
    L["Unknown command. Type /guda help for commands"] = "未知命令。输入 /guda help 查看命令"
    L["Debug mode: %s"] = "调试模式: %s"
    L["Debug sort mode: %s"] = "排序调试模式: %s"
    L["Debug category mode: %s"] = "分类调试模式: %s"
    L["Quest bar: %s"] = "任务栏: %s"
    L["ON"] = "开"
    L["OFF"] = "关"
    L["Settings window not available"] = "设置窗口不可用"
    L["Performance stats not available"] = "性能统计不可用"
    L["Performance stats reset"] = "性能统计已重置"
    L["Cannot reset pool while bag/bank frames are open. Close them first."] = "背包/银行窗口打开时无法重置按钮池。请先关闭它们。"
    L["Button pool reset. Pool is now empty."] = "按钮池已重置。"
    L["Button pool reset function not available."] = "按钮池重置功能不可用。"

    -- Bag/Bank/Mail frame chrome
    L["%s's Bags"] = "%s 的背包"
    L["%s's Bank"] = "%s 的银行"
    L["%s's Mailbox"] = "%s 的邮箱"
    L["Bank"] = "银行"
    L["Backpack"] = "背包"
    L["Keyring"] = "钥匙链"
    L["Bag %d"] = "背包 %d"
    L["Bag Slots"] = "背包栏"
    L["Bank Bag Slot %d"] = "银行背包栏 %d"
    L["Search, try ~equipment"] = "搜索,试试 ~equipment"
    L["Search bank..."] = "搜索银行..."
    L["Search mailbox..."] = "搜索邮箱..."
    L["Use Guda Bank UI"] = "使用 Guda 银行界面"
    L["Switched to Guda bank UI"] = "已切换到 Guda 银行界面"
    L["No Mail"] = "无邮件"
    L["No mailbox data found for this character.\n\nVisit a mailbox in-game to save your mail data."] = "未找到此角色的邮箱数据。\n\n请在游戏中访问邮箱以保存邮件数据。"
    L["Current realm gold"] = "当前服务器金币"
    L["Total gold"] = "总金币"
    L["Settings"] = "设置"
    L["Sort Bags"] = "整理背包"
    L["Lockpicking"] = "开锁"
    L["Click to cast Pick Lock"] = "点击施放开锁"
    L["Requires Thieves' Tools"] = "需要盗贼工具"
    L["My Characters"] = "我的角色"
    L["View Bank"] = "查看银行"
    L["View Mailbox"] = "查看邮箱"
    L["Right-click to manage characters"] = "右键点击管理角色"
    L["(Right-Click to hide)"] = "(右键点击隐藏)"
    L["%d Slots"] = "%d 格"
    L["Regular Bags:"] = "普通背包:"
    L["Sort Bank"] = "整理银行"
    L["Use Blizzard Bank UI"] = "使用暴雪银行界面"

    -- Sort / sell prints
    L["Cannot sort another character's bags!"] = "无法整理其他角色的背包!"
    L["Cannot sort in read-only mode!"] = "只读模式下无法整理!"
    L["Bags are already sorted!"] = "背包已经整理好了!"
    L["Bank is already sorted!"] = "银行已经整理好了!"
    L["Bank must be open to sort!"] = "必须打开银行才能整理!"
    L["Sorting already in progress, please wait..."] = "正在整理中,请稍候..."
    L["Restacked %d stack(s)"] = "重新堆叠了 %d 组物品"
    L["Sold %d junk item(s)"] = "出售了 %d 件垃圾物品"
    L["Bag replaced successfully!"] = "背包替换成功!"
    L["Cannot replace bag: another replacement is in progress."] = "无法替换背包:已有替换操作正在进行。"
    L["Cannot replace bag while sorting is in progress."] = "整理进行中,无法替换背包。"
    L["Cannot replace bag during combat."] = "战斗中无法替换背包。"

    -- Item-button protection prints
    L["Cannot sell %s — item is protected"] = "无法出售 %s — 物品已被保护"
    L["Cannot disenchant %s — item is protected"] = "无法分解 %s — 物品已被保护"
    L["Cannot delete %s — item is protected"] = "无法删除 %s — 物品已被保护"
    L["Slot pinned %s (skipped during sort)"] = "已固定 %s(整理时跳过)"
    L["Slot unpinned %s"] = "已取消固定 %s"
    L["%s set protection removed"] = "%s 套装保护已移除"
    L["%s set protection restored"] = "%s 套装保护已恢复"
    L["%s locked"] = "%s 已锁定"
    L["%s unlocked"] = "%s 已解锁"

    -- Quest item bar
    L["Item is not currently in your bags (loading from database)."] = "物品当前不在你的背包中(从数据库加载)。"

    -- Tooltip integration
    L["Inventory"] = "库存"
    L["Other Accounts"] = "其他账号"
    L["Total"] = "总计"
    L["Bags"] = "背包"
    L["Mail"] = "邮件"
    L["Equipped"] = "已装备"

    -- SharedData
    L["Imported %d character(s) from other accounts"] = "从其他账号导入了 %d 个角色"

    -- Performance stats
    L["=== Guda Performance Stats ==="] = "=== Guda 性能统计 ==="
    L["Frame Budget: %.0fms"] = "帧预算: %.0fms"
    L["Last Update: %.1fms"] = "上次更新: %.1fms"
    L["Total Updates: %d"] = "总更新次数: %d"
    L["Budget Exceeded: %d times"] = "超出预算: %d 次"

    -- Settings popup
    L["Guda Settings"] = "Guda 设置"
    L["Appearance"] = "外观"
    L["Options"] = "选项"
    L["Automation"] = "自动化"
    L["View"] = "视图"
    L["Columns"] = "列数"
    L["Icon"] = "图标"
    L["Icon Options"] = "图标选项"
    L["Quest Bar"] = "任务栏"
    L["Tracked"] = "追踪"
    L["Theme"] = "主题"
    L["Bag View"] = "背包视图"
    L["Bank View"] = "银行视图"
    L["Bag columns"] = "背包列数"
    L["Bank columns"] = "银行列数"
    L["Background Transparency"] = "背景透明度"
    L["Icon size"] = "图标大小"
    L["Icon font size"] = "图标字号"
    L["Icon spacing"] = "图标间距"
    L["Quest bar size"] = "任务栏大小"
    L["Tracked bar size"] = "追踪栏大小"
    L["Junk item opacity"] = "垃圾物品透明度"
    L["Lock Window"] = "锁定窗口"
    L["Hide Frame Borders"] = "隐藏窗口边框"
    L["Equipment Borders"] = "装备边框"
    L["Other Item Borders"] = "其他物品边框"
    L["Show Search Bar"] = "显示搜索栏"
    L["Show Quest Bar"] = "显示任务栏"
    L["Show All Bags"] = "显示所有背包"
    L["Hide Footer"] = "隐藏底栏"
    L["Mark Unusable Items"] = "标记不可用物品"
    L["Equip Set Categories"] = "装备套装分类"
    L["Mark Equipment Sets"] = "标记装备套装"
    L["Auto Lock Set Items"] = "自动锁定套装物品"
    L["Show Category Count"] = "显示分类数量"
    L["Auto Sell Junk"] = "自动出售垃圾"
    L["Auto Open Bags"] = "自动打开背包"
    L["Auto Close Bags"] = "自动关闭背包"
    L["White Items as Junk"] = "白色物品视为垃圾"
    L["pfUI Transparency"] = "pfUI 透明度"
    L["Reverse Stack Sort"] = "反向堆叠排序"
    L["Edit"] = "编辑"
    L["Save"] = "保存"
    L["Cancel"] = "取消"
    L["+ Add Category"] = "+ 添加分类"
    L["+ Add Rule"] = "+ 添加规则"
    L["Reset Defaults"] = "恢复默认"
    L["Select Type"] = "选择类型"
    L["Select Value"] = "选择值"
    L["Tracking Items:"] = "追踪物品:"
    L["Locked Items:"] = "锁定物品:"
    L["Pin Slot:"] = "固定栏位:"
    L["Moving Bars:"] = "移动栏位:"
    L["Merge"] = "合并"
    L["Group:"] = "分组:"
    L["Mark:"] = "标记:"
    L["Any rule"] = "任一规则"
    L["All rules"] = "所有规则"
    L["Edit Category (Built-in)"] = "编辑分类(内置)"
    L["Edit Category"] = "编辑分类"
    L["Rules (%d/%d):"] = "规则 (%d/%d):"

    -- Settings tab labels
    L["General"] = "常规"
    L["Layout"] = "布局"
    L["Icons"] = "图标"
    L["Bar"] = "栏"
    L["Categories"] = "分类"
    L["Guide"] = "指南"

    -- Slider value-display formats
    L["Bag columns: %d"] = "背包列数: %d"
    L["Bank columns: %d"] = "银行列数: %d"
    L["Background Transparency: %d%%"] = "背景透明度: %d%%"
    L["Icon size: %dpx"] = "图标大小: %dpx"
    L["Icon font size: %dpx"] = "图标字号: %dpx"
    L["Icon spacing: %s"] = "图标间距: %s"
    L["Quest bar size: %dpx"] = "任务栏大小: %dpx"
    L["Tracked bar size: %dpx"] = "追踪栏大小: %dpx"
    L["Junk item opacity: %d%%"] = "垃圾物品透明度: %d%%"

    -- Tooltip extension
    L["Show Item Counts in Tooltip"] = "在提示框中显示物品数量"
    L["Tooltip Extension"] = "提示框扩展"
    L["Show how many of this item you have across all your characters in the item tooltip."] = "在物品提示框中显示你所有角色拥有此物品的数量。"

    -- Settings tooltip text
    L["Lock the bag frames in place so they cannot be moved by dragging."] = "锁定背包窗口位置,无法通过拖动移动。"
    L["Hide the thick borders around the bag and bank frames for a cleaner look."] = "隐藏背包和银行窗口的粗边框,使外观更简洁。"
    L["Show a color-coded border around equipped items based on their quality (Common, Rare, Epic, etc.)."] = "为装备物品显示基于品质的彩色边框(普通、稀有、史诗等)。"
    L["Show a color-coded border around non-equipped items in your bags and bank based on their quality."] = "为背包和银行中非装备物品显示基于品质的彩色边框。"
    L["Show a search bar at the top of your bags to quickly find items."] = "在背包顶部显示搜索栏,快速查找物品。"
    L["Show a bar for quickly accessing quest-related items."] = "显示一个栏位,快速访问任务相关物品。"
    L["Minimizes the bag container to show only the main bag and keyring. Hover over the main bag to view the other bags."] = "最小化背包容器,仅显示主背包和钥匙链。悬停在主背包上查看其他背包。"
    L["Hides bag slots 1-4 from the footer. Click the main bag to show a flyout with all bag slots."] = "隐藏底栏的背包栏 1-4。点击主背包显示所有背包栏的弹出菜单。"
    L["Hide the bottom section of the bag frame containing money and bag slots."] = "隐藏背包窗口底部包含金币和背包栏的部分。"
    L["Show a red tint on items that your character cannot use (wrong class, level, etc.)."] = "在你的角色无法使用的物品上显示红色色调(职业不符、等级不足等)。"
    L["Show equipment set categories in category view."] = "在分类视图中显示装备套装分类。"
    L["Show a special icon on items that belong to an equipment set."] = "在属于装备套装的物品上显示特殊图标。"
    L["Prevent selling and deleting items saved in equipment sets."] = "防止出售和删除装备套装中保存的物品。"
    L["Show the item count next to each category header in category view."] = "在分类视图中,在每个分类标题旁显示物品数量。"
    L["Automatically sell gray (junk) items when you visit a vendor."] = "访问商人时自动出售灰色(垃圾)物品。"
    L["Automatically open bags when interacting with bank, auction house, mail, or trade."] = "与银行、拍卖行、邮箱或交易交互时自动打开背包。"
    L["Automatically close bags when closing bank, auction house, mail, trade, or vendor."] = "关闭银行、拍卖行、邮箱、交易或商人时自动关闭背包。"
    L["Treat white (common) equippable items as junk. They will be dimmed and auto-sold if auto-sell is enabled."] = "将白色(普通)可装备物品视为垃圾。它们将变暗,如果启用了自动出售,会被自动出售。"
    L["When enabled, uses pfUI's background transparency instead of the slider below."] = "启用后,使用 pfUI 的背景透明度而不是下方的滑块。"
    L["When enabled, smaller stacks of the same item will be sorted before larger stacks (e.g., stack of 16 before stack of 20)."] = "启用后,同一物品较小的堆叠会排在较大的堆叠之前(例如,16 组排在 20 组之前)。"

    -- Categories / Guide
    L["GUIDE_TEXT"] = "|cffffd100追踪物品:|r\n" ..
        "Alt + 左键点击背包中的任何物品以追踪它。\n" ..
        "被追踪的物品会显示在追踪物品栏中。\n" ..
        "左键点击栏中的物品以使用它。\n" ..
        "Alt + 左键点击栏中的物品以取消追踪。\n\n" ..
        "|cffffd100锁定物品:|r\n" ..
        "Ctrl + 右键点击任何物品以锁定/解锁。\n" ..
        "锁定的物品无法在商人处出售、删除或分解。\n" ..
        "装备套装中的物品会自动受到保护。\n" ..
        "Ctrl + 右键点击套装物品可切换其保护状态。\n" ..
        "右下角会显示锁定图标。\n\n" ..
        "|cffffd100固定栏位:|r\n" ..
        "Alt + 右键点击任何背包栏位以固定/取消固定。\n" ..
        "固定的栏位在排序时会被跳过。\n" ..
        "固定保留在栏位上,而不是物品上。\n" ..
        "左上角会显示固定图标。\n\n" ..
        "|cffffd100移动栏位:|r\n" ..
        "Shift + 左键拖动任务物品栏或追踪物品栏中的任何物品以移动该栏。\n"

    L["Manage item categories and their display order:"] = "管理物品分类及其显示顺序:"
    L["(Built-in)"] = "(内置)"
    L["(Drop Item)"] = "(放下物品)"
    L["Name:"] = "名称:"
    L["Match Mode:"] = "匹配模式:"
    L["Rules:"] = "规则:"

elseif locale == "esES" then
    -- Spanish

    L["Auto Loot"] = "Saqueo automático"
    L["Automatically loot all items when looting a corpse or container."] = "Saquea automáticamente todos los objetos al saquear un cadáver o contenedor."
    L["Auto Loot requires the SuperWoW client mod. Install SuperWoW to enable this option."] = "El saqueo automático requiere la modificación de cliente SuperWoW. Instala SuperWoW para habilitar esta opción, o aplica el ajuste 'Always auto-loot' del lanzador (el cliente saqueará automáticamente, independientemente de este addon)."
    L["Auto Open Clams"] = "Abrir almejas automáticamente"
    L["Automatically open clams in your bags when you loot one."] = "Abre automáticamente las almejas de tus bolsas cuando saqueas una."
    L["/guda openclams - Open all clams in bags"] = "/guda openclams - Abrir todas las almejas de las bolsas"
    L["Opening clams..."] = "Abriendo almejas..."
    L["No clams found in your bags."] = "No se encontraron almejas en tus bolsas."
    L["No more clams to open."] = "No hay más almejas para abrir."
    L["Clam opener is already running."] = "El abridor de almejas ya está en ejecución."
    L["Clam opener stopped: %s"] = "Abridor de almejas detenido: %s"

    L["Initializing..."] = "Inicializando..."
    L["Initializing UI..."] = "Inicializando interfaz..."
    L["Ready! Type /guda to open bags"] = "¡Listo! Escribe /guda para abrir las bolsas"
    L["Scanning equipped items..."] = "Escaneando objetos equipados..."
    L["Equipped items scanned and saved!"] = "¡Objetos equipados escaneados y guardados!"

    L["Commands:"] = "Comandos:"
    L["/guda - Toggle bags"] = "/guda - Mostrar/ocultar bolsas"
    L["/guda bank - Toggle bank"] = "/guda bank - Mostrar/ocultar banco"
    L["/guda mail - Toggle mailbox"] = "/guda mail - Mostrar/ocultar buzón"
    L["/guda settings - Open settings"] = "/guda settings - Abrir ajustes"
    L["/guda sort - Sort bags"] = "/guda sort - Ordenar bolsas"
    L["/guda sortbank - Sort bank"] = "/guda sortbank - Ordenar banco"
    L["/guda track - Toggle item tracking"] = "/guda track - Alternar seguimiento de objetos"
    L["/guda debug - Toggle debug mode"] = "/guda debug - Alternar modo de depuración"
    L["/guda debugsort - Toggle sort debug output"] = "/guda debugsort - Alternar depuración de orden"
    L["/guda cleanup - Remove old characters"] = "/guda cleanup - Eliminar personajes antiguos"
    L["/guda perf - Show performance stats"] = "/guda perf - Mostrar estadísticas"
    L["/guda perfreset - Reset performance stats"] = "/guda perfreset - Restablecer estadísticas"
    L["/guda poolreset - Reset button pool (debug)"] = "/guda poolreset - Restablecer grupo de botones (depuración)"
    L["Unknown command. Type /guda help for commands"] = "Comando desconocido. Escribe /guda help para ver los comandos"
    L["Debug mode: %s"] = "Modo de depuración: %s"
    L["Debug sort mode: %s"] = "Modo de depuración de orden: %s"
    L["Debug category mode: %s"] = "Modo de depuración de categoría: %s"
    L["Quest bar: %s"] = "Barra de misión: %s"
    L["ON"] = "ACTIVADO"
    L["OFF"] = "DESACTIVADO"
    L["Settings window not available"] = "Ventana de ajustes no disponible"
    L["Performance stats not available"] = "Estadísticas de rendimiento no disponibles"
    L["Performance stats reset"] = "Estadísticas restablecidas"
    L["Cannot reset pool while bag/bank frames are open. Close them first."] = "No se puede restablecer el grupo con las bolsas/banco abiertos. Ciérralos primero."
    L["Button pool reset. Pool is now empty."] = "Grupo de botones restablecido. Está vacío."
    L["Button pool reset function not available."] = "Función de reinicio del grupo no disponible."

    L["%s's Bags"] = "Bolsas de %s"
    L["%s's Bank"] = "Banco de %s"
    L["%s's Mailbox"] = "Buzón de %s"
    L["Bank"] = "Banco"
    L["Backpack"] = "Mochila"
    L["Keyring"] = "Llavero"
    L["Bag %d"] = "Bolsa %d"
    L["Bag Slots"] = "Espacios de bolsa"
    L["Bank Bag Slot %d"] = "Espacio de bolsa del banco %d"
    L["Search, try ~equipment"] = "Buscar, prueba ~equipment"
    L["Search bank..."] = "Buscar en el banco..."
    L["Search mailbox..."] = "Buscar en el buzón..."
    L["Use Guda Bank UI"] = "Usar interfaz de banco Guda"
    L["Switched to Guda bank UI"] = "Cambiado a la interfaz de banco Guda"
    L["No Mail"] = "Sin correo"
    L["No mailbox data found for this character.\n\nVisit a mailbox in-game to save your mail data."] = "No hay datos de buzón para este personaje.\n\nVisita un buzón en el juego para guardar los datos."
    L["Current realm gold"] = "Oro del reino actual"
    L["Total gold"] = "Oro total"
    L["Settings"] = "Ajustes"
    L["Sort Bags"] = "Ordenar bolsas"
    L["Lockpicking"] = "Forzar cerraduras"
    L["Click to cast Pick Lock"] = "Haz clic para lanzar Forzar cerradura"
    L["Requires Thieves' Tools"] = "Requiere Herramientas de ladrón"
    L["My Characters"] = "Mis personajes"
    L["View Bank"] = "Ver banco"
    L["View Mailbox"] = "Ver buzón"
    L["Right-click to manage characters"] = "Clic derecho para gestionar personajes"
    L["(Right-Click to hide)"] = "(Clic derecho para ocultar)"
    L["%d Slots"] = "%d espacios"
    L["Regular Bags:"] = "Bolsas normales:"
    L["Sort Bank"] = "Ordenar banco"
    L["Use Blizzard Bank UI"] = "Usar interfaz de banco de Blizzard"

    L["Cannot sort another character's bags!"] = "¡No se pueden ordenar las bolsas de otro personaje!"
    L["Cannot sort in read-only mode!"] = "¡No se puede ordenar en modo solo lectura!"
    L["Bags are already sorted!"] = "¡Las bolsas ya están ordenadas!"
    L["Bank is already sorted!"] = "¡El banco ya está ordenado!"
    L["Bank must be open to sort!"] = "¡El banco debe estar abierto para ordenar!"
    L["Sorting already in progress, please wait..."] = "Ya se está ordenando, espera por favor..."
    L["Restacked %d stack(s)"] = "Reapiladas %d pila(s)"
    L["Sold %d junk item(s)"] = "Vendidos %d objeto(s) de basura"
    L["Bag replaced successfully!"] = "¡Bolsa reemplazada con éxito!"
    L["Cannot replace bag: another replacement is in progress."] = "No se puede reemplazar la bolsa: hay otra operación en curso."
    L["Cannot replace bag while sorting is in progress."] = "No se puede reemplazar la bolsa durante el ordenamiento."
    L["Cannot replace bag during combat."] = "No se puede reemplazar la bolsa en combate."

    L["Cannot sell %s — item is protected"] = "No se puede vender %s — objeto protegido"
    L["Cannot disenchant %s — item is protected"] = "No se puede desencantar %s — objeto protegido"
    L["Cannot delete %s — item is protected"] = "No se puede eliminar %s — objeto protegido"
    L["Slot pinned %s (skipped during sort)"] = "Casilla fijada %s (omitida al ordenar)"
    L["Slot unpinned %s"] = "Casilla desfijada %s"
    L["%s set protection removed"] = "%s protección de conjunto eliminada"
    L["%s set protection restored"] = "%s protección de conjunto restaurada"
    L["%s locked"] = "%s bloqueado"
    L["%s unlocked"] = "%s desbloqueado"

    L["Item is not currently in your bags (loading from database)."] = "El objeto no está en tus bolsas (cargando de la base de datos)."

    L["Inventory"] = "Inventario"
    L["Other Accounts"] = "Otras cuentas"
    L["Total"] = "Total"
    L["Bags"] = "Bolsas"
    L["Mail"] = "Correo"
    L["Equipped"] = "Equipado"

    L["Imported %d character(s) from other accounts"] = "Importado(s) %d personaje(s) de otras cuentas"

    L["=== Guda Performance Stats ==="] = "=== Estadísticas de rendimiento Guda ==="
    L["Frame Budget: %.0fms"] = "Presupuesto de fotograma: %.0fms"
    L["Last Update: %.1fms"] = "Última actualización: %.1fms"
    L["Total Updates: %d"] = "Actualizaciones totales: %d"
    L["Budget Exceeded: %d times"] = "Presupuesto excedido: %d veces"

    L["Guda Settings"] = "Ajustes de Guda"
    L["Appearance"] = "Apariencia"
    L["Options"] = "Opciones"
    L["Automation"] = "Automatización"
    L["View"] = "Vista"
    L["Columns"] = "Columnas"
    L["Icon"] = "Icono"
    L["Icon Options"] = "Opciones de icono"
    L["Quest Bar"] = "Barra de misión"
    L["Tracked"] = "Seguimiento"
    L["Theme"] = "Tema"
    L["Bag View"] = "Vista de bolsa"
    L["Bank View"] = "Vista de banco"
    L["Bag columns"] = "Columnas de bolsa"
    L["Bank columns"] = "Columnas de banco"
    L["Background Transparency"] = "Transparencia de fondo"
    L["Icon size"] = "Tamaño de icono"
    L["Icon font size"] = "Tamaño de fuente de icono"
    L["Icon spacing"] = "Espaciado de icono"
    L["Quest bar size"] = "Tamaño de barra de misión"
    L["Tracked bar size"] = "Tamaño de barra de seguimiento"
    L["Junk item opacity"] = "Opacidad de objetos basura"
    L["Lock Window"] = "Bloquear ventana"
    L["Hide Frame Borders"] = "Ocultar bordes de marco"
    L["Equipment Borders"] = "Bordes de equipo"
    L["Other Item Borders"] = "Bordes de otros objetos"
    L["Show Search Bar"] = "Mostrar barra de búsqueda"
    L["Show Quest Bar"] = "Mostrar barra de misión"
    L["Show All Bags"] = "Mostrar todas las bolsas"
    L["Hide Footer"] = "Ocultar pie"
    L["Mark Unusable Items"] = "Marcar objetos inutilizables"
    L["Equip Set Categories"] = "Categorías de conjunto"
    L["Mark Equipment Sets"] = "Marcar conjuntos de equipo"
    L["Auto Lock Set Items"] = "Bloquear objetos de conjunto auto."
    L["Show Category Count"] = "Mostrar conteo de categoría"
    L["Auto Sell Junk"] = "Vender basura automáticamente"
    L["Auto Open Bags"] = "Abrir bolsas automáticamente"
    L["Auto Close Bags"] = "Cerrar bolsas automáticamente"
    L["White Items as Junk"] = "Objetos blancos como basura"
    L["pfUI Transparency"] = "Transparencia pfUI"
    L["Reverse Stack Sort"] = "Orden de pila inverso"
    L["Edit"] = "Editar"
    L["Save"] = "Guardar"
    L["Cancel"] = "Cancelar"
    L["+ Add Category"] = "+ Añadir categoría"
    L["+ Add Rule"] = "+ Añadir regla"
    L["Reset Defaults"] = "Restablecer"
    L["Select Type"] = "Seleccionar tipo"
    L["Select Value"] = "Seleccionar valor"
    L["Tracking Items:"] = "Objetos en seguimiento:"
    L["Locked Items:"] = "Objetos bloqueados:"
    L["Pin Slot:"] = "Fijar casilla:"
    L["Moving Bars:"] = "Mover barras:"
    L["Merge"] = "Combinar"
    L["Group:"] = "Grupo:"
    L["Mark:"] = "Marca:"
    L["Any rule"] = "Cualquier regla"
    L["All rules"] = "Todas las reglas"
    L["Edit Category (Built-in)"] = "Editar categoría (integrada)"
    L["Edit Category"] = "Editar categoría"
    L["Rules (%d/%d):"] = "Reglas (%d/%d):"

    L["General"] = "General"
    L["Layout"] = "Diseño"
    L["Icons"] = "Iconos"
    L["Bar"] = "Barra"
    L["Categories"] = "Categorías"
    L["Guide"] = "Guía"

    L["Bag columns: %d"] = "Columnas de bolsa: %d"
    L["Bank columns: %d"] = "Columnas de banco: %d"
    L["Background Transparency: %d%%"] = "Transparencia de fondo: %d%%"
    L["Icon size: %dpx"] = "Tamaño de icono: %dpx"
    L["Icon font size: %dpx"] = "Tamaño de fuente: %dpx"
    L["Icon spacing: %s"] = "Espaciado de icono: %s"
    L["Quest bar size: %dpx"] = "Tamaño de barra de misión: %dpx"
    L["Tracked bar size: %dpx"] = "Tamaño de barra de seguimiento: %dpx"
    L["Junk item opacity: %d%%"] = "Opacidad de basura: %d%%"

    L["Show Item Counts in Tooltip"] = "Mostrar contadores en la información"
    L["Tooltip Extension"] = "Extensión de información"
    L["Show how many of this item you have across all your characters in the item tooltip."] = "Muestra cuántos de este objeto tienes en todos tus personajes en la información del objeto."

    L["Lock the bag frames in place so they cannot be moved by dragging."] = "Bloquea las bolsas en su sitio para que no se puedan arrastrar."
    L["Hide the thick borders around the bag and bank frames for a cleaner look."] = "Oculta los bordes gruesos alrededor de las bolsas y el banco para un aspecto más limpio."
    L["Show a color-coded border around equipped items based on their quality (Common, Rare, Epic, etc.)."] = "Muestra un borde de color alrededor de los objetos equipados según su calidad (Común, Raro, Épico, etc.)."
    L["Show a color-coded border around non-equipped items in your bags and bank based on their quality."] = "Muestra un borde de color alrededor de los objetos no equipados en tus bolsas y banco según su calidad."
    L["Show a search bar at the top of your bags to quickly find items."] = "Muestra una barra de búsqueda en la parte superior de tus bolsas para encontrar objetos rápidamente."
    L["Show a bar for quickly accessing quest-related items."] = "Muestra una barra para acceder rápidamente a objetos de misión."
    L["Minimizes the bag container to show only the main bag and keyring. Hover over the main bag to view the other bags."] = "Minimiza el contenedor para mostrar solo la bolsa principal y el llavero. Pasa el cursor sobre la bolsa principal para ver las demás."
    L["Hides bag slots 1-4 from the footer. Click the main bag to show a flyout with all bag slots."] = "Oculta los espacios de bolsa 1-4 del pie. Haz clic en la bolsa principal para mostrar un menú con todas las bolsas."
    L["Hide the bottom section of the bag frame containing money and bag slots."] = "Oculta la sección inferior de la ventana de bolsas con dinero y bolsas."
    L["Show a red tint on items that your character cannot use (wrong class, level, etc.)."] = "Muestra un tinte rojo en los objetos que tu personaje no puede usar (clase incorrecta, nivel, etc.)."
    L["Show equipment set categories in category view."] = "Muestra las categorías de conjuntos de equipo en la vista por categorías."
    L["Show a special icon on items that belong to an equipment set."] = "Muestra un icono especial en los objetos que pertenecen a un conjunto de equipo."
    L["Prevent selling and deleting items saved in equipment sets."] = "Evita vender y eliminar objetos guardados en conjuntos de equipo."
    L["Show the item count next to each category header in category view."] = "Muestra el número de objetos junto a cada encabezado de categoría en la vista por categorías."
    L["Automatically sell gray (junk) items when you visit a vendor."] = "Vende automáticamente los objetos grises (basura) al visitar un vendedor."
    L["Automatically open bags when interacting with bank, auction house, mail, or trade."] = "Abre automáticamente las bolsas al interactuar con el banco, la casa de subastas, el correo o el comercio."
    L["Automatically close bags when closing bank, auction house, mail, trade, or vendor."] = "Cierra automáticamente las bolsas al cerrar el banco, la casa de subastas, el correo, el comercio o el vendedor."
    L["Treat white (common) equippable items as junk. They will be dimmed and auto-sold if auto-sell is enabled."] = "Trata los objetos equipables blancos (comunes) como basura. Se atenuarán y se venderán automáticamente si la venta automática está activa."
    L["When enabled, uses pfUI's background transparency instead of the slider below."] = "Cuando está activado, usa la transparencia de fondo de pfUI en lugar del control deslizante de abajo."
    L["When enabled, smaller stacks of the same item will be sorted before larger stacks (e.g., stack of 16 before stack of 20)."] = "Cuando está activado, las pilas más pequeñas del mismo objeto se ordenarán antes que las más grandes (p. ej., una pila de 16 antes que una de 20)."

    L["GUIDE_TEXT"] = "|cffffd100Seguir objetos:|r\n" ..
        "Alt + Clic izquierdo en cualquier objeto de tus bolsas para seguirlo.\n" ..
        "Los objetos seguidos aparecerán en la barra de objetos seguidos.\n" ..
        "Clic izquierdo en un objeto de la barra para usarlo.\n" ..
        "Alt + Clic izquierdo en un objeto de la barra para dejar de seguirlo.\n\n" ..
        "|cffffd100Objetos bloqueados:|r\n" ..
        "Ctrl + Clic derecho en cualquier objeto para bloquear/desbloquear.\n" ..
        "Los objetos bloqueados no pueden venderse, eliminarse ni desencantarse.\n" ..
        "Los objetos de los conjuntos de equipo están protegidos automáticamente.\n" ..
        "Ctrl + Clic derecho en un objeto de conjunto para alternar su protección.\n" ..
        "Aparece un icono de candado en la esquina inferior derecha.\n\n" ..
        "|cffffd100Fijar casilla:|r\n" ..
        "Alt + Clic derecho en cualquier casilla de bolsa para fijarla/desfijarla.\n" ..
        "Las casillas fijadas se omiten al ordenar.\n" ..
        "La fijación se queda en la casilla, no en el objeto.\n" ..
        "Aparece un icono de chincheta en la esquina superior izquierda.\n\n" ..
        "|cffffd100Mover barras:|r\n" ..
        "Shift + Clic izquierdo y arrastrar cualquier objeto de la barra de objetos de misión o seguidos para mover la barra.\n"

    L["Manage item categories and their display order:"] = "Gestiona las categorías de objetos y su orden:"
    L["(Built-in)"] = "(Integrada)"
    L["(Drop Item)"] = "(Soltar objeto)"
    L["Name:"] = "Nombre:"
    L["Match Mode:"] = "Modo de coincidencia:"
    L["Rules:"] = "Reglas:"

elseif locale == "ptBR" then
    -- Portuguese (Brazilian)

    L["Auto Loot"] = "Saque automático"
    L["Automatically loot all items when looting a corpse or container."] = "Saqueia automaticamente todos os itens ao saquear um cadáver ou recipiente."
    L["Auto Loot requires the SuperWoW client mod. Install SuperWoW to enable this option."] = "O saque automático requer a modificação de cliente SuperWoW. Instale o SuperWoW para habilitar esta opção, ou aplique o ajuste 'Always auto-loot' do lançador (o cliente saqueará automaticamente, independentemente deste addon)."
    L["Auto Open Clams"] = "Abrir mariscos automaticamente"
    L["Automatically open clams in your bags when you loot one."] = "Abre automaticamente os mariscos nas suas bolsas quando você saqueia um."
    L["/guda openclams - Open all clams in bags"] = "/guda openclams - Abrir todos os mariscos nas bolsas"
    L["Opening clams..."] = "Abrindo mariscos..."
    L["No clams found in your bags."] = "Nenhum marisco encontrado nas suas bolsas."
    L["No more clams to open."] = "Não há mais mariscos para abrir."
    L["Clam opener is already running."] = "O abridor de mariscos já está em execução."
    L["Clam opener stopped: %s"] = "Abridor de mariscos parado: %s"

    L["Initializing..."] = "Inicializando..."
    L["Initializing UI..."] = "Inicializando interface..."
    L["Ready! Type /guda to open bags"] = "Pronto! Digite /guda para abrir as bolsas"
    L["Scanning equipped items..."] = "Escaneando itens equipados..."
    L["Equipped items scanned and saved!"] = "Itens equipados escaneados e salvos!"

    L["Commands:"] = "Comandos:"
    L["/guda - Toggle bags"] = "/guda - Alternar bolsas"
    L["/guda bank - Toggle bank"] = "/guda bank - Alternar banco"
    L["/guda mail - Toggle mailbox"] = "/guda mail - Alternar caixa de correio"
    L["/guda settings - Open settings"] = "/guda settings - Abrir configurações"
    L["/guda sort - Sort bags"] = "/guda sort - Organizar bolsas"
    L["/guda sortbank - Sort bank"] = "/guda sortbank - Organizar banco"
    L["/guda track - Toggle item tracking"] = "/guda track - Alternar rastreamento de itens"
    L["/guda debug - Toggle debug mode"] = "/guda debug - Alternar modo de depuração"
    L["/guda debugsort - Toggle sort debug output"] = "/guda debugsort - Alternar depuração de organização"
    L["/guda cleanup - Remove old characters"] = "/guda cleanup - Remover personagens antigos"
    L["/guda perf - Show performance stats"] = "/guda perf - Mostrar estatísticas"
    L["/guda perfreset - Reset performance stats"] = "/guda perfreset - Redefinir estatísticas"
    L["/guda poolreset - Reset button pool (debug)"] = "/guda poolreset - Redefinir pool de botões (depuração)"
    L["Unknown command. Type /guda help for commands"] = "Comando desconhecido. Digite /guda help para ver os comandos"
    L["Debug mode: %s"] = "Modo de depuração: %s"
    L["Debug sort mode: %s"] = "Modo de depuração de organização: %s"
    L["Debug category mode: %s"] = "Modo de depuração de categoria: %s"
    L["Quest bar: %s"] = "Barra de missão: %s"
    L["ON"] = "LIGADO"
    L["OFF"] = "DESLIGADO"
    L["Settings window not available"] = "Janela de configurações indisponível"
    L["Performance stats not available"] = "Estatísticas indisponíveis"
    L["Performance stats reset"] = "Estatísticas redefinidas"
    L["Cannot reset pool while bag/bank frames are open. Close them first."] = "Não é possível redefinir o pool com as bolsas/banco abertos. Feche-os primeiro."
    L["Button pool reset. Pool is now empty."] = "Pool de botões redefinido. Está vazio."
    L["Button pool reset function not available."] = "Função de redefinição do pool indisponível."

    L["%s's Bags"] = "Bolsas de %s"
    L["%s's Bank"] = "Banco de %s"
    L["%s's Mailbox"] = "Caixa de correio de %s"
    L["Bank"] = "Banco"
    L["Backpack"] = "Mochila"
    L["Keyring"] = "Chaveiro"
    L["Bag %d"] = "Bolsa %d"
    L["Bag Slots"] = "Espaços de bolsa"
    L["Bank Bag Slot %d"] = "Espaço de bolsa do banco %d"
    L["Search, try ~equipment"] = "Buscar, tente ~equipment"
    L["Search bank..."] = "Buscar no banco..."
    L["Search mailbox..."] = "Buscar na caixa de correio..."
    L["Use Guda Bank UI"] = "Usar interface de banco Guda"
    L["Switched to Guda bank UI"] = "Alterado para a interface de banco Guda"
    L["No Mail"] = "Sem correio"
    L["No mailbox data found for this character.\n\nVisit a mailbox in-game to save your mail data."] = "Nenhum dado de caixa de correio para este personagem.\n\nVisite uma caixa de correio no jogo para salvar os dados."
    L["Current realm gold"] = "Ouro do reino atual"
    L["Total gold"] = "Ouro total"
    L["Settings"] = "Configurações"
    L["Sort Bags"] = "Organizar bolsas"
    L["Lockpicking"] = "Arrombar fechaduras"
    L["Click to cast Pick Lock"] = "Clique para lançar Arrombar fechadura"
    L["Requires Thieves' Tools"] = "Requer Ferramentas de ladrão"
    L["My Characters"] = "Meus personagens"
    L["View Bank"] = "Ver banco"
    L["View Mailbox"] = "Ver caixa de correio"
    L["Right-click to manage characters"] = "Clique direito para gerenciar personagens"
    L["(Right-Click to hide)"] = "(Clique direito para ocultar)"
    L["%d Slots"] = "%d espaços"
    L["Regular Bags:"] = "Bolsas comuns:"
    L["Sort Bank"] = "Organizar banco"
    L["Use Blizzard Bank UI"] = "Usar interface de banco da Blizzard"

    L["Cannot sort another character's bags!"] = "Não é possível organizar as bolsas de outro personagem!"
    L["Cannot sort in read-only mode!"] = "Não é possível organizar em modo somente leitura!"
    L["Bags are already sorted!"] = "As bolsas já estão organizadas!"
    L["Bank is already sorted!"] = "O banco já está organizado!"
    L["Bank must be open to sort!"] = "O banco precisa estar aberto para organizar!"
    L["Sorting already in progress, please wait..."] = "Organização em andamento, aguarde..."
    L["Restacked %d stack(s)"] = "%d pilha(s) reorganizadas"
    L["Sold %d junk item(s)"] = "Vendidos %d item(ns) de lixo"
    L["Bag replaced successfully!"] = "Bolsa substituída com sucesso!"
    L["Cannot replace bag: another replacement is in progress."] = "Não é possível substituir a bolsa: outra substituição em andamento."
    L["Cannot replace bag while sorting is in progress."] = "Não é possível substituir a bolsa durante a organização."
    L["Cannot replace bag during combat."] = "Não é possível substituir a bolsa em combate."

    L["Cannot sell %s — item is protected"] = "Não é possível vender %s — item protegido"
    L["Cannot disenchant %s — item is protected"] = "Não é possível desencantar %s — item protegido"
    L["Cannot delete %s — item is protected"] = "Não é possível excluir %s — item protegido"
    L["Slot pinned %s (skipped during sort)"] = "Espaço fixado %s (ignorado ao organizar)"
    L["Slot unpinned %s"] = "Espaço desafixado %s"
    L["%s set protection removed"] = "Proteção de conjunto removida de %s"
    L["%s set protection restored"] = "Proteção de conjunto restaurada para %s"
    L["%s locked"] = "%s bloqueado"
    L["%s unlocked"] = "%s desbloqueado"

    L["Item is not currently in your bags (loading from database)."] = "O item não está nas suas bolsas (carregando do banco de dados)."

    L["Inventory"] = "Inventário"
    L["Other Accounts"] = "Outras contas"
    L["Total"] = "Total"
    L["Bags"] = "Bolsas"
    L["Mail"] = "Correio"
    L["Equipped"] = "Equipado"

    L["Imported %d character(s) from other accounts"] = "Importado(s) %d personagem(ns) de outras contas"

    L["=== Guda Performance Stats ==="] = "=== Estatísticas de desempenho Guda ==="
    L["Frame Budget: %.0fms"] = "Orçamento de quadro: %.0fms"
    L["Last Update: %.1fms"] = "Última atualização: %.1fms"
    L["Total Updates: %d"] = "Total de atualizações: %d"
    L["Budget Exceeded: %d times"] = "Orçamento excedido: %d vezes"

    L["Guda Settings"] = "Configurações Guda"
    L["Appearance"] = "Aparência"
    L["Options"] = "Opções"
    L["Automation"] = "Automação"
    L["View"] = "Visão"
    L["Columns"] = "Colunas"
    L["Icon"] = "Ícone"
    L["Icon Options"] = "Opções de ícone"
    L["Quest Bar"] = "Barra de missão"
    L["Tracked"] = "Rastreado"
    L["Theme"] = "Tema"
    L["Bag View"] = "Visão da bolsa"
    L["Bank View"] = "Visão do banco"
    L["Bag columns"] = "Colunas da bolsa"
    L["Bank columns"] = "Colunas do banco"
    L["Background Transparency"] = "Transparência do fundo"
    L["Icon size"] = "Tamanho do ícone"
    L["Icon font size"] = "Tamanho da fonte do ícone"
    L["Icon spacing"] = "Espaçamento do ícone"
    L["Quest bar size"] = "Tamanho da barra de missão"
    L["Tracked bar size"] = "Tamanho da barra rastreada"
    L["Junk item opacity"] = "Opacidade dos itens de lixo"
    L["Lock Window"] = "Travar janela"
    L["Hide Frame Borders"] = "Ocultar bordas do quadro"
    L["Equipment Borders"] = "Bordas de equipamento"
    L["Other Item Borders"] = "Bordas de outros itens"
    L["Show Search Bar"] = "Mostrar barra de busca"
    L["Show Quest Bar"] = "Mostrar barra de missão"
    L["Show All Bags"] = "Mostrar todas as bolsas"
    L["Hide Footer"] = "Ocultar rodapé"
    L["Mark Unusable Items"] = "Marcar itens inutilizáveis"
    L["Equip Set Categories"] = "Categorias de conjunto"
    L["Mark Equipment Sets"] = "Marcar conjuntos de equipamento"
    L["Auto Lock Set Items"] = "Travar itens de conjunto auto."
    L["Show Category Count"] = "Mostrar contagem de categoria"
    L["Auto Sell Junk"] = "Vender lixo automaticamente"
    L["Auto Open Bags"] = "Abrir bolsas automaticamente"
    L["Auto Close Bags"] = "Fechar bolsas automaticamente"
    L["White Items as Junk"] = "Itens brancos como lixo"
    L["pfUI Transparency"] = "Transparência pfUI"
    L["Reverse Stack Sort"] = "Ordem de pilha inversa"
    L["Edit"] = "Editar"
    L["Save"] = "Salvar"
    L["Cancel"] = "Cancelar"
    L["+ Add Category"] = "+ Adicionar categoria"
    L["+ Add Rule"] = "+ Adicionar regra"
    L["Reset Defaults"] = "Redefinir padrões"
    L["Select Type"] = "Selecionar tipo"
    L["Select Value"] = "Selecionar valor"
    L["Tracking Items:"] = "Rastreando itens:"
    L["Locked Items:"] = "Itens bloqueados:"
    L["Pin Slot:"] = "Fixar espaço:"
    L["Moving Bars:"] = "Mover barras:"
    L["Merge"] = "Mesclar"
    L["Group:"] = "Grupo:"
    L["Mark:"] = "Marca:"
    L["Any rule"] = "Qualquer regra"
    L["All rules"] = "Todas as regras"
    L["Edit Category (Built-in)"] = "Editar categoria (integrada)"
    L["Edit Category"] = "Editar categoria"
    L["Rules (%d/%d):"] = "Regras (%d/%d):"

    L["General"] = "Geral"
    L["Layout"] = "Layout"
    L["Icons"] = "Ícones"
    L["Bar"] = "Barra"
    L["Categories"] = "Categorias"
    L["Guide"] = "Guia"

    L["Bag columns: %d"] = "Colunas da bolsa: %d"
    L["Bank columns: %d"] = "Colunas do banco: %d"
    L["Background Transparency: %d%%"] = "Transparência do fundo: %d%%"
    L["Icon size: %dpx"] = "Tamanho do ícone: %dpx"
    L["Icon font size: %dpx"] = "Tamanho da fonte: %dpx"
    L["Icon spacing: %s"] = "Espaçamento: %s"
    L["Quest bar size: %dpx"] = "Tamanho da barra de missão: %dpx"
    L["Tracked bar size: %dpx"] = "Tamanho da barra rastreada: %dpx"
    L["Junk item opacity: %d%%"] = "Opacidade do lixo: %d%%"

    L["Show Item Counts in Tooltip"] = "Mostrar contagem na dica"
    L["Tooltip Extension"] = "Extensão da dica"
    L["Show how many of this item you have across all your characters in the item tooltip."] = "Mostra quantos deste item você tem em todos os seus personagens, na dica do item."

    L["Lock the bag frames in place so they cannot be moved by dragging."] = "Trava as bolsas no lugar para que não possam ser arrastadas."
    L["Hide the thick borders around the bag and bank frames for a cleaner look."] = "Oculta as bordas grossas ao redor das bolsas e do banco para um visual mais limpo."
    L["Show a color-coded border around equipped items based on their quality (Common, Rare, Epic, etc.)."] = "Mostra uma borda colorida ao redor dos itens equipados com base em sua qualidade (Comum, Raro, Épico, etc.)."
    L["Show a color-coded border around non-equipped items in your bags and bank based on their quality."] = "Mostra uma borda colorida ao redor dos itens não equipados em suas bolsas e banco com base em sua qualidade."
    L["Show a search bar at the top of your bags to quickly find items."] = "Mostra uma barra de busca no topo das bolsas para encontrar itens rapidamente."
    L["Show a bar for quickly accessing quest-related items."] = "Mostra uma barra para acessar rapidamente itens de missão."
    L["Minimizes the bag container to show only the main bag and keyring. Hover over the main bag to view the other bags."] = "Minimiza o contêiner para mostrar apenas a bolsa principal e o chaveiro. Passe o mouse sobre a bolsa principal para ver as outras."
    L["Hides bag slots 1-4 from the footer. Click the main bag to show a flyout with all bag slots."] = "Oculta os espaços de bolsa 1-4 do rodapé. Clique na bolsa principal para mostrar um menu com todas as bolsas."
    L["Hide the bottom section of the bag frame containing money and bag slots."] = "Oculta a seção inferior da janela de bolsas, contendo dinheiro e espaços de bolsa."
    L["Show a red tint on items that your character cannot use (wrong class, level, etc.)."] = "Mostra um tom vermelho nos itens que seu personagem não pode usar (classe errada, nível, etc.)."
    L["Show equipment set categories in category view."] = "Mostra as categorias de conjuntos de equipamento na visão por categorias."
    L["Show a special icon on items that belong to an equipment set."] = "Mostra um ícone especial nos itens que pertencem a um conjunto de equipamento."
    L["Prevent selling and deleting items saved in equipment sets."] = "Impede a venda e exclusão de itens salvos em conjuntos de equipamento."
    L["Show the item count next to each category header in category view."] = "Mostra a contagem de itens ao lado de cada cabeçalho de categoria na visão por categorias."
    L["Automatically sell gray (junk) items when you visit a vendor."] = "Vende automaticamente itens cinza (lixo) ao visitar um vendedor."
    L["Automatically open bags when interacting with bank, auction house, mail, or trade."] = "Abre as bolsas automaticamente ao interagir com banco, casa de leilões, correio ou comércio."
    L["Automatically close bags when closing bank, auction house, mail, trade, or vendor."] = "Fecha as bolsas automaticamente ao fechar banco, casa de leilões, correio, comércio ou vendedor."
    L["Treat white (common) equippable items as junk. They will be dimmed and auto-sold if auto-sell is enabled."] = "Trata itens equipáveis brancos (comuns) como lixo. Eles serão escurecidos e vendidos automaticamente se a venda automática estiver ativada."
    L["When enabled, uses pfUI's background transparency instead of the slider below."] = "Quando ativado, usa a transparência de fundo do pfUI em vez do controle deslizante abaixo."
    L["When enabled, smaller stacks of the same item will be sorted before larger stacks (e.g., stack of 16 before stack of 20)."] = "Quando ativado, pilhas menores do mesmo item serão organizadas antes das pilhas maiores (ex: pilha de 16 antes da pilha de 20)."

    L["GUIDE_TEXT"] = "|cffffd100Rastreando itens:|r\n" ..
        "Alt + Clique esquerdo em qualquer item das bolsas para rastreá-lo.\n" ..
        "Os itens rastreados aparecem na Barra de Itens Rastreados.\n" ..
        "Clique esquerdo em um item da barra para usá-lo.\n" ..
        "Alt + Clique esquerdo em um item da barra para parar de rastreá-lo.\n\n" ..
        "|cffffd100Itens bloqueados:|r\n" ..
        "Ctrl + Clique direito em qualquer item para travar/destravar.\n" ..
        "Itens travados não podem ser vendidos, excluídos ou desencantados.\n" ..
        "Os itens de conjuntos de equipamento são protegidos automaticamente.\n" ..
        "Ctrl + Clique direito em um item de conjunto para alternar a proteção.\n" ..
        "Um ícone de cadeado aparece no canto inferior direito.\n\n" ..
        "|cffffd100Fixar espaço:|r\n" ..
        "Alt + Clique direito em qualquer espaço de bolsa para fixar/desafixar.\n" ..
        "Espaços fixados são ignorados durante a organização.\n" ..
        "A fixação fica no espaço, não no item.\n" ..
        "Um ícone de pino aparece no canto superior esquerdo.\n\n" ..
        "|cffffd100Mover barras:|r\n" ..
        "Shift + Clique esquerdo e arraste qualquer item na Barra de Missão ou na Barra de Itens Rastreados para mover a barra.\n"

    L["Manage item categories and their display order:"] = "Gerencie as categorias de itens e sua ordem de exibição:"
    L["(Built-in)"] = "(Integrada)"
    L["(Drop Item)"] = "(Soltar item)"
    L["Name:"] = "Nome:"
    L["Match Mode:"] = "Modo de correspondência:"
    L["Rules:"] = "Regras:"

elseif locale == "deDE" then
    -- German

    L["Auto Loot"] = "Automatisches Plündern"
    L["Automatically loot all items when looting a corpse or container."] = "Plündere automatisch alle Gegenstände von Leichen und Behältern."
    L["Auto Loot requires the SuperWoW client mod. Install SuperWoW to enable this option."] = "Automatisches Plündern erfordert die SuperWoW-Clienterweiterung. Installiere SuperWoW, um diese Option zu aktivieren, oder wende den Launcher-Tweak 'Always auto-loot' an (dann plündert der Client unabhängig von diesem Addon automatisch)."
    L["Auto Open Clams"] = "Muscheln automatisch öffnen"
    L["Automatically open clams in your bags when you loot one."] = "Öffnet automatisch Muscheln in deinen Taschen, wenn du eine erbeutest."
    L["/guda openclams - Open all clams in bags"] = "/guda openclams - Alle Muscheln in den Taschen öffnen"
    L["Opening clams..."] = "Öffne Muscheln..."
    L["No clams found in your bags."] = "Keine Muscheln in deinen Taschen gefunden."
    L["No more clams to open."] = "Keine weiteren Muscheln zu öffnen."
    L["Clam opener is already running."] = "Der Muschelöffner läuft bereits."
    L["Clam opener stopped: %s"] = "Muschelöffner gestoppt: %s"

    L["Initializing..."] = "Initialisiere..."
    L["Initializing UI..."] = "Initialisiere Oberfläche..."
    L["Ready! Type /guda to open bags"] = "Bereit! Tippe /guda um die Taschen zu öffnen"
    L["Scanning equipped items..."] = "Untersuche ausgerüstete Gegenstände..."
    L["Equipped items scanned and saved!"] = "Ausgerüstete Gegenstände gescannt und gespeichert!"

    L["Commands:"] = "Befehle:"
    L["/guda - Toggle bags"] = "/guda - Taschen umschalten"
    L["/guda bank - Toggle bank"] = "/guda bank - Bank umschalten"
    L["/guda mail - Toggle mailbox"] = "/guda mail - Briefkasten umschalten"
    L["/guda settings - Open settings"] = "/guda settings - Einstellungen öffnen"
    L["/guda sort - Sort bags"] = "/guda sort - Taschen sortieren"
    L["/guda sortbank - Sort bank"] = "/guda sortbank - Bank sortieren"
    L["/guda track - Toggle item tracking"] = "/guda track - Verfolgung umschalten"
    L["/guda debug - Toggle debug mode"] = "/guda debug - Debug-Modus umschalten"
    L["/guda debugsort - Toggle sort debug output"] = "/guda debugsort - Sortier-Debug umschalten"
    L["/guda cleanup - Remove old characters"] = "/guda cleanup - Alte Charaktere entfernen"
    L["/guda perf - Show performance stats"] = "/guda perf - Leistungsstatistiken anzeigen"
    L["/guda perfreset - Reset performance stats"] = "/guda perfreset - Statistiken zurücksetzen"
    L["/guda poolreset - Reset button pool (debug)"] = "/guda poolreset - Button-Pool zurücksetzen (debug)"
    L["Unknown command. Type /guda help for commands"] = "Unbekannter Befehl. Tippe /guda help für die Befehle"
    L["Debug mode: %s"] = "Debug-Modus: %s"
    L["Debug sort mode: %s"] = "Sortier-Debug-Modus: %s"
    L["Debug category mode: %s"] = "Kategorie-Debug-Modus: %s"
    L["Quest bar: %s"] = "Quest-Leiste: %s"
    L["ON"] = "AN"
    L["OFF"] = "AUS"
    L["Settings window not available"] = "Einstellungsfenster nicht verfügbar"
    L["Performance stats not available"] = "Leistungsstatistiken nicht verfügbar"
    L["Performance stats reset"] = "Statistiken zurückgesetzt"
    L["Cannot reset pool while bag/bank frames are open. Close them first."] = "Pool kann nicht zurückgesetzt werden, solange Taschen/Bank offen sind. Schließe sie zuerst."
    L["Button pool reset. Pool is now empty."] = "Button-Pool zurückgesetzt. Pool ist leer."
    L["Button pool reset function not available."] = "Pool-Reset-Funktion nicht verfügbar."

    L["%s's Bags"] = "Taschen von %s"
    L["%s's Bank"] = "Bank von %s"
    L["%s's Mailbox"] = "Briefkasten von %s"
    L["Bank"] = "Bank"
    L["Backpack"] = "Rucksack"
    L["Keyring"] = "Schlüsselbund"
    L["Bag %d"] = "Tasche %d"
    L["Bag Slots"] = "Taschenplätze"
    L["Bank Bag Slot %d"] = "Bank-Taschenplatz %d"
    L["Search, try ~equipment"] = "Suche, versuche ~equipment"
    L["Search bank..."] = "Bank durchsuchen..."
    L["Search mailbox..."] = "Briefkasten durchsuchen..."
    L["Use Guda Bank UI"] = "Guda-Bankoberfläche verwenden"
    L["Switched to Guda bank UI"] = "Zur Guda-Bankoberfläche gewechselt"
    L["No Mail"] = "Keine Post"
    L["No mailbox data found for this character.\n\nVisit a mailbox in-game to save your mail data."] = "Keine Briefkastendaten für diesen Charakter.\n\nBesuche einen Briefkasten im Spiel, um Daten zu speichern."
    L["Current realm gold"] = "Gold auf aktuellem Realm"
    L["Total gold"] = "Gesamtgold"
    L["Settings"] = "Einstellungen"
    L["Sort Bags"] = "Taschen sortieren"
    L["Lockpicking"] = "Schlossknacken"
    L["Click to cast Pick Lock"] = "Klicken um Schloss knacken zu wirken"
    L["Requires Thieves' Tools"] = "Benötigt Diebeswerkzeug"
    L["My Characters"] = "Meine Charaktere"
    L["View Bank"] = "Bank anzeigen"
    L["View Mailbox"] = "Briefkasten anzeigen"
    L["Right-click to manage characters"] = "Rechtsklick zum Verwalten der Charaktere"
    L["(Right-Click to hide)"] = "(Rechtsklick zum Ausblenden)"
    L["%d Slots"] = "%d Plätze"
    L["Regular Bags:"] = "Normale Taschen:"
    L["Sort Bank"] = "Bank sortieren"
    L["Use Blizzard Bank UI"] = "Blizzard-Bankoberfläche verwenden"

    L["Cannot sort another character's bags!"] = "Taschen anderer Charaktere können nicht sortiert werden!"
    L["Cannot sort in read-only mode!"] = "Im Nur-Lese-Modus kann nicht sortiert werden!"
    L["Bags are already sorted!"] = "Die Taschen sind bereits sortiert!"
    L["Bank is already sorted!"] = "Die Bank ist bereits sortiert!"
    L["Bank must be open to sort!"] = "Die Bank muss zum Sortieren offen sein!"
    L["Sorting already in progress, please wait..."] = "Sortierung läuft, bitte warten..."
    L["Restacked %d stack(s)"] = "%d Stapel neu gestapelt"
    L["Sold %d junk item(s)"] = "%d Müll-Gegenstand/Gegenstände verkauft"
    L["Bag replaced successfully!"] = "Tasche erfolgreich ersetzt!"
    L["Cannot replace bag: another replacement is in progress."] = "Tasche kann nicht ersetzt werden: ein anderer Tausch läuft."
    L["Cannot replace bag while sorting is in progress."] = "Tasche kann während der Sortierung nicht ersetzt werden."
    L["Cannot replace bag during combat."] = "Tasche kann im Kampf nicht ersetzt werden."

    L["Cannot sell %s — item is protected"] = "%s kann nicht verkauft werden — Gegenstand geschützt"
    L["Cannot disenchant %s — item is protected"] = "%s kann nicht entzaubert werden — Gegenstand geschützt"
    L["Cannot delete %s — item is protected"] = "%s kann nicht gelöscht werden — Gegenstand geschützt"
    L["Slot pinned %s (skipped during sort)"] = "Platz fixiert %s (beim Sortieren übersprungen)"
    L["Slot unpinned %s"] = "Platz freigegeben %s"
    L["%s set protection removed"] = "%s Set-Schutz entfernt"
    L["%s set protection restored"] = "%s Set-Schutz wiederhergestellt"
    L["%s locked"] = "%s gesperrt"
    L["%s unlocked"] = "%s entsperrt"

    L["Item is not currently in your bags (loading from database)."] = "Der Gegenstand befindet sich nicht in deinen Taschen (lade aus der Datenbank)."

    L["Inventory"] = "Inventar"
    L["Other Accounts"] = "Andere Konten"
    L["Total"] = "Gesamt"
    L["Bags"] = "Taschen"
    L["Mail"] = "Post"
    L["Equipped"] = "Ausgerüstet"

    L["Imported %d character(s) from other accounts"] = "%d Charakter(e) aus anderen Konten importiert"

    L["=== Guda Performance Stats ==="] = "=== Guda Leistungsstatistiken ==="
    L["Frame Budget: %.0fms"] = "Frame-Budget: %.0fms"
    L["Last Update: %.1fms"] = "Letztes Update: %.1fms"
    L["Total Updates: %d"] = "Updates insgesamt: %d"
    L["Budget Exceeded: %d times"] = "Budget überschritten: %d mal"

    L["Guda Settings"] = "Guda Einstellungen"
    L["Appearance"] = "Aussehen"
    L["Options"] = "Optionen"
    L["Automation"] = "Automatisierung"
    L["View"] = "Ansicht"
    L["Columns"] = "Spalten"
    L["Icon"] = "Symbol"
    L["Icon Options"] = "Symboloptionen"
    L["Quest Bar"] = "Quest-Leiste"
    L["Tracked"] = "Verfolgt"
    L["Theme"] = "Design"
    L["Bag View"] = "Taschenansicht"
    L["Bank View"] = "Bankansicht"
    L["Bag columns"] = "Taschenspalten"
    L["Bank columns"] = "Bankspalten"
    L["Background Transparency"] = "Hintergrundtransparenz"
    L["Icon size"] = "Symbolgröße"
    L["Icon font size"] = "Symbolschriftgröße"
    L["Icon spacing"] = "Symbolabstand"
    L["Quest bar size"] = "Quest-Leistengröße"
    L["Tracked bar size"] = "Verfolgungsleistengröße"
    L["Junk item opacity"] = "Müll-Transparenz"
    L["Lock Window"] = "Fenster sperren"
    L["Hide Frame Borders"] = "Rahmen ausblenden"
    L["Equipment Borders"] = "Ausrüstungsrahmen"
    L["Other Item Borders"] = "Andere Gegenstandsrahmen"
    L["Show Search Bar"] = "Suchleiste anzeigen"
    L["Show Quest Bar"] = "Quest-Leiste anzeigen"
    L["Show All Bags"] = "Alle Taschen anzeigen"
    L["Hide Footer"] = "Fußzeile ausblenden"
    L["Mark Unusable Items"] = "Unbenutzbare markieren"
    L["Equip Set Categories"] = "Ausrüstungsset-Kategorien"
    L["Mark Equipment Sets"] = "Ausrüstungssets markieren"
    L["Auto Lock Set Items"] = "Set-Gegenstände automatisch sperren"
    L["Show Category Count"] = "Kategorieanzahl anzeigen"
    L["Auto Sell Junk"] = "Müll automatisch verkaufen"
    L["Auto Open Bags"] = "Taschen automatisch öffnen"
    L["Auto Close Bags"] = "Taschen automatisch schließen"
    L["White Items as Junk"] = "Weiße Gegenstände als Müll"
    L["pfUI Transparency"] = "pfUI-Transparenz"
    L["Reverse Stack Sort"] = "Stapel umgekehrt sortieren"
    L["Edit"] = "Bearbeiten"
    L["Save"] = "Speichern"
    L["Cancel"] = "Abbrechen"
    L["+ Add Category"] = "+ Kategorie hinzufügen"
    L["+ Add Rule"] = "+ Regel hinzufügen"
    L["Reset Defaults"] = "Standard wiederherstellen"
    L["Select Type"] = "Typ auswählen"
    L["Select Value"] = "Wert auswählen"
    L["Tracking Items:"] = "Verfolgte Gegenstände:"
    L["Locked Items:"] = "Gesperrte Gegenstände:"
    L["Pin Slot:"] = "Platz fixieren:"
    L["Moving Bars:"] = "Leisten verschieben:"
    L["Merge"] = "Zusammenführen"
    L["Group:"] = "Gruppe:"
    L["Mark:"] = "Markierung:"
    L["Any rule"] = "Beliebige Regel"
    L["All rules"] = "Alle Regeln"
    L["Edit Category (Built-in)"] = "Kategorie bearbeiten (integriert)"
    L["Edit Category"] = "Kategorie bearbeiten"
    L["Rules (%d/%d):"] = "Regeln (%d/%d):"

    L["General"] = "Allgemein"
    L["Layout"] = "Layout"
    L["Icons"] = "Symbole"
    L["Bar"] = "Leiste"
    L["Categories"] = "Kategorien"
    L["Guide"] = "Hilfe"

    L["Bag columns: %d"] = "Taschenspalten: %d"
    L["Bank columns: %d"] = "Bankspalten: %d"
    L["Background Transparency: %d%%"] = "Hintergrundtransparenz: %d%%"
    L["Icon size: %dpx"] = "Symbolgröße: %dpx"
    L["Icon font size: %dpx"] = "Symbolschriftgröße: %dpx"
    L["Icon spacing: %s"] = "Symbolabstand: %s"
    L["Quest bar size: %dpx"] = "Quest-Leistengröße: %dpx"
    L["Tracked bar size: %dpx"] = "Verfolgungsleistengröße: %dpx"
    L["Junk item opacity: %d%%"] = "Müll-Transparenz: %d%%"

    L["Show Item Counts in Tooltip"] = "Gegenstandsanzahl im Tooltip"
    L["Tooltip Extension"] = "Tooltip-Erweiterung"
    L["Show how many of this item you have across all your characters in the item tooltip."] = "Zeigt im Gegenstands-Tooltip, wie viele dieses Gegenstands du auf allen Charakteren hast."

    L["Lock the bag frames in place so they cannot be moved by dragging."] = "Sperrt die Taschenfenster, sodass sie nicht verschoben werden können."
    L["Hide the thick borders around the bag and bank frames for a cleaner look."] = "Versteckt die dicken Rahmen um Taschen- und Bankfenster für ein aufgeräumteres Aussehen."
    L["Show a color-coded border around equipped items based on their quality (Common, Rare, Epic, etc.)."] = "Zeigt einen farbigen Rahmen um ausgerüstete Gegenstände entsprechend ihrer Qualität (Gewöhnlich, Selten, Episch usw.)."
    L["Show a color-coded border around non-equipped items in your bags and bank based on their quality."] = "Zeigt einen farbigen Rahmen um nicht ausgerüstete Gegenstände in Taschen und Bank entsprechend ihrer Qualität."
    L["Show a search bar at the top of your bags to quickly find items."] = "Zeigt oben in den Taschen eine Suchleiste, um Gegenstände schnell zu finden."
    L["Show a bar for quickly accessing quest-related items."] = "Zeigt eine Leiste für schnellen Zugriff auf questbezogene Gegenstände."
    L["Minimizes the bag container to show only the main bag and keyring. Hover over the main bag to view the other bags."] = "Minimiert den Taschencontainer auf Haupttasche und Schlüsselbund. Bewege den Mauszeiger über die Haupttasche, um die anderen Taschen zu sehen."
    L["Hides bag slots 1-4 from the footer. Click the main bag to show a flyout with all bag slots."] = "Versteckt die Taschenplätze 1-4 in der Fußzeile. Klicke auf die Haupttasche für ein Menü mit allen Taschenplätzen."
    L["Hide the bottom section of the bag frame containing money and bag slots."] = "Versteckt den unteren Bereich des Taschenfensters mit Gold und Taschenplätzen."
    L["Show a red tint on items that your character cannot use (wrong class, level, etc.)."] = "Färbt Gegenstände rot ein, die dein Charakter nicht benutzen kann (falsche Klasse, Stufe usw.)."
    L["Show equipment set categories in category view."] = "Zeigt Ausrüstungsset-Kategorien in der Kategorieansicht an."
    L["Show a special icon on items that belong to an equipment set."] = "Zeigt ein spezielles Symbol auf Gegenständen, die zu einem Ausrüstungsset gehören."
    L["Prevent selling and deleting items saved in equipment sets."] = "Verhindert das Verkaufen und Löschen von Gegenständen, die in Ausrüstungssets gespeichert sind."
    L["Show the item count next to each category header in category view."] = "Zeigt die Gegenstandsanzahl neben jeder Kategorieüberschrift in der Kategorieansicht."
    L["Automatically sell gray (junk) items when you visit a vendor."] = "Verkauft graue (Müll-)Gegenstände automatisch, wenn du einen Händler besuchst."
    L["Automatically open bags when interacting with bank, auction house, mail, or trade."] = "Öffnet die Taschen automatisch bei Interaktion mit Bank, Auktionshaus, Post oder Handel."
    L["Automatically close bags when closing bank, auction house, mail, trade, or vendor."] = "Schließt die Taschen automatisch beim Schließen von Bank, Auktionshaus, Post, Handel oder Händler."
    L["Treat white (common) equippable items as junk. They will be dimmed and auto-sold if auto-sell is enabled."] = "Behandelt weiße (gewöhnliche) ausrüstbare Gegenstände als Müll. Sie werden ausgegraut und automatisch verkauft, wenn der Auto-Verkauf aktiv ist."
    L["When enabled, uses pfUI's background transparency instead of the slider below."] = "Wenn aktiviert, wird die pfUI-Hintergrundtransparenz statt des Schiebereglers unten verwendet."
    L["When enabled, smaller stacks of the same item will be sorted before larger stacks (e.g., stack of 16 before stack of 20)."] = "Wenn aktiviert, werden kleinere Stapel desselben Gegenstands vor größeren Stapeln sortiert (z. B. Stapel mit 16 vor Stapel mit 20)."

    L["GUIDE_TEXT"] = "|cffffd100Gegenstände verfolgen:|r\n" ..
        "Alt + Linksklick auf einen Gegenstand in deinen Taschen, um ihn zu verfolgen.\n" ..
        "Verfolgte Gegenstände erscheinen in der Verfolgungsleiste.\n" ..
        "Linksklick auf einen Gegenstand in der Leiste, um ihn zu benutzen.\n" ..
        "Alt + Linksklick auf einen Gegenstand in der Leiste, um die Verfolgung zu beenden.\n\n" ..
        "|cffffd100Gesperrte Gegenstände:|r\n" ..
        "Strg + Rechtsklick auf einen Gegenstand zum Sperren/Entsperren.\n" ..
        "Gesperrte Gegenstände können nicht verkauft, gelöscht oder entzaubert werden.\n" ..
        "Gegenstände aus Ausrüstungssets sind automatisch geschützt.\n" ..
        "Strg + Rechtsklick auf einen Set-Gegenstand, um den Schutz umzuschalten.\n" ..
        "Unten rechts erscheint ein Schloss-Symbol.\n\n" ..
        "|cffffd100Platz fixieren:|r\n" ..
        "Alt + Rechtsklick auf einen Taschenplatz, um ihn zu fixieren/freizugeben.\n" ..
        "Fixierte Plätze werden beim Sortieren übersprungen.\n" ..
        "Die Fixierung bleibt am Platz, nicht am Gegenstand.\n" ..
        "Oben links erscheint ein Stecknadel-Symbol.\n\n" ..
        "|cffffd100Leisten verschieben:|r\n" ..
        "Shift + Linksklick und Ziehen auf einen Gegenstand der Quest- oder Verfolgungsleiste, um die Leiste zu verschieben.\n"

    L["Manage item categories and their display order:"] = "Verwalte Gegenstandskategorien und ihre Anzeigereihenfolge:"
    L["(Built-in)"] = "(Integriert)"
    L["(Drop Item)"] = "(Gegenstand ablegen)"
    L["Name:"] = "Name:"
    L["Match Mode:"] = "Übereinstimmungsmodus:"
    L["Rules:"] = "Regeln:"

elseif locale == "ruRU" then
    -- Russian

    L["Auto Loot"] = "Автосбор"
    L["Automatically loot all items when looting a corpse or container."] = "Автоматически собирать все предметы при обыске трупов и контейнеров."
    L["Auto Loot requires the SuperWoW client mod. Install SuperWoW to enable this option."] = "Автосбор требует клиентскую модификацию SuperWoW. Установите SuperWoW, чтобы включить эту опцию, или примените твик лаунчера 'Always auto-loot' (тогда клиент будет автоматически собирать добычу независимо от этого аддона)."
    L["Auto Open Clams"] = "Автооткрытие моллюсков"
    L["Automatically open clams in your bags when you loot one."] = "Автоматически открывать моллюсков в сумках, как только один из них получен."
    L["/guda openclams - Open all clams in bags"] = "/guda openclams - Открыть всех моллюсков в сумках"
    L["Opening clams..."] = "Открытие моллюсков..."
    L["No clams found in your bags."] = "В ваших сумках нет моллюсков."
    L["No more clams to open."] = "Больше моллюсков для открытия нет."
    L["Clam opener is already running."] = "Открывалка моллюсков уже работает."
    L["Clam opener stopped: %s"] = "Открывалка моллюсков остановлена: %s"

    L["Initializing..."] = "Инициализация..."
    L["Initializing UI..."] = "Инициализация интерфейса..."
    L["Ready! Type /guda to open bags"] = "Готово! Введите /guda, чтобы открыть сумки"
    L["Scanning equipped items..."] = "Сканирование экипированных предметов..."
    L["Equipped items scanned and saved!"] = "Экипированные предметы отсканированы и сохранены!"

    L["Commands:"] = "Команды:"
    L["/guda - Toggle bags"] = "/guda - Открыть/закрыть сумки"
    L["/guda bank - Toggle bank"] = "/guda bank - Открыть/закрыть банк"
    L["/guda mail - Toggle mailbox"] = "/guda mail - Открыть/закрыть почту"
    L["/guda settings - Open settings"] = "/guda settings - Открыть настройки"
    L["/guda sort - Sort bags"] = "/guda sort - Сортировать сумки"
    L["/guda sortbank - Sort bank"] = "/guda sortbank - Сортировать банк"
    L["/guda track - Toggle item tracking"] = "/guda track - Переключить отслеживание"
    L["/guda debug - Toggle debug mode"] = "/guda debug - Переключить режим отладки"
    L["/guda debugsort - Toggle sort debug output"] = "/guda debugsort - Переключить отладку сортировки"
    L["/guda cleanup - Remove old characters"] = "/guda cleanup - Удалить старых персонажей"
    L["/guda perf - Show performance stats"] = "/guda perf - Показать статистику"
    L["/guda perfreset - Reset performance stats"] = "/guda perfreset - Сбросить статистику"
    L["/guda poolreset - Reset button pool (debug)"] = "/guda poolreset - Сбросить пул кнопок (отладка)"
    L["Unknown command. Type /guda help for commands"] = "Неизвестная команда. Введите /guda help для списка команд"
    L["Debug mode: %s"] = "Режим отладки: %s"
    L["Debug sort mode: %s"] = "Режим отладки сортировки: %s"
    L["Debug category mode: %s"] = "Режим отладки категорий: %s"
    L["Quest bar: %s"] = "Панель заданий: %s"
    L["ON"] = "ВКЛ"
    L["OFF"] = "ВЫКЛ"
    L["Settings window not available"] = "Окно настроек недоступно"
    L["Performance stats not available"] = "Статистика недоступна"
    L["Performance stats reset"] = "Статистика сброшена"
    L["Cannot reset pool while bag/bank frames are open. Close them first."] = "Невозможно сбросить пул, пока открыты сумки/банк. Сначала закройте их."
    L["Button pool reset. Pool is now empty."] = "Пул кнопок сброшен. Пул пуст."
    L["Button pool reset function not available."] = "Функция сброса пула недоступна."

    L["%s's Bags"] = "Сумки %s"
    L["%s's Bank"] = "Банк %s"
    L["%s's Mailbox"] = "Почта %s"
    L["Bank"] = "Банк"
    L["Backpack"] = "Рюкзак"
    L["Keyring"] = "Связка ключей"
    L["Bag %d"] = "Сумка %d"
    L["Bag Slots"] = "Слоты сумок"
    L["Bank Bag Slot %d"] = "Слот сумки банка %d"
    L["Search, try ~equipment"] = "Поиск, попробуйте ~equipment"
    L["Search bank..."] = "Поиск в банке..."
    L["Search mailbox..."] = "Поиск в почте..."
    L["Use Guda Bank UI"] = "Использовать интерфейс банка Guda"
    L["Switched to Guda bank UI"] = "Переключено на интерфейс банка Guda"
    L["No Mail"] = "Нет писем"
    L["No mailbox data found for this character.\n\nVisit a mailbox in-game to save your mail data."] = "Нет данных почты для этого персонажа.\n\nПосетите почтовый ящик в игре, чтобы сохранить данные."
    L["Current realm gold"] = "Золото текущего сервера"
    L["Total gold"] = "Всего золота"
    L["Settings"] = "Настройки"
    L["Sort Bags"] = "Сортировать сумки"
    L["Lockpicking"] = "Взлом замков"
    L["Click to cast Pick Lock"] = "Нажмите, чтобы применить «Взлом замков»"
    L["Requires Thieves' Tools"] = "Требуются «Воровские инструменты»"
    L["My Characters"] = "Мои персонажи"
    L["View Bank"] = "Просмотр банка"
    L["View Mailbox"] = "Просмотр почты"
    L["Right-click to manage characters"] = "Правый клик для управления персонажами"
    L["(Right-Click to hide)"] = "(Правый клик чтобы скрыть)"
    L["%d Slots"] = "%d слотов"
    L["Regular Bags:"] = "Обычные сумки:"
    L["Sort Bank"] = "Сортировать банк"
    L["Use Blizzard Bank UI"] = "Использовать интерфейс банка Blizzard"

    L["Cannot sort another character's bags!"] = "Нельзя сортировать сумки другого персонажа!"
    L["Cannot sort in read-only mode!"] = "Нельзя сортировать в режиме «только чтение»!"
    L["Bags are already sorted!"] = "Сумки уже отсортированы!"
    L["Bank is already sorted!"] = "Банк уже отсортирован!"
    L["Bank must be open to sort!"] = "Банк должен быть открыт для сортировки!"
    L["Sorting already in progress, please wait..."] = "Сортировка уже выполняется, подождите..."
    L["Restacked %d stack(s)"] = "Перегруппировано %d стопок"
    L["Sold %d junk item(s)"] = "Продано %d мусорных предметов"
    L["Bag replaced successfully!"] = "Сумка успешно заменена!"
    L["Cannot replace bag: another replacement is in progress."] = "Нельзя заменить сумку: уже выполняется другая замена."
    L["Cannot replace bag while sorting is in progress."] = "Нельзя заменить сумку во время сортировки."
    L["Cannot replace bag during combat."] = "Нельзя заменить сумку в бою."

    L["Cannot sell %s — item is protected"] = "Нельзя продать %s — предмет защищён"
    L["Cannot disenchant %s — item is protected"] = "Нельзя распылить %s — предмет защищён"
    L["Cannot delete %s — item is protected"] = "Нельзя удалить %s — предмет защищён"
    L["Slot pinned %s (skipped during sort)"] = "Слот закреплён %s (пропущен при сортировке)"
    L["Slot unpinned %s"] = "Слот откреплён %s"
    L["%s set protection removed"] = "Защита комплекта снята с %s"
    L["%s set protection restored"] = "Защита комплекта восстановлена для %s"
    L["%s locked"] = "%s заблокирован"
    L["%s unlocked"] = "%s разблокирован"

    L["Item is not currently in your bags (loading from database)."] = "Предмета сейчас нет в сумках (загрузка из базы данных)."

    L["Inventory"] = "Инвентарь"
    L["Other Accounts"] = "Другие аккаунты"
    L["Total"] = "Всего"
    L["Bags"] = "Сумки"
    L["Mail"] = "Почта"
    L["Equipped"] = "Надето"

    L["Imported %d character(s) from other accounts"] = "Импортировано %d персонажей из других аккаунтов"

    L["=== Guda Performance Stats ==="] = "=== Статистика производительности Guda ==="
    L["Frame Budget: %.0fms"] = "Бюджет кадра: %.0fмс"
    L["Last Update: %.1fms"] = "Последнее обновление: %.1fмс"
    L["Total Updates: %d"] = "Всего обновлений: %d"
    L["Budget Exceeded: %d times"] = "Бюджет превышен: %d раз"

    L["Guda Settings"] = "Настройки Guda"
    L["Appearance"] = "Внешний вид"
    L["Options"] = "Опции"
    L["Automation"] = "Автоматизация"
    L["View"] = "Вид"
    L["Columns"] = "Столбцы"
    L["Icon"] = "Иконка"
    L["Icon Options"] = "Опции иконки"
    L["Quest Bar"] = "Панель заданий"
    L["Tracked"] = "Отслеживание"
    L["Theme"] = "Тема"
    L["Bag View"] = "Вид сумок"
    L["Bank View"] = "Вид банка"
    L["Bag columns"] = "Столбцы сумок"
    L["Bank columns"] = "Столбцы банка"
    L["Background Transparency"] = "Прозрачность фона"
    L["Icon size"] = "Размер иконки"
    L["Icon font size"] = "Размер шрифта иконки"
    L["Icon spacing"] = "Расстояние между иконками"
    L["Quest bar size"] = "Размер панели заданий"
    L["Tracked bar size"] = "Размер панели отслеживания"
    L["Junk item opacity"] = "Прозрачность мусора"
    L["Lock Window"] = "Закрепить окно"
    L["Hide Frame Borders"] = "Скрыть рамки"
    L["Equipment Borders"] = "Рамки экипировки"
    L["Other Item Borders"] = "Рамки других предметов"
    L["Show Search Bar"] = "Показать строку поиска"
    L["Show Quest Bar"] = "Показать панель заданий"
    L["Show All Bags"] = "Показать все сумки"
    L["Hide Footer"] = "Скрыть нижнюю панель"
    L["Mark Unusable Items"] = "Отмечать непригодные"
    L["Equip Set Categories"] = "Категории комплектов"
    L["Mark Equipment Sets"] = "Отмечать комплекты"
    L["Auto Lock Set Items"] = "Авто-блок предметов комплекта"
    L["Show Category Count"] = "Показать счётчик категорий"
    L["Auto Sell Junk"] = "Авто-продажа мусора"
    L["Auto Open Bags"] = "Авто-открытие сумок"
    L["Auto Close Bags"] = "Авто-закрытие сумок"
    L["White Items as Junk"] = "Белые предметы как мусор"
    L["pfUI Transparency"] = "Прозрачность pfUI"
    L["Reverse Stack Sort"] = "Обратный порядок стопок"
    L["Edit"] = "Изменить"
    L["Save"] = "Сохранить"
    L["Cancel"] = "Отмена"
    L["+ Add Category"] = "+ Добавить категорию"
    L["+ Add Rule"] = "+ Добавить правило"
    L["Reset Defaults"] = "Сбросить настройки"
    L["Select Type"] = "Выбрать тип"
    L["Select Value"] = "Выбрать значение"
    L["Tracking Items:"] = "Отслеживаемые предметы:"
    L["Locked Items:"] = "Заблокированные предметы:"
    L["Pin Slot:"] = "Закрепить слот:"
    L["Moving Bars:"] = "Перемещение панелей:"
    L["Merge"] = "Объединить"
    L["Group:"] = "Группа:"
    L["Mark:"] = "Метка:"
    L["Any rule"] = "Любое правило"
    L["All rules"] = "Все правила"
    L["Edit Category (Built-in)"] = "Изменить категорию (встроенная)"
    L["Edit Category"] = "Изменить категорию"
    L["Rules (%d/%d):"] = "Правила (%d/%d):"

    L["General"] = "Общие"
    L["Layout"] = "Макет"
    L["Icons"] = "Иконки"
    L["Bar"] = "Панель"
    L["Categories"] = "Категории"
    L["Guide"] = "Справка"

    L["Bag columns: %d"] = "Столбцы сумок: %d"
    L["Bank columns: %d"] = "Столбцы банка: %d"
    L["Background Transparency: %d%%"] = "Прозрачность фона: %d%%"
    L["Icon size: %dpx"] = "Размер иконки: %dpx"
    L["Icon font size: %dpx"] = "Размер шрифта иконки: %dpx"
    L["Icon spacing: %s"] = "Расстояние между иконками: %s"
    L["Quest bar size: %dpx"] = "Размер панели заданий: %dpx"
    L["Tracked bar size: %dpx"] = "Размер панели отслеживания: %dpx"
    L["Junk item opacity: %d%%"] = "Прозрачность мусора: %d%%"

    L["Show Item Counts in Tooltip"] = "Показывать количество в подсказке"
    L["Tooltip Extension"] = "Расширение подсказки"
    L["Show how many of this item you have across all your characters in the item tooltip."] = "Показывает в подсказке предмета, сколько этого предмета у всех ваших персонажей."

    L["Lock the bag frames in place so they cannot be moved by dragging."] = "Закрепляет окна сумок на месте, чтобы их нельзя было перемещать."
    L["Hide the thick borders around the bag and bank frames for a cleaner look."] = "Скрывает толстые рамки вокруг окон сумок и банка для более чистого вида."
    L["Show a color-coded border around equipped items based on their quality (Common, Rare, Epic, etc.)."] = "Показывает цветную рамку вокруг экипированных предметов в зависимости от их качества (Обычное, Редкое, Эпическое и т.д.)."
    L["Show a color-coded border around non-equipped items in your bags and bank based on their quality."] = "Показывает цветную рамку вокруг неэкипированных предметов в сумках и банке в зависимости от их качества."
    L["Show a search bar at the top of your bags to quickly find items."] = "Показывает строку поиска в верхней части сумок для быстрого поиска предметов."
    L["Show a bar for quickly accessing quest-related items."] = "Показывает панель для быстрого доступа к предметам заданий."
    L["Minimizes the bag container to show only the main bag and keyring. Hover over the main bag to view the other bags."] = "Сворачивает контейнер до основной сумки и связки ключей. Наведите курсор на основную сумку, чтобы увидеть остальные."
    L["Hides bag slots 1-4 from the footer. Click the main bag to show a flyout with all bag slots."] = "Скрывает слоты сумок 1-4 из нижней панели. Щёлкните по основной сумке, чтобы открыть меню со всеми слотами."
    L["Hide the bottom section of the bag frame containing money and bag slots."] = "Скрывает нижнюю часть окна сумок с золотом и слотами сумок."
    L["Show a red tint on items that your character cannot use (wrong class, level, etc.)."] = "Окрашивает в красный предметы, которые ваш персонаж не может использовать (не тот класс, уровень и т.д.)."
    L["Show equipment set categories in category view."] = "Показывает категории комплектов экипировки в режиме просмотра по категориям."
    L["Show a special icon on items that belong to an equipment set."] = "Показывает особый значок на предметах, входящих в комплект экипировки."
    L["Prevent selling and deleting items saved in equipment sets."] = "Запрещает продажу и удаление предметов, сохранённых в комплектах экипировки."
    L["Show the item count next to each category header in category view."] = "Показывает количество предметов рядом с каждым заголовком категории в режиме просмотра по категориям."
    L["Automatically sell gray (junk) items when you visit a vendor."] = "Автоматически продаёт серые (мусорные) предметы при посещении торговца."
    L["Automatically open bags when interacting with bank, auction house, mail, or trade."] = "Автоматически открывает сумки при взаимодействии с банком, аукционом, почтой или обменом."
    L["Automatically close bags when closing bank, auction house, mail, trade, or vendor."] = "Автоматически закрывает сумки при закрытии банка, аукциона, почты, обмена или торговца."
    L["Treat white (common) equippable items as junk. They will be dimmed and auto-sold if auto-sell is enabled."] = "Считает белые (обычные) экипируемые предметы мусором. Они будут затемнены и проданы автоматически, если включена авто-продажа."
    L["When enabled, uses pfUI's background transparency instead of the slider below."] = "Когда включено, использует прозрачность фона pfUI вместо ползунка ниже."
    L["When enabled, smaller stacks of the same item will be sorted before larger stacks (e.g., stack of 16 before stack of 20)."] = "Когда включено, меньшие стопки одного и того же предмета будут отсортированы перед большими (например, стопка из 16 перед стопкой из 20)."

    L["GUIDE_TEXT"] = "|cffffd100Отслеживание предметов:|r\n" ..
        "Alt + Левый клик по любому предмету в сумках, чтобы отслеживать его.\n" ..
        "Отслеживаемые предметы появятся на панели отслеживания.\n" ..
        "Левый клик по предмету на панели, чтобы использовать его.\n" ..
        "Alt + Левый клик по предмету на панели, чтобы прекратить отслеживание.\n\n" ..
        "|cffffd100Заблокированные предметы:|r\n" ..
        "Ctrl + Правый клик по любому предмету, чтобы заблокировать/разблокировать.\n" ..
        "Заблокированные предметы нельзя продать, удалить или распылить.\n" ..
        "Предметы из комплектов экипировки защищены автоматически.\n" ..
        "Ctrl + Правый клик по предмету комплекта, чтобы переключить защиту.\n" ..
        "В правом нижнем углу появляется значок замка.\n\n" ..
        "|cffffd100Закрепить слот:|r\n" ..
        "Alt + Правый клик по любому слоту сумки, чтобы закрепить/открепить.\n" ..
        "Закреплённые слоты пропускаются при сортировке.\n" ..
        "Закрепление остаётся на слоте, а не на предмете.\n" ..
        "В левом верхнем углу появляется значок булавки.\n\n" ..
        "|cffffd100Перемещение панелей:|r\n" ..
        "Shift + Левый клик и перетаскивание любого предмета на панели заданий или отслеживания, чтобы переместить панель.\n"

    L["Manage item categories and their display order:"] = "Управление категориями предметов и их порядком:"
    L["(Built-in)"] = "(Встроенная)"
    L["(Drop Item)"] = "(Сбросить предмет)"
    L["Name:"] = "Имя:"
    L["Match Mode:"] = "Режим совпадения:"
    L["Rules:"] = "Правила:"

end

-- Sync the legacy L_* globals (referenced from SettingsPopup.lua) to whatever
-- locale block above resolved. Doing it here means the L_* values automatically
-- track the active language without us having to repeat assignments per locale.
L_SHOW_TOOLTIP_COUNTS    = L["Tooltip Extension"]
L_SHOW_TOOLTIP_COUNTS_TT = L["Show how many of this item you have across all your characters in the item tooltip."]
L_LOCK_BAGS_TT           = L["Lock the bag frames in place so they cannot be moved by dragging."]
L_HIDE_BORDERS_TT        = L["Hide the thick borders around the bag and bank frames for a cleaner look."]
L_QUALITY_BORDER_EQ_TT   = L["Show a color-coded border around equipped items based on their quality (Common, Rare, Epic, etc.)."]
L_QUALITY_BORDER_OTHER_TT= L["Show a color-coded border around non-equipped items in your bags and bank based on their quality."]
L_SHOW_SEARCH_BAR_TT     = L["Show a search bar at the top of your bags to quickly find items."]
L_SHOW_QUEST_BAR_TT      = L["Show a bar for quickly accessing quest-related items."]
L_HOVER_BAGLINE_TT       = L["Minimizes the bag container to show only the main bag and keyring. Hover over the main bag to view the other bags."]
L_HIDE_BAGLINE_TT        = L["Hides bag slots 1-4 from the footer. Click the main bag to show a flyout with all bag slots."]
L_HIDE_FOOTER_TT         = L["Hide the bottom section of the bag frame containing money and bag slots."]
