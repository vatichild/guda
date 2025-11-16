-- Guda Item Button
-- Handles item button display and interaction

local addon = Guda

-- Item button pool
local buttonPool = {}
local nextButtonID = 1

-- Create or get a button from the pool
function Guda_GetItemButton(parent)
    -- Try to reuse existing button
    for _, button in pairs(buttonPool) do
        if not button:IsShown() and button:GetParent() == parent then
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
end

-- Set item data
function Guda_ItemButton_SetItem(self, bagID, slotID, itemData, isBank, otherCharName, matchesFilter)
    self.bagID = bagID
    self.slotID = slotID
    self.itemData = itemData
    self.isBank = isBank or false
    self.otherChar = otherCharName

    -- Default to true if not specified (for non-filtered displays)
    if matchesFilter == nil then
        matchesFilter = true
    end

    local countText = getglobal(self:GetName().."_Count")
    local qualityBorder = getglobal(self:GetName().."_QualityBorder")
    local emptySlotBg = getglobal(self:GetName().."_EmptySlotBg")

    -- Apply icon size setting
    local iconSize = Guda.Modules.DB:GetSetting("iconSize") or addon.Constants.BUTTON_SIZE
    self:SetWidth(iconSize)
    self:SetHeight(iconSize)

    -- Resize empty slot background to match icon size (slightly larger to ensure coverage)
    if emptySlotBg then
        emptySlotBg:ClearAllPoints()
        emptySlotBg:SetPoint("TOPLEFT", self, "TOPLEFT", -2, 2)
        emptySlotBg:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 2, -2)
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
    end

    if itemData then
        self.hasItem = true

        -- Set icon
        SetItemButtonTexture(self, itemData.texture)

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

        -- Set quality border
        if itemData.quality and itemData.quality > 1 then
            local r, g, b = addon.Modules.Utils:GetQualityColor(itemData.quality)
            qualityBorder:SetVertexColor(r, g, b, 1)
            qualityBorder:Show()
        else
            qualityBorder:Hide()
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
        qualityBorder:Hide()
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
            -- Make icon 3px smaller than slot for nice inset effect
            local iconDisplaySize = iconSize - 15
            iconTexture:ClearAllPoints()
            iconTexture:SetPoint("CENTER", self, "CENTER", 0, 0)
            iconTexture:SetWidth(iconDisplaySize)
            iconTexture:SetHeight(iconDisplaySize)
            -- Crop icon edges slightly (pfUI uses .08 to .92)
            iconTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            iconTexture:Show()
        else
            -- Hide icon for empty slots
            iconTexture:Hide()
        end
    end
end

-- OnEnter handler (show tooltip)
function Guda_ItemButton_OnEnter(self)
    if not self.hasItem or not self.itemData then
        return
    end

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

    if self.otherChar then
        -- Viewing another character's item
        if self.itemData.link then
            GameTooltip:SetHyperlink(self.itemData.link)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cFFFFFFFFOwned by: |cFF00FF96" .. self.otherChar .. "|r", 1, 1, 1)
        end
    else
        -- Current character's item
        if self.isBank then
            GameTooltip:SetInventoryItem("player", BankButtonIDToInvSlotID(self.slotID, self.bagID))
        else
            GameTooltip:SetBagItem(self.bagID, self.slotID)
        end
    end

    GameTooltip:Show()
end

-- OnLeave handler
function Guda_ItemButton_OnLeave(self)
    GameTooltip:Hide()
end

-- OnDragStart handler
function Guda_ItemButton_OnDragStart(self, button)
    -- Don't allow dragging other characters' items
    if self.otherChar then
        return
    end

    -- Only allow left button drag
    if button == "LeftButton" and self.hasItem then
        PickupContainerItem(self.bagID, self.slotID)
    end
end

-- OnReceiveDrag handler
function Guda_ItemButton_OnReceiveDrag(self)
    -- Don't allow dragging to other characters' items
    if self.otherChar then
        return
    end

    -- Place the item being dragged
    PickupContainerItem(self.bagID, self.slotID)
end

-- OnClick handler
function Guda_ItemButton_OnClick(self, button)
    -- Don't allow interaction with other characters' items
    if self.otherChar then
        return
    end

    -- Handle modified clicks first
    if IsShiftKeyDown() then
        -- Shift+Click: Link in chat
        if self.hasItem and self.itemData and self.itemData.link then
            if ChatFrameEditBox:IsVisible() then
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
