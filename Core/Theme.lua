-- Guda Theme System
-- Provides theme selection between Guda dark and Blizzard classic looks

local addon = Guda

local Theme = {}
addon.Modules.Theme = Theme

-- Theme debug flag — set to true and /reload to trace every ApplyToFrame call
addon.DEBUG_THEME = false

local function ThemeDebug(msg, a1, a2, a3, a4, a5, a6, a7)
    if addon.DEBUG_THEME then
        local text = string.format(msg or "nil", a1 or "", a2 or "", a3 or "", a4 or "", a5 or "", a6 or "", a7 or "")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF8800[Theme]|r " .. text)
    end
end

-- Read a color from pfUI_config.appearance.border (e.g. "background" or "color")
-- pfUI stores colors as comma-separated strings: "R,G,B,A"
local function ParseColorString(str)
    if not str then return nil end
    local vals = {}
    for v in string.gfind(str, "[^,]+") do
        table.insert(vals, tonumber(v))
    end
    if vals[1] then
        return vals[1], vals[2], vals[3], vals[4]
    end
    return nil
end

local function GetPfUIColor(key)
    if pfUI_config and pfUI_config.appearance and pfUI_config.appearance.border then
        return ParseColorString(pfUI_config.appearance.border[key])
    end
    return nil
end

-- Theme definitions
-- Background is rendered via a standalone Texture child (not bgFile).
local themes = {
    guda = {
        bgTexture = "Interface\\ChatFrame\\ChatFrameBackground",
        bgColor = { r = 0.08, g = 0.08, b = 0.08 },
        bgTile = true,
        bgTileSize = 16,
        border = {
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        },
        borderMinimal = {
            edgeFile = "",
            edgeSize = 0,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        },
        nineSlice = {
            corner = "Interface\\AddOns\\Guda\\Assets\\NineSlice-Corner",
            edgeH  = "Interface\\AddOns\\Guda\\Assets\\NineSlice-EdgeH",
            edgeV  = "Interface\\AddOns\\Guda\\Assets\\NineSlice-EdgeV",
            cornerSize = 32,
            edgeThickness = 16,
        },
        titleColor = { r = 1, g = 0.82, b = 0 },
        slotBgAlpha = { empty = 0.5, filled = 0.3 },
        footerButtonBg = { 0.12, 0.12, 0.12, 1 },
        footerButtonBorder = { 0.30, 0.30, 0.30, 1 },
        showHeaderButtonBg = false,
    },
    blizzard = {
        bgTexture = "Interface\\ChatFrame\\ChatFrameBackground",
        bgColor = { r = 0, g = 0, b = 0 },
        bgTile = true,
        bgTileSize = 16,
        bgOverlay = "Interface\\AddOns\\Guda\\Assets\\UI-Background-Rock",
        border = {
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        },
        borderMinimal = {
            edgeFile = "",
            edgeSize = 0,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        },
        nineSlice = {
            corner = "Interface\\AddOns\\Guda\\Assets\\NineSlice-Corner",
            edgeH  = "Interface\\AddOns\\Guda\\Assets\\NineSlice-EdgeH",
            edgeV  = "Interface\\AddOns\\Guda\\Assets\\NineSlice-EdgeV",
            cornerSize = 32,
            edgeThickness = 16,
        },
        titleColor = { r = 1, g = 0.82, b = 0 },
        slotBgAlpha = { empty = 1, filled = 1 },
        footerButtonBg = { 0.12, 0.12, 0.12, 1 },
        footerButtonBorder = { 0.30, 0.30, 0.30, 1 },
        showHeaderButtonBg = true,
        headerButtonBg = { 0.15, 0.12, 0.10, 0.6 },
        headerButtonBorder = { 0.45, 0.40, 0.35, 1 },
    },
    pfui = {
        bgTexture = "Interface\\Buttons\\WHITE8x8",
        bgColor = { r = 0, g = 0, b = 0 },
        bgTile = false,
        bgTileSize = 1,
        border = {
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = -1, right = -1, top = -1, bottom = -1 }
        },
        borderMinimal = {
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = -1, right = -1, top = -1, bottom = -1 }
        },
        nineSlice = nil,
        titleColor = { r = 1, g = 1, b = 1 },
        slotBgAlpha = { empty = 0.5, filled = 0.3 },
        footerButtonBg = { 0, 0, 0, 1 },
        footerButtonBorder = { 0.2, 0.2, 0.2, 1 },
        showHeaderButtonBg = false,
        slotStyle = "square",
        borderColor = { 0.2, 0.2, 0.2, 1 },
        qualityBorderStyle = "square",
    },
}

-- Cached active theme
local cachedTheme = nil
local cachedThemeName = nil

-- Get the active theme name from DB
local function GetThemeName()
    if addon.Modules and addon.Modules.DB then
        return addon.Modules.DB:GetSetting("theme") or "guda"
    end
    return "guda"
