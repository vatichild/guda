# Guda

A comprehensive bag and bank management addon for Turtle WoW (1.12.1).

## Features

### 🎒 Bag Management

- **Unified Bag View**: All your bags in one window
- **Smart Sorting**: Sort by quality, name, or item type
- **Search Functionality**: Quickly find items with the search box
- **Quality Borders**: Visual quality indicators on items

### 🏦 Bank Management

- **Bank Viewing**: View your bank from anywhere (cached data)
- **Bank Sorting**: Organize your bank with one click
- **Persistent Storage**: Bank contents saved and viewable offline

### 👥 Multi-Character Support

- **Cross-Character Viewing**: View any character's bags and bank
- **Money Tracking**: See total gold across all characters
- **Character Selector**: Easy switching between characters
- **Faction Filtering**: Only shows characters of the same faction

### 💰 Money Display

- **Current Character**: Shows your current gold/silver/copper
- **Total Money**: Displays combined wealth across all characters
- **Per-Character**: View each character's money in the selector

## Slash Commands

```
/guda or /gn

/guda              - Toggle bags
/guda bank         - Toggle bank view
/guda sort         - Sort your bags
/guda sortbank     - Sort your bank (must be at bank)
/guda save         - Manually save data
/guda debug        - Toggle debug mode
/guda cleanup      - Remove characters not seen in 90 days
/guda help         - Show this help
```

## How to Use

### Basic Usage

1. Press **B** or type `/guda` to open your bags
2. Click **Characters** button to view other characters
3. Click **Bank** button to view your bank (cached)
4. Click **Sort** to organize your bags

### Sorting

- **Sort Bags**: Click the **Sort** button or `/guda sort`
- **Sort Bank**: Click **Sort Bank** button (must be at bank) or `/guda sortbank`
- **Sort Methods**: Quality (default), Name, or Type
  - Quality: Epic → Rare → Uncommon → Common
  - Name: Alphabetical
  - Type: By item class and subclass

## Features in Detail

### Bag Scanner

- Automatically scans bags on login and updates
- Tracks all items with full details (name, quality, count, etc.)
- Updates in real-time as you loot/move items

### Bank Scanner

- Scans bank when you open it
- Saves bank contents for offline viewing
- Updates automatically while bank is open

### Money Tracker

- Tracks money changes in real-time
- Shows current character money
- Calculates total across all characters
- Per-character money in character selector

### Data Storage

- Saves to `Guda_DB` (global)
- Character settings in `Guda_CharDB`
- Persistent across sessions
- Automatic cleanup of old characters (90+ days)

## Configuration

Currently all configuration is automatic. Future versions may include:

- Customizable sort methods
- Buttons per row
- Filter options
- Color customization

## Known Limitations

- **Sort Functionality**: Basic sorting is implemented but actual item moving requires additional complexity to handle:
  - Soulbound items
  - Bag type restrictions (soul bags, etc.)
  - Quest items
  - Locked items
- **Bank Access**: Must open bank at least once to cache contents
- **Same Faction**: Can only view characters of the same faction

## Technical Details

### Saved Variables

- `Guda_DB`: Global database (all characters)
  - Character data (bags, bank, money)
  - Last update timestamps
- `Guda_CharDB`: Per-character settings
  - UI preferences
  - Sort method

### Auto-Save Schedule

- Every 30 minutes while playing
- On player logout
- Manual: `/guda save`

### Events Monitored

- `BAG_UPDATE`: Bag content changes
- `BANKFRAME_OPENED`: Bank opened
- `BANKFRAME_CLOSED`: Bank closed
- `PLAYER_MONEY`: Money changes
- `PLAYER_LOGIN`: Character login
- `PLAYER_LOGOUT`: Character logout

## Credits

Created for Turtle WoW 1.12.1
Version 1.0.2

## Support

For bugs or feature requests, please report them in-game or on the forums.

## Changelog

### Version 1.0.2

- Initial release
- Bag viewing and sorting
- Bank viewing and sorting
- Multi-character support
- Money tracking
- Auto-save system
- Character selector
- Search functionality
