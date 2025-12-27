-- FrameHelpers: central utilities for frame headers and bag parents
local addon = Guda

local FrameHelpers = {}
addon.Modules.FrameHelpers = FrameHelpers

-- Create or return a section header for a given frame prefix and container
function Guda_GetSectionHeader(framePrefix, containerName, index)
    local name = framePrefix .. "_SectionHeader" .. index
    local header = getglobal(name)
    if not header then
        local container = getglobal(containerName)
        header = CreateFrame("Frame", name, container)
        header:SetHeight(20)
        header:EnableMouse(true)
        local text = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", header, "LEFT", 0, 0)
        header.text = text

        header:SetScript("OnEnter", function()
            if this.fullName and this.isShortened then
                GameTooltip:SetOwner(this, "ANCHOR_TOP")
                GameTooltip:SetText(this.fullName)
                GameTooltip:Show()
            end
        end)
        header:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end
    header.inUse = true
    return header
end

-- Create or return a bag parent frame for a frame prefix and bag parents table
function Guda_GetBagParent(framePrefix, parentsTable, bagID, containerName)
    local container = getglobal(containerName)
    if not parentsTable[bagID] then
        local name = framePrefix .. "_BagParent" .. bagID
        parentsTable[bagID] = CreateFrame("Frame", name, container)
        parentsTable[bagID]:SetAllPoints(container)
        if parentsTable[bagID].SetID then
            parentsTable[bagID]:SetID(bagID)
        end
    end
    return parentsTable[bagID]
end