end

-- Get active theme table (cached)
function Theme:Get()
    local name = GetThemeName()
    if cachedTheme and cachedThemeName == name then
        return cachedTheme
    end
    cachedThemeName = name
    local base = themes[name] or themes.guda

    -- When pfUI theme is active and pfUI is loaded, inherit pfUI's colors
    if name == "pfui" then
        -- Shallow copy so we don't mutate the static theme table
        local t = {}
        for k, v in pairs(base) do t[k] = v end

        local br, bg, bb, ba = GetPfUIColor("background")
        if br then
            t.bgColor = { r = br, g = bg, b = bb }
            t.footerButtonBg = { br, bg, bb, ba or 1 }
        end
        local er, eg, eb, ea = GetPfUIColor("color")
        if er then
            t.borderColor = { er, eg, eb, ea or 1 }
            t.footerButtonBorder = { er, eg, eb, ea or 1 }
        end
        cachedTheme = t
    else
        cachedTheme = base
    end

    return cachedTheme
end

-- Single property lookup
function Theme:GetValue(key)
    local t = self:Get()
    return t[key]
end

-- Get slot style (square for pfUI, rounded for others)
function Theme:GetSlotStyle()
    return self:GetValue("slotStyle") or "rounded"
end

-- Get quality border style
function Theme:GetQualityBorderStyle()
    return self:GetValue("qualityBorderStyle") or "rounded"
end

-- Get frame padding values (reduced for pfUI borderless style)
function Theme:GetFramePadding()
    local style = self:GetSlotStyle()
    if style == "square" then
        return {
            containerExtra = 10,  -- added to columns*size for container width
            frameExtra = 10,      -- added to containerWidth for frame width
            titleHeight = 28,
            searchBarHeight = 28,
            footerHeight = 55,
            footerHiddenHeight = 5,
            startX = 10,
            startY = -5,
        }
    else
        return {
            containerExtra = 20,
            frameExtra = 20,
            titleHeight = 40,
            searchBarHeight = 30,
            footerHeight = 55,
            footerHiddenHeight = 10,
            startX = 10,
            startY = -2,
        }
    end
end

-- Get border config based on hideBorders setting
local function GetBorderConfig(t)
    local hideBorders = false
    if addon.Modules and addon.Modules.DB then
        hideBorders = addon.Modules.DB:GetSetting("hideBorders")
        if hideBorders == nil then hideBorders = false end
    end
    if hideBorders then
        return t.borderMinimal, true
    else
        return t.border, false
    end
end

-- Hide NineSlice textures
local function HideNineSlice(frame)
    if not frame._gudaNineSlice then return end
    for i = 1, 8 do
        frame._gudaNineSlice[i]:Hide()
    end
end

-- Apply or hide a TGA background texture (for themes where bgFile TGA doesn't work with SetBackdrop)
-- Uses ARTWORK layer so it always renders above the backdrop's BACKGROUND fill,
-- preventing the intermittent z-order issue where both share the same BACKGROUND layer.
local function ApplyBgTexture(frame, texturePath, alpha, padding)
    if not frame._gudaBgTex then
        frame._gudaBgTex = frame:CreateTexture(nil, "ARTWORK")
    end
    local p = padding or 6
    local tex = frame._gudaBgTex
    tex:ClearAllPoints()
    tex:SetTexture(texturePath)
    tex:SetPoint("TOPLEFT", frame, "TOPLEFT", p, -p)
    tex:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -p, p)
    tex:SetAlpha(alpha or 1)
    tex:Show()
end

local function HideBgTexture(frame)
    if frame._gudaBgTex then
        frame._gudaBgTex:Hide()
    end
end

-- Apply or hide background quadrant textures (4 pieces forming a 320x384 background)
-- Layout: TopLeft(256x256) + TopRight(64x256) on top,
--         BotLeft(256x128) + BotRight(64x128) directly below them
local function ApplyBgQuadrants(frame, quadrants)
    if not frame._gudaBgQuad then
        frame._gudaBgQuad = {}
        for i = 1, 4 do
            frame._gudaBgQuad[i] = frame:CreateTexture(nil, "BACKGROUND")
        end
    end
    local q = frame._gudaBgQuad
    -- TopLeft: 256x256, anchored at top-left
    q[1]:ClearAllPoints()
    q[1]:SetTexture(quadrants.topLeft)
    q[1]:SetWidth(256); q[1]:SetHeight(256)
    q[1]:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    q[1]:Show()
    -- TopRight: 64x256, anchored to the right of TopLeft
    q[2]:ClearAllPoints()
    q[2]:SetTexture(quadrants.topRight)
    q[2]:SetWidth(64); q[2]:SetHeight(256)
    q[2]:SetPoint("TOPLEFT", q[1], "TOPRIGHT", 0, 0)
    q[2]:Show()
    -- BotLeft: 256x128, anchored below TopLeft
    q[3]:ClearAllPoints()
    q[3]:SetTexture(quadrants.bottomLeft)
    q[3]:SetWidth(256); q[3]:SetHeight(128)
    q[3]:SetPoint("TOPLEFT", q[1], "BOTTOMLEFT", 0, 0)
    q[3]:Show()
    -- BotRight: 64x128, anchored below TopRight / right of BotLeft
    q[4]:ClearAllPoints()
    q[4]:SetTexture(quadrants.bottomRight)
    q[4]:SetWidth(64); q[4]:SetHeight(128)
    q[4]:SetPoint("TOPLEFT", q[1], "BOTTOMRIGHT", 0, 0)
    q[4]:Show()
