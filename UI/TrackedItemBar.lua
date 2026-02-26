-- Guda Tracked Item Bar
-- Displays tracked items with their total bag count

local addon = Guda
local TrackedItemBar = addon.Modules.TrackedItemBar
if not TrackedItemBar then
    TrackedItemBar = {}
    addon.Modules.TrackedItemBar = TrackedItemBar
end

local buttons = {}
local trackedItemsInfo = {}

-- Check if an item is a quest item by scanning tooltip
local function IsQuestItem(bagID, slotID)
    if addon.Modules.Utils and addon.Modules.Utils.IsQuestItem then
        return addon.Modules.Utils:IsQuestItem(bagID, slotID, nil, false, false)
    end
    return false, false
end

-- Scan bags for tracked items and calculate total counts
function TrackedItemBar:ScanForTrackedItems()
    trackedItemsInfo = {}
    local trackedIDs = addon.Modules.DB:GetSetting("trackedItems") or {}

    local itemCounts = {}
    local itemTextures = {}
    local itemLinks = {}
    local itemOrder = {}
    local itemIsQuest = {}
    local itemIsQuestStarter = {}
    local itemQualities = {}

    -- Scan backpack and 4 bags
    for bagID = 0, 4 do
        local numSlots = GetContainerNumSlots(bagID)
        for slotID = 1, numSlots do
            local texture, count = GetContainerItemInfo(bagID, slotID)
            if texture then
                local link = GetContainerItemLink(bagID, slotID)
                local id = addon.Modules.Utils:ExtractItemID(link)
                if id and trackedIDs[id] then
                    if not itemCounts[id] then
                        itemCounts[id] = 0
                        itemTextures[id] = texture
                        itemLinks[id] = link
                        itemCounts[id .. "_bag"] = bagID
                        itemCounts[id .. "_slot"] = slotID
                        -- Check if quest item
                        local isQuest, isStarter = IsQuestItem(bagID, slotID)
                        itemIsQuest[id] = isQuest
                        itemIsQuestStarter[id] = isStarter
                        -- Get item quality
                        local _, _, itemQuality = GetItemInfo(id)
                        itemQualities[id] = tonumber(itemQuality)
                        table.insert(itemOrder, id)
                    end
                    itemCounts[id] = itemCounts[id] + count
                end
            end
        end
    end

    for _, id in ipairs(itemOrder) do
        local bagID = itemCounts[id .. "_bag"]
        local slotID = itemCounts[id .. "_slot"]
        local link = itemLinks[id]

        -- Detect unusable and junk status using centralized ItemDetection
        local isUnusable = false
        local isJunk = false
        if addon.Modules.ItemDetection and link then
            local itemData = { link = link }
            local props = addon.Modules.ItemDetection:GetItemProperties(itemData, bagID, slotID)
            isUnusable = props.isUnusable
            isJunk = props.isJunk
        end

        table.insert(trackedItemsInfo, {
            itemID = id,
            texture = itemTextures[id],
            count = itemCounts[id],
            link = link,
            bagID = bagID,
            slotID = slotID,
            isQuest = itemIsQuest[id],
            isQuestStarter = itemIsQuestStarter[id],
            isUnusable = isUnusable,
            isJunk = isJunk,
            quality = itemQualities[id],
        })
    end
end

