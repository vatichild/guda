-- Guda Quest Item Bar
-- Displays usable quest items in a separate bar

local addon = Guda
local QuestItemBar = addon.Modules.QuestItemBar
if not QuestItemBar then
    -- Fallback if Init.lua changed
    QuestItemBar = {}
    addon.Modules.QuestItemBar = QuestItemBar
end

local buttons = {}
local questItems = {}
local flyoutButtons = {}
local flyoutFrame

-- Create a hidden tooltip for scanning
local scanTooltip
local function GetScanTooltip()
    if not scanTooltip then
        scanTooltip = CreateFrame("GameTooltip", "Guda_QuestBarScanTooltip", nil, "GameTooltipTemplate")
        scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end
    return scanTooltip
end

-- Combined function to check if an item is a quest item AND usable in ONE tooltip scan
-- This avoids the expensive double-scan that was causing lag
function QuestItemBar:CheckQuestItemUsable(bagID, slotID)
    if not bagID or not slotID then return false, false, false end

    local tooltip = GetScanTooltip()
    tooltip:ClearLines()
    tooltip:SetBagItem(bagID, slotID)

    local isQuestItem = false
    local isQuestStarter = false
    local isUsable = false

    for i = 1, tooltip:NumLines() do
        local line = getglobal("Guda_QuestBarScanTooltipTextLeft" .. i)
        if line then
            local text = line:GetText()
            if text then
                local tl = string.lower(text)
                -- Check for quest item indicators
                if string.find(text, "Quest Starter") or
                   string.find(text, "This Item Begins a Quest") or
                   string.find(text, "Use: Starts a Quest") then
                    isQuestItem = true
                    isQuestStarter = true
                    isUsable = true -- Quest starters are always usable
                elseif string.find(text, "Quest Item") then
                    isQuestItem = true
                end
                -- Check for usability (case-insensitive)
                if string.find(tl, "use:") or string.find(tl, "begins a quest") or string.find(tl, "starts a quest") then
                    isUsable = true
                end
            end
        end
    end

    -- Fallback check for quest category if not detected from tooltip
    local link = GetContainerItemLink(bagID, slotID)
    local itemID
    local itemCategory, itemType
    
    if link and addon.Modules.Utils and addon.Modules.Utils.ExtractItemID and addon.Modules.Utils.GetItemInfoSafe then
        itemID = addon.Modules.Utils:ExtractItemID(link)
        if itemID then
            _, _, _, _, itemCategory, itemType = addon.Modules.Utils:GetItemInfoSafe(itemID)
        end
    end

    -- If it's a Weapon or Armor, it shouldn't be a QuestItem unless it's specifically categorized as Quest
    -- This avoids "Use:" equipment showing up in the quest bar
    if itemCategory == "Weapon" or itemCategory == "Armor" or itemType == "Weapon" or itemType == "Armor" then
        if itemCategory ~= "Quest" and itemType ~= "Quest" then
            isQuestItem = false
            isQuestStarter = false
        end
    end

    if not isQuestItem then
        if itemCategory == "Quest" or itemType == "Quest" then
            isQuestItem = true
        end
    end

    -- Check the QuestItemsDB for known faction-specific quest items
    if not isQuestItem then
        if itemID and addon.IsQuestItemByID then
            local playerFaction = UnitFactionGroup("player")
            local isDBQuestItem = addon:IsQuestItemByID(itemID, playerFaction)
            if isDBQuestItem then
                isQuestItem = true
            end
        end
    end

    return isQuestItem, isQuestStarter, isUsable
end

-- Scan bags for quest items (optimized: single tooltip scan per item)
function QuestItemBar:ScanForQuestItems()
    questItems = {}

    -- Scan backpack and 4 bags
    for bagID = 0, 4 do
        local numSlots = GetContainerNumSlots(bagID)
        for slotID = 1, numSlots do
            local texture, count = GetContainerItemInfo(bagID, slotID)
            if texture then
                -- Single combined check instead of two separate tooltip scans
                local isQuest, isStarter, isUsable = self:CheckQuestItemUsable(bagID, slotID)
                if isQuest and isUsable and not isStarter then
                    table.insert(questItems, {
                        bagID = bagID,
                        slotID = slotID,
                        texture = texture,
                        count = count
                    })
                end
            end
        end
    end