end

local function HideBgQuadrants(frame)
    if not frame._gudaBgQuad then return end
    for i = 1, 4 do
        frame._gudaBgQuad[i]:Hide()
    end
end

-- Apply NineSlice metal border using separate texture files
-- Uses 3 TGA source files: Corner, EdgeH, EdgeV
-- Corners are flipped via SetTexCoord (0/1 swaps only)
local function ApplyNineSlice(frame, cfg)
    local cs = cfg.cornerSize   -- 32
    local et = cfg.edgeThickness -- 16

    -- Create or reuse 8 textures: BL, TL, TR, BR, Bottom, Top, Left, Right
    if not frame._gudaNineSlice then
        frame._gudaNineSlice = {}
        for i = 1, 8 do
            frame._gudaNineSlice[i] = frame:CreateTexture(nil, "OVERLAY")
        end
    end

    local ns = frame._gudaNineSlice

    -- 1: Bottom-Left corner (as-is)
    local bl = ns[1]
    bl:ClearAllPoints()
    bl:SetTexture(cfg.corner)
    bl:SetWidth(cs)
    bl:SetHeight(cs)
    bl:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    bl:SetTexCoord(0, 1, 0, 1)
    bl:Show()

    -- 2: Top-Left corner (flip vertically)
    local tl = ns[2]
    tl:ClearAllPoints()
    tl:SetTexture(cfg.corner)
    tl:SetWidth(cs)
    tl:SetHeight(cs)
    tl:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    tl:SetTexCoord(0, 1, 1, 0)
    tl:Show()

    -- 3: Top-Right corner (flip both)
    local tr = ns[3]
    tr:ClearAllPoints()
    tr:SetTexture(cfg.corner)
    tr:SetWidth(cs)
    tr:SetHeight(cs)
    tr:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    tr:SetTexCoord(1, 0, 1, 0)
    tr:Show()

    -- 4: Bottom-Right corner (flip horizontally)
    local br = ns[4]
    br:ClearAllPoints()
    br:SetTexture(cfg.corner)
    br:SetWidth(cs)
    br:SetHeight(cs)
    br:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    br:SetTexCoord(1, 0, 0, 1)
    br:Show()

    -- 5: Bottom edge (stretches between BL and BR corners)
    local bottom = ns[5]
    bottom:ClearAllPoints()
    bottom:SetTexture(cfg.edgeH)
    bottom:SetHeight(et)
    bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", cs, 0)
    bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -cs, 0)
    bottom:SetTexCoord(0, 1, 0, 1)
    bottom:Show()

    -- 6: Top edge (flip vertically)
    local top = ns[6]
    top:ClearAllPoints()
    top:SetTexture(cfg.edgeH)
    top:SetHeight(et)
    top:SetPoint("TOPLEFT", frame, "TOPLEFT", cs, 0)
    top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -cs, 0)
    top:SetTexCoord(0, 1, 1, 0)
    top:Show()

    -- 7: Left edge (stretches between TL and BL corners)
    local left = ns[7]
    left:ClearAllPoints()
    left:SetTexture(cfg.edgeV)
    left:SetWidth(et)
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -cs)
    left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, cs)
    left:SetTexCoord(0, 1, 0, 1)
    left:Show()

    -- 8: Right edge (flip horizontally)
    local right = ns[8]
    right:ClearAllPoints()
    right:SetTexture(cfg.edgeV)
    right:SetWidth(et)
    right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -cs)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, cs)
    right:SetTexCoord(1, 0, 0, 1)
    right:Show()
end

