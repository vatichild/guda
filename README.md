# Guda

A comprehensive **bag and bank management addon** for **World of Warcraft 1.12.1**, fully compatible with **Turtle WoW**.

Guda provides a modern, unified bag/bank experience with multi-character support, sorting, item tracking, and quality-of-life tools.

---

## 📦 Features

### 🎒 Bag Management

* **Unified Bag View** – All bags displayed in one window
* **Smart Sorting** – Sort by quality, name, or item type
* **Search Box** – Quickly find items
* **Quality Borders** – Items are visually color-coded based on rarity

### 🏦 Bank Management

* **Remote Bank Viewing** – View cached bank contents from anywhere
* **One-Click Sorting** – Organize your bank easily
* **Persistent Storage** – Bank data saved between sessions

### 👥 Multi-Character Support

* **Cross-Character Viewing** – View bags & banks of any character
* **Money Tracking** – See total gold across all characters
* **Character Selector** – Switch characters quickly
* **Faction Filtering** – Shows only characters from the same faction
* **Global Item Counting** – Item totals across all characters, including:

    * Bags
    * Banks
    * Equipped items
    * Tooltip breakdown per character

### 💰 Money Display

* **Current Character Money**
* **Total Money Across All Characters**
* **Per-Character Overview** in the selector

---

## 📝 Slash Commands

```
/guda or /gn

/guda              - Toggle bags
/guda bank         - Toggle bank view
/guda sort         - Sort your bags
/guda sortbank     - Sort your bank (must be at bank)
/guda debug        - Toggle debug mode
/guda cleanup      - Remove characters not seen in 90 days
/guda help         - Show this help
```

---

## 🚀 How to Use

### Basic Usage

1. Press **B** or type `/guda` to open your bags
2. Click **Characters** to switch characters
3. Click **Bank** to view your cached bank
4. Click **Sort** to organize your bags

### Sorting

* **Sort Bags**: Press **Sort** or use `/guda sort`
* **Sort Bank**: Use **Sort Bank** or `/guda sortbank`
* Sorting modes:

    * **Quality** (Epic → Rare → Uncommon → Common)
    * **Name** (A → Z)
    * **Type** (Item class & subclass)

---

## 🧠 Internal Systems

### 🔍 Bag Scanner

* Scans all bags at login
* Updates when looting, moving, or modifying items
* Stores item details (count, quality, name, link, etc.)

### 🏦 Bank Scanner

* Scans on bank open
* Saves snapshot for offline viewing
* Updates live while the bank is open

### 💰 Money Tracker

* Tracks money changes in real time
* Displays per-character, current character, and total money

### 🗄️ Data Storage

* **Guda_DB** – Global data:

    * Bag & bank contents
    * Character money
    * Last update timestamps
* **Guda_CharDB** – Per-character UI settings

---

## ⚙️ Configuration

Configuration is currently automatic. Future updates may include:

* Custom sort methods
* Adjustable layout (buttons per row, item size)
* Item filters
* Color customization

---

## ⚠️ Known Limitations

* **Sorting**:

    * Advanced sorting requires handling bag restrictions (soul bags, profession bags)
    * Locked and soulbound items need special handling
* **Bank Access**:

    * Must open the bank at least once to cache contents
* **Faction Restriction**:

    * Only shows characters from the same faction

---

## 🖼️ Images

### Guda Settings

![Guda Settings](https://i.imgur.com/Tfzl6ru.png)

### Bag View

![Bag View](https://i.imgur.com/cqISq71.png)

### Bank View

![Bank View](https://i.imgur.com/rV1f8Lu.png)

---

## 🐞 Common Issues

### 1. Cannot open bags using **B**

Set the keybinding:
**Esc → Key Bindings → Guda → Toggle Bags**

![Keybindings Fix](https://i.imgur.com/IJv36Lg.png)

### 2. Issues after updating the addon

Delete outdated saved variables:

```
WTF/Account/<ACCOUNT_NAME>/SavedVariables/Guda.lua
WTF/Account/<ACCOUNT_NAME>/SavedVariables/Guda.lua.bak
```

---

## 📢 Support

For bugs or feature requests, please open an issue or post on the Turtle WoW forums.
Your feedback helps improve the addon!