end

-- Legacy function kept for compatibility (now calls combined function)
function QuestItemBar:IsQuestItem(bagID, slotID)
    local isQuestItem, isQuestStarter, _ = self:CheckQuestItemUsable(bagID, slotID)
    return isQuestItem, isQuestStarter
end

function QuestItemBar:PinItem(itemID, slot)
    if not itemID then return end
    local pins = addon.Modules.DB:GetSetting("questBarPinnedItems") or {}
    
    local targetSlot = slot or 1
    if not slot then
        -- Original logic: Find first empty slot or replace first
        for i = 1, 2 do
            if pins[i] == itemID then return end
        end
        
        for i = 1, 2 do
            if not pins[i] then
                targetSlot = i
                break
            end
        end
    end
    
    pins[targetSlot] = itemID
    addon.Modules.DB:SetSetting("questBarPinnedItems", pins)
    self:Update()
    return true
end

-- Update the bar buttons
function QuestItemBar:Update()
    local showQuestBar = addon.Modules.DB:GetSetting("showQuestBar")
    local frame = Guda_QuestItemBar
    
    if not frame then return end

    if showQuestBar == false then
        frame:Hide()
        return
    end
    
    self:ScanForQuestItems()
    
    -- If no quest items found, hide the bar
    if table.getn(questItems or {}) == 0 then
        frame:Hide()
        return
    end

    frame:Show()

    local pinnedItems = addon.Modules.DB:GetSetting("questBarPinnedItems") or {}
    local buttonSize = addon.Modules.DB:GetSetting("questBarSize") or 36
    local spacing = 2
    local xOffset = 5

    -- Update frame height based on button size
    frame:SetHeight(buttonSize + 8)
    
    -- Used to keep track of which bag items are already displayed
    local usedBagSlots = {}

    local slots = math.min(2, table.getn(questItems or {}))
    for i = 1, slots do
        local index = i
        local button = buttons[i]
        if not button then
            button = CreateFrame("Button", "Guda_QuestItemBarButton" .. i, frame, "Guda_ItemButtonTemplate")
            table.insert(buttons, button)
            
            -- Set up the button once
            button:RegisterForDrag("LeftButton")
            button:SetScript("OnDragStart", function() end)
            button:SetScript("OnReceiveDrag", function() end)
            button:SetScript("OnMouseDown", function()
                if arg1 == "LeftButton" then
                    if IsShiftKeyDown() and not (CursorHasItem and CursorHasItem()) then
                        this:GetParent():StartMoving()
                        this:GetParent().isMoving = true
                    end
                end
            end)
            button:SetScript("OnMouseUp", function()
                if arg1 == "LeftButton" then
                    local parent = this:GetParent()
                    if parent.isMoving then
                        parent:StopMovingOrSizing()
                        parent.isMoving = false
                        local point, _, relativePoint, x, y = parent:GetPoint()
                        addon.Modules.DB:SetSetting("questBarPosition", {point = point, relativePoint = relativePoint, x = x, y = y})
                    end
                end
            end)
        end

        local itemToDisplay = nil
        
        -- 1. Try to find the pinned item for this slot
        local pinnedID = pinnedItems[i]
        if pinnedID then
            -- Find this item in bags
            for _, item in ipairs(questItems) do
                local itemID = addon.Modules.Utils:ExtractItemID(GetContainerItemLink(item.bagID, item.slotID))
                if itemID == pinnedID and not usedBagSlots[item.bagID .. ":" .. item.slotID] then
                    itemToDisplay = item
                    usedBagSlots[item.bagID .. ":" .. item.slotID] = true
                    break
                end
            end
        end
        
        -- 2. If no pinned item or pinned item not found, auto-fill
        if not itemToDisplay then
            for _, item in ipairs(questItems) do
                if not usedBagSlots[item.bagID .. ":" .. item.slotID] then
                    itemToDisplay = item
                    usedBagSlots[item.bagID .. ":" .. item.slotID] = true
                    break
                end
            end
        end

        if itemToDisplay then
            button.bagID = itemToDisplay.bagID
            button.slotID = itemToDisplay.slotID
            button.hasItem = true
            button.fromDB = itemToDisplay.fromDB
            
            local link = itemToDisplay.link
            if not link and itemToDisplay.bagID and itemToDisplay.slotID then
                link = GetContainerItemLink(itemToDisplay.bagID, itemToDisplay.slotID)
            end
            button.itemData = { link = link }
            
            local icon = getglobal(button:GetName() .. "IconTexture")
            icon:SetTexture(itemToDisplay.texture)
            icon:SetVertexColor(1.0, 1.0, 1.0, 1.0)
            
            local countText = getglobal(button:GetName() .. "Count")
            if itemToDisplay.count > 1 then
                countText:SetText(itemToDisplay.count)
                countText:Show()
            else
                countText:Hide()
            end
            
            button:SetScript("OnClick", function()
                if this.fromDB then
                    addon:Print("Item is not currently in your bags (loading from database).")
                    return
                end
                
                if arg1 == "LeftButton" then
                    if CursorHasItem() then
                        -- Try to pin item on cursor
                        local tooltip = GetScanTooltip()
                        tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
                        tooltip:SetCursorItem()
                        local link = nil
                        -- In 1.12, getting link from cursor is hard.
                        -- We'll rely on Alt-Click from bags for pinning.
                    end

                    if not IsShiftKeyDown() then
                        UseContainerItem(this.bagID, this.slotID)
                    end
                elseif arg1 == "RightButton" then
                    if IsAltKeyDown() then
                        -- Clear pin for this slot
                        local pins = addon.Modules.DB:GetSetting("questBarPinnedItems") or {}
                        pins[index] = nil
                        addon.Modules.DB:SetSetting("questBarPinnedItems", pins)
                        QuestItemBar:Update()
                    elseif not IsShiftKeyDown() then
                        UseContainerItem(this.bagID, this.slotID)
                    end
                end
            end)
            
            button:Show()
        else
            -- Empty slot
            button.hasItem = false
            button.bagID = nil
            button.slotID = nil
            
            local icon = getglobal(button:GetName() .. "IconTexture")
            icon:SetTexture("Interface\\Buttons\\UI-EmptySlot")
            icon:SetVertexColor(0.5, 0.5, 0.5, 0.5)
            
            local countText = getglobal(button:GetName() .. "Count")
            countText:Hide()
            
            button:SetScript("OnClick", function()
                if arg1 == "LeftButton" then
                    if CursorHasItem() then
                        -- Pinning from cursor is hard in 1.12 without hooks.
                    end
                elseif arg1 == "RightButton" then
                    if IsAltKeyDown() then
                        -- Clear pin for this slot
                        local pins = addon.Modules.DB:GetSetting("questBarPinnedItems") or {}
                        pins[index] = nil
                        addon.Modules.DB:SetSetting("questBarPinnedItems", pins)
                        QuestItemBar:Update()
                    end
                end
            end)
            
            button:Show()
        end

        button:SetScript("OnEnter", function()
            if this.hasItem then
                Guda_ItemButton_OnEnter(this)
            else
                GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
                GameTooltip:SetText("Quest Slot " .. index)
                GameTooltip:AddLine("Auto-fills with usable quest items.", 1, 1, 1)
                GameTooltip:AddLine("Alt-Click an item in bags to pin it.", 0, 1, 0)
                GameTooltip:AddLine("Alt-Right-Click to unpin.", 0.5, 0.5, 0.5)
                GameTooltip:Show()
            end
            
            -- Only show flyout if there are more quest items to show
            if QuestItemBar:HasExtraQuestItems() then
                QuestItemBar:ShowFlyout(this)
            end
        end)

        button:SetScript("OnLeave", function()
            if this.hasItem then
                Guda_ItemButton_OnLeave(this)
            else
                GameTooltip:Hide()
            end
            QuestItemBar:HideFlyout()
        end)

        button:ClearAllPoints()
        button:SetPoint("LEFT", frame, "LEFT", xOffset + (i-1) * (buttonSize + spacing), 0)
        button:SetWidth(buttonSize)
        button:SetHeight(buttonSize)

        -- Resize all button textures to match button size
        local icon = getglobal(button:GetName() .. "IconTexture")
        if icon then
            icon:SetWidth(buttonSize)
            icon:SetHeight(buttonSize)
        end

        -- Scale border proportionally (64/37 is the standard ratio for WoW item buttons)
        local borderSize = buttonSize * 64 / 37
        local normalTex = getglobal(button:GetName() .. "NormalTexture")
        if normalTex then
            normalTex:SetWidth(borderSize)
            normalTex:SetHeight(borderSize)
        end

        -- Resize empty slot background
        local emptyBg = getglobal(button:GetName() .. "_EmptySlotBg")
        if emptyBg then
            emptyBg:SetWidth(buttonSize)
            emptyBg:SetHeight(buttonSize)
        end

        -- Update visual overlays (cooldown, etc)
        if Guda_ItemButton_UpdateCooldown then
            Guda_ItemButton_UpdateCooldown(button)
        end
    end

    -- Hide any extra buttons beyond current slots
    for j = slots + 1, table.getn(buttons) do
        local extra = buttons[j]
        if extra then
            extra:Hide()
            extra.hasItem = false
        end
    end

    -- Fixed width for current number of slots
    local newWidth = xOffset * 2 + slots * (buttonSize + spacing) - spacing
    frame:SetWidth(newWidth)
