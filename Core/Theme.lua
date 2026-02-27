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

-- Theme definitions
-- Background is rendered via a standalone Texture child (not bgFile).
local themes = {
    guda = {
        -- ChatFrameBackground is a solid white 1x1 pixel.
        -- Vertex-colored (0,0,0) it becomes a solid dark background.
        bgTexture = "Interface\\ChatFrame\\ChatFrameBackground",
        bgColor = { r = 0, g = 0, b = 0 },
        bgTile = true,
        bgTileSize = 16,
        border = {
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        },
        borderMinimal = {
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 2,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        },
        titleColor = { r = 1, g = 0.82, b = 0 },
        slotBgAlpha = { empty = 0.5, filled = 0.3 },
        footerButtonBg = { 0.12, 0.12, 0.12, 1 },
        footerButtonBorder = { 0.30, 0.30, 0.30, 1 },
        showHeaderButtonBg = false,
    },
    blizzard = {
        -- Custom bank parchment texture bundled with the addon.
        -- Blizzard's MPQ textures (UI-DialogBox-Background) don't render
        -- when set via Lua SetBackdrop() in TurtleWoW 1.12.
        bgTexture = "Interface\\AddOns\\Guda\\Assets\\Bank-Background",
        bgColor = { r = 1, g = 1, b = 1 },
        bgTile = true,
        bgTileSize = 256,
        border = {
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        },
        borderMinimal = {
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 2,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        },
        titleColor = { r = 1, g = 0.82, b = 0 },
        slotBgAlpha = { empty = 1, filled = 1 },
        footerButtonBg = { 0.5, 0.06, 0.06, 0.6 },
        footerButtonBorder = { 0.5, 0.06, 0.06, 1 },
        showHeaderButtonBg = true,
        headerButtonBg = { 0.5, 0.06, 0.06, 0.6 },
        headerButtonBorder = { 0.5, 0.06, 0.06, 1 },
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
    cachedTheme = themes[name] or themes.guda
    return cachedTheme
end

-- Single property lookup
function Theme:GetValue(key)
    local t = self:Get()
    return t[key]
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

    -- Full backdrop: bgFile + border in a single SetBackdrop call.
    local backdrop = {
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

    frame:SetBackdrop(nil)
    frame:SetBackdrop(backdrop)
    ThemeDebug("  SetBackdrop done (bgFile + border)")

    if isMinimal then
        frame:SetBackdropBorderColor(1, 1, 1, 1)
    end

    -- Background color / alpha
    local bg = t.bgColor
    local transparency = 0.15
    if addon.Modules and addon.Modules.DB then
        transparency = addon.Modules.DB:GetSetting("bgTransparency") or 0.15
    end
    local alpha = 1.0 - transparency
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
    local frameNames = { "Guda_BagFrame", "Guda_BankFrame", "Guda_MailboxFrame", "Guda_SettingsPopup", "Guda_CategoryEditor", "Guda_QuestItemBar" }
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

    ThemeDebug("=== ApplyToAllFrames done ===")
end

-- Update emptySlotBg alpha on all visible item buttons
function Theme:UpdateAllSlotBackgrounds(sa)
    local i = 1
    while true do
        local btn = getglobal("Guda_ItemButton" .. i)
        if not btn then break end
        local bg = getglobal(btn:GetName() .. "_EmptySlotBg")
        if bg then
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
        local frameNames = { "Guda_BagFrame", "Guda_BankFrame", "Guda_MailboxFrame", "Guda_SettingsPopup", "Guda_CategoryEditor", "Guda_QuestItemBar" }
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