-- Apply theme to a single frame
function Theme:ApplyToFrame(frame)
    if not frame then
        ThemeDebug("ApplyToFrame called with nil frame")
        return
    end

    local frameName = frame:GetName() or "unnamed"
    ThemeDebug("--- ApplyToFrame: %s ---", frameName)

    local t = self:Get()
    local borderCfg, isMinimal = GetBorderConfig(t)

    ThemeDebug("  theme=%s  minimal=%s", tostring(cachedThemeName), tostring(isMinimal))
    ThemeDebug("  bgTexture=%s  tileSize=%s", tostring(t.bgTexture), tostring(t.bgTileSize))

    -- Determine if NineSlice should be used (full border mode + theme has nineSlice config)
    local useNineSlice = t.nineSlice and not isMinimal

    if useNineSlice then
        -- Background only (no edgeFile), NineSlice handles the border
        local backdrop = {
            bgFile = t.bgTexture,
            tile = true,
            tileSize = t.bgTileSize,
            edgeSize = 0,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        }
        frame:SetBackdrop(nil)
        frame:SetBackdrop(backdrop)
        ApplyNineSlice(frame, t.nineSlice)
        ThemeDebug("  SetBackdrop done (bgFile + NineSlice border)")
    else
        -- Standard backdrop with edgeFile border (or no border when hidden)
        local hasEdge = borderCfg.edgeFile and borderCfg.edgeFile ~= ""
        local backdrop
        if hasEdge then
            backdrop = {
                bgFile = t.bgTexture,
                edgeFile = borderCfg.edgeFile,
                tile = true,
                tileSize = t.bgTileSize,
                edgeSize = borderCfg.edgeSize,
                insets = {
                    left = borderCfg.insets.left,
                    right = borderCfg.insets.right,
                    top = borderCfg.insets.top,
                    bottom = borderCfg.insets.bottom,
                }
            }
        else
            -- No border: omit edgeFile key entirely (WoW 1.12 renders a black
            -- line when edgeFile is "" or nil inside the table)
            backdrop = {
                bgFile = t.bgTexture,
                tile = true,
                tileSize = t.bgTileSize,
                edgeSize = 0,
                insets = { left = 0, right = 0, top = 0, bottom = 0 }
            }
        end
        frame:SetBackdrop(nil)
        frame:SetBackdrop(backdrop)
        HideNineSlice(frame)
        ThemeDebug("  SetBackdrop done (bgFile + %s border)", hasEdge and "edgeFile" or "none")
    end

    -- Apply border color when an edge is present
    local hasEdge = borderCfg.edgeFile and borderCfg.edgeFile ~= ""
    if hasEdge then
        local bc = t.borderColor or { 1, 1, 1, 1 }
        if isMinimal or t.borderColor then
            frame:SetBackdropBorderColor(bc[1], bc[2], bc[3], bc[4])
        end
    end

    -- Background quadrant textures (disabled for testing)
    HideBgQuadrants(frame)

    -- TGA background overlay (CreateTexture, since TGA doesn't work with SetBackdrop bgFile)
    if t.bgOverlay then
        local transparency = 0.15
        if addon.Modules and addon.Modules.DB then
            transparency = addon.Modules.DB:GetSetting("bgTransparency") or 0.15
        end
        local bgPadding = isMinimal and 0 or 6
        ApplyBgTexture(frame, t.bgOverlay, 1.0 - transparency, bgPadding)
    else
        HideBgTexture(frame)
    end

    -- Background color / alpha
    local bg = t.bgColor
    local alpha
    local usePfUITransp = false
    if addon.Modules and addon.Modules.DB then
        usePfUITransp = addon.Modules.DB:GetSetting("usePfUITransparency")
    end
    if cachedThemeName == "pfui" and usePfUITransp ~= false then
        local _, _, _, ba = GetPfUIColor("background")
        alpha = ba or 1
    else
        local transparency = 0.15
        if addon.Modules and addon.Modules.DB then
            transparency = addon.Modules.DB:GetSetting("bgTransparency") or 0.15
        end
        alpha = 1.0 - transparency
    end
    frame:SetBackdropColor(bg.r, bg.g, bg.b, alpha)
    ThemeDebug("  SetBackdropColor(%s,%s,%s,%s)", tostring(bg.r), tostring(bg.g), tostring(bg.b), tostring(alpha))

    -- Clean up legacy child frame / texture from previous approaches
    if frame._gudaBgFrame then
        frame._gudaBgFrame:Hide()
        frame._gudaBgFrame:SetParent(nil)
        frame._gudaBgFrame = nil
    end
    if frame._gudaBg then
        frame._gudaBg:Hide()
    end

    -- Verify
    local bd = frame:GetBackdrop()
    if bd then
        ThemeDebug("  VERIFY: bgFile=%s tile=%s tileSize=%s",
            tostring(bd.bgFile), tostring(bd.tile), tostring(bd.tileSize))
    end
    ThemeDebug("  VERIFY: frame size=%sx%s  visible=%s  level=%s  strata=%s",
        tostring(frame:GetWidth()), tostring(frame:GetHeight()),
        tostring(frame:IsVisible()), tostring(frame:GetFrameLevel()),
        tostring(frame:GetFrameStrata()))
end

-- Apply theme to all main frames
function Theme:ApplyToAllFrames()
    ThemeDebug("=== ApplyToAllFrames ===")
    local frameNames = { "Guda_BagFrame", "Guda_BankFrame", "Guda_MailboxFrame", "Guda_SettingsPopup", "Guda_CategoryEditor" }
    for _, frameName in ipairs(frameNames) do
        local frame = getglobal(frameName)
        if frame then
            self:ApplyToFrame(frame)
        else
            ThemeDebug("  frame %s NOT FOUND (nil)", frameName)
        end
    end

    -- Update slot background alphas on all existing item buttons
    local sa = self:GetValue("slotBgAlpha")
    if sa then
        self:UpdateAllSlotBackgrounds(sa)
    end

    -- Update footer button backdrops (bag slots + keyring)
    if Guda_BagSlot_ApplyBackdrop then
        local footerButtons = {
            "Guda_BagFrame_Toolbar_BagSlot0",
            "Guda_BagFrame_Toolbar_BagSlot1",
            "Guda_BagFrame_Toolbar_BagSlot2",
            "Guda_BagFrame_Toolbar_BagSlot3",
            "Guda_BagFrame_Toolbar_BagSlot4",
            "Guda_BagFrame_Toolbar_KeyringButton",
            "Guda_BagFrame_Toolbar_SoulBagButton",
        }
        for _, name in ipairs(footerButtons) do
            local btn = getglobal(name)
            if btn then Guda_BagSlot_ApplyBackdrop(btn) end
        end
        -- Update flyout buttons too
        for i = 1, 4 do
            local btn = getglobal("Guda_BagFlyout_Slot" .. i)
            if btn then Guda_BagSlot_ApplyBackdrop(btn) end
        end
    end

    -- Update header button backgrounds
    self:ApplyHeaderButtonBackgrounds()

    -- Update search box styling
    self:ApplySearchBoxStyle()

    -- Adjust frame padding for borderless/pfUI themes
    self:ApplyFramePadding()

    ThemeDebug("=== ApplyToAllFrames done ===")
end

-- Update emptySlotBg alpha and style on all visible item buttons
function Theme:UpdateAllSlotBackgrounds(sa)
    local slotStyle = self:GetSlotStyle()
    local i = 1
    while true do
        local btn = getglobal("Guda_ItemButton" .. i)
        if not btn then break end
        local bg = getglobal(btn:GetName() .. "_EmptySlotBg")
        if bg then
            -- Update texture and anchors based on slot style
            if slotStyle == "square" then
                bg:SetTexture("Interface\\Buttons\\WHITE8x8")
                bg:SetVertexColor(0.05, 0.05, 0.05, 1)
                bg:ClearAllPoints()
                bg:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
                bg:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
                bg:SetTexCoord(0, 1, 0, 1)
            else
                bg:SetTexture("Interface\\Buttons\\UI-EmptySlot")
                bg:SetVertexColor(1, 1, 1, 1)
                bg:ClearAllPoints()
                bg:SetPoint("TOPLEFT", btn, "TOPLEFT", -9, 9)
                bg:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 9, -9)
                bg:SetTexCoord(0, 1, 0, 1)
            end
            local alpha = btn.hasItem and sa.filled or sa.empty
            if alpha > 0 then
                bg:SetAlpha(alpha)
                bg:Show()
            else
                bg:Hide()
            end
        end
        i = i + 1
    end
