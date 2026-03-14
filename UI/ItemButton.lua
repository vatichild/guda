-- Local alias to the addon root table (must be defined before any usages below)
local addon = Guda

-- Item button pool
local buttonPool = {}
local nextButtonID = 1
local BUTTON_POOL_MAX = 500  -- Maximum buttons to create (bags ~80 + bank ~200 + keyring ~96 + buffer for both frames open)

-- Category drag-drop: track cursor item for category reassignment
local cursorItemInfo = nil  -- { bagID, slotID, itemID, link }
local activeCategoryDropIndicator = nil  -- the currently shown "+" indicator button

-- Get button pool statistics (for /guda perf command)
function Guda_GetButtonPoolStats()
    local total = 0
    local shown = 0
    local hidden = 0
    local inUse = 0
    local available = 0
    for _, button in pairs(buttonPool) do
        total = total + 1
        if button:IsShown() then
            shown = shown + 1
        else
            hidden = hidden + 1
        end
        if button.inUse then
            inUse = inUse + 1
        else
            available = available + 1
        end
    end
    return {
        total = total,
        shown = shown,
        hidden = hidden,
        inUse = inUse,
        available = available,
        maxSize = BUTTON_POOL_MAX,
    }
end

-- Reset button pool (for testing/debugging)
-- WARNING: Only call this when no bag/bank frames are visible!
function Guda_ResetButtonPool()
    -- Hide and clear all buttons
    for id, button in pairs(buttonPool) do
        button:Hide()
        button:ClearAllPoints()
        -- Clear from parent tracking
        local parent = button:GetParent()
        if parent and parent.itemButtons then
            parent.itemButtons[button] = nil
        end
    end
    -- Clear the pool table
    for k in pairs(buttonPool) do
        buttonPool[k] = nil
    end
    -- Reset counter
    nextButtonID = 1
end

-- Mark all buttons as available for reuse (called when switching view types)
-- This allows buttons from one frame to be reused by another
function Guda_ReleaseAllButtons()
    for _, button in pairs(buttonPool) do
        if not button.isBagSlot then
            button.inUse = false
        end
    end
end

-- Category drop indicator: a single shared frame (parented to UIParent) with plus icon
local HideCategoryDropIndicator  -- forward declaration
local categoryDropIndicator = nil  -- the single shared indicator frame
local dropIndicatorCategoryId = nil  -- category the indicator is currently showing for
local dropCooldownTime = 0  -- GetTime() when cooldown expires

-- Helper: get category of cursor item using tracked info
local function GetCursorItemCategory()
    local info = Guda_GetCursorItemInfo()
    addon:Debug("GetCursorItemCat: info=%s", tostring(info ~= nil))
    if not info or not info.itemID or not addon.Modules.CategoryManager then
        addon:Debug("GetCursorItemCat: BAIL - info=%s itemID=%s catMgr=%s", tostring(info ~= nil), tostring(info and info.itemID), tostring(addon.Modules.CategoryManager ~= nil))
        return nil
    end
    local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture
    if info.link then
        itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(info.link)
    end
    addon:Debug("GetCursorItemCat: itemName=%s itemType=%s", tostring(itemName), tostring(itemType))
    if not itemName then return nil end
    local itemData = {
        link = info.link,
        itemID = info.itemID,
        name = itemName,
        quality = itemQuality or 0,
        class = itemType or "",
        subClass = itemSubType or "",
        equipLoc = itemEquipLoc or "",
        stackCount = itemStackCount or 1,
        level = itemLevel or 0,
        minLevel = itemMinLevel or 0,
        texture = itemTexture,
    }
    return addon.Modules.CategoryManager:CategorizeItem(itemData, info.bagID, info.slotID)
end

-- Create the single shared indicator frame (once)
local function GetOrCreateIndicator()
    if categoryDropIndicator then return categoryDropIndicator end

    local f = CreateFrame("Frame", "Guda_CategoryDropIndicator", UIParent)
    f:SetWidth(36)
    f:SetHeight(36)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(500)

    -- Slot background (same texture as empty bag slot, with green tint like GudaBags)
    local slotBg = f:CreateTexture(nil, "BACKGROUND")
    slotBg:SetPoint("TOPLEFT", f, "TOPLEFT", -9, 9)
    slotBg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 9, -9)
    slotBg:SetTexture("Interface\\Buttons\\UI-EmptySlot")
    slotBg:SetVertexColor(0.4, 0.8, 0.4, 0.9)
    f.slotBg = slotBg

    -- Plus icon centered
    local plus = f:CreateTexture(nil, "OVERLAY")
    plus:SetWidth(20)
    plus:SetHeight(20)
    plus:SetPoint("CENTER", f, "CENTER", 0, 0)
    plus:SetTexture("Interface\\AddOns\\Guda\\Assets\\plus")
    f.plus = plus

    -- Mouse-enabled for drops
    f:EnableMouse(true)

    -- Handle drop on the indicator itself
    local function DoIndicatorDrop()
        if not activeCategoryDropIndicator then return end
        local parentBtn = activeCategoryDropIndicator
        if parentBtn and parentBtn:GetScript("OnReceiveDrag") then
            local savedThis = getfenv(0)["this"]
            getfenv(0)["this"] = parentBtn
            parentBtn:GetScript("OnReceiveDrag")()
            getfenv(0)["this"] = savedThis
        end
    end

    f:SetScript("OnReceiveDrag", DoIndicatorDrop)
    f:SetScript("OnMouseUp", function()
        if CursorHasItem and CursorHasItem() then
            DoIndicatorDrop()
        end
    end)

    -- Tooltip on hover
    f:SetScript("OnEnter", function()
        if dropIndicatorCategoryId then
            GameTooltip:SetOwner(this, "ANCHOR_TOP")
            GameTooltip:SetText("Add item to this category", 1, 1, 1)
            GameTooltip:AddLine("Drop here to permanently assign", 0.7, 0.7, 0.7)
            GameTooltip:AddLine("this item to \"" .. tostring(dropIndicatorCategoryId) .. "\"", 0.5, 1, 0.5)
            GameTooltip:Show()
        end
    end)

    f:SetScript("OnLeave", function()
        GameTooltip:Hide()
        -- Delay hide: use an OnUpdate check instead of C_Timer
        local elapsed = 0
        this:SetScript("OnUpdate", function()
            elapsed = elapsed + arg1
            if elapsed >= 0.05 then
                this:SetScript("OnUpdate", nil)
                -- Check if mouse is still over the indicator or the parent button
                if activeCategoryDropIndicator and MouseIsOver(activeCategoryDropIndicator) then
                    return
                end
                if this:IsMouseOver() then
                    return
                end
                HideCategoryDropIndicator()
            end
        end)
    end)

    f:Hide()
    categoryDropIndicator = f
    return f
end

local function ShowCategoryDropIndicator(button)
    if activeCategoryDropIndicator == button then return end

    -- Don't show during drop cooldown
    if GetTime() < dropCooldownTime then return end

    HideCategoryDropIndicator()

    local ind = GetOrCreateIndicator()
    local size = button:GetWidth()

    -- Size to match icon
    ind:SetWidth(size)
    ind:SetHeight(size)

    -- Update plus icon size (60% of icon, min 16)
    local plusSize = math.max(16, math.floor(size * 0.6))
    ind.plus:SetWidth(plusSize)
    ind.plus:SetHeight(plusSize)

    -- Position below the hovered button using screen coordinates
    local buttonLeft = button:GetLeft()
    local buttonBottom = button:GetBottom()
    ind:ClearAllPoints()
    if buttonLeft and buttonBottom then
        ind:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", buttonLeft, buttonBottom - 2)
    end

    -- Track state
    dropIndicatorCategoryId = button.categoryId or nil
    activeCategoryDropIndicator = button
    ind:Show()
end

HideCategoryDropIndicator = function()
    if categoryDropIndicator then
        categoryDropIndicator:Hide()
        categoryDropIndicator:SetScript("OnUpdate", nil)
        GameTooltip:Hide()
    end
    activeCategoryDropIndicator = nil
    dropIndicatorCategoryId = nil
end

-- Track what item the cursor is holding (called before pickup)
function Guda_TrackCursorItem(bagID, slotID)
    local link = GetContainerItemLink(bagID, slotID)
    if link then
        local itemID = addon.Modules.Utils:ExtractItemID(link)
        cursorItemInfo = { bagID = bagID, slotID = slotID, itemID = itemID, link = link }
        addon:Debug("TrackCursor: bag=%d slot=%d itemID=%s", bagID, slotID, tostring(itemID))
    else
        cursorItemInfo = nil
        addon:Debug("TrackCursor: no link at bag=%d slot=%d", bagID, slotID)
    end
end

function Guda_ClearCursorItem()
    cursorItemInfo = nil
end

function Guda_GetCursorItemInfo()
    return cursorItemInfo
end

-- Check if we're in category view for bags or bank
local function IsInCategoryView(isBank)
    if not addon.Modules.DB then return false end
    local key = isBank and "bankViewType" or "bagViewType"
    return (addon.Modules.DB:GetSetting(key) or "single") == "category"
end

-- Auto-clear cursor tracking when cursor is truly empty
-- Uses a short delay to avoid clearing during the pickup transition
-- (CURSOR_UPDATE fires before the item is fully on the cursor)
local cursorWatcher = CreateFrame("Frame")
cursorWatcher:RegisterEvent("CURSOR_UPDATE")
cursorWatcher:SetScript("OnEvent", function()
    -- Don't clear immediately — wait a frame to let the pickup finish
    if not cursorItemInfo then
        HideCategoryDropIndicator()
        return
    end
    -- Schedule a check next frame
    this.pendingCheck = true
end)
cursorWatcher:SetScript("OnUpdate", function()
    if not this.pendingCheck then return end
    this.pendingCheck = nil
    -- Now check if cursor actually has an item
    if cursorItemInfo and (not CursorHasItem or not CursorHasItem()) then
        cursorItemInfo = nil
        HideCategoryDropIndicator()
    end
end)