-- Update the bar buttons
function TrackedItemBar:Update()
    local frame = Guda_TrackedItemBar
    
    if not frame then return end
    frame:Show()

    self:ScanForTrackedItems()

    local buttonSize = addon.Modules.DB:GetSetting("trackedBarSize") or 36
    local spacing = 2
    local xOffset = 5

    -- Update frame height based on button size
    frame:SetHeight(buttonSize + 8)
    
    -- Hide all buttons and their overlays initially
    for _, btn in ipairs(buttons) do
        btn:Hide()
        if btn.qualityBorder then btn.qualityBorder:Hide() end
        if btn.unusableOverlay then btn.unusableOverlay:Hide() end
        if btn.junkIcon then btn.junkIcon:Hide() end
    end

    for i, info in ipairs(trackedItemsInfo) do
        local button = buttons[i]
        if not button then
            button = CreateFrame("Button", "Guda_TrackedItemBarButton" .. i, frame, "Guda_ItemButtonTemplate")
            table.insert(buttons, button)

            -- Create quest border (golden)
            local questBorder = CreateFrame("Frame", nil, button)
            questBorder:SetFrameLevel(button:GetFrameLevel() + 6)
            questBorder:SetBackdrop({
                bgFile = nil,
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 12,
                insets = {left = 4, right = 4, top = 4, bottom = 4}
            })
            questBorder:SetBackdropBorderColor(1.0, 0.82, 0, 1)
            questBorder:Hide()
            button.questBorder = questBorder

            -- Create quality border (colored by rarity)
            local qualityBorder = CreateFrame("Frame", nil, button)
            qualityBorder:SetFrameLevel(button:GetFrameLevel() + 5)
            qualityBorder:SetBackdrop({
                bgFile = nil,
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 12,
                insets = {left = 4, right = 4, top = 4, bottom = 4}
            })
            qualityBorder:SetBackdropBorderColor(0, 0, 0, 0)
            qualityBorder:Hide()
            button.qualityBorder = qualityBorder

            -- Create quest icon (question mark in corner)
            local questIcon = CreateFrame("Frame", nil, button)
            questIcon:SetFrameLevel(button:GetFrameLevel() + 7)
            questIcon:SetWidth(16)
            questIcon:SetHeight(16)
            local iconTex = questIcon:CreateTexture(nil, "OVERLAY")
            iconTex:SetAllPoints(questIcon)
            iconTex:SetTexture("Interface\\GossipFrame\\ActiveQuestIcon")
            iconTex:SetTexCoord(0, 1, 0, 1)
            questIcon:Hide()
            button.questIcon = questIcon

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
                        addon.Modules.DB:SetSetting("trackedBarPosition", {point = point, relativePoint = relativePoint, x = x, y = y})
                    end
                end
            end)
        end

        button.hasItem = true
        button.itemData = { link = info.link }
        button.itemID = info.itemID
        button.bagID = info.bagID
        button.slotID = info.slotID
        button.isReadOnly = false -- Changed to false to allow interaction and tooltips showing usage
        
        local icon = getglobal(button:GetName() .. "IconTexture")
        icon:SetTexture(info.texture)
        icon:SetVertexColor(1.0, 1.0, 1.0, 1.0)
        
        local countText = getglobal(button:GetName() .. "Count")
        countText:SetText(info.count)
        countText:Show()
        
        button:SetScript("OnClick", function()
            if IsAltKeyDown() and arg1 == "LeftButton" then
                -- Un-track item
                local itemID = this.itemID
                if itemID then
                    local trackedIDs = addon.Modules.DB:GetSetting("trackedItems") or {}
                    trackedIDs[itemID] = nil
                    addon.Modules.DB:SetSetting("trackedItems", trackedIDs)
                    
                    -- Update everything
                    if Guda.Modules.BagFrame and Guda.Modules.BagFrame.Update then
                        Guda.Modules.BagFrame:Update()
                    end
                    TrackedItemBar:Update()
                end
            elseif not IsShiftKeyDown() then
                -- Use item
                if this.bagID and this.slotID then
                    UseContainerItem(this.bagID, this.slotID)
                end
            end
        end)
        
        button:SetScript("OnEnter", function()
            Guda_ItemButton_OnEnter(this)
        end)

        button:SetScript("OnLeave", function()
            Guda_ItemButton_OnLeave(this)
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

        -- Position and show/hide quality border
        if button.qualityBorder then
            button.qualityBorder:ClearAllPoints()
            button.qualityBorder:SetPoint("TOPLEFT", icon, "TOPLEFT", -5, 5)
            button.qualityBorder:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 5, -5)
            if info.quality and info.quality >= 1 then
                local r, g, b = 1, 1, 1
                if addon.Modules.Utils and addon.Modules.Utils.GetQualityColor then
                    r, g, b = addon.Modules.Utils:GetQualityColor(info.quality)
                end
                button.qualityBorder:SetBackdropBorderColor(r, g, b, 1)
                button.qualityBorder:Show()
            else
                button.qualityBorder:Hide()
            end
        end

        -- Position and show/hide quest border
        if button.questBorder then
            button.questBorder:ClearAllPoints()
            button.questBorder:SetPoint("TOPLEFT", icon, "TOPLEFT", -2, 2)
            button.questBorder:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, -2)
            if info.isQuest then
                button.questBorder:Show()
            else
                button.questBorder:Hide()
            end
        end

        -- Position and show/hide quest icon
        if button.questIcon then
            local questIconSize = math.max(12, math.min(20, buttonSize * 0.35))
            button.questIcon:SetWidth(questIconSize)
            button.questIcon:SetHeight(questIconSize)
            button.questIcon:ClearAllPoints()
            button.questIcon:SetPoint("TOPRIGHT", button, "TOPRIGHT", 1, 0)

            if info.isQuest then
                -- Set appropriate texture based on quest type
                local tex = button.questIcon:GetRegions()
                if tex and tex.SetTexture then
                    if info.isQuestStarter then
                        tex:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
                    else
                        tex:SetTexture("Interface\\GossipFrame\\ActiveQuestIcon")
                    end
                end
                button.questIcon:Show()
            else
                button.questIcon:Hide()
            end
        end

        -- Apply unusable red overlay (same as bag slot indicator)
        if info.isUnusable then
            if not button.unusableOverlay then
                local overlay = button:CreateTexture(nil, "OVERLAY")
                overlay:SetAllPoints(icon)
                overlay:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
                overlay:Hide()
                button.unusableOverlay = overlay
            end
            local r, g, b = 0.9, 0.2, 0.2
            if RED_FONT_COLOR then
                r, g, b = RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b
            end
            button.unusableOverlay:SetVertexColor(r, g, b, 0.45)
            button.unusableOverlay:Show()
        else
            if button.unusableOverlay then
                button.unusableOverlay:Hide()
            end
        end

        -- Apply junk vendor icon (same as bag slot indicator)
        if info.isJunk then
            if not button.junkIcon then
                local junkFrame = CreateFrame("Frame", nil, button)
                junkFrame:SetFrameStrata("HIGH")
                local junkTex = junkFrame:CreateTexture(nil, "OVERLAY")
                junkTex:SetAllPoints(junkFrame)
                junkTex:SetTexture("Interface\\GossipFrame\\VendorGossipIcon")
                junkTex:SetTexCoord(0, 1, 0, 1)
                junkFrame.texture = junkTex
                button.junkIcon = junkFrame
            end
            local junkIconSize = math.max(10, math.min(14, buttonSize * 0.30))
            button.junkIcon:SetWidth(junkIconSize)
            button.junkIcon:SetHeight(junkIconSize)
            button.junkIcon:ClearAllPoints()
            button.junkIcon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
            button.junkIcon:Show()
        else
            if button.junkIcon then
                button.junkIcon:Hide()
            end
        end

        button:Show()
    end

    local numItems = table.getn(trackedItemsInfo)
    if numItems > 0 then
        local newWidth = xOffset * 2 + numItems * (buttonSize + spacing) - spacing
        frame:SetWidth(newWidth)
        frame:Show()
    else
        frame:Hide()
    end