end

-- Apply or remove header button background based on theme
local headerButtonBackdrop = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
}

function Theme:ApplyHeaderButtonBg(button)
    local showBg = self:GetValue("showHeaderButtonBg")
    if showBg then
        -- Create or reuse background frame behind the icon
        if not button._themeBg then
            local bg = CreateFrame("Frame", nil, button)
            bg:SetWidth(button:GetWidth() + 4)
            bg:SetHeight(button:GetHeight() + 4)
            bg:SetPoint("CENTER", button, "CENTER", 0, 0)
            bg:SetFrameLevel(button:GetFrameLevel())
            bg:SetBackdrop(headerButtonBackdrop)
            button._themeBg = bg
        end
        local hbBg = self:GetValue("headerButtonBg") or { 0.5, 0.06, 0.06, 0.6 }
        local hbBorder = self:GetValue("headerButtonBorder") or { 0.5, 0.06, 0.06, 1 }
        button._themeBg:SetBackdropColor(hbBg[1], hbBg[2], hbBg[3], hbBg[4])
        button._themeBg:SetBackdropBorderColor(hbBorder[1], hbBorder[2], hbBorder[3], hbBorder[4])
        button._themeBg:Show()
    else
        if button._themeBg then
            button._themeBg:Hide()
        end
    end
end

function Theme:ApplyHeaderButtonBackgrounds()
    local headerButtons = {
        -- BagFrame
        "Guda_BagFrame_SettingsButton",
        "Guda_BagFrame_SortButton",
        "Guda_BagFrame_CharsButton",
        "Guda_BagFrame_BankButton",
        "Guda_BagFrame_MailButton",
        -- BankFrame
        "Guda_BankFrame_SettingsButton",
        "Guda_BankFrame_SortButton",
        "Guda_BankFrame_CharsButton",
        "Guda_BankFrame_BlizzardUIButton",
        -- MailboxFrame
        "Guda_MailboxFrame_CharacterButton",
    }
    for _, name in ipairs(headerButtons) do
        local btn = getglobal(name)
        if btn then
            self:ApplyHeaderButtonBg(btn)
        end
    end