-- Use shared tooltip from Utils module (retrieved on-demand to ensure Utils is loaded)

-- Helper function to check if an item is a quest item
-- Uses centralized ItemDetection module
local function IsQuestItem(bagID, slotID, isBank, itemData)
    -- Use ItemDetection if available
    if addon and addon.Modules and addon.Modules.ItemDetection then
        local props = addon.Modules.ItemDetection:GetItemProperties(itemData, bagID, slotID)
        return props.isQuestItem, props.isQuestStarter
    end
    -- Fallback to Utils
    if addon and addon.Modules and addon.Modules.Utils and addon.Modules.Utils.IsQuestItem then
        return addon.Modules.Utils:IsQuestItem(bagID, slotID, nil, false, isBank)
    end
    return false, false
end

--=====================================================
-- Inner Shadow (inset quality glow, GudaBags-inspired)
-- 4 gradient textures along edges colored by item quality
--=====================================================
local INNER_SHADOW_SIZE = 3
local INNER_SHADOW_ALPHA = 0.5
local INNER_SHADOW_INSET = 2  -- Pixels inset from icon edge so glow stays inside the slot

-- Create the 4-edge inner shadow textures on a button, anchored to an icon texture
local function CreateInnerShadow(button, anchorTo)
    local shadow = {}
    local inset = INNER_SHADOW_INSET
    -- Top edge
    shadow.top = button:CreateTexture(nil, "ARTWORK", nil, 1)
    shadow.top:SetPoint("TOPLEFT", anchorTo, "TOPLEFT", inset, -inset)
    shadow.top:SetPoint("TOPRIGHT", anchorTo, "TOPRIGHT", -inset, -inset)
    shadow.top:SetHeight(INNER_SHADOW_SIZE)
    shadow.top:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    shadow.top:Hide()
    -- Bottom edge
    shadow.bottom = button:CreateTexture(nil, "ARTWORK", nil, 1)
    shadow.bottom:SetPoint("BOTTOMLEFT", anchorTo, "BOTTOMLEFT", inset, inset)
    shadow.bottom:SetPoint("BOTTOMRIGHT", anchorTo, "BOTTOMRIGHT", -inset, inset)
    shadow.bottom:SetHeight(INNER_SHADOW_SIZE)
    shadow.bottom:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    shadow.bottom:Hide()
    -- Left edge
    shadow.left = button:CreateTexture(nil, "ARTWORK", nil, 1)
    shadow.left:SetPoint("TOPLEFT", anchorTo, "TOPLEFT", inset, -inset)
    shadow.left:SetPoint("BOTTOMLEFT", anchorTo, "BOTTOMLEFT", inset, inset)
    shadow.left:SetWidth(INNER_SHADOW_SIZE)
    shadow.left:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    shadow.left:Hide()
    -- Right edge
    shadow.right = button:CreateTexture(nil, "ARTWORK", nil, 1)
    shadow.right:SetPoint("TOPRIGHT", anchorTo, "TOPRIGHT", -inset, -inset)
    shadow.right:SetPoint("BOTTOMRIGHT", anchorTo, "BOTTOMRIGHT", -inset, inset)
    shadow.right:SetWidth(INNER_SHADOW_SIZE)
    shadow.right:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    shadow.right:Hide()
    return shadow
end

-- Show inner shadow with a given quality color
local function ShowInnerShadow(shadow, r, g, b)
    if not shadow then return end
    local a = INNER_SHADOW_ALPHA
    shadow.top:SetGradientAlpha("VERTICAL", r, g, b, 0, r, g, b, a)
    shadow.top:Show()
    shadow.bottom:SetGradientAlpha("VERTICAL", r, g, b, a, r, g, b, 0)
    shadow.bottom:Show()
    shadow.left:SetGradientAlpha("HORIZONTAL", r, g, b, a, r, g, b, 0)
    shadow.left:Show()
    shadow.right:SetGradientAlpha("HORIZONTAL", r, g, b, 0, r, g, b, a)
    shadow.right:Show()
end

-- Hide inner shadow
local function HideInnerShadow(shadow)
    if not shadow then return end
    shadow.top:Hide()
    shadow.bottom:Hide()
    shadow.left:Hide()
    shadow.right:Hide()
end

--=====================================================
-- Quality/Quest Border — rounded backdrop border overlay
-- on top of the icon texture for a clean colored frame
--=====================================================
local QUALITY_BORDER_SIZE = 2      -- Border thickness
local QUALITY_BORDER_PADDING = 1   -- Inset from button edge

local qualityBorderBackdrop = {
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
}

-- Get or create the quality border frame for a button
local function GetQualityBorderFrame(button)
    if button._qualityBorder then return button._qualityBorder end
    local frame = CreateFrame("Frame", nil, button)
    frame:SetFrameLevel(button:GetFrameLevel() + 3)
    local pad = QUALITY_BORDER_PADDING
    frame:SetPoint("TOPLEFT", button, "TOPLEFT", -pad, pad)
    frame:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", pad, -pad)
    frame:SetBackdrop(qualityBorderBackdrop)
    frame:Hide()
    button._qualityBorder = frame
    return frame
end

-- Show quality border with color
local function TintSlotBorder(button, r, g, b)
    local frame = GetQualityBorderFrame(button)
    frame:SetBackdropBorderColor(r, g, b, 1)
    frame:Show()
    button._borderTinted = true
end

-- Hide quality border
local function ResetSlotBorder(button)
    if not button._borderTinted then return end
    if button._qualityBorder then
        button._qualityBorder:Hide()
    end
    button._borderTinted = false
end

--=====================================================
-- Junk Icon Pool (Baganator-inspired memory optimization)
-- Uses frame pooling to avoid creating new frames per button
--=====================================================
local junkIconPool = {}

-- Get a junk icon from pool or create new one
local function AcquireJunkIcon()
    local icon = table.remove(junkIconPool)
    if not icon then
        icon = CreateFrame("Frame", nil, UIParent)
        icon:SetFrameStrata("HIGH")
        icon:SetWidth(14)
        icon:SetHeight(14)

        local texture = icon:CreateTexture(nil, "OVERLAY")
        texture:SetAllPoints(icon)
        texture:SetTexture("Interface\\GossipFrame\\VendorGossipIcon")
        texture:SetTexCoord(0, 1, 0, 1)
        icon.texture = texture
    end
    return icon
end

-- Release a junk icon back to the pool
local function ReleaseJunkIcon(icon)
    if icon then
        icon:Hide()
        icon:ClearAllPoints()
        table.insert(junkIconPool, icon)
    end
end

-- Update junk icon visibility and position (uses pooling)
local function UpdateJunkIcon(button, isJunk, iconSize)
    if isJunk then
        -- Acquire from pool if needed
        if not button.junkIcon then
            button.junkIcon = AcquireJunkIcon()
        end
        -- Scale icon size based on button size
        local junkIconSize = math.max(10, math.min(14, iconSize * 0.30))
        button.junkIcon:SetWidth(junkIconSize)
        button.junkIcon:SetHeight(junkIconSize)
        button.junkIcon:ClearAllPoints()
        button.junkIcon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
        button.junkIcon:SetAlpha(1.0)
        button.junkIcon:Show()
    else
        -- Release back to pool when not needed
        if button.junkIcon then
            ReleaseJunkIcon(button.junkIcon)
            button.junkIcon = nil
        end
    end
end

-- Hide junk icon (releases to pool)
local function HideJunkIcon(button)
    if button.junkIcon then
        ReleaseJunkIcon(button.junkIcon)
        button.junkIcon = nil
    end
end

--=====================================================
-- Lock Icon Pool (same pattern as junk icon pool)
--=====================================================
local lockIconPool = {}

local function AcquireLockIcon()
	local icon = table.remove(lockIconPool)
	if not icon then
		icon = CreateFrame("Frame", nil, UIParent)
		icon:SetFrameStrata("HIGH")
		icon:SetWidth(13)
		icon:SetHeight(13)

		-- Shadow (behind)
		local shadow = icon:CreateTexture(nil, "BACKGROUND")
		shadow:SetWidth(13)
		shadow:SetHeight(13)
		shadow:SetPoint("CENTER", icon, "CENTER", 1, -1)
		shadow:SetTexture("Interface\\AddOns\\Guda\\Assets\\lock_glow")
		shadow:SetVertexColor(0, 0, 0, 1)
		icon.shadow = shadow

		-- Icon (front)
		local texture = icon:CreateTexture(nil, "OVERLAY")
		texture:SetAllPoints(icon)
		texture:SetTexture("Interface\\AddOns\\Guda\\Assets\\lock_glow")
		icon.texture = texture
	end
	return icon
end

local function ReleaseLockIcon(icon)
	if icon then
		icon:Hide()
		icon:ClearAllPoints()
		table.insert(lockIconPool, icon)
	end
end

local function UpdateLockIcon(button, iconSize)
	local DB = addon.Modules.DB
	if not DB then return end

	local isLocked = false
	if button.hasItem and button.itemData and button.itemData.link then
		local Utils = addon.Modules.Utils
		local itemID = Utils and Utils.ExtractItemID and Utils:ExtractItemID(button.itemData.link)
		if itemID and DB:IsItemLocked(itemID) then
			isLocked = true
		end
	end

	if isLocked then
		if not button.lockIcon then
			button.lockIcon = AcquireLockIcon()
		end
		local lockSize = math.max(10, math.min(14, iconSize * 0.35))
		button.lockIcon:SetWidth(lockSize)
		button.lockIcon:SetHeight(lockSize)
		if button.lockIcon.shadow then
			button.lockIcon.shadow:SetWidth(lockSize)
			button.lockIcon.shadow:SetHeight(lockSize)
		end
		button.lockIcon:ClearAllPoints()
		button.lockIcon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
		button.lockIcon:SetFrameLevel(button:GetFrameLevel() + 5)
		button.lockIcon:Show()
	else
		if button.lockIcon then
			ReleaseLockIcon(button.lockIcon)
			button.lockIcon = nil
		end
	end
