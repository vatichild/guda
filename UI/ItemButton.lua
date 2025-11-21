-- Local alias to the addon root table (must be defined before any usages below)
local addon = Guda
 
-- Item button pool
local buttonPool = {}
local nextButtonID = 1

-- Hidden tooltip for scanning quest items
local scanTooltip = CreateFrame("GameTooltip", "Guda_QuestScanTooltip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

-- (rollback) no custom drag-source tracking or target resolution; rely on Blizzard handlers

-- Check if an item is a quest item by scanning its tooltip
local function IsQuestItem(bagID, slotID)
    if not bagID or not slotID then return false end

    scanTooltip:ClearLines()
    scanTooltip:SetBagItem(bagID, slotID)

    -- Check all tooltip lines for "Quest Item" text
    for i = 1, scanTooltip:NumLines() do
        local line = getglobal("Guda_QuestScanTooltipTextLeft" .. i)
        if line then
            local text = line:GetText()
            if text then
                -- Check for "Quest Item" text (case sensitive to match WoW's tooltip)
                if string.find(text, "Quest Item") then
                    return true
                end
            end
        end
    end

    return false
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
end

-- Set item data
function Guda_ItemButton_SetItem(self, bagID, slotID, itemData, isBank, otherCharName, matchesFilter, isReadOnly)
    self.bagID = bagID
    self.slotID = slotID
    -- Also set the Blizzard slot ID for compatibility with ContainerFrameItemButtonTemplate behavior
    if self.SetID and slotID then
        self:SetID(slotID)
    end
    self.itemData = itemData
    self.isBank = isBank or false
    self.otherChar = otherCharName
    self.isReadOnly = isReadOnly or false  -- Track if this is read-only mode

    -- Re-register for drag/drop every time (crucial for button reuse in Classic/Vanilla)
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

    -- Default to true if not specified (for non-filtered displays)
    if matchesFilter == nil then
        matchesFilter = true
    end

    -- Use Blizzard's default count fontstring (ContainerFrameItemButtonTemplate creates $parentCount)
    local countText = getglobal(self:GetName().."Count")
    local emptySlotBg = getglobal(self:GetName().."_EmptySlotBg")

    -- Apply icon size setting (nil-safe)
    local iconSize = 37
    if addon and addon.Modules and addon.Modules.DB and addon.Modules.DB.GetSetting then
        iconSize = addon.Modules.DB:GetSetting("iconSize") or iconSize
    elseif Guda and Guda.Modules and Guda.Modules.DB and Guda.Modules.DB.GetSetting then
        iconSize = Guda.Modules.DB:GetSetting("iconSize") or iconSize
    end
    if addon and addon.Constants and addon.Constants.BUTTON_SIZE then
        iconSize = iconSize or addon.Constants.BUTTON_SIZE
    end
    self:SetWidth(iconSize)
    self:SetHeight(iconSize)

    -- In live mode (readOnly=false), query real-time game state instead of cached DB
    -- In read-only mode (readOnly=true), use cached itemData from DB
    local displayTexture, displayCount

    if not self.isReadOnly then
        -- LIVE MODE: Always query game state directly, never use cached itemData
        local liveTexture, liveCount = GetContainerItemInfo(bagID, slotID)
        if liveTexture then
            displayTexture = liveTexture
            displayCount = liveCount
            self.hasItem = true
        else
            -- No item in this slot (even if itemData has cached data)
            self.hasItem = false
        end
    else
        -- READ-ONLY MODE: Use cached itemData from DB (can't query other characters)
        if itemData and itemData.texture then
            displayTexture = itemData.texture
            displayCount = itemData.count
            self.hasItem = true
        else
            self.hasItem = false
        end
    end

    -- Apply the determined texture and count
    if self.hasItem then
        if SetItemButtonTexture then SetItemButtonTexture(self, displayTexture) end
        if SetItemButtonCount then SetItemButtonCount(self, displayCount or 1) end
        if emptySlotBg then emptySlotBg:Hide() end
    else
        -- Fully clear all item button state for empty slots
        if SetItemButtonTexture then SetItemButtonTexture(self, nil) end
        if SetItemButtonCount then SetItemButtonCount(self, 0) end
        if SetItemButtonDesaturated then SetItemButtonDesaturated(self, false) end

        -- Also clear the icon texture directly
        local iconTexture = getglobal(self:GetName().."IconTexture")
        if not iconTexture then
            iconTexture = getglobal(self:GetName().."Icon") or self.icon or self.Icon
        end
        if iconTexture then
            iconTexture:SetTexture(nil)
            iconTexture:Hide()
        end

        if emptySlotBg then emptySlotBg:Show() end
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
        if addon and addon.Modules and addon.Modules.DB and addon.Modules.DB.GetSetting then
            fontSize = addon.Modules.DB:GetSetting("iconFontSize") or fontSize
        elseif Guda and Guda.Modules and Guda.Modules.DB and Guda.Modules.DB.GetSetting then
            fontSize = Guda.Modules.DB:GetSetting("iconFontSize") or fontSize
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

        -- Hide NormalTexture for filled slots (pfUI style)
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

        -- Search filtering (pfUI style - ONLY use alpha, no other effects)
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

        -- Set quality border (pfUI style using backdrop border)
        if self.qualityBorder then
            if bagID == -2 then
                -- Special border for keyring items (cyan/blue)
                self.qualityBorder:SetBackdropBorderColor(0.2, 0.8, 1.0, 1)
                self.qualityBorder:Show()
            elseif itemQuality and itemLink then
                -- Check settings to determine if we should show borders (nil-safe)
                local showEquipmentBorder, showOtherBorder
                if addon and addon.Modules and addon.Modules.DB and addon.Modules.DB.GetSetting then
                    showEquipmentBorder = addon.Modules.DB:GetSetting("showQualityBorderEquipment")
                    showOtherBorder = addon.Modules.DB:GetSetting("showQualityBorderOther")
                elseif Guda and Guda.Modules and Guda.Modules.DB and Guda.Modules.DB.GetSetting then
                    showEquipmentBorder = Guda.Modules.DB:GetSetting("showQualityBorderEquipment")
                    showOtherBorder = Guda.Modules.DB:GetSetting("showQualityBorderOther")
                end

                -- Default to true if settings not found
                if showEquipmentBorder == nil then
                    showEquipmentBorder = true
                end
                if showOtherBorder == nil then
                    showOtherBorder = true
                end

                -- Check if item is equipment (nil-safe)
                local isEquipment = false
                if addon and addon.Modules and addon.Modules.Utils and addon.Modules.Utils.IsEquipment then
                    isEquipment = addon.Modules.Utils:IsEquipment(itemLink)
                elseif Guda and Guda.Modules and Guda.Modules.Utils and Guda.Modules.Utils.IsEquipment then
                    isEquipment = Guda.Modules.Utils:IsEquipment(itemLink)
                end

                -- Determine if we should show the border based on item type and settings
                local shouldShowBorder = (isEquipment and showEquipmentBorder) or (not isEquipment and showOtherBorder)

                if shouldShowBorder then
                    -- Show colored border for all items (Poor, Common, Uncommon, Rare, Epic, etc.)
                    local r, g, b = 1, 1, 1
                    if addon and addon.Modules and addon.Modules.Utils and addon.Modules.Utils.GetQualityColor then
                        r, g, b = addon.Modules.Utils:GetQualityColor(itemQuality)
                    elseif Guda and Guda.Modules and Guda.Modules.Utils and Guda.Modules.Utils.GetQualityColor then
                        r, g, b = Guda.Modules.Utils:GetQualityColor(itemQuality)
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

        -- Check for quest items and show golden border + icon (higher priority than quality border)
        -- Only check for current character's items (not other characters or bank in read-only mode)
        local isQuest = not self.otherChar and not self.isReadOnly and IsQuestItem(bagID, slotID)

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

        -- Dim empty slots when searching (pfUI style)
        if matchesFilter then
            -- No search active or passes filter: normal opacity
            self:SetAlpha(1.0)
        else
            -- Search active and doesn't match: very dim (25% like pfUI)
            self:SetAlpha(0.25)
        end

        countText:Hide()

        -- Show border for empty keyring slots (pfUI style)
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

    -- Setup icon texture using pfUI's approach (anchor to fill button)
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
            -- Crop icon edges slightly (pfUI uses .08 to .92)
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
        else
            -- Hide icon for empty slots
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
    if not self.hasItem or not self.itemData then
        return
    end

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

    -- For bank items, use the item link directly since SetBagItem might not work for bank bags
    if self.isBank and self.itemData.link then
        -- Extract hyperlink from item link: |cFFFFFFFF|Hitem:1234:0:0:0|h[Name]|h|r -> item:1234:0:0:0
        local _, _, hyperlink = strfind(self.itemData.link, "|H(.+)|h")
        if hyperlink then
            GameTooltip:SetHyperlink(hyperlink)
        else
            -- Fallback to SetBagItem
            GameTooltip:SetBagItem(self.bagID, self.slotID)
        end
    else
        -- For regular bags, use SetBagItem as normal
        GameTooltip:SetBagItem(self.bagID, self.slotID)
    end

    GameTooltip:Show()

    -- Handle merchant sell cursor (same approach as BagShui)
    if MerchantFrame:IsShown() and not self.isBank and not self.otherChar and self.hasItem then
        ShowContainerSellCursor(self.bagID, self.slotID)
    else
        ResetCursor()
    end
end

-- OnLeave handler
function Guda_ItemButton_OnLeave(self)
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

-- OnDragStart handler
function Guda_ItemButton_OnDragStart(self, button)
    -- Don't allow dragging other characters' items or in read-only mode
    if self.otherChar or self.isReadOnly then
        return
    end

    -- Only allow left button drag
    if button == "LeftButton" and self.hasItem then
        -- Ensure the global click catcher doesn't intercept the drag/drop
        local cc = getglobal and getglobal("Guda_ClickCatcher")
        if cc and cc.Hide and cc:IsShown() then
            cc:Hide()
        end
        PickupContainerItem(self.bagID, self.slotID)
    end
end

-- OnReceiveDrag handler
function Guda_ItemButton_OnReceiveDrag(self)
    -- Don't allow dragging to other characters' items or in read-only mode
    if self.otherChar or self.isReadOnly then
        return
    end

    -- Place the item being dragged
    PickupContainerItem(self.bagID, self.slotID)
end

-- Handle mouse-up to emulate Blizzard drop behavior on 1.12 where OnReceiveDrag may not always fire
-- (rollback) no custom OnMouseUp; rely on Blizzard default

-- OnMouseDown handler - pick up item when pressing mouse button (classic pattern)
-- (rollback) no custom OnMouseDown; rely on Blizzard default

-- OnDragStop handler (optional cleanup)
function Guda_ItemButton_OnDragStop(self)
    -- Reset cursor to default to avoid lingering special cursors
    if ResetCursor then
        ResetCursor()
    end
end

-- Stack split callback (called by StackSplitFrame)
local function ItemButton_SplitStack(self, split)
    if self.bagID and self.slotID then
        SplitContainerItem(self.bagID, self.slotID, split)
    end
end

-- OnClick handler
function Guda_ItemButton_OnClick(self, button)
    -- Don't allow interaction with other characters' items or in read-only mode
    if self.otherChar or self.isReadOnly then return end

    -- Set the split callback
    self.SplitStack = ItemButton_SplitStack

    -- Modified clicks
    if IsShiftKeyDown() then
        if button == "LeftButton" and self.hasItem then
            -- Get live count and link
            local _, count = GetContainerItemInfo(self.bagID, self.slotID)
            local itemLink = GetContainerItemLink(self.bagID, self.slotID)

            -- Shift+Left Click on stackable item: Show split stack dialog
            if count and count > 1 then
                OpenStackSplitFrame(count, self, "BOTTOMRIGHT", "TOPRIGHT")
                return
            end
            -- If not stackable or only 1 item, link to chat
            if itemLink and ChatFrameEditBox:IsVisible() then
                ChatFrameEditBox:Insert(itemLink)
            end
        end
        return
    elseif IsControlKeyDown() then
        -- Ctrl+Click: Dress up (if applicable)
        if self.hasItem then
            local itemLink = GetContainerItemLink(self.bagID, self.slotID)
            if itemLink then
                DressUpItemLink(itemLink)
            end
        end
        return
    end

    if button == "LeftButton" then
        -- Left clicks are handled by MouseDown/MouseUp to prevent instant self-drop.
        return
    elseif button == "RightButton" then
        -- Right click: Use item (only if slot has an item)
        if self.hasItem then
            UseContainerItem(self.bagID, self.slotID)
        end
    end
end

-- Release all buttons
function Guda_ReleaseAllButtons()
    for _, button in pairs(buttonPool) do
        button:Hide()
        button:ClearAllPoints()
    end
end