end

-- Apply square/rounded styling to search boxes
function Theme:ApplySearchBoxStyle()
    local slotStyle = self:GetSlotStyle()
    local searchBoxNames = {
        "Guda_BagFrame_SearchBar_SearchBox",
        "Guda_BankFrame_SearchBar_SearchBox",
    }
    for _, name in ipairs(searchBoxNames) do
        local box = getglobal(name)
        if box then
            -- Hide InputBoxTemplate border textures (Left, Right, Middle)
            local left = getglobal(name .. "Left")
            local right = getglobal(name .. "Right")
            local mid = getglobal(name .. "Middle")
            if slotStyle == "square" then
                if left then left:Hide() end
                if right then right:Hide() end
                if mid then mid:Hide() end
                -- Apply pfUI-style backdrop
                box:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8x8",
                    edgeFile = "Interface\\Buttons\\WHITE8x8",
                    edgeSize = 1,
                    insets = { left = -1, right = -1, top = -1, bottom = -1 },
                })
                local t = self:Get()
                local sbg = t.bgColor
                box:SetBackdropColor(sbg.r, sbg.g, sbg.b, 1)
                local sbc = t.borderColor or { 0.2, 0.2, 0.2, 1 }
                box:SetBackdropBorderColor(sbc[1], sbc[2], sbc[3], sbc[4])
                -- Reposition flush left at x=10
                box:ClearAllPoints()
                box:SetPoint("LEFT", box:GetParent(), "LEFT", 8, 0)
                box:SetPoint("RIGHT", box:GetParent(), "RIGHT", -7, 0)
                -- Add text padding inside the field
                box:SetTextInsets(5, 5, 0, 0)
            else
                if left then left:Show() end
                if right then right:Show() end
                if mid then mid:Show() end
                box:SetBackdrop(nil)
                -- Restore default anchors
                box:ClearAllPoints()
                box:SetPoint("LEFT", box:GetParent(), "LEFT", 15, 0)
                box:SetPoint("RIGHT", box:GetParent(), "RIGHT", -12, 0)
                -- Restore default text insets
                box:SetTextInsets(3, 3, 0, 0)
            end
        end
    end
end

-- Adjust header/footer padding to match theme border style
function Theme:ApplyFramePadding()
    local slotStyle = self:GetSlotStyle()
    -- Only adjust for pfUI/square style; otherwise restore defaults
    local isPfui = (slotStyle == "square")

    -- BagFrame adjustments
    local bagFrameElements = {
        { name = "Guda_BagFrame_Title",       pfui = { "TOP", nil, "TOP", 0, -8 },        default = { "TOP", nil, "TOP", 0, -12 } },
        { name = "Guda_BagFrame_CloseButton", pfui = { "TOPRIGHT", nil, "TOPRIGHT", -5, -5 }, default = { "TOPRIGHT", nil, "TOPRIGHT", -13, -10 } },
        { name = "Guda_BagFrame_CharsButton", pfui = { "TOPLEFT", nil, "TOPLEFT", 10, -8 },   default = { "TOPLEFT", nil, "TOPLEFT", 21, -15 } },
        { name = "Guda_BagFrame_SearchBar",   pfui = { "TOP", nil, "TOP", 0, -30 },       default = { "TOP", nil, "TOP", 0, -40 } },
        { name = "Guda_BagFrame_Toolbar",     pfui = { "BOTTOMLEFT", nil, "BOTTOMLEFT", 5, 5 }, default = { "BOTTOMLEFT", nil, "BOTTOMLEFT", 10, 5 } },
        { name = "Guda_BagFrame_MoneyFrame", pfui = { "BOTTOMRIGHT", nil, "BOTTOMRIGHT", -5, 7 }, default = { "BOTTOMRIGHT", nil, "BOTTOMRIGHT", -5, 7 } },
    }
    for _, elem in ipairs(bagFrameElements) do
        local frame = getglobal(elem.name)
        if frame then
            local pos = isPfui and elem.pfui or elem.default
            local parent = frame:GetParent()
            frame:ClearAllPoints()
            frame:SetPoint(pos[1], parent, pos[3], pos[4], pos[5])
        end
    end

    -- BankFrame adjustments (similar structure)
    local bankFrameElements = {
        { name = "Guda_BankFrame_Title",          pfui = { "TOP", nil, "TOP", 0, -8 },            default = { "TOP", nil, "TOP", 0, -12 } },
        { name = "Guda_BankFrame_CloseButton",  pfui = { "TOPRIGHT", nil, "TOPRIGHT", -5, -5 }, default = { "TOPRIGHT", nil, "TOPRIGHT", -13, -10 } },
        { name = "Guda_BankFrame_BlizzardUIButton", pfui = { "TOPLEFT", nil, "TOPLEFT", 10, -8 }, default = { "TOPLEFT", nil, "TOPLEFT", 23, -15 } },
        { name = "Guda_BankFrame_SearchBar",    pfui = { "TOP", nil, "TOP", 0, -30 },       default = { "TOP", nil, "TOP", 0, -40 } },
        { name = "Guda_BankFrame_Toolbar",      pfui = { "BOTTOMLEFT", nil, "BOTTOMLEFT", 5, 5 }, default = { "BOTTOMLEFT", nil, "BOTTOMLEFT", 15, 5 } },
    }
    for _, elem in ipairs(bankFrameElements) do
        local frame = getglobal(elem.name)
        if frame then
            local pos = isPfui and elem.pfui or elem.default
            local parent = frame:GetParent()
            frame:ClearAllPoints()
            frame:SetPoint(pos[1], parent, pos[3], pos[4], pos[5])
        end
    end
