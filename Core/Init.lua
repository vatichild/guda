-- Guda - Turtle WoW Bag Addon
-- Core initialization

-- Create addon namespace
Guda = {}
local addon = Guda

-- Version info
addon.VERSION = "1.0.0"
addon.BUILD = "TurtleWoW-1.12.1"

-- Debug flag
addon.DEBUG = false

-- Constants
addon.Constants = {
    -- Bag IDs
    BACKPACK = 0,
    BAG_1 = 1,
    BAG_2 = 2,
    BAG_3 = 3,
    BAG_4 = 4,
    BANK = -1,
    BANK_BAG_1 = 5,
    BANK_BAG_2 = 6,
    BANK_BAG_3 = 7,
    BANK_BAG_4 = 8,
    BANK_BAG_5 = 9,
    BANK_BAG_6 = 10,

    -- All bag IDs for easy iteration
    BAGS = {0, 1, 2, 3, 4},
    BANK_BAGS = {-1, 5, 6, 7, 8, 9, 10},
    ALL_BAGS = {0, 1, 2, 3, 4, -1, 5, 6, 7, 8, 9, 10},

    -- Item qualities (colors)
    QUALITY_COLORS = {
        [0] = {r = 0.62, g = 0.62, b = 0.62}, -- Poor (Gray)
        [1] = {r = 1.00, g = 1.00, b = 1.00}, -- Common (White)
        [2] = {r = 0.12, g = 1.00, b = 0.00}, -- Uncommon (Green)
        [3] = {r = 0.00, g = 0.44, b = 0.87}, -- Rare (Blue)
        [4] = {r = 0.64, g = 0.21, b = 0.93}, -- Epic (Purple)
        [5] = {r = 1.00, g = 0.50, b = 0.00}, -- Legendary (Orange)
    },

    -- Save intervals
    SAVE_INTERVAL = 1800, -- 30 minutes in seconds

    -- UI Constants
    BUTTON_SIZE = 40,
    BUTTON_SPACING = 0,
    BUTTONS_PER_ROW = 10,
    MIN_ICON_SIZE = 30,
    MAX_ICON_SIZE = 64,

    -- Backdrop configurations (to avoid duplication across UI files)
    Backdrops = {
        -- Standard frame backdrop (used for main windows)
        DEFAULT_FRAME = {
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        },

        -- Minimalist border (used when "hide borders" setting is enabled)
        MINIMALIST_BORDER = {
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 2,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        },

        -- Dropdown/popup backdrop (used for character selection dropdowns)
        DROPDOWN = {
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        }
    },

    -- Backdrop colors (common configurations)
    BackdropColors = {
        DEFAULT = {r = 0, g = 0, b = 0, a = 0.9},
        DROPDOWN = {r = 0, g = 0, b = 0, a = 0.95},
    },
}

-- Initialize modules storage
addon.Modules = {}

-- Readiness flags for safe early keybind handling
addon._ready = false
addon._pendingToggleBags = false
addon._pendingToggleBank = false
addon._deferBagsRegistered = false
addon._deferBankRegistered = false

-- Global safe wrappers for keybindings (defined early and always available)
function Guda_ToggleBags()
    local a = Guda
    if a and a._ready and a.Modules and a.Modules.BagFrame and a.Modules.BagFrame.Toggle then
        a.Modules.BagFrame:Toggle()
        return
    end

    -- Defer until PLAYER_LOGIN completes addon initialization
    if a and a.Modules and a.Modules.Events and not a._deferBagsRegistered then
        a._pendingToggleBags = true
        a._deferBagsRegistered = true
        a.Modules.Events:OnPlayerLogin(function()
            if Guda and Guda._pendingToggleBags then
                Guda._pendingToggleBags = false
                if Guda.Modules and Guda.Modules.BagFrame and Guda.Modules.BagFrame.Toggle then
                    Guda.Modules.BagFrame:Toggle()
                end
            end
        end, "Guda_KeybindDefer_Bags")
    else
        -- If Events not yet available, set pending flag; Main will clear it when ready
        if a then a._pendingToggleBags = true end
    end
end

function Guda_ToggleBank()
    local a = Guda
    local function doToggleBank()
        if Guda_BankFrame and Guda_BankFrame:IsShown() then
            Guda_BankFrame:Hide()
        else
            if a and a.Modules and a.Modules.DB then
                local fullName = a.Modules.DB:GetPlayerFullName()
                -- WoW 1.12 uses getglobal/setglobal; `_G` is not available (Lua 5.0)
                local showBankFn = getglobal and getglobal("Guda_BagFrame_ShowCharacterBank") or nil
                if fullName and showBankFn then
                    -- Prefer exported helper if available
                    showBankFn(fullName)
                elseif a and a.Modules and a.Modules.BankFrame then
                    a.Modules.BankFrame:ShowCharacter(fullName)
                    if Guda_BankFrame then Guda_BankFrame:Show() end
                end
            end
        end
    end

    if a and a._ready then
        doToggleBank()
        return
    end

    if a and a.Modules and a.Modules.Events and not a._deferBankRegistered then
        a._pendingToggleBank = true
        a._deferBankRegistered = true
        a.Modules.Events:OnPlayerLogin(function()
            if Guda and Guda._pendingToggleBank then
                Guda._pendingToggleBank = false
                doToggleBank()
            end
        end, "Guda_KeybindDefer_Bank")
    else
        if a then a._pendingToggleBank = true end
    end
end

-- Helper to apply backdrop with color
function addon:ApplyBackdrop(frame, backdropType, colorType)
    local backdrop = self.Constants.Backdrops[backdropType]
    local color = self.Constants.BackdropColors[colorType or "DEFAULT"]

    if not backdrop or not color then
        self:Debug("Invalid backdrop type: %s or color type: %s",
                   tostring(backdropType), tostring(colorType))
        return
    end

    frame:SetBackdrop(backdrop)
    frame:SetBackdropColor(color.r, color.g, color.b, color.a)

    -- Set border color to white for minimalist borders
    if backdropType == "MINIMALIST_BORDER" then
        frame:SetBackdropBorderColor(1, 1, 1, 1)
    end
end

-- Print function with addon prefix
function addon:Print(msg, a1, a2, a3, a4, a5, a6, a7)
    local text = string.format(msg, a1, a2, a3, a4, a5, a6, a7)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF96Guda:|r " .. text)
end

-- Debug print
function addon:Debug(msg, a1, a2, a3, a4, a5, a6, a7)
    if self.DEBUG then
        local text = string.format(msg, a1, a2, a3, a4, a5, a6, a7)
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00[Debug]|r |cFF00FF96Guda:|r " .. text)
    end
end

-- Error handler
function addon:Error(msg, a1, a2, a3, a4, a5, a6, a7)
    local text = string.format(msg, a1, a2, a3, a4, a5, a6, a7)
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[Error]|r |cFF00FF96Guda:|r " .. text)
end

addon:Print("Loaded v%s", addon.VERSION)