end

local function HideLockIcon(button)
	if button.lockIcon then
		ReleaseLockIcon(button.lockIcon)
		button.lockIcon = nil
	end
end

-- Hook UseContainerItem to prevent selling protected items at vendor
local OriginalUseContainerItem = UseContainerItem
UseContainerItem = function(bag, slot, ...)
	local DB = addon.Modules.DB
	if DB and MerchantFrame and MerchantFrame:IsVisible() then
		local link = GetContainerItemLink(bag, slot)
		if link then
			local Utils = addon.Modules.Utils
			local itemID = Utils and Utils.ExtractItemID and Utils:ExtractItemID(link)
			if itemID and DB:IsItemProtected(itemID) then
				addon:Print("Cannot sell " .. link .. " — item is protected")
				return
			end
		end
	end
	return OriginalUseContainerItem(bag, slot)
end

-- Track cursor item for delete protection (GetCursorInfo doesn't exist in 1.12.1)
local cursorProtectedLink = nil

local OriginalPickupContainerItem = PickupContainerItem
PickupContainerItem = function(bag, slot, ...)
	local DB = addon.Modules.DB
	if DB then
		local link = GetContainerItemLink(bag, slot)
		if link then
			local Utils = addon.Modules.Utils
			local itemID = Utils and Utils.ExtractItemID and Utils:ExtractItemID(link)
			if itemID and DB:IsItemProtected(itemID) then
				cursorProtectedLink = link
			else
				cursorProtectedLink = nil
			end
		else
			cursorProtectedLink = nil
		end
	end
	return OriginalPickupContainerItem(bag, slot)
end

-- Hook delete confirmation popups
local function HookDeletePopup(dialogName)
	if not StaticPopupDialogs or not StaticPopupDialogs[dialogName] then return end
	local originalOnShow = StaticPopupDialogs[dialogName].OnShow
	StaticPopupDialogs[dialogName].OnShow = function()
		if cursorProtectedLink then
			addon:Print("Cannot delete " .. cursorProtectedLink .. " — item is protected")
			ClearCursor()
			cursorProtectedLink = nil
			this:Hide()
			return
		end
		if originalOnShow then
			return originalOnShow()
		end
	end
end
HookDeletePopup("DELETE_ITEM")
HookDeletePopup("DELETE_GOOD_ITEM")

--=====================================================
-- Unusable item detection (pfUI-inspired implementation)
-- Adds a red tint overlay to items that your character
-- cannot use (class/race/skill restrictions), excluding
-- purely broken durability cases.
--=====================================================
local function Guda_GetUnusableColor()
    if pfUI and C and C.appearance and C.appearance.bags and C.appearance.bags.unusable_color then
        local cr, cg, cb, ca = strsplit(",", C.appearance.bags.unusable_color)
        local r = tonumber(cr) or 0.9
        local g = tonumber(cg) or 0.2
        local b = tonumber(cb) or 0.2
        local a = tonumber(ca) or 1.0
        return r, g, b, a
    end
    -- Then Blizzard's RED_FONT_COLOR if present
    if RED_FONT_COLOR then
        return RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b, 1.0
    end
    -- Default pfUI-like
    return 0.9, 0.2, 0.2, 1.0
end

-- NOTE: IsItemUnusable detection is now handled by ItemDetection:IsUnusable()
-- which uses cached tooltip scanning to avoid duplicate scans per item.
-- The old IsItemUnusable, IsRedColor, and durabilityPattern have been removed
-- to prevent redundant tooltip scanning - all detection is now centralized.

-- Apply/remove red tint on item texture for unusable items
local function Guda_ItemButton_UpdateUsableTint(self)
-- Clear any existing tint/overlay first
	if self.unusableOverlay and self.unusableOverlay.Hide then
		self.unusableOverlay:Hide()
	end
	if SetItemButtonTextureVertexColor then
		SetItemButtonTextureVertexColor(self, 1.0, 1.0, 1.0)
	end

	-- Check if feature is enabled
	local markUnusable = true
	if Guda and Guda.Modules and Guda.Modules.DB then
		markUnusable = Guda.Modules.DB:GetSetting("markUnusableItems")
		if markUnusable == nil then
			markUnusable = true
		end
	end

	-- If feature is disabled, just return after clearing
	if not markUnusable then
		return
	end

	-- Only evaluate for live (player) items; DB cached items from other chars cannot be scanned
	if not self or not self.hasItem or not self.bagID or not self.slotID or self.isReadOnly or self.otherChar then
		return
	end

	-- Use cached detection from ItemDetection module (avoids duplicate tooltip scans)
	local unusable = false
	if self.itemData and addon.Modules.ItemDetection then
		unusable = addon.Modules.ItemDetection:IsUnusable(self.itemData, self.bagID, self.slotID)
	end

	-- Ensure overlay exists (created in OnLoad, but be defensive)
	if not self.unusableOverlay then
		local icon = getglobal(self:GetName().."IconTexture") or getglobal(self:GetName().."Icon") or self.icon or self.Icon
		local overlay = (icon and icon:GetParent() or self):CreateTexture(nil, "OVERLAY")
		overlay:SetAllPoints(icon or self)
		overlay:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
		overlay:Hide()
		self.unusableOverlay = overlay
	end

	if unusable then
		local r, g, b, a = Guda_GetUnusableColor()
		-- Slightly reduce alpha to avoid over-darkening the icon
		local alpha = (a or 1.0) * 0.45
		self.unusableOverlay:SetVertexColor(r or 0.9, g or 0.2, b or 0.2, alpha)
		self.unusableOverlay:Show()
	else
		self.unusableOverlay:Hide()
	end
end


-- Check if a button is available for reuse
-- A button is available if it's either:
-- 1. Hidden (not shown)
-- 2. Marked as not in use (inUse == false) during an update cycle
local function IsButtonAvailable(button)
    if not button:IsShown() then
        return true
    end
    -- During update cycles, buttons are marked inUse = false before display
    -- and inUse = true when assigned. This allows reuse without hiding first.
    if button.inUse == false then
        return true
    end
    return false
end

-- Create or get a button from the pool
function Guda_GetItemButton(parent)
    local reuseCandidate = nil  -- Button from different parent we can reparent

    -- Try to reuse existing button from pool
    for _, button in pairs(buttonPool) do
        -- Skip bag slot buttons
        if not button.isBagSlot and IsButtonAvailable(button) then
            if button:GetParent() == parent then
                -- Same parent - best case, reuse immediately
                -- Mark as in use to prevent double-assignment
                button.inUse = true
                -- Re-register with parent (itemButtons hash may have been cleared)
                if Guda_RegisterItemButton then
                    Guda_RegisterItemButton(parent, button)
                end
                return button
            elseif not reuseCandidate then
                -- Different parent but available - save as candidate for reparenting
                reuseCandidate = button
            end
        end
    end

    -- If we found an available button from a different parent, reparent it
    if reuseCandidate then
        -- Mark as in use
        reuseCandidate.inUse = true

        -- Unregister from old parent
        local oldParent = reuseCandidate:GetParent()
        if oldParent and oldParent.itemButtons then
            oldParent.itemButtons[reuseCandidate] = nil
        end

        -- Reparent to new parent
        reuseCandidate:SetParent(parent)

        -- Register with new parent
        if Guda_RegisterItemButton then
            Guda_RegisterItemButton(parent, reuseCandidate)
        end

        return reuseCandidate
    end

    -- Only create new button if under pool limit
    if nextButtonID <= BUTTON_POOL_MAX then
        local button = CreateFrame("Button", "Guda_ItemButton" .. nextButtonID, parent, "Guda_ItemButtonTemplate")
        buttonPool[nextButtonID] = button
        nextButtonID = nextButtonID + 1
        button.inUse = true

        -- Register button with parent for tracking (avoids GetChildren() allocation)
        if Guda_RegisterItemButton then
            Guda_RegisterItemButton(parent, button)
        end

        return button
    end

    -- Pool is at max and no available button found - this shouldn't normally happen
    -- but as a fallback, force-reuse the first non-bag-slot button we find
    for _, button in pairs(buttonPool) do
        if not button.isBagSlot then
            -- Hide it first (in case it was shown)
            button:Hide()
            button.inUse = true

            -- Unregister from old parent
            local oldParent = button:GetParent()
            if oldParent and oldParent.itemButtons then
                oldParent.itemButtons[button] = nil
            end

            -- Reparent
            button:SetParent(parent)

            -- Register with new parent
            if Guda_RegisterItemButton then
                Guda_RegisterItemButton(parent, button)
            end

            return button
        end
    end

    -- Ultimate fallback (should never reach here) - create one more button
    local button = CreateFrame("Button", "Guda_ItemButton" .. nextButtonID, parent, "Guda_ItemButtonTemplate")
    buttonPool[nextButtonID] = button
    nextButtonID = nextButtonID + 1
    button.inUse = true
    if Guda_RegisterItemButton then
        Guda_RegisterItemButton(parent, button)
    end
    return button
end

-- Update quest icon based on item type (starter vs regular quest item)
local function Guda_ItemButton_UpdateQuestIcon(self, isQuest, isQuestStarter)
	if not self.questIcon then return end

	if isQuest then
	-- Set appropriate texture based on quest type
		if isQuestStarter then
		-- Quest starter: exclamation mark
			local texture = self.questIcon:GetRegions()
			if texture and texture.SetTexture then
				texture:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
				texture:SetTexCoord(0, 1, 0, 1)
			end
		else
		-- Regular quest item: question mark
			local texture = self.questIcon:GetRegions()
			if texture and texture.SetTexture then
				texture:SetTexture("Interface\\GossipFrame\\ActiveQuestIcon")
				texture:SetTexCoord(0, 1, 0, 1)
			end
		end
		self.questIcon:Show()
	else
		self.questIcon:Hide()
	end
end

-- OnLoad handler
function Guda_ItemButton_OnLoad(self)
    self.hasItem = false
    self.bagID = nil
    self.slotID = nil
    self.itemData = nil
    self.isBank = false
    self.otherChar = nil

    -- Create inner shadow for quality color glow (anchored to icon texture)
    if not self.innerShadow then
        local iconTex = getglobal(self:GetName() .. "IconTexture")
        if iconTex then
            self.innerShadow = CreateInnerShadow(self, iconTex)
        end
    end

    -- Create quest icon overlay (exclamation mark in corner)
    if not self.questIcon then
        local iconFrame = CreateFrame("Frame", nil, self)
        iconFrame:SetFrameLevel(self:GetFrameLevel() + 7)  -- Above quest border
        iconFrame:SetWidth(16)
        iconFrame:SetHeight(16)

        local texture = iconFrame:CreateTexture(nil, "OVERLAY")
        texture:SetAllPoints(iconFrame)
        texture:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
        texture:SetTexCoord(0, 1, 0, 1)

        iconFrame:Hide()
        self.questIcon = iconFrame
    end

    -- Note: Junk icon is acquired from pool on-demand in UpdateJunkIcon, not pre-created

    -- Ensure the item button sits above its container backdrop and is mouse-enabled
    local parent = self:GetParent()
    if parent and parent.GetFrameLevel then
        -- Place button above parent backdrop/mouse layer to reliably receive drops
        local parentLevel = parent:GetFrameLevel()
        if parentLevel and self:GetFrameLevel() <= parentLevel + 1 then
            self:SetFrameLevel(parentLevel + 2)
        end
    end

    -- Enable mouse and register for drag/drop (crucial for Classic/Vanilla WoW)
    if self.EnableMouse then
        self:EnableMouse(true)
    end
    if self.RegisterForDrag then
        self:RegisterForDrag("LeftButton")
    end
    if self.RegisterForClicks then
        self:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    end

    -- Hide junk and lock icons when button is hidden (since they're parented to UIParent)
    self:SetScript("OnHide", function()
        HideJunkIcon(this)
        HideLockIcon(this)
    end)

    -- Track cursor item on drag start for category drag-drop
    self:SetScript("OnDragStart", function()
        if this.hasItem and this.bagID and this.slotID and not this.otherChar and not this.isReadOnly then
            Guda_TrackCursorItem(this.bagID, this.slotID)
            PickupContainerItem(this.bagID, this.slotID)
        end
    end)

    self:SetScript("OnClick", function()
        -- Lock/unlock item with Ctrl+Right-Click
        if IsControlKeyDown() and arg1 == "RightButton" and this.hasItem and not this.otherChar and not this.isReadOnly then
            local link = GetContainerItemLink(this.bagID, this.slotID)
            if link and addon and addon.Modules and addon.Modules.Utils and addon.Modules.DB then
                local itemID = addon.Modules.Utils:ExtractItemID(link)
                if itemID then
                    -- Skip if already protected by equipment set
                    if addon.Modules.DB:GetSetting("autoLockSetItems") then
                        local EquipSets = addon.Modules.EquipmentSets
                        if EquipSets and EquipSets.IsInSet and EquipSets:IsInSet(itemID) then
                            addon:Print(link .. " is already protected by equipment set")
                            return
                        end
                    end
                    local isNowLocked = addon.Modules.DB:ToggleItemLock(itemID)
                    if isNowLocked then
                        addon:Print(link .. " locked")
                    else
                        addon:Print(link .. " unlocked")
                    end
                    -- Refresh bag/bank frames
                    if addon.Modules.BagFrame and addon.Modules.BagFrame.Update then
                        addon.Modules.BagFrame:Update()
                    end
                    if addon.Modules.BankFrame and addon.Modules.BankFrame.Update then
                        addon.Modules.BankFrame:Update()
                    end
                end
            end
            return
        end

        if IsAltKeyDown() and arg1 == "LeftButton" and this.hasItem and not this.otherChar and not this.isReadOnly then
            local link = GetContainerItemLink(this.bagID, this.slotID)
            if link and addon and addon.Modules and addon.Modules.Utils then
                local itemID = addon.Modules.Utils:ExtractItemID(link)
                if itemID then
                    local isQuest = IsQuestItem(this.bagID, this.slotID, this.isBank, this.itemData)
                    local isUnique = addon.Modules.Utils:IsUniqueItem(this.bagID, this.slotID, link)

                    -- Only pin to QuestItemBar if it's a unique quest item
                    if isQuest and isUnique and addon.Modules.QuestItemBar and addon.Modules.QuestItemBar.PinItem then
                        addon.Modules.QuestItemBar:PinItem(itemID)
                        return
                    end

                    -- Track non-unique quest items and regular items in TrackedItemBar
                    local trackedItems = addon.Modules.DB:GetSetting("trackedItems") or {}
                    if trackedItems[itemID] then
                        trackedItems[itemID] = nil
                    else
                        trackedItems[itemID] = true
                    end
                    addon.Modules.DB:SetSetting("trackedItems", trackedItems)

                    -- Update all item buttons
                    if Guda.Modules.BagFrame and Guda.Modules.BagFrame.Update then
                        Guda.Modules.BagFrame:Update()
                    end
                    if Guda.Modules.BankFrame and Guda.Modules.BankFrame.Update then
                        Guda.Modules.BankFrame:Update()
                    end
                    if Guda.Modules.TrackedItemBar and Guda.Modules.TrackedItemBar.Update then
                        Guda.Modules.TrackedItemBar:Update()
                    end
                    return
                end
            end
        end
        
        -- Shift-click to link cached items to chat (remote bank, read-only, or closed bank)
        if IsShiftKeyDown() and arg1 == "LeftButton" and this.hasItem then
            if this.otherChar or this.isReadOnly or (this.isBank and this.bagID == -1 and not (getglobal("BankFrame") and getglobal("BankFrame"):IsVisible())) then
                local link = this.itemData and this.itemData.link
                if link and ChatFrameEditBox and ChatFrameEditBox:IsVisible() then
                    ChatFrameEditBox:Insert(link)
                    return
                end
            end
        end

        -- Default behavior
        if ContainerFrameItemButton_OnClick then
            -- Mailbox clicks should be ignored except for Ctrl+Click (preview)
            -- OR if it's a live mail item for the current player and Shift+Click (loot)
            if this.isMail then
                if IsControlKeyDown() then
                    ContainerFrameItemButton_OnClick(arg1)
                end
                return
            end

            -- Track cursor item before pickup for category drag-drop
            if this.hasItem and this.bagID and this.slotID and not CursorHasItem() then
                Guda_TrackCursorItem(this.bagID, this.slotID)
            end

            ContainerFrameItemButton_OnClick(arg1)

            -- Clear cursor tracking if item was placed (cursor no longer has item)
            if not CursorHasItem() then
                Guda_ClearCursorItem()
            end
        end
    end)

    -- OnReceiveDrag: category reassignment in category view
    self:SetScript("OnReceiveDrag", function()
        local info = Guda_GetCursorItemInfo()
        if not info then return end

        local inCatView = IsInCategoryView(this.isBank)
        if not inCatView then
            -- Single view: let default swap happen
            if ContainerFrameItemButton_OnClick then
                ContainerFrameItemButton_OnClick("LeftButton")
            end
            return
        end

        -- Category view: reassign dragged item to target item's category
        if this.hasItem and this.itemData and addon.Modules.CategoryManager then
            local targetCategory = addon.Modules.CategoryManager:CategorizeItem(this.itemData, this.bagID, this.slotID, this.otherChar)
            if targetCategory and info.itemID then
                addon.Modules.CategoryManager:AssignItemToCategory(info.itemID, targetCategory)
                addon:Debug("Reassigned item %d to category: %s", info.itemID, targetCategory)
            end
        end

        -- Put dragged item back in its original slot
        if CursorHasItem() then
            PickupContainerItem(info.bagID, info.slotID)
        end

        -- Set drop cooldown to prevent immediate re-show
        dropCooldownTime = GetTime() + 0.3
        HideCategoryDropIndicator()
        Guda_ClearCursorItem()

        -- Refresh frames
        if addon.Modules.BagFrame and addon.Modules.BagFrame.Update then
            addon.Modules.BagFrame:Update()
        end
        if addon.Modules.BankFrame and addon.Modules.BankFrame.Update then
            local bankFrame = getglobal("Guda_BankFrame")
            if bankFrame and bankFrame:IsShown() then
                addon.Modules.BankFrame:Update()
            end
        end
    end)
end

-- Update the Blizzard cooldown overlay on this item button
function Guda_ItemButton_UpdateCooldown(self)
    -- Only show cooldowns for live items of the current character
    if not self then return end

    local cooldown = getglobal(self:GetName().."Cooldown") or self.cooldown
    if not cooldown then return end

    -- Ensure cooldown overlay is NOT shown for read-only or other-character views
    if self.isReadOnly or self.otherChar then
        -- Clear any previous timer state and hide to avoid carry-over from pooled buttons
        if CooldownFrame_SetTimer then
            CooldownFrame_SetTimer(cooldown, 0, 0, 0)
        elseif CooldownFrame_Set then
            CooldownFrame_Set(cooldown, 0, 0, 0)
        end
        cooldown:Hide()
        return
    end

    if not self.hasItem or not self.bagID or not self.slotID then
        cooldown:Hide()
        return
    end

    local start, duration, enable = GetContainerItemCooldown(self.bagID, self.slotID)
    if start and duration and duration > 0 and enable == 1 then
        if CooldownFrame_SetTimer then
            CooldownFrame_SetTimer(cooldown, start, duration, enable)
        elseif CooldownFrame_Set then
            -- Some clients expose CooldownFrame_Set instead
            CooldownFrame_Set(cooldown, start, duration, enable)
        else
            -- Fallback: show the frame if API missing
            cooldown:Show()
        end
    else
        cooldown:Hide()
    end
end

--=====================================================
-- Helper functions for SetItem (extracted for clarity)
--=====================================================

-- Reset all visual state on a button (for reuse from pool)
local function ResetButtonVisualState(self)
    if self.questIcon then self.questIcon:Hide() end
    ResetSlotBorder(self)
    HideInnerShadow(self.innerShadow)
    if self.unusableOverlay then self.unusableOverlay:Hide() end
    HideJunkIcon(self)
    if self.categoryMarkIcon then self.categoryMarkIcon:Hide() end

    -- Clear cooldown overlay
    local cd = getglobal(self:GetName().."Cooldown") or self.cooldown
    if cd then
        if CooldownFrame_SetTimer then
            CooldownFrame_SetTimer(cd, 0, 0, 0)
        elseif CooldownFrame_Set then
            CooldownFrame_Set(cd, 0, 0, 0)
        end
        if cd.Hide then cd:Hide() end
    end
end

-- Configure drag/drop registration based on read-only state
local function SetupDragDrop(self)
    if not self.isReadOnly and not self.otherChar then
        if self.RegisterForDrag then
            self:RegisterForDrag("LeftButton")
        end
        if self.RegisterForClicks then
            self:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        end
        if self.EnableMouse then
            self:EnableMouse(true)
        end
    else
        -- Disable drag for read-only or other character items
        if self.RegisterForDrag then
            self:RegisterForDrag()  -- Clear drag registration
        end
        if self.EnableMouse then
            self:EnableMouse(true)  -- Still enable mouse for tooltips
        end
    end
end

-- Get display texture and count for an item slot
-- Returns: texture, count, hasItem (boolean)
local function GetItemDisplayInfo(bagID, slotID, itemData, isReadOnly)
    local displayTexture, displayCount
    local hasItem = false

    if not isReadOnly then
        -- LIVE MODE: Query game state directly
        local liveTexture, liveCount = GetContainerItemInfo(bagID, slotID)
        if liveTexture then
            displayTexture = liveTexture
            displayCount = liveCount
            hasItem = true
        elseif bagID == -2 then
            -- Fallback for keyring in 1.12.1
            local link = GetContainerItemLink(bagID, slotID)
            if link then
                hasItem = true
                local _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(link)
                displayTexture = itemTexture
                displayCount = 1
            end
        end
    else
        -- READ-ONLY MODE: Use cached itemData
        if itemData and itemData.texture then
            displayTexture = itemData.texture
            displayCount = itemData.count
            hasItem = true
        end
    end

    return displayTexture, displayCount, hasItem
end

-- Update the tracking checkmark on an item button
local function UpdateTrackingCheckmark(self, Utils)
    local check = getglobal(self:GetName().."_Check")
    if not check then return end

    local isTracked = false
    if self.hasItem and self.itemData and self.itemData.link then
        local itemID = Utils and Utils.ExtractItemID and Utils:ExtractItemID(self.itemData.link)
        if itemID then
            local trackedItems = Utils and Utils.SafeCall and Utils:SafeCall("DB", "GetSetting", "trackedItems") or {}
            if trackedItems[itemID] then
                isTracked = true
            end
        end
    end

    if isTracked then
        check:Show()
    else
        check:Hide()
    end
end

-- Resize empty slot background to match icon size
local function UpdateEmptySlotBackground(self, emptySlotBg, iconSize)
    if not emptySlotBg then return end

    -- Extend 9px past button edges so the rounded corners of UI-EmptySlot
    -- cover the square corners of the icon texture (same as GudaBags)
    emptySlotBg:ClearAllPoints()
    emptySlotBg:SetPoint("TOPLEFT", self, "TOPLEFT", -9, 9)
    emptySlotBg:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 9, -9)
    emptySlotBg:SetTexCoord(0, 1, 0, 1)
end

-- Resize texture elements to match button size
local function ResizeTextureElements(self, iconSize)
    -- Pushed texture
    local pushedTexture = getglobal(self:GetName().."PushedTexture")
    if not pushedTexture and self.GetPushedTexture then
        pushedTexture = self:GetPushedTexture()
    end
    if pushedTexture then
        pushedTexture:ClearAllPoints()
        pushedTexture:SetPoint("CENTER", self, "CENTER", 0, 0)
        pushedTexture:SetWidth(iconSize)
        pushedTexture:SetHeight(iconSize)
    end

    -- Highlight texture
    local highlightTexture = getglobal(self:GetName().."HighlightTexture")
    if not highlightTexture and self.GetHighlightTexture then
        highlightTexture = self:GetHighlightTexture()
    end
    if highlightTexture then
        highlightTexture:ClearAllPoints()
        highlightTexture:SetPoint("CENTER", self, "CENTER", 0, 0)
        highlightTexture:SetWidth(iconSize)
        highlightTexture:SetHeight(iconSize)
    end

    -- Checked texture
    local checkedTexture = getglobal(self:GetName().."CheckedTexture")
    if not checkedTexture and self.GetCheckedTexture then
        checkedTexture = self:GetCheckedTexture()
    end
    if checkedTexture then
        checkedTexture:ClearAllPoints()
        checkedTexture:SetPoint("CENTER", self, "CENTER", 0, 0)
        checkedTexture:SetWidth(iconSize)
        checkedTexture:SetHeight(iconSize)
    end
end

-- Position icon and borders based on icon size
local function PositionIconAndBorders(self, iconSize)
    local iconTexture = getglobal(self:GetName().."IconTexture")
    if not iconTexture then
        iconTexture = getglobal(self:GetName().."Icon") or self.icon or self.Icon
    end

    if not iconTexture or not self.hasItem then return end

    -- Icon fills the full button slot
    local iconDisplaySize = iconSize

    iconTexture:ClearAllPoints()
    iconTexture:SetPoint("CENTER", self, "CENTER", 0, 0)
    iconTexture:SetWidth(iconDisplaySize)
    iconTexture:SetHeight(iconDisplaySize)
    iconTexture:SetTexCoord(0, 1, 0, 1)
    iconTexture:Show()

    -- Position quest icon in top-right corner
    if self.questIcon then
        local questIconSize = math.max(12, math.min(20, iconSize * 0.35))
        self.questIcon:SetWidth(questIconSize)
        self.questIcon:SetHeight(questIconSize)
        self.questIcon:ClearAllPoints()
        self.questIcon:SetPoint("TOPRIGHT", self, "TOPRIGHT", 1, 0)
    end
end

-- Update quality border display (tints the EmptySlotBg)
local function UpdateQualityBorder(self, itemQuality, itemLink, bagID, Utils)
    if not itemQuality then
        ResetSlotBorder(self)
        HideInnerShadow(self.innerShadow)
        return
    end

    -- Check settings
    local showEquipmentBorder, showOtherBorder
    if Utils and Utils.SafeCall then
        showEquipmentBorder = Utils:SafeCall("DB", "GetSetting", "showQualityBorderEquipment")
        showOtherBorder = Utils:SafeCall("DB", "GetSetting", "showQualityBorderOther")
    end

    if showEquipmentBorder == nil then showEquipmentBorder = true end
    if showOtherBorder == nil then showOtherBorder = true end

    -- Check if item is equipment
    local isEquipment = false
    if itemLink and Utils and Utils.IsEquipment then
        isEquipment = Utils:IsEquipment(itemLink)
    end

    local shouldShowBorder = (isEquipment and showEquipmentBorder) or (not isEquipment and showOtherBorder)

    if shouldShowBorder then
        -- Use the item link's title color directly (matches what the player sees)
        local r, g, b
        if itemLink and Utils and Utils.GetLinkColor then
            r, g, b = Utils:GetLinkColor(itemLink)
        end
        if not r then
            -- Fallback to quality-based color
            if Utils and Utils.GetQualityColor then
                r, g, b = Utils:GetQualityColor(itemQuality)
            else
                r, g, b = 1, 1, 1
            end
        end
        TintSlotBorder(self, r, g, b)
        -- Only show inner shadow for colored borders, not white (poor/common quality)
        if r < 0.95 or g < 0.95 or b < 0.95 then
            ShowInnerShadow(self.innerShadow, r, g, b)
        else
            HideInnerShadow(self.innerShadow)
        end
    else
        ResetSlotBorder(self)
        HideInnerShadow(self.innerShadow)
    end
end

-- Clear item button for empty slot
local function ClearItemButton(self, emptySlotBg, countText, bagID)
    self.hasItem = false

    if SetItemButtonTexture then SetItemButtonTexture(self, nil) end
    if SetItemButtonCount then SetItemButtonCount(self, 0) end
    if SetItemButtonDesaturated then SetItemButtonDesaturated(self, false) end

    -- Clear cooldown overlay
    local cooldown = getglobal(self:GetName().."Cooldown") or self.cooldown
    if cooldown and cooldown.Hide then cooldown:Hide() end

    -- Clear icon texture
    local iconTexture = getglobal(self:GetName().."IconTexture")
    if not iconTexture then
        iconTexture = getglobal(self:GetName().."Icon") or self.icon or self.Icon
    end
    if iconTexture then
        iconTexture:SetTexture(nil)
        iconTexture:Hide()
    end

    -- Clear unusable tint
    if SetItemButtonTextureVertexColor then
        SetItemButtonTextureVertexColor(self, 1.0, 1.0, 1.0)
    end
    if self.unusableOverlay and self.unusableOverlay.Hide then
        self.unusableOverlay:Hide()
    end

    -- Hide junk icon
    HideJunkIcon(self)

    -- Hide lock icon
    HideLockIcon(self)

    -- Hide normal texture
    self:SetNormalTexture("")
    local normalBorder = getglobal(self:GetName().."NormalTexture")
    if normalBorder then normalBorder:SetTexture("") end

    -- Show/hide empty slot background
    if emptySlotBg then
        local slotAlpha = 0.5
        if addon.Modules and addon.Modules.Theme then
            local sa = addon.Modules.Theme:GetValue("slotBgAlpha")
            if sa then slotAlpha = sa.empty end
        end
        if slotAlpha > 0 then
            emptySlotBg:Show()
            emptySlotBg:SetAlpha(slotAlpha)
        else
            emptySlotBg:Hide()
        end
    end

    if countText then countText:Hide() end

    ResetSlotBorder(self)
    HideInnerShadow(self.innerShadow)

    -- Hide quest elements
    if self.questIcon then self.questIcon:Hide() end
end

--=====================================================
-- Main SetItem function (orchestrates helper functions)
--=====================================================

-- Set item data
function Guda_ItemButton_SetItem(self, bagID, slotID, itemData, isBank, otherCharName, matchesFilter, isReadOnly)
    -- Proactively convert to number to avoid comparisons with strings in downstream functions
    bagID = tonumber(bagID)
    slotID = tonumber(slotID)

    -- Reset all visual state before reassigning pooled button
    ResetButtonVisualState(self)

    -- Set button properties
    self.bagID = bagID
    self.slotID = slotID
    if self.SetID then
        self:SetID(slotID or 0)
    end
    self.bagIndex = bagID or -100
    self.itemData = itemData
    self.isBank = isBank or false
    self.otherChar = otherCharName
    self.isReadOnly = isReadOnly or false
    self.isMail = false
    self.mailIndex = nil
    self.mailItemIndex = nil
    self.mailData = nil

    -- Configure drag/drop
    SetupDragDrop(self)

    -- Default to true if not specified
    if matchesFilter == nil then
        matchesFilter = true
    end

    -- Get UI elements
    local countText = getglobal(self:GetName().."Count")
    local emptySlotBg = getglobal(self:GetName().."_EmptySlotBg")
    local Utils = addon and addon.Modules and addon.Modules.Utils

    -- Get icon size setting
    local iconSize = 37
    if Utils and Utils.SafeCall then
        iconSize = Utils:SafeCall("DB", "GetSetting", "iconSize") or iconSize
    end
    if addon and addon.Constants then
        iconSize = iconSize or addon.Constants.BUTTON_SIZE
    end
    self:SetWidth(iconSize)
    self:SetHeight(iconSize)

    -- Get item display info (texture, count, hasItem)
    local displayTexture, displayCount, hasItem = GetItemDisplayInfo(bagID, slotID, itemData, self.isReadOnly)
    self.hasItem = hasItem

    -- Apply display based on whether slot has item
    if self.hasItem then
        -- Set texture
        if SetItemButtonTexture then
            SetItemButtonTexture(self, displayTexture)
        end
        local iconTexture = getglobal(self:GetName().."IconTexture") or getglobal(self:GetName().."Icon") or self.icon or self.Icon
        if iconTexture and displayTexture then
            iconTexture:SetTexture(displayTexture)
            iconTexture:Show()
        end

        -- Set count
        if SetItemButtonCount then SetItemButtonCount(self, displayCount or 1) end

        -- Update cooldown overlay for live items
        if not self.isReadOnly and not self.otherChar and Guda_ItemButton_UpdateCooldown then
            Guda_ItemButton_UpdateCooldown(self)
        else
            local cd = getglobal(self:GetName().."Cooldown") or self.cooldown
            if cd and cd.Hide then cd:Hide() end
        end

        -- Update unusable red overlay tint
        if Guda_ItemButton_UpdateUsableTint then
            Guda_ItemButton_UpdateUsableTint(self)
        end
    else
        -- Clear empty slot
        ClearItemButton(self, emptySlotBg, countText, bagID)
    end

    -- Update tracking checkmark
    UpdateTrackingCheckmark(self, Utils)
    local check = getglobal(self:GetName().."_Check")
    if check then
        local isTracked = false
        if self.hasItem and self.itemData and self.itemData.link then
            local itemID = Utils and Utils.ExtractItemID and Utils:ExtractItemID(self.itemData.link)
            if itemID then
                local trackedItems = Utils and Utils.SafeCall and Utils:SafeCall("DB", "GetSetting", "trackedItems") or {}
                if trackedItems[itemID] then
                    isTracked = true
                end
            end
        end
        
        if isTracked then
            check:Show()
        else
            check:Hide()
        end
    end

    -- Update lock icon
    UpdateLockIcon(self, iconSize)

    -- Extend empty slot bg 9px past button edges for rounded corner coverage
    if emptySlotBg then
        emptySlotBg:ClearAllPoints()
        emptySlotBg:SetPoint("TOPLEFT", self, "TOPLEFT", -9, 9)
        emptySlotBg:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 9, -9)
        emptySlotBg:SetTexCoord(0, 1, 0, 1)
    end

    -- Also resize the underlying slot textures so the border/background scale with the button.
    -- On 1.12/Turtle, ItemButtonTemplate uses fixed-size textures, so we explicitly size them
    -- to match the current iconSize instead of letting them use their default dimensions.

    -- For 1.12.1 compatibility, access textures using both methods and proper naming
    -- We'll set the NormalTexture later based on whether slot is empty or filled

    -- ICON TEXTURE: Ensure we use the correct name ($parentIconTexture is standard)
    local iconTexture = getglobal(self:GetName().."IconTexture") or getglobal(self:GetName().."Icon") or self.icon or self.Icon

    -- Pushed texture follows the button size/position
    local pushedTexture = getglobal(self:GetName().."PushedTexture")
    if not pushedTexture and self.GetPushedTexture then
        pushedTexture = self:GetPushedTexture()
    end
    if pushedTexture then
        pushedTexture:ClearAllPoints()
        pushedTexture:SetPoint("CENTER", self, "CENTER", 0, 0)
        pushedTexture:SetWidth(iconSize)
        pushedTexture:SetHeight(iconSize)
    end

    -- Highlight texture for mouseover (not used for search)
    local highlightTexture = getglobal(self:GetName().."HighlightTexture")
    if not highlightTexture and self.GetHighlightTexture then
        highlightTexture = self:GetHighlightTexture()
    end
    if highlightTexture then
        highlightTexture:ClearAllPoints()
        highlightTexture:SetPoint("CENTER", self, "CENTER", 0, 0)
        highlightTexture:SetWidth(iconSize)
        highlightTexture:SetHeight(iconSize)
    end

    -- Checked texture (centered square pattern when slot is "active")
    local checkedTexture = getglobal(self:GetName().."CheckedTexture")
    if not checkedTexture and self.GetCheckedTexture then
        checkedTexture = self:GetCheckedTexture()
    end
    if checkedTexture then
        checkedTexture:ClearAllPoints()
        checkedTexture:SetPoint("CENTER", self, "CENTER", 0, 0)
        checkedTexture:SetWidth(iconSize)
        checkedTexture:SetHeight(iconSize)
    end


    -- Apply icon font size setting to stack count text
    if countText and countText.GetFont then
        local font, _, flags = countText:GetFont()
        local fontSize = 12
        if Utils and Utils.SafeCall then
            fontSize = Utils:SafeCall("DB", "GetSetting", "iconFontSize") or fontSize
        end
        countText:SetFont(font, fontSize, flags)

        -- Adjust count text position based on icon size for better alignment
        countText:ClearAllPoints()
        if iconSize < 44 then
            -- Smaller offset for small icons
            countText:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -1, 1)
        else
            -- Standard offset for larger icons
            countText:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -3, 3)
        end
    end

    -- Get live metadata if in live mode (quality, link, lock status)
    local itemQuality, itemLink, isLocked
    if not self.isReadOnly and bagID and slotID and self.hasItem then
        -- Query live game state for metadata
        -- Special handling for bank main bag (bagID == -1) which uses inventory slot API
        if self.isBank and bagID == -1 then
            local invSlot = 39 + slotID
            itemLink = GetInventoryItemLink("player", invSlot)
            isLocked = IsInventoryItemLocked(invSlot)
            -- Quality will be determined from GetItemInfo below
        else
            local _, _, locked, quality = GetContainerItemInfo(bagID, slotID)
            itemLink = GetContainerItemLink(bagID, slotID)
            itemQuality = quality
            isLocked = locked
        end

        -- Fall back to itemData.quality if live query returned nil (timing issue on bank open)
        if itemQuality == nil and itemData and itemData.quality then
            itemQuality = itemData.quality
        end

        -- Ensure itemData is populated for live items (needed for ItemDetection)
        if itemLink then
            local itemName, _, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(itemLink)
            -- Always prefer GetItemInfo quality — GetContainerItemInfo often
            -- returns wrong quality (e.g. 1/white) for epic tokens in TurtleWoW 1.12
            if itemRarity then
                itemQuality = itemRarity
            end
            if itemQuality == nil and itemData and itemData.quality then
                itemQuality = itemData.quality
            end
            if not itemData then
                -- Create new itemData
                if itemName then
                    itemData = {
                        link = itemLink,
                        name = itemName,
                        quality = itemRarity or itemQuality or 0,
                        class = itemType,
                        subclass = itemSubType,
                        texture = itemTexture,
                        count = 1,
                    }
                    self.itemData = itemData
                end
            else
                -- ALWAYS update itemData.link with live link to ensure correct detection after swaps
                -- This is critical: cached itemData might have stale link from before a swap
                itemData.link = itemLink
                -- Update other fields only if missing
                if itemData.quality == nil then itemData.quality = itemRarity or itemQuality or 0 end
                if not itemData.class and itemType then itemData.class = itemType end
                if not itemData.subclass and itemSubType then itemData.subclass = itemSubType end
                if not itemData.name and itemName then itemData.name = itemName end
                self.itemData = itemData
            end
        end
    elseif itemData then
        -- Use cached metadata from database
        itemQuality = itemData.quality
        itemLink = itemData.link
        isLocked = itemData.locked
    end

    if self.hasItem then
        -- Icon already set above based on mode (live vs cached)

        -- Gray out locked items (being traded, mailed, or auctioned) - BagShui style
        -- Don't desaturate items from other characters since they're read-only anyway
        if not self.otherChar and not self.isReadOnly then
            SetItemButtonDesaturated(self, isLocked, 0.5, 0.5, 0.5)
        end

        -- Hide NormalTexture for filled slots
        self:SetNormalTexture("")
        local normalBorder = getglobal(self:GetName().."NormalTexture")
        if normalBorder then
            normalBorder:SetTexture("")
        end

        -- Always show slot background so rounded corners cover the icon
        if emptySlotBg then
            emptySlotBg:Show()
            emptySlotBg:SetAlpha(1)
        end

        -- Check if item is junk and get category mark using the CategoryManager
        local isJunk = false
        local categoryMarkTexture = nil
        if itemData and addon.Modules.CategoryManager then
            local category = addon.Modules.CategoryManager:CategorizeItem(itemData, bagID, slotID, self.otherChar)
            isJunk = (category == "Junk")
            -- Get category mark icon if set
            local catDef = addon.Modules.CategoryManager:GetCategory(category)
            if catDef and catDef.categoryMark then
                categoryMarkTexture = catDef.categoryMark
            end
        end

        -- Update category mark overlay (bottom-left of icon texture)
        if categoryMarkTexture then
            local iconTex = getglobal(self:GetName().."IconTexture") or getglobal(self:GetName().."Icon") or self.icon or self.Icon
            local anchor = iconTex or self
            if not self.categoryMarkIcon then
                self.categoryMarkIcon = self:CreateTexture(nil, "OVERLAY", 7)
            end
            local markSize = math.max(10, math.floor(iconSize * 0.3)) + 3
            self.categoryMarkIcon:SetWidth(markSize)
            self.categoryMarkIcon:SetHeight(markSize)
            self.categoryMarkIcon:ClearAllPoints()
            self.categoryMarkIcon:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 2, 2)
            self.categoryMarkIcon:SetTexture(categoryMarkTexture)
            self.categoryMarkIcon:SetVertexColor(1, 1, 1, 1)
            self.categoryMarkIcon:SetAlpha(1)
            self.categoryMarkIcon:Show()
        else
            if self.categoryMarkIcon then self.categoryMarkIcon:Hide() end
        end

        -- Search filtering and junk opacity
        if matchesFilter then
            if isJunk then
                -- Junk items: configurable opacity (default 60%)
                local junkOpacity = 0.6
                if addon.Modules.DB and addon.Modules.DB.GetSetting then
                    junkOpacity = addon.Modules.DB:GetSetting("junkOpacity") or 0.6
                end
                self:SetAlpha(junkOpacity)
            else
                -- Normal items: full opacity (1.0)
                self:SetAlpha(1.0)
            end
        else
            -- Non-matching items: 25% opacity (0.25) - very dim
            self:SetAlpha(0.25)
        end

        -- Show/hide junk icon (vendor sell icon in top-left corner)
        UpdateJunkIcon(self, isJunk, iconSize)

        -- Set count (use displayCount which was determined above based on mode)
        if displayCount and displayCount > 1 then
            countText:SetText(displayCount)
            countText:Show()
        else
            countText:Hide()
        end

        -- Set quality border (tint slot bg) and inner shadow
        do
            local borderApplied = false
            if itemQuality then
                -- Check settings to determine if we should show borders
                local showEquipmentBorder, showOtherBorder
                if Utils and Utils.SafeCall then
                    showEquipmentBorder = Utils:SafeCall("DB", "GetSetting", "showQualityBorderEquipment")
                    showOtherBorder = Utils:SafeCall("DB", "GetSetting", "showQualityBorderOther")
                end

                if showEquipmentBorder == nil then showEquipmentBorder = true end
                if showOtherBorder == nil then showOtherBorder = true end

                -- Check if item is equipment
                local isEquipment = false
                if itemLink and Utils and Utils.IsEquipment then
                    isEquipment = Utils:IsEquipment(itemLink)
                end

                local shouldShowBorder = (isEquipment and showEquipmentBorder) or (not isEquipment and showOtherBorder)

                if shouldShowBorder then
                    local r, g, b
                    if itemLink and Utils and Utils.GetLinkColor then
                        r, g, b = Utils:GetLinkColor(itemLink)
                    end
                    if not r then
                        if Utils and Utils.GetQualityColor then
                            r, g, b = Utils:GetQualityColor(itemQuality)
                        else
                            r, g, b = 1, 1, 1
                        end
                    end
                    TintSlotBorder(self, r, g, b)
                    -- Only show inner shadow for colored borders, not white
                    if r < 0.95 or g < 0.95 or b < 0.95 then
                        ShowInnerShadow(self.innerShadow, r, g, b)
                    else
                        HideInnerShadow(self.innerShadow)
                    end
                    borderApplied = true
                end
            end

            -- Quest items override with golden border
            if not self.otherChar and not self.isReadOnly then
                local isQuest, isQuestStarter = IsQuestItem(bagID, slotID, self.isBank, itemData)
                Guda_ItemButton_UpdateQuestIcon(self, isQuest, isQuestStarter)
                if isQuest then
                    TintSlotBorder(self, 1.0, 0.82, 0)
                    ShowInnerShadow(self.innerShadow, 1.0, 0.82, 0)
                    borderApplied = true
                end
                if self.questIcon then
                    if isQuest then
                        self.questIcon:Show()
                    else
                        self.questIcon:Hide()
                    end
                end
            end

            if not borderApplied then
                ResetSlotBorder(self)
                HideInnerShadow(self.innerShadow)
            end
		end

        -- Handle tracking toggle on click
        -- Note: Tracking toggle is now handled in the main OnClick script above to avoid conflicts
        -- and unified with QuestItemBar pinning logic.

        self:Show()
    else
        self.hasItem = false
        -- For empty slots, clear the icon texture
        SetItemButtonTexture(self, nil)

        -- Hide NormalTexture for empty slots (we use EmptySlotBg instead)
        self:SetNormalTexture("")
        local normalBorder = getglobal(self:GetName().."NormalTexture")
        if normalBorder then
            normalBorder:SetTexture("")
        end

        -- Show classic bag pattern background for empty slots
        if emptySlotBg then
            local slotAlpha = 0.5
            if addon.Modules and addon.Modules.Theme then
                local sa = addon.Modules.Theme:GetValue("slotBgAlpha")
                if sa then slotAlpha = sa.empty end
            end
            if slotAlpha > 0 then
                emptySlotBg:Show()
                emptySlotBg:SetAlpha(slotAlpha)
            else
                emptySlotBg:Hide()
            end
        end

        -- Dim empty slots when searching
        if matchesFilter then
            -- No search active or passes filter: normal opacity
            self:SetAlpha(1.0)
        else
            -- Search active and doesn't match: very dim
            self:SetAlpha(0.25)
        end

        countText:Hide()

        -- Reset slot border and hide inner shadow for empty slots
        ResetSlotBorder(self)
        HideInnerShadow(self.innerShadow)

        -- Hide quest icon for empty slots
        if self.questIcon then
            self.questIcon:Hide()
        end

        self:Show()
    end

    -- In 1.12.1, ItemButtonTemplate creates an icon named "$parentIconTexture"
    local iconTexture = getglobal(self:GetName().."IconTexture")
    if not iconTexture then
        -- Fallback for other naming conventions
        iconTexture = getglobal(self:GetName().."Icon") or self.icon or self.Icon
    end

    if iconTexture then
        if self.hasItem then
            -- Icon fills the full button slot
            local iconDisplaySize = iconSize
            iconTexture:ClearAllPoints()
            iconTexture:SetPoint("CENTER", self, "CENTER", 0, 0)
            iconTexture:SetWidth(iconDisplaySize)
            iconTexture:SetHeight(iconDisplaySize)
            -- Crop icon edges slightly
            iconTexture:SetTexCoord(0, 1, 0, 1)
            iconTexture:Show()

            -- Position quest icon in top-right corner
            if self.questIcon then
                -- Scale icon size based on button size
                local questIconSize = math.max(12, math.min(20, iconSize * 0.35))
                self.questIcon:SetWidth(questIconSize)
                self.questIcon:SetHeight(questIconSize)

                self.questIcon:ClearAllPoints()
                self.questIcon:SetPoint("TOPRIGHT", self, "TOPRIGHT", 1, 0)
            end
        elseif not self.isMail then
            -- Hide icon for empty slots, but keep it for mailbox custom icons
            iconTexture:Hide()
        end
    end
