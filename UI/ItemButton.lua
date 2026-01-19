-- Local alias to the addon root table (must be defined before any usages below)
local addon = Guda

-- Item button pool
local buttonPool = {}
local nextButtonID = 1

local scanTooltip = CreateFrame("GameTooltip", "Guda_QuestScanTooltip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

-- Helper function to check if an item is a quest item
-- Delegates to consolidated Utils:IsQuestItem() function
local function IsQuestItem(bagID, slotID, isBank)
    if addon and addon.Modules and addon.Modules.Utils and addon.Modules.Utils.IsQuestItem then
        return addon.Modules.Utils:IsQuestItem(bagID, slotID, nil, false, isBank)
    end
    return false, false
end

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

-- Build durability match pattern based on the client template
local durabilityPattern
if DURABILITY_TEMPLATE then
    -- e.g. "Durability %d / %d" -> "Durability (.+)"
    durabilityPattern = string.gsub(DURABILITY_TEMPLATE, "%%[^%s]+", "(.+)")
end

-- Tiny helper to compare font color to Blizzard's RED_FONT_COLOR
local function IsRedColor(r, g, b)
    if not r or not g or not b or not RED_FONT_COLOR then return false end
    local dr = math.abs(r - RED_FONT_COLOR.r)
    local dg = math.abs(g - RED_FONT_COLOR.g)
    local db = math.abs(b - RED_FONT_COLOR.b)
    return (dr < 0.08 and dg < 0.08 and db < 0.08)
end

-- Scan tooltip for red text that is NOT a durability line
local function IsItemUnusable(bagID, slotID, isBank)
    bagID = tonumber(bagID)
    slotID = tonumber(slotID)
    if not bagID or not slotID then return false end

    -- Some clients require SetOwner before every SetBagItem/SetInventoryItem to populate lines
    if scanTooltip.SetOwner then
        scanTooltip:SetOwner(UIParent or WorldFrame, "ANCHOR_NONE")
    end
    scanTooltip:ClearLines()

    if isBank and bagID == -1 then
        -- Bank frame item buttons map slots 1.. to inventory slots 40.. (39 + slot)
        if scanTooltip.SetInventoryItem then
            scanTooltip:SetInventoryItem("player", 39 + slotID)
        else
            -- Fallback to bag scan if API missing
            scanTooltip:SetBagItem(bagID, slotID)
        end
    else
        scanTooltip:SetBagItem(bagID, slotID)
    end

    if scanTooltip.Show then scanTooltip:Show() end

    local num = scanTooltip:NumLines() or 0
    for i = 1, num do
        -- Scan LEFT column
        local left = getglobal("Guda_QuestScanTooltipTextLeft" .. i)
        if left and left:IsShown() then
            local text = left:GetText()
            local r, g, b = left:GetTextColor()
            -- Be tolerant with red detection in case client colors differ slightly
            local isRed = IsRedColor(r, g, b) or (r and g and b and r > 0.85 and g < 0.3 and b < 0.3)
            if text and isRed then
                -- Ignore red durability (broken) lines
                if durabilityPattern and string.find(text, durabilityPattern, 1) then
                    -- skip durability
                else
                    if scanTooltip.Hide then scanTooltip:Hide() end
                    return true
                end
            end
        end

        -- Scan RIGHT column as well (required level etc can appear here on some clients)
        local right = getglobal("Guda_QuestScanTooltipTextRight" .. i)
        if right and right:IsShown() then
            local text = right:GetText()
            local r, g, b = right:GetTextColor()
            local isRed = IsRedColor(r, g, b) or (r and g and b and r > 0.85 and g < 0.3 and b < 0.3)
            if text and isRed then
                if durabilityPattern and string.find(text, durabilityPattern, 1) then
                    -- skip durability
                else
                    if scanTooltip.Hide then scanTooltip:Hide() end
                    return true
                end
            end
        end
    end

    return false
end

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

	local unusable = IsItemUnusable(self.bagID, self.slotID, self.isBank)

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


-- Create or get a button from the pool
function Guda_GetItemButton(parent)
    -- Try to reuse existing button
    for _, button in pairs(buttonPool) do
        -- Skip bag slot buttons
        if not button.isBagSlot and not button:IsShown() and button:GetParent() == parent then
            return button
        end
    end

    -- Create new button
    local button = CreateFrame("Button", "Guda_ItemButton" .. nextButtonID, parent, "Guda_ItemButtonTemplate")
    buttonPool[nextButtonID] = button
    nextButtonID = nextButtonID + 1

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

    -- Create backdrop for quality border with rounded corners
    -- Will be positioned relative to icon later
    if not self.qualityBorder then
        local backdrop = CreateFrame("Frame", nil, self)
        backdrop:SetFrameLevel(self:GetFrameLevel() + 5)
        backdrop:SetBackdrop({
            bgFile = nil,
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = {left = 4, right = 4, top = 4, bottom = 4}
        })
        backdrop:SetBackdropBorderColor(0, 0, 0, 0) -- Hidden by default
        backdrop:Hide()
        self.qualityBorder = backdrop
    end

    -- Create quest item border (golden, higher priority than quality border)
    if not self.questBorder then
        local questBackdrop = CreateFrame("Frame", nil, self)
        questBackdrop:SetFrameLevel(self:GetFrameLevel() + 6)  -- Higher than quality border
        questBackdrop:SetBackdrop({
            bgFile = nil,
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = {left = 4, right = 4, top = 4, bottom = 4}
        })
        questBackdrop:SetBackdropBorderColor(1.0, 0.82, 0, 1) -- Golden color
        questBackdrop:Hide()
        self.questBorder = questBackdrop
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
    
    self:SetScript("OnClick", function()
        if IsAltKeyDown() and arg1 == "LeftButton" and this.hasItem and not this.otherChar and not this.isReadOnly then
            local link = GetContainerItemLink(this.bagID, this.slotID)
            if link and addon and addon.Modules and addon.Modules.Utils then
                local itemID = addon.Modules.Utils:ExtractItemID(link)
                if itemID then
                    local isQuest = IsQuestItem(this.bagID, this.slotID, this.isBank)
                    if isQuest and addon.Modules.QuestItemBar and addon.Modules.QuestItemBar.PinItem then
                        addon.Modules.QuestItemBar:PinItem(itemID)
                        return
                    end
                    
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

            ContainerFrameItemButton_OnClick(arg1)
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
    if self.questBorder then self.questBorder:Hide() end
    if self.questIcon then self.questIcon:Hide() end
    if self.qualityBorder then self.qualityBorder:Hide() end
    if self.unusableOverlay then self.unusableOverlay:Hide() end

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

    emptySlotBg:ClearAllPoints()
    -- Use smaller padding for small icons
    local bgPadding = iconSize < 44 and 1 or 2
    emptySlotBg:SetPoint("TOPLEFT", self, "TOPLEFT", -bgPadding, bgPadding)
    emptySlotBg:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", bgPadding, -bgPadding)
    emptySlotBg:SetTexCoord(0.1, 0.9, 0.1, 0.9)
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

    -- Calculate icon inset based on size
    local iconInset = iconSize < 44 and 10 or 15
    local iconDisplaySize = iconSize - iconInset

    iconTexture:ClearAllPoints()
    iconTexture:SetPoint("CENTER", self, "CENTER", -0.5, 0.5)
    iconTexture:SetWidth(iconDisplaySize)
    iconTexture:SetHeight(iconDisplaySize)
    iconTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    iconTexture:Show()

    -- Position quality border around the icon
    if self.qualityBorder then
        self.qualityBorder:ClearAllPoints()
        self.qualityBorder:SetPoint("TOPLEFT", iconTexture, "TOPLEFT", -5, 5)
        self.qualityBorder:SetPoint("BOTTOMRIGHT", iconTexture, "BOTTOMRIGHT", 5, -5)
    end

    -- Position quest border around the icon
    if self.questBorder then
        self.questBorder:ClearAllPoints()
        self.questBorder:SetPoint("TOPLEFT", iconTexture, "TOPLEFT", -5, 5)
        self.questBorder:SetPoint("BOTTOMRIGHT", iconTexture, "BOTTOMRIGHT", 5, -5)
    end

    -- Position quest icon in top-right corner
    if self.questIcon then
        local questIconSize = math.max(12, math.min(20, iconSize * 0.35))
        self.questIcon:SetWidth(questIconSize)
        self.questIcon:SetHeight(questIconSize)
        self.questIcon:ClearAllPoints()
        self.questIcon:SetPoint("TOPRIGHT", self, "TOPRIGHT", 1, 0)
    end
end

-- Update quality border display
local function UpdateQualityBorder(self, itemQuality, itemLink, bagID, Utils)
    if not self.qualityBorder then return end

    if bagID == -2 then
        -- Special border for keyring items (cyan/blue)
        self.qualityBorder:SetBackdropBorderColor(0.2, 0.8, 1.0, 1)
        self.qualityBorder:Show()
        return
    end

    if not itemQuality then
        self.qualityBorder:Hide()
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
        local r, g, b = 1, 1, 1
        if Utils and Utils.GetQualityColor then
            r, g, b = Utils:GetQualityColor(itemQuality)
        end
        self.qualityBorder:SetBackdropBorderColor(r, g, b, 1)
        self.qualityBorder:Show()
    else
        self.qualityBorder:Hide()
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

    -- Hide normal texture
    self:SetNormalTexture("")
    local normalBorder = getglobal(self:GetName().."NormalTexture")
    if normalBorder then normalBorder:SetTexture("") end

    -- Show/hide empty slot background
    if emptySlotBg then
        emptySlotBg:Show()
        emptySlotBg:SetAlpha(0.5)
    end

    if countText then countText:Hide() end

    -- Handle quality border for empty keyring slots
    if self.qualityBorder then
        if bagID == -2 then
            self.qualityBorder:SetBackdropBorderColor(0.2, 0.8, 1.0, 0.5)
            self.qualityBorder:Show()
        else
            self.qualityBorder:Hide()
        end
    end

    -- Hide quest elements
    if self.questBorder then self.questBorder:Hide() end
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
        if emptySlotBg then emptySlotBg:Hide() end

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

    -- Resize empty slot background to match icon size (slightly larger to ensure coverage)
    if emptySlotBg then
        emptySlotBg:ClearAllPoints()
        -- Use smaller padding for small icons
        local bgPadding = iconSize < 44 and 1 or 2
        emptySlotBg:SetPoint("TOPLEFT", self, "TOPLEFT", -bgPadding, bgPadding)
        emptySlotBg:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", bgPadding, -bgPadding)
        -- Crop texture edges slightly to remove any built-in padding
        emptySlotBg:SetTexCoord(0.1, 0.9, 0.1, 0.9)
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
            countText:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -3, 3)
        else
            -- Standard offset for larger icons
            countText:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -8, 8)
        end
    end

    -- Get live metadata if in live mode (quality, link, lock status)
    local itemQuality, itemLink, isLocked
    if not self.isReadOnly and bagID and slotID and self.hasItem then
        -- Query live game state for metadata
        local _, _, locked, quality = GetContainerItemInfo(bagID, slotID)
        itemLink = GetContainerItemLink(bagID, slotID)
        itemQuality = quality
        isLocked = locked
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

        -- Show bag pattern background behind items as well
        if emptySlotBg then
            emptySlotBg:Show()
            emptySlotBg:SetAlpha(0.3)  -- More subtle for filled slots
        end

        -- Search filtering
        if matchesFilter then
            -- Matching items: full opacity (1.0)
            self:SetAlpha(1.0)
        else
            -- Non-matching items: 25% opacity (0.25) - very dim
            self:SetAlpha(0.25)
        end

        -- Set count (use displayCount which was determined above based on mode)
        if displayCount and displayCount > 1 then
            countText:SetText(displayCount)
            countText:Show()
        else
            countText:Hide()
        end

        -- Set quality border
        if self.qualityBorder then
            if bagID == -2 then
                -- Special border for keyring items (cyan/blue)
                self.qualityBorder:SetBackdropBorderColor(0.2, 0.8, 1.0, 1)
                self.qualityBorder:Show()
            elseif itemQuality then
                -- Check settings to determine if we should show borders
                local showEquipmentBorder, showOtherBorder
                if Utils and Utils.SafeCall then
                    showEquipmentBorder = Utils:SafeCall("DB", "GetSetting", "showQualityBorderEquipment")
                    showOtherBorder = Utils:SafeCall("DB", "GetSetting", "showQualityBorderOther")
                end

                -- Default to true if settings not found
                if showEquipmentBorder == nil then
                    showEquipmentBorder = true
                end
                if showOtherBorder == nil then
                    showOtherBorder = true
                end

                -- Check if item is equipment
                local isEquipment = false
                if itemLink and Utils and Utils.IsEquipment then
                    isEquipment = Utils:IsEquipment(itemLink)
                end

                -- Determine if we should show the border based on item type and settings
                local shouldShowBorder = (isEquipment and showEquipmentBorder) or (not isEquipment and showOtherBorder)

                if shouldShowBorder then
                    -- Show colored border for all items (Poor, Common, Uncommon, Rare, Epic, etc.)
                    local r, g, b = 1, 1, 1
                    if Utils and Utils.GetQualityColor then
                        r, g, b = Utils:GetQualityColor(itemQuality)
                    end
                    self.qualityBorder:SetBackdropBorderColor(r, g, b, 1)
                    self.qualityBorder:Show()
                else
                    self.qualityBorder:Hide()
                end
            else
                self.qualityBorder:Hide()
            end
        end

		if not self.otherChar and not self.isReadOnly then
			local isQuest, isQuestStarter = IsQuestItem(bagID, slotID)
			-- Update quest icon with the appropriate texture
			Guda_ItemButton_UpdateQuestIcon(self, isQuest, isQuestStarter)
			if self.questBorder then
				if isQuest then
					self.questBorder:Show()
				else
					self.questBorder:Hide()
				end
			end

			if self.questIcon then
				if isQuest then
					self.questIcon:Show()
				else
					self.questIcon:Hide()
				end
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
            emptySlotBg:Show()
            emptySlotBg:SetAlpha(0.5)  -- Slightly more visible
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

        -- Show border for empty keyring slots
        if self.qualityBorder then
            if bagID == -2 then
                self.qualityBorder:SetBackdropBorderColor(0.2, 0.8, 1.0, 0.5) -- Dimmer cyan for empty slots
                self.qualityBorder:Show()
            else
                self.qualityBorder:Hide()
            end
        end

        -- Hide quest border and icon for empty slots
        if self.questBorder then
            self.questBorder:Hide()
        end
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
            -- Scale icon proportionally based on button size
            -- For icons < 44: use smaller inset (4px) for better fit
            -- For icons >= 44: use larger inset (15px) for classic look
            local iconInset
            if iconSize < 44 then
                iconInset = 10  -- Small inset for small icons
            else
                iconInset = 15 -- Larger inset for larger icons
            end

            local iconDisplaySize = iconSize - iconInset
            iconTexture:ClearAllPoints()
            iconTexture:SetPoint("CENTER", self, "CENTER", -0.5, 0.5)
            iconTexture:SetWidth(iconDisplaySize)
            iconTexture:SetHeight(iconDisplaySize)
            -- Crop icon edges slightly
            iconTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            iconTexture:Show()

            -- Position quality border around the icon (not the slot)
            if self.qualityBorder then
                self.qualityBorder:ClearAllPoints()
                self.qualityBorder:SetPoint("TOPLEFT", iconTexture, "TOPLEFT", -5, 5)
                self.qualityBorder:SetPoint("BOTTOMRIGHT", iconTexture, "BOTTOMRIGHT", 5, -5)
            end

            -- Position quest border around the icon (same as quality border)
            if self.questBorder then
                self.questBorder:ClearAllPoints()
                self.questBorder:SetPoint("TOPLEFT", iconTexture, "TOPLEFT", -5, 5)
                self.questBorder:SetPoint("BOTTOMRIGHT", iconTexture, "BOTTOMRIGHT", 5, -5)
            end

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

    -- TESTING: Print item info to console for debugging
    --local name, link, itemQuality, iLevel, itemCategory, itemType, itemStackCount, itemSubType, itemTexture, itemEquipLoc, itemSellPrice = addon.Modules.Utils:GetItemInfo(self.itemData.link)
	--addon:Print("name:" .. tostring(name) .. " link:" .. tostring(link) .. " quality:" .. tostring(itemQuality) .. " iLevel:" .. tostring(iLevel) .. " category:" .. tostring(itemCategory) .. " type:" .. tostring(itemType) .. " subType:" .. tostring(itemSubType) .. " stackCount:" .. tostring(itemStackCount) .. " equipLoc:" .. tostring(itemEquipLoc) .. " sellPrice:" .. tostring(itemSellPrice))

    -- Handle merchant sell cursor (same approach as BagShui)
	if MerchantFrame:IsShown() and not self.isBank and not self.otherChar and self.hasItem then
		ShowContainerSellCursor(self.bagID, self.slotID)
	else
		ResetCursor()
	end
end


-- OnLeave handler
function Guda_ItemButton_OnLeave(self)
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