end

function QuestItemBar:UpdateCooldowns()
    for _, button in ipairs(buttons) do
        if button:IsShown() and Guda_ItemButton_UpdateCooldown then
            Guda_ItemButton_UpdateCooldown(button)
        end
    end
    for _, button in ipairs(flyoutButtons) do
        if button:IsShown() and Guda_ItemButton_UpdateCooldown then
            Guda_ItemButton_UpdateCooldown(button)
        end
    end
end

-- Check if there are more quest items than shown in the main slots
function QuestItemBar:HasExtraQuestItems()
    local mainItemIDs = {}
    for i = 1, 2 do
        local btn = buttons[i]
        if btn and btn.hasItem and btn.itemData and btn.itemData.link then
            local id = addon.Modules.Utils:ExtractItemID(btn.itemData.link)
            if id then mainItemIDs[id] = true end
        end
    end
    
    for _, item in ipairs(questItems or {}) do
        local link = item.link
        if not link and item.bagID and item.slotID then
            link = GetContainerItemLink(item.bagID, item.slotID)
        end
        
        if link then
            local id = addon.Modules.Utils:ExtractItemID(link)
            if id and not mainItemIDs[id] then
                return true
            end
        end
    end
    
    return false
end

function QuestItemBar:ShowFlyout(parent)
    if not flyoutFrame then return end
    
    self:UpdateFlyout(parent)
    flyoutFrame:Show()