end

-- OnEnter handler (show tooltip)
function Guda_ItemButton_OnEnter(self)
    addon:Debug("OnEnter FIRED: button=%s CursorHasItem=%s", tostring(self:GetName()), tostring(CursorHasItem and CursorHasItem()))
    -- Category drag-drop: show "+" indicator when hovering with cursor item in category view
    local hasCursor = CursorHasItem and CursorHasItem()
    if hasCursor then
        addon:Debug("DropInd OnEnter: hasItem=%s otherChar=%s isBank=%s", tostring(self.hasItem), tostring(self.otherChar), tostring(self.isBank))
    end
    if hasCursor and self.hasItem and not self.otherChar then
        local inCatView = IsInCategoryView(self.isBank)
        addon:Debug("DropInd: inCatView=%s hasItemData=%s hasCatMgr=%s", tostring(inCatView), tostring(self.itemData ~= nil), tostring(addon.Modules.CategoryManager ~= nil))
        if inCatView and self.itemData and addon.Modules.CategoryManager then
            -- Don't show indicator if dragged item is already in the same category
            local targetCategory = addon.Modules.CategoryManager:CategorizeItem(self.itemData, self.bagID, self.slotID, self.otherChar)
            local cursorCategory = GetCursorItemCategory()
            addon:Debug("DropInd: targetCat=%s cursorCat=%s cooldown=%s", tostring(targetCategory), tostring(cursorCategory), tostring(GetTime() < dropCooldownTime))
            if targetCategory and cursorCategory and targetCategory ~= cursorCategory then
                self.categoryId = targetCategory
                addon:Debug("DropInd: SHOWING indicator for %s", tostring(targetCategory))
                ShowCategoryDropIndicator(self)
            else
                addon:Debug("DropInd: NOT showing - same=%s targetNil=%s cursorNil=%s", tostring(targetCategory == cursorCategory), tostring(targetCategory == nil), tostring(cursorCategory == nil))
            end
        end
    end

    -- Highlight the corresponding bag button in the footer (works for empty and filled slots)
	if not self.otherChar and self.bagID then
		if self.isBank then
		-- Bank item - highlight bank bag button
			Guda_BankFrame_HighlightBagButton(self.bagID)
		else
		-- Regular bag item - highlight bag button
			Guda_BagFrame_HighlightBagButton(self.bagID)
		end
	end

	-- Early return for empty slots (no tooltip needed)
	if not self.hasItem and not self.isMail then
		return
	end

	-- Check if pfUI cursor tooltip mode is active
	local pfuiCursorMode = false
	if pfUI and pfUI.env and pfUI.env.C and pfUI.env.C.tooltip and pfUI.env.C.tooltip.position == "cursor" then
		pfuiCursorMode = true
	end

	-- Set tooltip owner and position
	if pfuiCursorMode then
		-- For pfUI cursor mode, use ANCHOR_CURSOR like pfUI does
		GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
	else
		-- Standard positioning relative to item button
		GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
		GameTooltip:ClearAllPoints()
		GameTooltip:SetPoint("BOTTOMRIGHT", self, "TOPLEFT", 10, 0)
	end

    -- Mailbox tooltip handling
    if self.isMail then
        local currentPlayerName = addon.Modules.DB:GetPlayerFullName()
        local isMailboxOpen = addon.Modules.MailboxScanner and addon.Modules.MailboxScanner:IsMailboxOpen()
        
        if (not self.otherChar or self.otherChar == currentPlayerName) and self.mailIndex and isMailboxOpen then
            -- Live mailbox for current character (only when mailbox is actually open)
            GameTooltip:SetInboxItem(self.mailIndex, self.mailItemIndex or 1)
        elseif self.itemData and (self.itemData.link or self.itemData.itemID) then
            -- Read-only / other character mailbox OR current character mailbox when closed
            GameTooltip.GudaViewedCharacter = self.otherChar or currentPlayerName
            if self.itemData.link then
                GameTooltip:SetHyperlink(self.itemData.link)
            else
                GameTooltip:SetHyperlink("item:" .. self.itemData.itemID .. ":0:0:0")
            end
        elseif self.itemData and self.itemData.name then
            -- Money or generic mail
            GameTooltip:AddLine(self.itemData.name, 1, 1, 1)
        elseif self.mailData and self.mailData.money and self.mailData.money > 0 then
            -- Fallback for money only mail
            GameTooltip:AddLine("Money", 1, 1, 1)
        end

        -- Add mailbox metadata if available
        local mailData = self.mailData
        
        if mailData then
            -- If we already added a line (for money/generic), or SetHyperlink/SetInboxItem added lines,
            -- we might want a separator if we're adding sender info.
            if GameTooltip:NumLines() > 0 then
                GameTooltip:AddLine(" ")
            end

            if mailData.sender then
                GameTooltip:AddLine("From: " .. mailData.sender, 1, 1, 1)
            end
            if mailData.subject then
                GameTooltip:AddLine("Subject: " .. mailData.subject, 1, 1, 0.8)
            end
            if (mailData.money or 0) > 0 and not (self.itemData and self.itemData.name == "Money") then
                GameTooltip:AddLine("Money: " .. addon.Modules.Utils:FormatMoney(mailData.money), 1, 1, 1)
            end
            if (mailData.CODAmount or 0) > 0 then
                GameTooltip:AddLine("COD: " .. addon.Modules.Utils:FormatMoney(mailData.CODAmount), 1, 0, 0)
            end
            if mailData.daysLeft then
                GameTooltip:AddLine("Days left: " .. math.floor(mailData.daysLeft), 0.5, 0.5, 0.5)
            end
        end

        -- Add Inventory counts for mailbox items at the very bottom
        if addon.Modules.Tooltip and addon.Modules.Tooltip.AddInventoryInfo then
            local link = self.itemData and (self.itemData.link or (self.itemData.itemID and ("item:" .. self.itemData.itemID .. ":0:0:0")))
            if not link and self.mailIndex and isMailboxOpen then
                link = addon.Modules.Utils:GetInboxItemLink(self.mailIndex, self.mailItemIndex or 1)
            end
            if link then
                addon.Modules.Tooltip:AddInventoryInfo(GameTooltip, link)
            end
        end
        
        GameTooltip:Show()
        return
	elseif self.otherChar or self.isReadOnly then
		GameTooltip.GudaViewedCharacter = self.otherChar
		if self.itemData and self.itemData.link then
			GameTooltip:SetHyperlink(self.itemData.link)
		else
			GameTooltip:Hide()
			return
		end
	-- Special handling for bank main bag when bank might be closed
	elseif self.isBank and self.bagID == -1 then
		local bankFrame = getglobal("BankFrame")
		if bankFrame and bankFrame:IsVisible() then
			-- Bank is open - use SetBagItem which will trigger inventory slot handling
			GameTooltip:SetBagItem(self.bagID, self.slotID)
		elseif self.itemData and self.itemData.link then
			-- Bank is closed - use cached link
			GameTooltip:SetHyperlink(self.itemData.link)
		end
	elseif self.bagID == -2 then
		-- Keyring: SetBagItem might be unreliable for -2 in some 1.12.1 environments, fallback to hyperlink if needed
		local link = GetContainerItemLink(self.bagID, self.slotID)
		if link then
			GameTooltip:SetHyperlink(link)
		else
			GameTooltip:SetBagItem(self.bagID, self.slotID)
		end
	else
		-- For live mode: use SetBagItem for all bags
		GameTooltip:SetBagItem(self.bagID, self.slotID)
	end

	GameTooltip:Show()

	-- Notify third-party tooltip addons (e.g. GFW_DisenchantPredictor, EnhTooltip)
	-- These addons hook ContainerFrameItemButton_OnEnter which Guda's custom buttons bypass
	if self.bagID and self.slotID and not self.otherChar and not self.isReadOnly then
		local link = GetContainerItemLink(self.bagID, self.slotID)
		if link then
			local _, _, itemLink = string.find(link, "(item:%d+:%d+:%d+:%d+)")
			if itemLink then
				local itemName = GetItemInfo(itemLink)
				-- GFWTooltip callback system
				if GFWTooltip_Callbacks then
					GameTooltip.gfwDone = nil  -- Reset so callbacks are not skipped
					for modName, callback in pairs(GFWTooltip_Callbacks) do
						if type(callback) == "function" then
							callback(GameTooltip, itemName, link, "CONTAINER")
						end
					end
					GameTooltip:Show()
				end
				-- EnhTooltip callback system
				if EnhTooltip and EnhTooltip.TooltipCall then
					EnhTooltip.TooltipCall(GameTooltip, itemName, link, nil, nil, self.bagID, self.slotID)
					GameTooltip:Show()
				end
			end
		end
	end

	-- Debug: print item classification info to chat when debug mode is active
	if addon.DEBUG and self.hasItem and self.bagID and self.slotID and not self._debugPrinted then
		local link = self.itemData and self.itemData.link or GetContainerItemLink(self.bagID, self.slotID)
		if link then
			local itemID = addon.Modules.Utils:ExtractItemID(link)
			if itemID then
				local itemName, _, itemRarity, itemLevel, itemCategory, itemType, _, itemSubType = GetItemInfo(itemID)
				addon:Debug("Item: %s (ID: %s)", tostring(itemName), tostring(itemID))
				addon:Debug("  Category: %s | Type: %s | SubType: %s", tostring(itemCategory), tostring(itemType), tostring(itemSubType))
				addon:Debug("  Quality: %s | iLvl: %s", tostring(itemRarity), tostring(itemLevel))
				if addon.Modules.ItemDetection then
					local props = addon.Modules.ItemDetection:GetItemProperties({link = link}, self.bagID, self.slotID)
					local flags = {}
					if props.isQuestItem then table.insert(flags, "Quest") end
					if props.isQuestStarter then table.insert(flags, "Starter") end
					if props.isQuestUsable then table.insert(flags, "Usable") end
					if props.isJunk then table.insert(flags, "Junk") end
					if props.isPermanentEnchant then table.insert(flags, "Enchant") end
					if props.isUnusable then table.insert(flags, "Unusable") end
					local flagStr = table.getn(flags) > 0 and table.concat(flags, ", ") or "none"
					addon:Debug("  Flags: %s", flagStr)
				end
				self._debugPrinted = true
			end
		end
	end

    -- Handle merchant sell cursor (same approach as BagShui)
	if MerchantFrame:IsShown() and not self.isBank and not self.otherChar and self.hasItem then
		ShowContainerSellCursor(self.bagID, self.slotID)
	else
		ResetCursor()
	end
