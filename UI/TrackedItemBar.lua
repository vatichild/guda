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

-- Create a hidden tooltip for scanning if needed (though we mostly use itemID)
local scanTooltip
local function GetScanTooltip()
    if not scanTooltip then
        scanTooltip = CreateFrame("GameTooltip", "Guda_TrackedBarScanTooltip", nil, "GameTooltipTemplate")
        scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end
    return scanTooltip
end

-- Scan bags for tracked items and calculate total counts
function TrackedItemBar:ScanForTrackedItems()
    trackedItemsInfo = {}
    local trackedIDs = addon.Modules.DB:GetSetting("trackedItems") or {}
    
    local itemCounts = {}
    local itemTextures = {}
    local itemLinks = {}
    local itemOrder = {}

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
                        table.insert(itemOrder, id)
                    end
                    itemCounts[id] = itemCounts[id] + count
                end
            end
        end
    end

    for _, id in ipairs(itemOrder) do
        table.insert(trackedItemsInfo, {
            itemID = id,
            texture = itemTextures[id],
            count = itemCounts[id],
            link = itemLinks[id]
        })
    end
end

-- Update the bar buttons
function TrackedItemBar:Update()
    local frame = Guda_TrackedItemBar
    
    if not frame then return end
    frame:Show()

    self:ScanForTrackedItems()
    
    local buttonSize = 37
    local spacing = 2
    local xOffset = 5
    
    -- Hide all buttons initially
    for _, btn in ipairs(buttons) do
        btn:Hide()
    end

    for i, info in ipairs(trackedItemsInfo) do
        local button = buttons[i]
        if not button then
            button = CreateFrame("Button", "Guda_TrackedItemBarButton" .. i, frame, "Guda_ItemButtonTemplate")
            table.insert(buttons, button)
            
            button:RegisterForDrag("LeftButton")
            button:SetScript("OnDragStart", function()
                if IsShiftKeyDown() then
                    this:GetParent():StartMoving()
                    this:GetParent().isMoving = true
                end
            end)
            button:SetScript("OnDragStop", function()
                local parent = this:GetParent()
                if parent.isMoving then
                    parent:StopMovingOrSizing()
                    parent.isMoving = false
                    local point, _, relativePoint, x, y = parent:GetPoint()
                    addon.Modules.DB:SetSetting("trackedBarPosition", {point = point, relativePoint = relativePoint, x = x, y = y})
                end
            end)
        end

        button.hasItem = true
        button.itemData = { link = info.link }
        button.itemID = info.itemID
        button.isReadOnly = true -- Don't allow regular clicks/interaction like usage? 
        -- Actually user didn't specify usage, but "action bar type" suggests it might be usable.
        -- But "tracked items" usually means materials or currencies.
        
        local icon = getglobal(button:GetName() .. "IconTexture")
        icon:SetTexture(info.texture)
        icon:SetVertexColor(1.0, 1.0, 1.0, 1.0)
        
        local countText = getglobal(button:GetName() .. "Count")
        countText:SetText(info.count)
        countText:Show()
        
        button:SetScript("OnClick", function()
            if IsControlKeyDown() then
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
    
    addon:ApplyBackdrop(frame, "DEFAULT_FRAME")
    
    -- Handle dragging
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function()
        this:StartMoving()
    end)
    frame:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        local point, _, relativePoint, x, y = this:GetPoint()
        addon.Modules.DB:SetSetting("trackedBarPosition", {point = point, relativePoint = relativePoint, x = x, y = y})
    end)
    
    -- Restore position
    local pos = addon.Modules.DB:GetSetting("trackedBarPosition")
    if pos and pos.point then
        frame:ClearAllPoints()
        frame:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.x, pos.y)
    end
    
    -- Register for events
    addon.Modules.Events:Register("BAG_UPDATE", function()
        TrackedItemBar:Update()
    end, "TrackedItemBar")
    
    addon.Modules.Events:Register("PLAYER_ENTERING_WORLD", function()
        TrackedItemBar:Update()
    end, "TrackedItemBar")

    TrackedItemBar:Update()
    addon:Debug("TrackedItemBar initialized")
end

TrackedItemBar.isLoaded = true