end

function QuestItemBar:HideFlyout(immediate)
    if not flyoutFrame then return end
    
    if immediate then
        flyoutFrame:Hide()
        flyoutFrame:SetScript("OnUpdate", nil)
        return
    end
    
    -- Delay hiding to allow moving mouse to the flyout
    flyoutFrame.hideTime = GetTime() + 0.1
    flyoutFrame:SetScript("OnUpdate", function()
        if GetTime() > this.hideTime then
            if not MouseIsOver(this) and (not this.parent or not MouseIsOver(this.parent)) then
                this:Hide()
            end
            this:SetScript("OnUpdate", nil)
        end
    end)
end

function QuestItemBar:UpdateFlyout(parent)
    if not flyoutFrame then return end
    flyoutFrame.parent = parent

    local buttonSize = addon.Modules.DB:GetSetting("questBarSize") or 36
    local spacing = 2
    
    -- Collect items not in main buttons
    local displayItems = {}
    local mainItemIDs = {}
    for _, btn in ipairs(buttons) do
        if btn and btn.hasItem and btn.itemData and btn.itemData.link then
            local id = addon.Modules.Utils:ExtractItemID(btn.itemData.link)
            if id then mainItemIDs[id] = true end
        end
    end
    
    for _, item in ipairs(questItems) do
        local link = GetContainerItemLink(item.bagID, item.slotID)
        local id = addon.Modules.Utils:ExtractItemID(link)
        if id and not mainItemIDs[id] then
            -- Avoid duplicates in flyout if multiple stacks exist (optional, but TrinketMenu does it)
            local alreadyInFlyout = false
            for _, existing in ipairs(displayItems) do
                if existing.itemID == id then
                    alreadyInFlyout = true
                    break
                end
            end
            
            if not alreadyInFlyout then
                table.insert(displayItems, {
                    bagID = item.bagID,
                    slotID = item.slotID,
                    texture = item.texture,
                    count = item.count,
                    itemID = id,
                    link = link
                })
            end
        end
    end
    
    -- Hide all flyout buttons first
    for _, btn in ipairs(flyoutButtons) do
        btn:Hide()
    end
    
    if table.getn(displayItems) == 0 then
        flyoutFrame:Hide()
        return
    end
    
    -- Position flyout above the parent button
    flyoutFrame:ClearAllPoints()
    flyoutFrame:SetPoint("BOTTOM", parent, "TOP", 0, 5)
    
    for i, item in ipairs(displayItems) do
        local btn = flyoutButtons[i]
        if not btn then
            btn = CreateFrame("Button", "Guda_QuestItemFlyoutButton" .. i, flyoutFrame, "Guda_ItemButtonTemplate")
            table.insert(flyoutButtons, btn)
            
            btn:SetScript("OnDragStart", function() end)
            btn:SetScript("OnReceiveDrag", function() end)
            btn:SetScript("OnMouseDown", function() end)
            
            btn:SetScript("OnEnter", function()
                Guda_ItemButton_OnEnter(this)
                if flyoutFrame then flyoutFrame.hideTime = GetTime() + 5 end -- Keep open
            end)
            btn:SetScript("OnLeave", function()
                Guda_ItemButton_OnLeave(this)
                QuestItemBar:HideFlyout()
            end)
        end
        
        btn.bagID = item.bagID
        btn.slotID = item.slotID
        btn.hasItem = true
        btn.fromDB = item.fromDB
        btn.itemData = { link = item.link }
        btn.itemID = item.itemID
        
        local icon = getglobal(btn:GetName() .. "IconTexture")
        icon:SetTexture(item.texture)
        
        local countText = getglobal(btn:GetName() .. "Count")
        if item.count > 1 then
            countText:SetText(item.count)
            countText:Show()
        else
            countText:Hide()
        end
        
        btn:SetScript("OnClick", function()
            if this.fromDB then
                addon:Print("Item is not currently in your bags (loading from database).")
                return
            end
            
            local targetSlot = 1
            if flyoutFrame.parent then
                -- Check if parent is Guda_QuestItemBarButton2
                if flyoutFrame.parent:GetName() == "Guda_QuestItemBarButton2" then
                    targetSlot = 2
                end
            end
            
            if arg1 == "LeftButton" then
                QuestItemBar:PinItem(this.itemID, targetSlot)
            elseif arg1 == "RightButton" then
                -- Both clicks now work on targetSlot based on context, 
                -- but we'll keep RightButton for slot 2 as a fallback/original behavior 
                -- or just make it also use targetSlot if we want "both clicks work on mouse 1".
                -- The requirement says "make both clicks work on mouse 1 instead of mouse 2 and mouse 1 clicks to separate bars"
                -- This phrasing is a bit ambiguous, but contextually it means 
                -- Mouse 1 on flyout button should replace the bar that was hovered.
                QuestItemBar:PinItem(this.itemID, targetSlot)
            end
            QuestItemBar:HideFlyout(true)
        end)
        
        btn:ClearAllPoints()
        btn:SetPoint("BOTTOM", flyoutFrame, "BOTTOM", 0, (i-1) * (buttonSize + spacing) + 5)
        btn:SetWidth(buttonSize)
        btn:SetHeight(buttonSize)

        -- Resize all button textures to match button size
        local btnIcon = getglobal(btn:GetName() .. "IconTexture")
        if btnIcon then
            btnIcon:SetWidth(buttonSize)
            btnIcon:SetHeight(buttonSize)
        end

        -- Scale border proportionally (64/37 is the standard ratio for WoW item buttons)
        local borderSize = buttonSize * 64 / 37
        local btnNormalTex = getglobal(btn:GetName() .. "NormalTexture")
        if btnNormalTex then
            btnNormalTex:SetWidth(borderSize)
            btnNormalTex:SetHeight(borderSize)
        end

        -- Resize empty slot background
        local btnEmptyBg = getglobal(btn:GetName() .. "_EmptySlotBg")
        if btnEmptyBg then
            btnEmptyBg:SetWidth(buttonSize)
            btnEmptyBg:SetHeight(buttonSize)
        end

        btn:Show()

        if Guda_ItemButton_UpdateCooldown then
            Guda_ItemButton_UpdateCooldown(btn)
        end
    end
    
    flyoutFrame:SetWidth(buttonSize + 10)
    flyoutFrame:SetHeight(table.getn(displayItems) * (buttonSize + spacing) + 10)
