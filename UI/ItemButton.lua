-- Guda Item Button
-- Handles item button display and interaction

local addon = Guda

-- Item button pool
local buttonPool = {}
local nextButtonID = 1

-- Hidden tooltip for scanning quest items
local scanTooltip = CreateFrame("GameTooltip", "Guda_QuestScanTooltip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

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
end

-- Set item data
function Guda_ItemButton_SetItem(self, bagID, slotID, itemData, isBank, otherCharName, matchesFilter, isReadOnly)
    self.bagID = bagID
    self.slotID = slotID
    self.itemData = itemData
    self.isBank = isBank or false
    self.otherChar = otherCharName
    self.isReadOnly = isReadOnly or false  -- Track if this is read-only mode

    -- Default to true if not specified (for non-filtered displays)
    if matchesFilter == nil then
        matchesFilter = true
    end

    local countText = getglobal(self:GetName().."_Count")
    local emptySlotBg = getglobal(self:GetName().."_EmptySlotBg")

    -- Apply icon size setting
    local iconSize = Guda.Modules.DB:GetSetting("iconSize") or addon.Constants.BUTTON_SIZE
    self:SetWidth(iconSize)
    self:SetHeight(iconSize)

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
        local fontSize = Guda.Modules.DB:GetSetting("iconFontSize") or 12
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

    if itemData then
        self.hasItem = true

        -- Set icon
        SetItemButtonTexture(self, itemData.texture)

        -- Gray out locked items (being traded, mailed, or auctioned) - BagShui style
        -- Don't desaturate items from other characters since they're read-only anyway
        if not self.otherChar and not self.isReadOnly then
            SetItemButtonDesaturated(self, itemData.locked, 0.5, 0.5, 0.5)
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

        -- Set count
        if itemData.count and itemData.count > 1 then
            countText:SetText(itemData.count)
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
            elseif itemData.quality and itemData.link then
                -- Check settings to determine if we should show borders
                local showEquipmentBorder = addon.Modules.DB:GetSetting("showQualityBorderEquipment")
                local showOtherBorder = addon.Modules.DB:GetSetting("showQualityBorderOther")

                -- Default to true if settings not found
                if showEquipmentBorder == nil then
                    showEquipmentBorder = true
                end
                if showOtherBorder == nil then
                    showOtherBorder = true
                end

                -- Check if item is equipment
                local isEquipment = addon.Modules.Utils:IsEquipment(itemData.link)

                -- Determine if we should show the border based on item type and settings
                local shouldShowBorder = (isEquipment and showEquipmentBorder) or (not isEquipment and showOtherBorder)

                if shouldShowBorder then
                    -- Show colored border for all items (Poor, Common, Uncommon, Rare, Epic, etc.)
                    local r, g, b = addon.Modules.Utils:GetQualityColor(itemData.quality)
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

-- Stack split callback (called by StackSplitFrame)
local function ItemButton_SplitStack(self, split)
    if self.bagID and self.slotID then
        SplitContainerItem(self.bagID, self.slotID, split)
    end
end

-- OnClick handler
function Guda_ItemButton_OnClick(self, button)
    -- Don't allow interaction with other characters' items or in read-only mode
    if self.otherChar or self.isReadOnly then
        return
    end

    -- Set the split callback
    self.SplitStack = ItemButton_SplitStack

    -- Handle modified clicks first
    if IsShiftKeyDown() then
        if button == "LeftButton" and self.hasItem then
            -- Shift+Left Click on stackable item: Show split stack dialog
            if self.itemData and self.itemData.count and self.itemData.count > 1 then
                -- Get the actual stack count from the container
                local _, count = GetContainerItemInfo(self.bagID, self.slotID)
                if count and count > 1 then
                    -- Open the stack split frame (positioned to the left)
                    OpenStackSplitFrame(count, self, "BOTTOMRIGHT", "TOPRIGHT")
                    return
                end
            end
            -- If not stackable or only 1 item, link to chat
            if self.itemData and self.itemData.link and ChatFrameEditBox:IsVisible() then
                ChatFrameEditBox:Insert(self.itemData.link)
            end
        end
        return
    elseif IsControlKeyDown() then
        -- Ctrl+Click: Dress up (if applicable)
        if self.hasItem and self.itemData and self.itemData.link then
            DressUpItemLink(self.itemData.link)
        end
        return
    end

    -- Normal clicks - handle item pickup/placement
    if button == "LeftButton" then
        -- Pick up or place item
        PickupContainerItem(self.bagID, self.slotID)
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