end

-- Clear cache (call when theme setting changes)
function Theme:ClearCache()
    cachedTheme = nil
    cachedThemeName = nil
end

-- Slash command to toggle theme debug
SLASH_GUDATHEME1 = "/gudatheme"
SlashCmdList["GUDATHEME"] = function(msg)
    if msg == "on" then
        addon.DEBUG_THEME = true
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF8800[Theme]|r Debug ON — reapplying all frames...")
        Theme:ApplyToAllFrames()
    elseif msg == "off" then
        addon.DEBUG_THEME = false
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF8800[Theme]|r Debug OFF")
    elseif msg == "apply" then
        local prev = addon.DEBUG_THEME
        addon.DEBUG_THEME = true
        Theme:ApplyToAllFrames()
        addon.DEBUG_THEME = prev
    elseif msg == "inspect" then
        -- Dump backdrop state for all frames without reapplying
        local frameNames = { "Guda_BagFrame", "Guda_BankFrame", "Guda_MailboxFrame", "Guda_SettingsPopup", "Guda_CategoryEditor" }
        -- Show current transparency setting
        local transp = "N/A"
        if addon.Modules and addon.Modules.DB then
            transp = tostring(addon.Modules.DB:GetSetting("bgTransparency"))
        end
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFF8800[Theme]|r === Inspect Backdrop === (bgTransparency=%s, alpha=%s)",
            transp, tostring(1.0 - (tonumber(transp) or 0.15))))
        for _, fn in ipairs(frameNames) do
            local f = getglobal(fn)
            if f then
                local bd = f:GetBackdrop()
                if bd then
                    DEFAULT_CHAT_FRAME:AddMessage(string.format("  |cFFFFFF00%s|r: bgFile=%s edgeFile=%s tile=%s tileSize=%s",
                        fn, tostring(bd.bgFile), tostring(bd.edgeFile), tostring(bd.tile), tostring(bd.tileSize)))
                else
                    DEFAULT_CHAT_FRAME:AddMessage(string.format("  |cFFFFFF00%s|r: backdrop=nil", fn))
                end
                DEFAULT_CHAT_FRAME:AddMessage(string.format("    visible=%s  size=%dx%d  level=%s  strata=%s",
                    tostring(f:IsVisible()), f:GetWidth(), f:GetHeight(),
                    tostring(f:GetFrameLevel()), tostring(f:GetFrameStrata())))
                -- Check child bg frame
                if f._gudaBgFrame then
                    local cbd = f._gudaBgFrame:GetBackdrop()
                    DEFAULT_CHAT_FRAME:AddMessage(string.format("    bgFrame: bgFile=%s shown=%s visible=%s level=%s",
                        cbd and tostring(cbd.bgFile) or "nil",
                        tostring(f._gudaBgFrame:IsShown()),
                        tostring(f._gudaBgFrame:IsVisible()),
                        tostring(f._gudaBgFrame:GetFrameLevel())))
                end
            else
                DEFAULT_CHAT_FRAME:AddMessage(string.format("  |cFFFF0000%s|r: frame not found", fn))
            end
        end
    elseif msg == "test" then
        -- Create standalone test frames to isolate which textures render via Lua
        local p = DEFAULT_CHAT_FRAME
        p:AddMessage("|cFFFF8800[Theme]|r === Texture Test ===")

        -- Test 1: ChatFrameBackground (known working)
        local f1 = CreateFrame("Frame", "GudaThemeTest1", UIParent)
        f1:SetWidth(200); f1:SetHeight(200)
        f1:SetPoint("CENTER", -220, 0)
        f1:SetFrameStrata("TOOLTIP")
        f1:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 16, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        f1:SetBackdropColor(0, 0, 0, 1)
        f1:Show()
        p:AddMessage("  Test 1 (LEFT): ChatFrameBackground — should be solid black")

        -- Test 2: UI-DialogBox-Background (the broken one)
        local f2 = CreateFrame("Frame", "GudaThemeTest2", UIParent)
        f2:SetWidth(200); f2:SetHeight(200)
        f2:SetPoint("CENTER", 0, 0)
        f2:SetFrameStrata("TOOLTIP")
        f2:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        f2:SetBackdropColor(1, 1, 1, 1)
        f2:Show()
        p:AddMessage("  Test 2 (CENTER): UI-DialogBox-Background — should be parchment")

        -- Test 3: UI-Tooltip-Background (another common texture)
        local f3 = CreateFrame("Frame", "GudaThemeTest3", UIParent)
        f3:SetWidth(200); f3:SetHeight(200)
        f3:SetPoint("CENTER", 220, 0)
        f3:SetFrameStrata("TOOLTIP")
        f3:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 16, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        f3:SetBackdropColor(1, 1, 1, 1)
        f3:Show()
        p:AddMessage("  Test 3 (RIGHT): UI-Tooltip-Background — should be purple/blue")

        p:AddMessage("|cFFFF8800[Theme]|r /gudatheme clear to remove test frames")

    elseif msg == "scan" then
        -- Enable mouseover scanning: hover any frame to print its backdrop info
        if addon._themeScanFrame then
            addon._themeScanFrame:Hide()
            addon._themeScanFrame = nil
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF8800[Theme]|r Scan OFF")
        else
            local scanner = CreateFrame("Frame", nil, UIParent)
            scanner:SetAllPoints(UIParent)
            scanner:SetFrameStrata("TOOLTIP")
            scanner:EnableMouse(false)
            scanner._lastFrame = nil
            scanner:SetScript("OnUpdate", function()
                local f = GetMouseFocus()
                if f and f ~= this._lastFrame then
                    this._lastFrame = f
                    local name = f:GetName() or "unnamed"
                    local p = DEFAULT_CHAT_FRAME

                    -- Print backdrop if any
                    local bd = f.GetBackdrop and f:GetBackdrop()
                    if bd and (bd.bgFile or bd.edgeFile) then
                        p:AddMessage(string.format(
                            "|cFFFF8800[Scan]|r |cFFFFFF00%s|r bgFile=%s edgeFile=%s tile=%s tileSize=%s",
                            name, tostring(bd.bgFile), tostring(bd.edgeFile),
                            tostring(bd.tile), tostring(bd.tileSize)))
                    end

                    -- Print textures via GetRegions()
                    if f.GetRegions then
                        local regions = { f:GetRegions() }
                        for i, region in ipairs(regions) do
                            if region and region.GetTexture then
                                local tex = region:GetTexture()
                                if tex and tex ~= "" then
                                    local rname = region:GetName() or ("region" .. i)
                                    local layer = region.GetDrawLayer and region:GetDrawLayer() or "?"
                                    p:AddMessage(string.format(
                                        "|cFFFF8800[Scan]|r   |cFF88FF88%s|r tex=%s layer=%s",
                                        rname, tostring(tex), tostring(layer)))
                                end
                            end
                        end
                    end

                    -- If nothing printed, at least show the frame name
                    if not (bd and (bd.bgFile or bd.edgeFile)) then
                        local hasTextures = false
                        if f.GetRegions then
                            local regions = { f:GetRegions() }
                            for _, region in ipairs(regions) do
                                if region and region.GetTexture and region:GetTexture() and region:GetTexture() ~= "" then
                                    hasTextures = true
                                    break
                                end
                            end
                        end
                        if not hasTextures then
                            p:AddMessage(string.format("|cFFFF8800[Scan]|r |cFF888888%s|r (no backdrop, no textures)", name))
                        end
                    end
                end
            end)
            scanner:Show()
            addon._themeScanFrame = scanner
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF8800[Theme]|r Scan ON — hover any frame to see its backdrop. /gudatheme scan again to stop.")
        end

    elseif msg == "clear" then
        for _, name in ipairs({"GudaThemeTest1", "GudaThemeTest2", "GudaThemeTest3"}) do
            local f = getglobal(name)
            if f then f:Hide() end
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF8800[Theme]|r Test frames hidden")

    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF8800[Theme]|r Usage:")
        DEFAULT_CHAT_FRAME:AddMessage("  /gudatheme on      — Enable debug logging")
        DEFAULT_CHAT_FRAME:AddMessage("  /gudatheme off     — Disable debug logging")
        DEFAULT_CHAT_FRAME:AddMessage("  /gudatheme apply   — Reapply all frames (with debug)")
        DEFAULT_CHAT_FRAME:AddMessage("  /gudatheme inspect — Dump backdrop state")
        DEFAULT_CHAT_FRAME:AddMessage("  /gudatheme test    — Show 3 test frames with different textures")
        DEFAULT_CHAT_FRAME:AddMessage("  /gudatheme clear   — Hide test frames")
    end
end

addon:Debug("Theme module loaded")