end

-- Global wrappers for keybindings
function Guda_UseQuestItem1()
    local button = getglobal("Guda_QuestItemBarButton1")
    if button and button:IsShown() and button.hasItem and button.bagID and button.slotID then
        UseContainerItem(button.bagID, button.slotID)
    end
end

function Guda_UseQuestItem2()
    local button = getglobal("Guda_QuestItemBarButton2")
    if button and button:IsShown() and button.hasItem and button.bagID and button.slotID then
        UseContainerItem(button.bagID, button.slotID)
    end
end

function QuestItemBar:Initialize()
    local frame = CreateFrame("Frame", "Guda_QuestItemBar", UIParent)
    frame:SetWidth(40)
    frame:SetHeight(45)
    frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 150)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    
    --addon:ApplyBackdrop(frame, "DEFAULT_FRAME")
    
    -- Create flyout frame
    flyoutFrame = CreateFrame("Frame", "Guda_QuestItemFlyout", UIParent)
    flyoutFrame:SetFrameStrata("TOOLTIP")
    flyoutFrame:Hide()
    addon:ApplyBackdrop(flyoutFrame, "DEFAULT_FRAME")
    
    -- Handle dragging
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnMouseDown", function()
        if arg1 == "LeftButton" then
            this:StartMoving()
            this.isMoving = true
        end
    end)
    frame:SetScript("OnMouseUp", function()
        if arg1 == "LeftButton" and this.isMoving then
            this:StopMovingOrSizing()
            this.isMoving = false
            local point, _, relativePoint, x, y = this:GetPoint()
            addon.Modules.DB:SetSetting("questBarPosition", {point = point, relativePoint = relativePoint, x = x, y = y})
        end
    end)
    
    -- Restore position
    local pos = addon.Modules.DB:GetSetting("questBarPosition")
    if pos and pos.point then
        frame:ClearAllPoints()
        frame:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.x, pos.y)
    end
    
    -- Register for events with debouncing to prevent lag on rapid bag updates
    local bagUpdatePending = false
    addon.Modules.Events:Register("BAG_UPDATE", function()
        if bagUpdatePending then return end
        bagUpdatePending = true
        -- Debounce: wait 0.15 seconds before updating to batch rapid events
        local debounceFrame = CreateFrame("Frame")
        debounceFrame.elapsed = 0
        debounceFrame:SetScript("OnUpdate", function()
            this.elapsed = this.elapsed + arg1
            if this.elapsed >= 0.15 then
                this:SetScript("OnUpdate", nil)
                bagUpdatePending = false
                QuestItemBar:Update()
            end
        end)
    end, "QuestItemBar")

    addon.Modules.Events:Register("BAG_UPDATE_COOLDOWN", function()
        QuestItemBar:UpdateCooldowns()
    end, "QuestItemBar")
    
    addon.Modules.Events:Register("PLAYER_ENTERING_WORLD", function()
        QuestItemBar:Update()
    end, "QuestItemBar")

    QuestItemBar:Update()
    addon:Debug("QuestItemBar initialized")
end

QuestItemBar.isLoaded = true