end


-- OnLeave handler
function Guda_ItemButton_OnLeave(self)
    -- Delay hide of drop indicator to allow mouse to move to indicator frame
    if activeCategoryDropIndicator == self and categoryDropIndicator and categoryDropIndicator:IsShown() then
        -- Use pooled timer to check if mouse moved to the indicator (avoids frame leak)
        Guda_ScheduleTimer(0.05, function()
            -- If mouse is over the indicator, don't hide
            if categoryDropIndicator and categoryDropIndicator:IsMouseOver() then
                return
            end
            -- If mouse is over the parent button, don't hide
            if activeCategoryDropIndicator and MouseIsOver(activeCategoryDropIndicator) then
                return
            end
            HideCategoryDropIndicator()
        end)
    else
        HideCategoryDropIndicator()
    end
    self._debugPrinted = nil
    -- Clear any viewed character hint on the tooltip when leaving
    if GameTooltip then
        GameTooltip.GudaViewedCharacter = nil
        GameTooltip.GudaInventoryAdded = nil
    end
    GameTooltip:Hide()
    ResetCursor()

    -- Clear bag button highlighting
    if not self.otherChar then
        if self.isBank then
            Guda_BankFrame_ClearBagButtonHighlight()
        else
            Guda_BagFrame_ClearBagButtonHighlight()
        end
    end
end