end

function TrackedItemBar:Initialize()
    local frame = CreateFrame("Frame", "Guda_TrackedItemBar", UIParent)
    frame:SetWidth(40)
    frame:SetHeight(45)
    frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 200) -- Default above quest bar
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    
    --addon:ApplyBackdrop(frame, "DEFAULT_FRAME")
    
    -- Handle dragging
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnMouseDown", function()
        if arg1 == "LeftButton" then
            if IsShiftKeyDown() and not (CursorHasItem and CursorHasItem()) then
                this:StartMoving()
                this.isMoving = true
            end
        end
    end)
    frame:SetScript("OnMouseUp", function()
        if arg1 == "LeftButton" and this.isMoving then
            this:StopMovingOrSizing()
            this.isMoving = false
            local point, _, relativePoint, x, y = this:GetPoint()
            addon.Modules.DB:SetSetting("trackedBarPosition", {point = point, relativePoint = relativePoint, x = x, y = y})
        end
    end)
    
    -- Restore position
    local pos = addon.Modules.DB:GetSetting("trackedBarPosition")
    if pos and pos.point then
        frame:ClearAllPoints()
        frame:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.x, pos.y)
    end
    
    -- Register for events with debouncing to prevent lag on rapid bag updates
    local bagUpdatePending = false
    addon.Modules.Events:Register("BAG_UPDATE", function()
        if bagUpdatePending then return end
        bagUpdatePending = true
        -- Debounce: wait 0.15 seconds before updating (uses pooled timer)
        Guda_ScheduleTimer(0.15, function()
            bagUpdatePending = false
            TrackedItemBar:Update()
        end)
    end, "TrackedItemBar")
    
    addon.Modules.Events:Register("PLAYER_ENTERING_WORLD", function()
        TrackedItemBar:Update()
    end, "TrackedItemBar")

    addon.Modules.Events:Register("PLAYER_LEVEL_UP", function()
        -- Delay to let client update internal player level before re-scanning tooltips
        Guda_ScheduleTimer(0.5, function()
            if addon.Modules.ItemDetection then
                addon.Modules.ItemDetection:ClearCache()
            end
            TrackedItemBar:Update()
        end)
    end, "TrackedItemBar")

    TrackedItemBar:Update()
    addon:Debug("TrackedItemBar initialized")
end

TrackedItemBar.isLoaded = true
