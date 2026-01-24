-- Bank Frame
-- Bank viewing UI

local addon = Guda

local BankFrame = {}
addon.Modules.BankFrame = BankFrame

local currentViewChar = nil
function BankFrame:GetCurrentViewChar()
    return currentViewChar
end
local searchText = ""
local isReadOnlyMode = false  -- Track if viewing saved bank (read-only) or live bank (interactive)
local hiddenBankBags = {} -- Track which bank bags are hidden (bagID -> true/false)
local bankBagParents = {} -- Parent frames per bank bag (same approach as BagFrame)
local bankSlotToButton = {} -- Fast O(1) lookup: bankSlotToButton[bagID][slotID] = button
-- Track empty slots that should show as placeholders in Category View
-- Format: recentlyEmptiedSlots[bagID][slotID] = { category = "CategoryName", timestamp = time }
local recentlyEmptiedSlots = {}
-- Global click catcher for clearing bank search focus
local bankClickCatcher = nil

--=====================================================
-- Deferred Usability Tint System
-- Prevents false positives when item data isn't fully loaded on bank open
-- Uses debouncing to handle rapid open/close safely
--=====================================================
local bankUsabilityCheckFrame = nil
local BANK_USABILITY_CHECK_DELAY = 0.25 -- Delay before re-checking usability (seconds)

-- Cancel any pending deferred usability check
local function CancelBankDeferredUsabilityCheck()
    if bankUsabilityCheckFrame then
        bankUsabilityCheckFrame:Hide()
        bankUsabilityCheckFrame.pending = false
    end
end

-- Update usability tints on all visible bank item buttons
local function UpdateAllBankUsabilityTints()
    if not Guda_BankFrame or not Guda_BankFrame:IsShown() then return end

    for _, bagParent in pairs(bankBagParents) do
        if bagParent and bagParent.itemButtons then
            for button in pairs(bagParent.itemButtons) do
                if button.hasItem and button:IsShown() and Guda_ItemButton_UpdateUsableTint then
                    Guda_ItemButton_UpdateUsableTint(button)
                end
            end
        end
    end
end

-- Schedule a deferred usability check with debouncing
local function ScheduleBankDeferredUsabilityCheck()
    -- Create frame on first use
    if not bankUsabilityCheckFrame then
        bankUsabilityCheckFrame = CreateFrame("Frame")
        bankUsabilityCheckFrame:Hide()
        bankUsabilityCheckFrame.elapsed = 0
        bankUsabilityCheckFrame.pending = false
        bankUsabilityCheckFrame:SetScript("OnUpdate", function()
            this.elapsed = this.elapsed + arg1
            if this.elapsed >= BANK_USABILITY_CHECK_DELAY then
                this:Hide()
                this.pending = false
                -- Only run if bank is still open
                if Guda_BankFrame and Guda_BankFrame:IsShown() then
                    -- Clear detection cache and re-check all items
                    if addon.Modules.ItemDetection and addon.Modules.ItemDetection.ClearCache then
                        addon.Modules.ItemDetection:ClearCache()
                    end
                    UpdateAllBankUsabilityTints()
                end
            end
        end)
    end

    -- Reset timer (debounce behavior)
    bankUsabilityCheckFrame.elapsed = 0
    bankUsabilityCheckFrame.pending = true
    bankUsabilityCheckFrame:Show()
end

-- Clear recently emptied slots (called when view is reset or frame hidden)
function BankFrame:ClearRecentlyEmptiedSlots()
    for k in pairs(recentlyEmptiedSlots) do
        recentlyEmptiedSlots[k] = nil
    end
end

-- Mark a slot as recently emptied (preserves its category and sort info for placeholder display)
function BankFrame:MarkSlotAsEmptied(bagID, slotID, category, itemData)
    if not recentlyEmptiedSlots[bagID] then
        recentlyEmptiedSlots[bagID] = {}
    end
    -- Store sort-relevant properties from the original item to maintain position
    recentlyEmptiedSlots[bagID][slotID] = {
        category = category or "Miscellaneous",
        timestamp = GetTime(),
        -- Preserve sort properties from original item
        quality = itemData and itemData.quality or 0,
        name = itemData and itemData.name or "",
        iLevel = itemData and itemData.iLevel or 0,
    }
    addon:DebugCategory("Marked slot %d:%d as emptied (category: %s)", bagID, slotID, category or "Miscellaneous")
end

-- Check if a slot is marked as recently emptied
function BankFrame:IsSlotRecentlyEmptied(bagID, slotID)
    return recentlyEmptiedSlots[bagID] and recentlyEmptiedSlots[bagID][slotID]
end

-- Get the category of a recently emptied slot
function BankFrame:GetEmptiedSlotCategory(bagID, slotID)
    local info = recentlyEmptiedSlots[bagID] and recentlyEmptiedSlots[bagID][slotID]
    return info and info.category or nil
end

-- Remove a slot from recently emptied (when item is placed back)
function BankFrame:UnmarkSlotAsEmptied(bagID, slotID)
    if recentlyEmptiedSlots[bagID] then
        recentlyEmptiedSlots[bagID][slotID] = nil
    end
end

-- OnLoad
function Guda_BankFrame_OnLoad(self)
    -- Set up initial backdrop
    addon:ApplyBackdrop(self, "DEFAULT_FRAME")

    -- Set up search box placeholder
    local searchBox = getglobal(self:GetName().."_SearchBar_SearchBox")
    if searchBox then
        searchBox:SetText("Search bank...")
        searchBox:SetTextColor(0.5, 0.5, 0.5, 1)
    end

    -- Create invisible full-screen frame to catch clicks outside the bank frame while typing in search
    if not bankClickCatcher then
        bankClickCatcher = CreateFrame("Frame", "Guda_BankClickCatcher", UIParent)
        bankClickCatcher:SetFrameStrata("BACKGROUND")
        bankClickCatcher:SetAllPoints(UIParent)
        bankClickCatcher:EnableMouse(true)
        bankClickCatcher:Hide()

        bankClickCatcher:SetScript("OnMouseDown", function()
            if Guda_BankFrame_ClearSearch then
                Guda_BankFrame_ClearSearch()
            end
        end)
    end

end

-- OnShow
function Guda_BankFrame_OnShow(self)
    if BankFrame.EnsureBagButtonsInitialized then
        BankFrame:EnsureBagButtonsInitialized()
    end
    -- Enforce MoneyFrame bottom margin in case any runtime code repositions it
    local moneyFrame = getglobal("Guda_BankFrame_MoneyFrame")
    if moneyFrame and moneyFrame.ClearAllPoints and moneyFrame.SetPoint then
        moneyFrame:ClearAllPoints()
        moneyFrame:SetPoint("BOTTOMRIGHT", Guda_BankFrame, "BOTTOMRIGHT", -15, 10)
    end

    -- Apply border visibility setting
    if BankFrame.UpdateBorderVisibility then
        BankFrame:UpdateBorderVisibility()
    end

   	-- Apply search bar visibility setting
   	if BankFrame.UpdateSearchBarVisibility then
   		BankFrame:UpdateSearchBarVisibility()
   	end

   	-- Apply footer visibility setting
   	if BankFrame.UpdateFooterVisibility then
   		BankFrame:UpdateFooterVisibility()
   	end

	-- Apply frame transparency
	if Guda_ApplyBackgroundTransparency then
		Guda_ApplyBackgroundTransparency()
	end

   	BankFrame:Update()

    -- Schedule deferred usability check to fix false positives from uncached item data
    -- This runs after a short delay when item info is fully loaded by the WoW client
    ScheduleBankDeferredUsabilityCheck()
end

-- OnHide
function Guda_BankFrame_OnHide(self)
    -- Close any open dropdown menus when the bank frame is hidden
    CloseDropDownMenus()

    -- Clear any pending update
    bankPendingUpdate = false

    -- Cancel any pending throttled updates
    local throttleFrame = getglobal("Guda_BankUpdateThrottle")
    if throttleFrame then
        throttleFrame:Hide()
    end

    -- Cancel any pending deferred usability check (debounce safety)
    CancelBankDeferredUsabilityCheck()

    -- Clear recently emptied slots tracking (reset placeholders)
    BankFrame:ClearRecentlyEmptiedSlots()

    -- Clear isEmptyPlaceholder flags on all buttons (reset for next open)
    for bagID, slots in pairs(bankSlotToButton) do
        if type(slots) == "table" then
            for slotID, button in pairs(slots) do
                if button and button.isEmptyPlaceholder then
                    button.isEmptyPlaceholder = nil
                end
            end
        end
    end

    -- Close the actual Blizzard bank too
    local blizzardBankFrame = getglobal("BankFrame")
    if blizzardBankFrame and blizzardBankFrame:IsShown() then
        CloseBankFrame()
    end
end

-- Toggle visibility
function BankFrame:Toggle()
    if Guda_BankFrame:IsShown() then
        Guda_BankFrame:Hide()
    else
        Guda_BankFrame:Show()
    end
end

-- Show specific character's bank (read-only mode)
function BankFrame:ShowCharacter(fullName)
    currentViewChar = fullName
    isReadOnlyMode = true  -- Viewing saved bank data (read-only)
    self:Update()
end

-- Show current character's bank (interactive mode)
function BankFrame:ShowCurrentCharacter()
    currentViewChar = nil
    isReadOnlyMode = false  -- Viewing live bank (interactive)
    self:Update()
end

-- Update lock states of existing buttons (lightweight, used during drag)
function BankFrame:UpdateLockStates()
    Guda_UpdateLockStates(bankBagParents)
end

-- Update a single slot without full frame redraw (used for manual item moves)
function BankFrame:UpdateSingleSlot(bagID, slotID, passedButton)
    if not Guda_BankFrame:IsShown() then
        addon:DebugCategory("UpdateSingleSlot: frame not shown")
        return false
    end
    if currentViewChar then
        addon:DebugCategory("UpdateSingleSlot: viewing other char")
        return false
    end

    -- Use passed button if available (from UpdateChangedSlots iteration)
    -- This avoids type mismatch issues with slot ID keys (string vs number)
    local targetButton = passedButton

    if not targetButton then
        -- Fallback to O(1) button lookup using hash table
        if not bankSlotToButton[bagID] then
            addon:DebugCategory("UpdateSingleSlot: no slotToButton for bag %d", bagID)
            return false
        end
        -- Try both numeric and string keys to handle type mismatches
        targetButton = bankSlotToButton[bagID][slotID] or bankSlotToButton[bagID][tonumber(slotID)]
        if not targetButton then
            addon:DebugCategory("UpdateSingleSlot: no button for bag %d slot %d", bagID, slotID)
            return false
        end
    end

    -- Get fresh item data for this slot
    local itemLink = GetContainerItemLink(bagID, slotID)
    local itemData = nil

    if itemLink then
        local texture, itemCount, locked, quality = GetContainerItemInfo(bagID, slotID)
        local itemID = nil
        local _, _, idStr = string.find(itemLink, "item:(%d+)")
        if idStr then itemID = tonumber(idStr) end

        if itemID then
            local name, link, itemQuality, iLevel, _, itemType, stackCount, subType, _, equipLoc = GetItemInfo(itemID)
            itemData = {
                link = itemLink,
                texture = texture,
                count = itemCount or 1,
                quality = quality or itemQuality or 0,  -- Prefer GetContainerItemInfo, fallback to GetItemInfo
                name = name,
                iLevel = iLevel,
                type = itemType,
                subclass = subType,
                equipLoc = equipLoc,
                stackSize = stackCount or 1,
                locked = locked,
            }
        end
    end

    addon:DebugCategory("UpdateSingleSlot: bag=%d slot=%d hasItem=%s -> updating button", bagID, slotID, itemLink and "yes" or "no")

    -- Track when slot becomes empty in Category View (keep empty placeholder visible)
    local viewType = addon.Modules.DB:GetSetting("bankViewType") or "single"
    local hadItem = targetButton.itemData and targetButton.itemData.link
    local hasItem = itemData and itemData.link

    if viewType == "category" then
        if hadItem and not hasItem then
            -- Item was removed - show empty placeholder, keep button visible
            addon:DebugCategory("UpdateSingleSlot: slot %d:%d emptied, showing empty placeholder", bagID, slotID)
            -- Mark as still in use so cleanup doesn't hide it
            targetButton.inUse = true
            targetButton.isEmptyPlaceholder = true
            -- Also mark in recentlyEmptiedSlots for full redraw support
            local oldItemData = targetButton.itemData
            local oldCategory = "Miscellaneous"
            if oldItemData and oldItemData.link then
                oldCategory = addon.Modules.CategoryManager:CategorizeItem(oldItemData, bagID, slotID) or "Miscellaneous"
            end
            self:MarkSlotAsEmptied(bagID, slotID, oldCategory, oldItemData)
        elseif hasItem and not hadItem then
            -- Item was added
            targetButton.isEmptyPlaceholder = false
            self:UnmarkSlotAsEmptied(bagID, slotID)
        end
    end

    -- Update the button visually
    local matchesFilter = self:PassesSearchFilter(itemData)
    Guda_ItemButton_SetItem(targetButton, bagID, slotID, itemData, true, nil, matchesFilter, isReadOnlyMode)

    -- Ensure empty placeholders stay visible
    if viewType == "category" and targetButton.isEmptyPlaceholder then
        targetButton:Show()
    end

    return true
end

-- Update changed slots in a bank bag by comparing with cached data
-- Returns number of slots updated, or -1 if full redraw is needed
function BankFrame:UpdateChangedSlots(bagID)
    if not Guda_BankFrame:IsShown() then
        addon:DebugCategory("UpdateChangedSlots: frame not shown")
        return -1
    end
    if currentViewChar then
        addon:DebugCategory("UpdateChangedSlots: viewing other char")
        return -1
    end

    -- Check if we have the slot lookup table for this bag
    if not bankSlotToButton[bagID] then
        addon:DebugCategory("UpdateChangedSlots: no slotToButton for bag %d", bagID)
        return -1
    end

    local viewType = addon.Modules.DB:GetSetting("bankViewType") or "single"
    local isCategoryView = (viewType == "category")
    addon:DebugCategory("UpdateChangedSlots: bag=%d, viewType=%s, isCategoryView=%s",
        bagID, viewType, tostring(isCategoryView))

    if isCategoryView then
        -- In Category View: update slots that HAVE button mappings
        -- AND check for NEW items that arrived in slots without buttons
        local updatedCount = 0
        for slotID, targetButton in pairs(bankSlotToButton[bagID]) do
            local currentLink = GetContainerItemLink(bagID, slotID)
            local cachedLink = targetButton.itemData and targetButton.itemData.link or nil

            local needsUpdate = false
            if currentLink ~= cachedLink then
                needsUpdate = true
            elseif currentLink then
                local _, currentCount = GetContainerItemInfo(bagID, slotID)
                local cachedCount = targetButton.itemData and targetButton.itemData.count or 0
                if currentCount ~= cachedCount then
                    needsUpdate = true
                end
            end

            if needsUpdate then
                addon:DebugCategory("  slot %d: needs update (had=%s, now=%s)", slotID,
                    cachedLink and "item" or "empty", currentLink and "item" or "empty")
                -- Pass the button directly to avoid type mismatch lookup issues
                if self:UpdateSingleSlot(bagID, slotID, targetButton) then
                    updatedCount = updatedCount + 1
                else
                    addon:DebugCategory("  slot %d: UpdateSingleSlot failed -> full redraw", slotID)
                    return -1
                end
            end
        end

        -- CRITICAL: Check for NEW items that arrived in slots WITHOUT button mappings
        -- Category View only has buttons for filled slots, so new items need full redraw
        local numSlots = addon.Modules.Utils:GetBagSlotCount(bagID)
        if numSlots and numSlots > 0 then
            for checkSlotID = 1, numSlots do
                -- If slot has an item but no button mapping -> new item arrived
                -- Check both numeric and potential string keys
                local hasButton = bankSlotToButton[bagID][checkSlotID] or bankSlotToButton[bagID][tostring(checkSlotID)]
                if not hasButton then
                    local currentLink = GetContainerItemLink(bagID, checkSlotID)
                    if currentLink then
                        addon:DebugCategory("  slot %d: NEW item arrived (no button) -> full redraw", checkSlotID)
                        return -1  -- Trigger full redraw to categorize new item
                    end
                end
            end
        end

        addon:DebugCategory("UpdateChangedSlots (category): success, updated %d slots", updatedCount)
        return updatedCount
    else
        -- In Single View: check all slots
        local numSlots = addon.Modules.Utils:GetBagSlotCount(bagID)
        if not numSlots or numSlots == 0 then
            addon:DebugCategory("UpdateChangedSlots: no slots for bag %d", bagID)
            return -1
        end

        local updatedCount = 0
        for slotID = 1, numSlots do
            -- Try both numeric and string keys to handle type mismatches
            local targetButton = bankSlotToButton[bagID][slotID] or bankSlotToButton[bagID][tostring(slotID)]

            if not targetButton then
                addon:DebugCategory("  slot %d: no button in single view -> full redraw", slotID)
                return -1
            end

            local currentLink = GetContainerItemLink(bagID, slotID)
            local cachedLink = targetButton.itemData and targetButton.itemData.link or nil

            local needsUpdate = false
            if currentLink ~= cachedLink then
                needsUpdate = true
            elseif currentLink then
                local _, currentCount = GetContainerItemInfo(bagID, slotID)
                local cachedCount = targetButton.itemData and targetButton.itemData.count or 0
                if currentCount ~= cachedCount then
                    needsUpdate = true
                end
            end

            if needsUpdate then
                addon:DebugCategory("  slot %d: needs update (had=%s, now=%s)", slotID,
                    cachedLink and "item" or "empty", currentLink and "item" or "empty")
                -- Pass the button directly to avoid type mismatch lookup issues
                if self:UpdateSingleSlot(bagID, slotID, targetButton) then
                    updatedCount = updatedCount + 1
                else
                    addon:DebugCategory("  slot %d: UpdateSingleSlot failed -> full redraw", slotID)
                    return -1
                end
            end
        end
        addon:DebugCategory("UpdateChangedSlots (single): success, updated %d slots", updatedCount)
        return updatedCount
    end
end

-- Deferred update state for frame budgeting
local bankPendingUpdate = false
local bankUpdateDebounceFrame = nil
local BANK_UPDATE_DEBOUNCE_TIME = 0.05  -- 50ms debounce for rapid updates

-- Schedule an update with debouncing (prevents multiple updates in rapid succession)
function BankFrame:ScheduleUpdate()
    if bankPendingUpdate then return end
    bankPendingUpdate = true

    if not bankUpdateDebounceFrame then
        bankUpdateDebounceFrame = CreateFrame("Frame")
        bankUpdateDebounceFrame.elapsed = 0
    end

    bankUpdateDebounceFrame.elapsed = 0
    bankUpdateDebounceFrame:SetScript("OnUpdate", function()
        this.elapsed = this.elapsed + arg1
        if this.elapsed >= BANK_UPDATE_DEBOUNCE_TIME then
            this:SetScript("OnUpdate", nil)
            bankPendingUpdate = false
            BankFrame:Update()
        end
    end)
end

-- Update display
function BankFrame:Update()
    if not Guda_BankFrame:IsShown() then
        return
    end

    -- Report entry for frame budget tracking
    if addon.Modules.Utils and addon.Modules.Utils.ReportEntry then
        addon.Modules.Utils:ReportEntry()
    end

    -- If cursor is holding an item (mid-drag), only update lock states, don't rebuild UI
    -- BUT only if we already have items displayed - otherwise we need to do initial build
    if CursorHasItem and CursorHasItem() then
        -- Check if we have any displayed items
        local hasDisplayedItems = false
        for _, bankBagParent in pairs(bankBagParents) do
            if bankBagParent and bankBagParent.itemButtons then
                for button in pairs(bankBagParent.itemButtons) do
                    if button.hasItem and button:IsShown() then
                        hasDisplayedItems = true
                        break
                    end
                end
            end
            if hasDisplayedItems then break end
        end

        if hasDisplayedItems then
            self:UpdateLockStates()
            return
        end
        -- If no items displayed yet, continue with full update
    end

    -- Mark all existing buttons as not in use (we'll mark active ones during display)
    -- Also clear the slot lookup table for fresh rebuild
    for _, bankBagParent in pairs(bankBagParents) do
        if bankBagParent and bankBagParent.itemButtons then
            for button in pairs(bankBagParent.itemButtons) do
                if button.hasItem ~= nil then
                    button.inUse = false
                end
            end
        end
    end
    for k in pairs(bankSlotToButton) do
        bankSlotToButton[k] = nil
    end

    -- Determine if we're in read-only mode:
    -- - If viewing another character → read-only
    -- - If bank is actually open → interactive (live)
    -- - Otherwise → read-only (viewing saved data)
    local bankIsOpen = addon.Modules.BankScanner:IsBankOpen()
    isReadOnlyMode = currentViewChar ~= nil or not bankIsOpen

    local bankData
    local isOtherChar = false
    local charName = ""

    if currentViewChar then
        -- Viewing another character's saved bank
        bankData = addon.Modules.DB:GetCharacterBank(currentViewChar)
        isOtherChar = true
        charName = currentViewChar
        getglobal("Guda_BankFrame_Title"):SetText(currentViewChar .. "'s Bank")
    else
        -- Viewing current character's bank
        -- Use live data if bank is officially open OR if we can access bank data
        -- (handles edge cases where IsBankOpen returns false but bank is still accessible)
        local useLiveData = bankIsOpen
        if not useLiveData then
            -- Try to get live data anyway - if bank bags are accessible, use live data
            local testSlots = GetContainerNumSlots(-1)  -- Main bank
            if testSlots and testSlots > 0 then
                useLiveData = true
                addon:DebugCategory("Update: IsBankOpen=false but bank accessible, using live data")
            end
        end

        local playerName = addon.Modules.DB:GetPlayerFullName()
        if useLiveData then
            -- Bank is accessible - use live data
            bankData = addon.Modules.BankScanner:GetBankData()
            getglobal("Guda_BankFrame_Title"):SetText(playerName .. "'s Bank")
        else
            -- Bank is truly closed - use saved data (read-only mode)
            bankData = addon.Modules.DB:GetCharacterBank(playerName)
            getglobal("Guda_BankFrame_Title"):SetText(playerName .. "'s Bank")
        end
    end

    local viewType = addon.Modules.DB:GetSetting("bankViewType") or "single"
    
    -- Reset all section headers before displaying items
    local i = 1
    while true do
        local header = getglobal("Guda_BankFrame_SectionHeader" .. i)
        if not header then break end
        header.inUse = false
        header:Hide()
        i = i + 1
    end

    if viewType == "category" then
        -- Debug: check bankData before display
        local bagCount = 0
        local totalItems = 0
        for bagID, bag in pairs(bankData or {}) do
            bagCount = bagCount + 1
            if bag and bag.slots then
                for slotID, item in pairs(bag.slots) do
                    if item then
                        totalItems = totalItems + 1
                    end
                end
            end
        end
        addon:DebugCategory("Update: bankData has %d bags, %d total items", bagCount, totalItems)
        self:DisplayItemsByCategory(bankData, isOtherChar, charName)
        -- Show sort button with merge icon/tooltip for category view
        local sortBtn = getglobal("Guda_BankFrame_SortButton")
        if sortBtn then
            sortBtn:Show()
            sortBtn.isCategoryView = true
        end
    else
        self:DisplayItems(bankData, isOtherChar, charName)
        local sortBtn = getglobal("Guda_BankFrame_SortButton")
        if sortBtn then
            sortBtn:Show()
            sortBtn.isCategoryView = false
        end
    end

    -- Update money
    self:UpdateMoney()

    -- Update bank slots info
    self:UpdateBankSlotsInfo(bankData, isOtherChar)

    -- Clean up unused buttons AFTER display is complete (prevents drag/drop issues)
    for _, bankBagParent in pairs(bankBagParents) do
        if bankBagParent and bankBagParent.itemButtons then
            for button in pairs(bankBagParent.itemButtons) do
                if button.hasItem ~= nil and not button.inUse then
                    button:Hide()
                    button:ClearAllPoints()
                end
            end
        end
    end

    -- Record performance metrics
    if addon.Modules.Utils and addon.Modules.Utils.RecordUpdateEnd then
        addon.Modules.Utils:RecordUpdateEnd()
    end
end

-- Use centralized frame helpers for section headers and bag parents
function BankFrame:GetSectionHeader(index)
    return Guda_GetSectionHeader("Guda_BankFrame", "Guda_BankFrame_ItemContainer", index)
end

function BankFrame:GetBagParent(bagID)
    return Guda_GetBagParent("Guda_BankFrame", bankBagParents, bagID, "Guda_BankFrame_ItemContainer")
end

-- Display items by category
function BankFrame:DisplayItemsByCategory(bankData, isOtherChar, charName)
    local buttonSize = addon.Modules.DB:GetSetting("iconSize") or addon.Constants.BUTTON_SIZE
    local spacing = addon.Modules.DB:GetSetting("iconSpacing") or addon.Constants.BUTTON_SPACING
    local perRow = addon.Modules.DB:GetSetting("bankColumns") or 10
    local itemContainer = getglobal("Guda_BankFrame_ItemContainer")

    -- Use centralized category initialization
    local categories, specialItems = Guda_InitCategories()
    local categoryList = Guda_CategoryList

    -- Categorize all items using centralized function
    local totalItemsCategorized = 0
    for _, bagID in ipairs(addon.Constants.BANK_BAGS) do
        if not hiddenBankBags[bagID] then
            local bag = bankData[bagID]
            if bag and bag.slots then
                local bagItemCount = 0
                for slotID, itemData in pairs(bag.slots) do
                    if itemData then
                        Guda_CategorizeItem(itemData, bagID, slotID, categories, specialItems, isOtherChar)
                        bagItemCount = bagItemCount + 1
                        totalItemsCategorized = totalItemsCategorized + 1
                    end
                end
                if bagItemCount > 0 then
                    addon:DebugCategory("DisplayItemsByCategory: bag %d has %d items", bagID, bagItemCount)
                end
            else
                addon:DebugCategory("DisplayItemsByCategory: bag %d has no data (bag=%s, slots=%s)",
                    bagID, tostring(bag ~= nil), tostring(bag and bag.slots ~= nil))
            end
        end
    end
    addon:DebugCategory("DisplayItemsByCategory: total items categorized = %d", totalItemsCategorized)

    -- Add recently emptied slots as empty placeholders in their respective categories
    -- This preserves the visual position of items that were just moved out
    if not isOtherChar then
        for bagID, slots in pairs(recentlyEmptiedSlots) do
            if not hiddenBankBags[bagID] then
                for slotID, info in pairs(slots) do
                    -- Only add if slot is actually empty (not refilled)
                    local currentLink = GetContainerItemLink(bagID, slotID)
                    if not currentLink then
                        local catName = info.category
                        if catName and categories[catName] then
                            -- Add empty placeholder to category with original item's sort properties
                            -- This keeps the placeholder in the same visual position as the original item
                            table.insert(categories[catName], {
                                bagID = bagID,
                                slotID = slotID,
                                itemData = {
                                    -- Fake itemData with sort-relevant properties from original item
                                    quality = info.quality or 0,
                                    name = info.name or "",
                                    iLevel = info.iLevel or 0,
                                },
                                isEmpty = true,  -- Mark as placeholder (display will show empty slot)
                            })
                            addon:DebugCategory("Added empty placeholder for %d:%d to category %s", bagID, slotID, catName)
                        end
                    else
                        -- Slot has item now, remove from tracking
                        slots[slotID] = nil
                    end
                end
            end
        end
    end

    -- Calculate total empty slots and find first available one for drop target
    local totalFreeSlots = 0
    local firstFreeBag, firstFreeSlot
    for _, bagID in ipairs(addon.Constants.BANK_BAGS) do
        if not hiddenBankBags[bagID] then
            local bag = bankData[bagID]
            if bag then
                totalFreeSlots = totalFreeSlots + (bag.freeSlots or 0)
                if not firstFreeBag and (bag.freeSlots or 0) > 0 then
                    for s = 1, (bag.numSlots or 0) do
                        if not bag.slots or not bag.slots[s] then
                            firstFreeBag = bagID
                            firstFreeSlot = s
                            break
                        end
                    end
                end
            end
        end
    end

    -- Layout
    local startX, startY = 5, -10
    local currentX, currentY = 0, 0
    local rowMaxHeight = 0
    local headerIdx = 1
    local totalWidth = perRow * (buttonSize + spacing)

    -- Frame budget tracking for category item processing
    local categoryItemsProcessed = 0
    local CATEGORY_ITEMS_PER_BUDGET_CHECK = 8

    for _, catName in ipairs(categoryList) do
        local items = categories[catName]
        local numItems = items and table.getn(items) or 0
        if numItems > 0 then
            -- Sort items using centralized sorter
            Guda_SortCategoryItems(items)

            local blockCols = numItems
            if blockCols > perRow then blockCols = perRow end
            local blockRows = math.ceil(numItems / perRow)
            local blockWidth = blockCols * (buttonSize + spacing)
            local blockHeight = 20 + (blockRows * (buttonSize + spacing)) + 5

            -- Check if it fits in current row
            if currentX > 0 and currentX + blockWidth + 20 > totalWidth + 5 then
                currentX = 0
                currentY = currentY + rowMaxHeight
                rowMaxHeight = 0
            end

            -- Add Header
            local header = self:GetSectionHeader(headerIdx)
            headerIdx = headerIdx + 1
            header:SetPoint("TOPLEFT", itemContainer, "TOPLEFT", startX + currentX, startY - currentY)
            header:SetWidth(blockWidth)
            
            local displayName = catName
            header.fullName = catName
            header.isShortened = false
            if string.len(displayName) > 10 and numItems < 2 then
                displayName = string.sub(displayName, 1, 7) .. "..."
                header.isShortened = true
            end
            header.text:SetText(displayName)
            header:Show()
            
            local itemY = currentY + 20
            local col = 0
            local row = 0
            for _, item in ipairs(items) do
                local bagID = item.bagID
                local slot = item.slotID
                -- For empty placeholders, pass nil itemData so button shows as empty slot
                local itemData = item.isEmpty and nil or item.itemData

                local bagParent = self:GetBagParent(bagID)
                local button = Guda_GetItemButton(bagParent)

                button:SetParent(bagParent)
                button:SetWidth(buttonSize)
                button:SetHeight(buttonSize)
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT", itemContainer, "TOPLEFT", startX + currentX + (col * (buttonSize + spacing)), startY - (itemY + (row * (buttonSize + spacing))))
                button:Show()

                local matchesFilter = self:PassesSearchFilter(itemData)
                Guda_ItemButton_SetItem(button, bagID, slot, itemData, true, isOtherChar and charName or nil, matchesFilter, isOtherChar or isReadOnlyMode)
                button.inUse = true
                button.itemCategory = catName  -- Track category for empty slot placeholders
                button.isEmptyPlaceholder = item.isEmpty  -- Track if this is a placeholder
                -- Populate slot lookup for O(1) access
                if not bankSlotToButton[bagID] then bankSlotToButton[bagID] = {} end
                bankSlotToButton[bagID][slot] = button
                -- Remove from recently emptied only if slot now has an item (not a placeholder)
                if itemData then
                    self:UnmarkSlotAsEmptied(bagID, slot)
                end

                col = col + 1
                if col >= blockCols then
                    col = 0
                    row = row + 1
                end

                -- Frame budget check
                categoryItemsProcessed = categoryItemsProcessed + 1
                if categoryItemsProcessed >= CATEGORY_ITEMS_PER_BUDGET_CHECK then
                    categoryItemsProcessed = 0
                    if addon.Modules.Utils and addon.Modules.Utils.CheckTimeout and addon.Modules.Utils:CheckTimeout() then
                        addon.Modules.Utils:ReportEntry()
                    end
                end
            end

            if blockHeight > rowMaxHeight then rowMaxHeight = blockHeight end
            currentX = currentX + blockWidth + 20
        end
    end

    -- Update Y for bottom sections
    local y = currentY + rowMaxHeight
    
    -- Special sections at bottom (Hearthstone, Mount, Tools, Empty)
    local bottomSections = {
        { name = "Home", items = specialItems.Hearthstone },
        { name = "Mounts", items = specialItems.Mount },
        { name = "Tools", items = specialItems.Tools },
        { name = "Empty", items = {} }
    }
    
    local x = startX
    y = startY - y
    
    local hasAnyBottom = false
    for _, sec in ipairs(bottomSections) do
        if table.getn(sec.items) > 0 then
            hasAnyBottom = true
            break
        end
    end
    -- Also show bottom section if there are free slots (for Empty drop target)
    if totalFreeSlots > 0 then
        hasAnyBottom = true
    end

    if hasAnyBottom then
        y = y - 10
        local currentBottomX = 0
        local sectionMaxHeight = 0

        for _, sec in ipairs(bottomSections) do
            local items = sec.items
            local numItems = table.getn(items)
            if sec.name == "Empty" then
                numItems = (totalFreeSlots > 0) and 1 or 0
            end
            if numItems > 0 then
                if sec.name == "Tools" then
                    table.sort(items, function(a, b)
                        -- Guard against nil entries
                        if not a or not a.itemData then return false end
                        if not b or not b.itemData then return true end
                        if (a.itemData.quality or 0) ~= (b.itemData.quality or 0) then
                            return (a.itemData.quality or 0) > (b.itemData.quality or 0)
                        end
                        return (a.itemData.name or "") < (b.itemData.name or "")
                    end)
                end

                local blockCols = numItems
                if blockCols > perRow then blockCols = perRow end
                local blockRows = math.ceil(numItems / perRow)
                local blockWidth = blockCols * (buttonSize + spacing)
                local blockHeight = 20 + (blockRows * (buttonSize + spacing))

                if currentBottomX > 0 and currentBottomX + blockWidth + 20 > totalWidth + 5 then
                    currentBottomX = 0
                    y = y - sectionMaxHeight - 5
                    sectionMaxHeight = 0
                end

                local header = self:GetSectionHeader(headerIdx)
                headerIdx = headerIdx + 1
                header:SetPoint("TOPLEFT", itemContainer, "TOPLEFT", x + currentBottomX, y)
                header:SetWidth(blockWidth)
                header.text:SetText(sec.name)
                header:Show()

                local itemY = y - 20
                local sCol = 0
                local sRow = 0
                
                if sec.name == "Empty" then
                    local bagID = firstFreeBag or -1
                    local slotID = firstFreeSlot or 1
                    local bagParent = self:GetBagParent(bagID)
                    local button = Guda_GetItemButton(bagParent)
                    button:SetParent(bagParent)
                    button:SetWidth(buttonSize)
                    button:SetHeight(buttonSize)
                    button:ClearAllPoints()
                    button:SetPoint("TOPLEFT", itemContainer, "TOPLEFT", x + currentBottomX, itemY)
                    button:Show()
                    
                    local emptyItemData = { 
                        texture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag", 
                        count = totalFreeSlots, 
                        name = "Empty Slots" 
                    }
                    Guda_ItemButton_SetItem(button, bagID, slotID, emptyItemData, true, isOtherChar and charName or nil, true, true)
                    button.isReadOnly = false
                    button.inUse = true
                else
                    for _, item in ipairs(items) do
                        local bagParent = self:GetBagParent(item.bagID)
                        local button = Guda_GetItemButton(bagParent)
                        button:SetParent(bagParent)
                        button:SetWidth(buttonSize)
                        button:SetHeight(buttonSize)
                        button:ClearAllPoints()
                        button:SetPoint("TOPLEFT", itemContainer, "TOPLEFT", x + currentBottomX + (sCol * (buttonSize + spacing)), itemY - (sRow * (buttonSize + spacing)))
                        button:Show()
                        Guda_ItemButton_SetItem(button, item.bagID, item.slotID, item.itemData, true, isOtherChar and charName or nil, self:PassesSearchFilter(item.itemData), isOtherChar or isReadOnlyMode)
                        button.inUse = true
                        -- Populate slot lookup for O(1) access
                        if not bankSlotToButton[item.bagID] then bankSlotToButton[item.bagID] = {} end
                        bankSlotToButton[item.bagID][item.slotID] = button

                        sCol = sCol + 1
                        if sCol >= blockCols then
                            sCol = 0
                            sRow = sRow + 1
                        end
                    end
                end

                if blockHeight > sectionMaxHeight then sectionMaxHeight = blockHeight end
                currentBottomX = currentBottomX + blockWidth + 20
                
                if currentBottomX >= totalWidth then
                    currentBottomX = 0
                    y = y - sectionMaxHeight - 5
                    sectionMaxHeight = 0
                end
            end
        end
        
        if currentBottomX > 0 then
            y = y - sectionMaxHeight
        end
    end
    
    local finalHeight = math.abs(y) + 20
    itemContainer:SetHeight(finalHeight)
    self:ResizeFrame(nil, nil, perRow, finalHeight)
end

-- Display items
function BankFrame:DisplayItems(bankData, isOtherChar, charName)
    local x, y = 5, -10
    local row = 0
    local col = 0
    local buttonSize = addon.Modules.DB:GetSetting("iconSize") or addon.Constants.BUTTON_SIZE
    local spacing = addon.Modules.DB:GetSetting("iconSpacing") or addon.Constants.BUTTON_SPACING
    local perRow = addon.Modules.DB:GetSetting("bankColumns") or 10
    local itemContainer = getglobal("Guda_BankFrame_ItemContainer")

    -- Separate bank bags into regular, enchant, herb, soul, quiver, and ammo types
    local regularBags = {}
    local enchantBags = {}
    local herbBags = {}
    local soulBags = {}
    local quiverBags = {}
    local ammoBags = {}

    for _, bagID in ipairs(addon.Constants.BANK_BAGS) do
        if not hiddenBankBags[bagID] then
            local bagType
            if isOtherChar then
                -- Use saved bag type for other characters
                local bagSaved = bankData and bankData[bagID]
                bagType = bagSaved and bagSaved.bagType or "regular"
            else
                -- Unified live detection for current character when bank is open
                bagType = addon.Modules.Utils:GetSpecializedBagType(bagID) or "regular"
            end

            if bagType == "enchant" then
                table.insert(enchantBags, bagID)
            elseif bagType == "herb" then
                table.insert(herbBags, bagID)
            elseif bagType == "soul" then
                table.insert(soulBags, bagID)
            elseif bagType == "quiver" then
                table.insert(quiverBags, bagID)
            elseif bagType == "ammo" then
                table.insert(ammoBags, bagID)
            else
                table.insert(regularBags, bagID)
            end
        end
    end

    -- Build display order: regular -> enchant -> herb -> soul -> quiver -> ammo
    local bagsToShow = {}
    for _, bagID in ipairs(regularBags) do
        table.insert(bagsToShow, { bagID = bagID, needsSpacing = false })
    end
    if table.getn(enchantBags) > 0 then
        for i, bagID in ipairs(enchantBags) do
            table.insert(bagsToShow, { bagID = bagID, needsSpacing = (i == 1) })
        end
    end
    if table.getn(herbBags) > 0 then
        for i, bagID in ipairs(herbBags) do
            table.insert(bagsToShow, { bagID = bagID, needsSpacing = (i == 1) })
        end
    end
    if table.getn(soulBags) > 0 then
        for i, bagID in ipairs(soulBags) do
            table.insert(bagsToShow, { bagID = bagID, needsSpacing = (i == 1) })
        end
    end
    if table.getn(quiverBags) > 0 then
        for i, bagID in ipairs(quiverBags) do
            table.insert(bagsToShow, { bagID = bagID, needsSpacing = (i == 1) })
        end
    end
    if table.getn(ammoBags) > 0 then
        for i, bagID in ipairs(ammoBags) do
            table.insert(bagsToShow, { bagID = bagID, needsSpacing = (i == 1) })
        end
    end

    -- Frame budget tracking for item processing
    local itemsProcessed = 0
    local ITEMS_PER_BUDGET_CHECK = 8  -- Check budget every N items

    for _, bagInfo in ipairs(bagsToShow) do
        local bagID = bagInfo.bagID
        local bag = bankData and bankData[bagID]

        -- Add spacing before first of each specialized section
        if bagInfo.needsSpacing then
            if col > 0 then
                col = 0
                row = row + 1
            end
            row = row + 0.5
        end

        -- Get slot count for this bag
        local numSlots
        if isOtherChar and bag and bag.numSlots then
            numSlots = bag.numSlots
        else
            numSlots = addon.Modules.Utils:GetBagSlotCount(bagID)
        end

        if numSlots and numSlots > 0 then
            for slot = 1, numSlots do
                local itemData = bag and bag.slots and bag.slots[slot] or nil

                local matchesFilter = self:PassesSearchFilter(itemData)

                -- Ensure a per-bag parent frame exists and carries the bag ID
                local bankBagParent = self:GetBagParent(bagID)

                local button = Guda_GetItemButton(bankBagParent)
                button.inUse = true

                local xPos = x + (col * (buttonSize + spacing))
                local yPos = y - (row * (buttonSize + spacing))

                button:ClearAllPoints()
                button:SetPoint("TOPLEFT", itemContainer, "TOPLEFT", xPos, yPos)

                Guda_ItemButton_SetItem(button, bagID, slot, itemData, true, isOtherChar and charName or nil, matchesFilter, isReadOnlyMode)
                -- Populate slot lookup for O(1) access
                if not bankSlotToButton[bagID] then bankSlotToButton[bagID] = {} end
                bankSlotToButton[bagID][slot] = button

                col = col + 1
                if col >= perRow then
                    col = 0
                    row = row + 1
                end

                -- Frame budget check: periodically check if we've exceeded the frame budget
                itemsProcessed = itemsProcessed + 1
                if itemsProcessed >= ITEMS_PER_BUDGET_CHECK then
                    itemsProcessed = 0
                    if addon.Modules.Utils and addon.Modules.Utils.CheckTimeout and addon.Modules.Utils:CheckTimeout() then
                        -- Budget exceeded - reset entry time and continue
                        addon.Modules.Utils:ReportEntry()
                    end
                end
            end
        end
    end

    -- Resize frame dynamically based on content
    self:ResizeFrame(row, col, perRow)
end

-- Resize bank frame based on number of rows and columns
function BankFrame:ResizeFrame(currentRow, currentCol, columns, overrideHeight)
    local buttonSize = addon.Modules.DB:GetSetting("iconSize") or addon.Constants.BUTTON_SIZE
    local spacing = addon.Modules.DB:GetSetting("iconSpacing") or addon.Constants.BUTTON_SPACING

    -- Calculate actual number of rows used
    local totalRows = (currentRow or 0) + 1
    if totalRows < 1 then
        totalRows = 1
    end

    -- Ensure at least 1 column
    if not columns or columns < 1 then
        columns = 1
    end

    -- Calculate required dimensions
    local containerWidth = (columns * (buttonSize + spacing)) + 10
    local containerHeight = overrideHeight or ((totalRows * (buttonSize + spacing)) + 20)
    local frameWidth = containerWidth + 30

    -- Check if search bar is visible
    local showSearchBar = addon.Modules.DB:GetSetting("showSearchBar")
    if showSearchBar == nil then
        showSearchBar = true
    end

    -- Adjust frame height based on search bar visibility
    -- Footer height varies: less space when search bar is hidden
    local titleHeight = 40
    local searchBarHeight = 30
    local footerHeight = 40
    local frameHeight

    local hideFooter = addon.Modules.DB:GetSetting("hideFooter")

    if hideFooter then
        footerHeight = 10 -- Small padding at bottom
        frameHeight = containerHeight + titleHeight + (showSearchBar and searchBarHeight or 0) + footerHeight
    elseif showSearchBar then
        frameHeight = containerHeight + titleHeight + searchBarHeight + footerHeight  -- 125 total
    else
        frameHeight = containerHeight + titleHeight + footerHeight  -- 80 total
    end

    -- Minimum sizes
    if containerWidth < 200 then
        containerWidth = 200
        frameWidth = 230
    end
    if containerHeight < 150 then
        containerHeight = 150
    end
    if frameHeight < 250 then
        frameHeight = 250
    end

    -- Maximum sizes
    if containerWidth > 1250 then
        containerWidth = 1250
        frameWidth = 1280
    end
    if containerHeight > 1000 then
        containerHeight = 1000
    end
    if frameHeight > 1200 then
        frameHeight = 1200
    end

    local bankFrame = getglobal("Guda_BankFrame")
    local itemContainer = getglobal("Guda_BankFrame_ItemContainer")

    if bankFrame then
        bankFrame:SetWidth(frameWidth)
        bankFrame:SetHeight(frameHeight)
    end

    if itemContainer then
        itemContainer:SetWidth(containerWidth)
        itemContainer:SetHeight(containerHeight)
    end

    -- Resize search bar to match container width
    local searchBar = getglobal("Guda_BankFrame_SearchBar")
    if searchBar then
        searchBar:SetWidth(containerWidth)
    end
end

-- Update bank slots info text
function BankFrame:UpdateBankSlotsInfo(bankData, isOtherChar)
    local infoText = getglobal("Guda_BankFrame_Toolbar_BankSlotsInfo_Text")
    if not infoText then return end

    local totalSlots = 0
    local usedSlots = 0

    -- Count slots in bank bags
    for _, bagID in ipairs(addon.Constants.BANK_BAGS) do
        local bag = bankData[bagID]

        -- Get slot count for this bag
        local numSlots
        if isOtherChar and bag and bag.numSlots then
            numSlots = bag.numSlots
        else
            numSlots = addon.Modules.Utils:GetBagSlotCount(bagID)
        end

        if numSlots and numSlots > 0 then
            totalSlots = totalSlots + numSlots

            -- Count used slots
            if bag and bag.slots then
                for slot = 1, numSlots do
                    if bag.slots[slot] then
                        usedSlots = usedSlots + 1
                    end
                end
            end
        end
    end

    -- Format: "24 / 80" (used / total)
    infoText:SetText(string.format("%d / %d", usedSlots, totalSlots))
    infoText:SetTextColor(0.7, 0.7, 0.7)
end

-- Update money display
function BankFrame:UpdateMoney()
    local hideFooter = addon.Modules.DB:GetSetting("hideFooter")
    local moneyFrame = getglobal("Guda_BankFrame_MoneyFrame")

    if hideFooter then
        if moneyFrame then moneyFrame:Hide() end
        return
    end

    if not moneyFrame then
        addon:Debug("Bank MoneyFrame not found! Checking parent...")
        addon:Debug("Guda_BankFrame exists: " .. tostring(getglobal("Guda_BankFrame") ~= nil))

        -- Try to create it manually
        self:CreateMoneyFrame()
        moneyFrame = getglobal("Guda_BankFrame_MoneyFrame")
    end

    if moneyFrame then
        MoneyFrame_Update("Guda_BankFrame_MoneyFrame", GetMoney())
        moneyFrame:Show()

        -- Ensure tooltip overlay exists
        self:EnsureMoneyTooltipOverlay()
    else
        addon:Debug("Still couldn't find or create Bank MoneyFrame!")
    end
end

-- Create MoneyFrame if it doesn't exist
function BankFrame:CreateMoneyFrame()
    local moneyFrame = CreateFrame("Frame", "Guda_BankFrame_MoneyFrame", Guda_BankFrame, "SmallMoneyFrameTemplate")
    moneyFrame:SetPoint("BOTTOMRIGHT", Guda_BankFrame, "BOTTOMRIGHT", -10, 10)
    moneyFrame:SetWidth(180)
    moneyFrame:SetHeight(35)

    -- Set up OnLoad handler
    Guda_BankFrame_MoneyFrame_OnLoad(moneyFrame)

    addon:Debug("Bank MoneyFrame created via CreateMoneyFrame")
end

-- Money frame OnLoad handler
function Guda_BankFrame_MoneyFrame_OnLoad(self)
    addon:Debug("Bank MoneyFrame OnLoad called for: " .. self:GetName())

    -- Set tooltip handlers on money denomination buttons
    local buttons = {"GoldButton", "SilverButton", "CopperButton"}

    for _, buttonName in ipairs(buttons) do
        local fullName = self:GetName() .. buttonName
        local button = getglobal(fullName)
        if button then
            button:SetScript("OnEnter", function()
                Guda_BankFrame_MoneyOnEnter(this:GetParent())
            end)
            button:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        end
    end

    -- Also set handlers on parent frame
    self:EnableMouse(true)
    self:SetScript("OnEnter", function()
        Guda_BankFrame_MoneyOnEnter(this)
    end)
    self:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

-- Money tooltip handler
function Guda_BankFrame_MoneyOnEnter(self)
    if not self then return end

    -- Anchor tooltip to TOPRIGHT
    GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT", 0, 0)
    GameTooltip:ClearLines()

    -- Get all characters and total (realm filtered, all factions)
    local chars = addon.Modules.DB:GetAllCharacters(false, true)
    local totalMoney = addon.Modules.DB:GetTotalMoney(false, true)

    -- Header with current realm total - use colored money
    GameTooltip:AddLine(
        "Current realm gold: " .. addon.Modules.Utils:FormatMoney(totalMoney, false, true),
        1, 0.82, 0
    )
    GameTooltip:AddLine(" ")

    -- List each character with class-colored names
    for _, char in ipairs(chars) do
        local classToken = char.classToken
        local classColor = classToken and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[classToken]
        local colorR, colorG, colorB = 0.7, 0.7, 0.7

        if classColor then
            colorR, colorG, colorB = classColor.r, classColor.g, classColor.b
        end

        -- Create colored name
        local coloredName = addon.Modules.Utils:ColorText(char.name, colorR, colorG, colorB)

        GameTooltip:AddLine(
            coloredName .. ": " .. addon.Modules.Utils:FormatMoney(char.money or 0, false, true)
        )
    end

    GameTooltip:Show()
end

-- Create transparent overlay for money tooltip
function BankFrame:EnsureMoneyTooltipOverlay()
    local overlayName = "Guda_BankFrame_MoneyTooltipOverlay"
    local overlay = getglobal(overlayName)

    if not overlay then
        local moneyFrame = getglobal("Guda_BankFrame_MoneyFrame")
        if not moneyFrame then return end

        -- Create transparent overlay frame
        overlay = CreateFrame("Frame", overlayName, moneyFrame)
        overlay:SetAllPoints(moneyFrame)
        overlay:SetFrameLevel(moneyFrame:GetFrameLevel() + 1)
        overlay:EnableMouse(true)

        -- Set tooltip handlers on overlay
        overlay:SetScript("OnEnter", function()
            Guda_BankFrame_MoneyOnEnter(moneyFrame)
        end)

        overlay:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        addon:Debug("Bank money tooltip overlay created")
    end

    overlay:Show()
end

-- Check if search is currently active
function BankFrame:IsSearchActive()
    return searchText and searchText ~= "" and searchText ~= "Search bank..."
end

-- Check if item passes search filter (pfUI style)
function BankFrame:PassesSearchFilter(itemData)
    if not self:IsSearchActive() then return true end
    return Guda_PassesSearchFilter(itemData, searchText)
end

-- Search changed handler
function Guda_BankFrame_OnSearchChanged(self)
    local text = self:GetText()
    -- Ignore placeholder text
    if text == "Search bank..." then
        text = ""
    end
    if text ~= searchText then
        searchText = text
        BankFrame:Update()
    end
end

-- Clear bank search and restore placeholder
function Guda_BankFrame_ClearSearch()
    local searchBox = getglobal("Guda_BankFrame_SearchBar_SearchBox")
    if searchBox then
        searchBox:SetText("Search bank...")
        searchBox:SetTextColor(0.5, 0.5, 0.5, 1)
        if searchBox.ClearFocus then searchBox:ClearFocus() end
    end

    -- Reset search state
    searchText = ""

    -- Update display
    BankFrame:Update()

    -- Hide click catcher if present
    if bankClickCatcher and bankClickCatcher.Hide then
        bankClickCatcher:Hide()
    end
end

-- Bank button handler
function Guda_BankFrame_Sort()
	if isReadOnlyMode or currentViewChar then
		addon:Print("Cannot sort in read-only mode!")
		return
	end

	if not addon.Modules.BankScanner:IsBankOpen() then
		addon:Print("Bank must be open to sort!")
		return
	end

	-- Check if we're in category view - restack and clean
	local sortBtn = getglobal("Guda_BankFrame_SortButton")
	if sortBtn and sortBtn.isCategoryView then
		Guda_BankFrame_MergeStacks()
		return
	end

 local success, message = addon.Modules.SortEngine:ExecuteSort(
        function() return addon.Modules.SortEngine:SortBankPass() end,
        function() return addon.Modules.SortEngine:AnalyzeBank() end,
        function() BankFrame:Update() end,
        "bank"
    )

	if not success and message == "already sorted" then
		addon:Print("Bank is already sorted!")
	end
end

-- Restack and Clean (for category view) - merges stacks and refreshes view
-- Queue-based approach like BagShui
function Guda_BankFrame_MergeStacks()
	if isReadOnlyMode or currentViewChar then
		addon:Print("Cannot restack in read-only mode!")
		return
	end

	if not addon.Modules.BankScanner:IsBankOpen() then
		addon:Print("Bank must be open to restack!")
		return
	end

	-- Check if sorting is already in progress
	if addon.Modules.SortEngine.sortingInProgress then
		addon:Print("Sorting already in progress, please wait...")
		return
	end

	local bagIDs = addon.Constants.BANK_BAGS
	local moveQueue = {}

	-- Collect all partial stacks grouped by item
	local partialStacks = {}
	for _, bagID in ipairs(bagIDs) do
		local numSlots = addon.Modules.Utils:GetBagSlotCount(bagID)
		if numSlots and numSlots > 0 then
			for slot = 1, numSlots do
				local link = GetContainerItemLink(bagID, slot)
				if link then
					local texture, count = GetContainerItemInfo(bagID, slot)
					local _, _, itemID = string.find(link, "item:(%d+)")
					itemID = tonumber(itemID)
					
					if itemID then
						local _, _, _, _, _, _, itemStackCount = GetItemInfo(itemID)
						local maxStack = tonumber(itemStackCount) or 1
						
						-- Only track items that can stack and aren't full
						if maxStack > 1 and count < maxStack then
							local groupKey = tostring(itemID)
							if not partialStacks[groupKey] then
								partialStacks[groupKey] = {
									maxStack = maxStack,
									stacks = {}
								}
							end
							table.insert(partialStacks[groupKey].stacks, {
								bagID = bagID,
								slot = slot,
								count = count
							})
						end
					end
				end
			end
		end
	end

	-- Build move queue for each item group
	for _, group in pairs(partialStacks) do
		if table.getn(group.stacks) > 1 then
			-- Sort stacks: larger stacks first (targets), smaller stacks last (sources)
			table.sort(group.stacks, function(a, b)
				if not a then return false end
				if not b then return true end
				return (a.count or 0) > (b.count or 0)
			end)

			local sourceLoopStart = table.getn(group.stacks)

			-- Process targets from start, sources from end
			for targetIdx = 1, table.getn(group.stacks) - 1 do
				local target = group.stacks[targetIdx]
				
				if target.count < group.maxStack and target.count > 0 then
					for sourceIdx = sourceLoopStart, targetIdx + 1, -1 do
						local source = group.stacks[sourceIdx]
						
						if source.count > 0 and target.count < group.maxStack then
							-- Queue this move
							table.insert(moveQueue, {
								source = source,
								target = target,
								maxStack = group.maxStack
							})
							
							-- Calculate changes (for queue planning)
							local oldTargetCount = target.count
							target.count = math.min(target.count + source.count, group.maxStack)
							source.count = source.count - (target.count - oldTargetCount)
							
							-- Move source pointer if depleted
							if source.count == 0 then
								sourceLoopStart = sourceLoopStart - 1
							end
							
							-- Stop if target is full
							if target.count >= group.maxStack then
								break
							end
						end
					end
				end
			end
		end
	end

	if table.getn(moveQueue) == 0 then
		-- No stacks to merge, just do a clean refresh
		BankFrame:ClearRecentlyEmptiedSlots()
		addon.Modules.BankScanner:InvalidateCache()
		-- Clear item detection cache to force fresh tooltip scans
		if addon.Modules.ItemDetection and addon.Modules.ItemDetection.ClearCache then
			addon.Modules.ItemDetection:ClearCache()
		end
		BankFrame:Update()
		addon:Print("View refreshed (no stacks to merge)")
		return
	end

	-- Set sorting flag and update button appearance
	addon.Modules.SortEngine.sortingInProgress = true
	addon.Modules.SortEngine:UpdateSortButtonState(true)

	-- Process queue with delays
	local queueIndex = 1
	local retryCount = 0
	local totalMoves = table.getn(moveQueue)

	local function ProcessNextMove()
		if queueIndex > table.getn(moveQueue) then
			addon.Modules.SortEngine.sortingInProgress = false
			addon.Modules.SortEngine:UpdateSortButtonState(false)
			-- Clear all caches for a clean view after restacking
			BankFrame:ClearRecentlyEmptiedSlots()
			addon.Modules.BankScanner:InvalidateCache()
			-- Clear item detection cache to force fresh tooltip scans
			if addon.Modules.ItemDetection and addon.Modules.ItemDetection.ClearCache then
				addon.Modules.ItemDetection:ClearCache()
			end
			BankFrame:Update()
			addon:Print("Restacked " .. totalMoves .. " stack(s)")
			return
		end
		
		local move = moveQueue[queueIndex]
		local source = move.source
		local target = move.target
		
		-- Check if items are locked
		local _, _, sourceLocked = GetContainerItemInfo(source.bagID, source.slot)
		local _, _, targetLocked = GetContainerItemInfo(target.bagID, target.slot)
		
		if sourceLocked or targetLocked then
			retryCount = retryCount + 1
			if retryCount < 10 then
				-- Retry after delay
				Guda_ScheduleTimer(0.3, ProcessNextMove)
				return
			else
				-- Give up on this move
				retryCount = 0
				queueIndex = queueIndex + 1
				Guda_ScheduleTimer(0.1, ProcessNextMove)
				return
			end
		end
		
		-- Perform the move
		ClearCursor()
		PickupContainerItem(source.bagID, source.slot)
		PickupContainerItem(target.bagID, target.slot)
		ClearCursor()
		
		-- Move to next
		retryCount = 0
		queueIndex = queueIndex + 1
		Guda_ScheduleTimer(0.15, ProcessNextMove)
	end
	
	ProcessNextMove()
end

-- Switch to Blizzard bank UI
function Guda_BankFrame_SwitchToBlizzardUI()
    -- Hide custom bank frame
    local customBankFrame = getglobal("Guda_BankFrame")
    if customBankFrame then
        customBankFrame:Hide()
    end

    -- Restore Blizzard bank frame
    local blizzardBankFrame = getglobal("BankFrame")
    if blizzardBankFrame then
        blizzardBankFrame:SetScale(1.0)
        blizzardBankFrame:SetAlpha(1.0)
        blizzardBankFrame:ClearAllPoints()
        blizzardBankFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104)
        blizzardBankFrame:Show()
        
        -- Show the Guda button if it exists
        BankFrame:ShowGudaButton()
    end
end

-- Switch from Blizzard bank UI back to Guda UI
function Guda_BankFrame_SwitchToGudaUI()
    -- Hide Blizzard bank frame visually (but keep it functional)
    local blizzardBankFrame = getglobal("BankFrame")
    if blizzardBankFrame then
        blizzardBankFrame:SetScale(0.001)
        blizzardBankFrame:SetPoint("TOPLEFT", 0, 0)
        blizzardBankFrame:SetAlpha(0)
    end
    
    -- Hide the Guda button
    local gudaButton = getglobal("BankFrame_GudaButton")
    if gudaButton then
        gudaButton:Hide()
    end

    -- Show custom bank frame
    local customBankFrame = getglobal("Guda_BankFrame")
    if customBankFrame then
        customBankFrame:Show()
    end

    -- Update the custom bank frame in interactive mode
    BankFrame:ShowCurrentCharacter()
    
    addon:Print("Switched to Guda bank UI")
end

-- Create button on Blizzard BankFrame to switch to Guda UI
function BankFrame:CreateGudaButtonOnBlizzardUI()
    local blizzardBankFrame = getglobal("BankFrame")
    if not blizzardBankFrame then return end

    -- Check if button already exists
    if getglobal("BankFrame_GudaButton") then return end

    -- Create the button next to close button
    local gudaButton = CreateFrame("Button", "BankFrame_GudaButton", blizzardBankFrame)
    gudaButton:SetWidth(20)
    gudaButton:SetHeight(20)
    
    -- Position next to close button (to the left of it)
    local closeButton = getglobal("BankFrameCloseButton")
    if closeButton then
        gudaButton:SetPoint("RIGHT", closeButton, "LEFT", -2, 0)
    else
        gudaButton:SetPoint("TOPRIGHT", blizzardBankFrame, "TOPRIGHT", -61, -14)
    end

    -- Create button texture
    local texture = gudaButton:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints(gudaButton)
    texture:SetTexture("Interface\\AddOns\\Guda\\Assets\\Chest")
    texture:SetTexCoord(0, 1, 0, 1)

    -- Create highlight texture
    local highlight = gudaButton:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(gudaButton)
    highlight:SetTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    highlight:SetBlendMode("ADD")

    -- Set scripts
    gudaButton:SetScript("OnClick", function()
        Guda_BankFrame_SwitchToGudaUI()
    end)

    gudaButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:SetText("Use Guda Bank UI")
        GameTooltip:Show()
    end)

    gudaButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Initially hide the button
    gudaButton:Hide()
    
end

-- Show the Guda button on Blizzard UI
function BankFrame:ShowGudaButton()
    local gudaButton = getglobal("BankFrame_GudaButton")
    if gudaButton then
        gudaButton:Show()
    end
end

-- Ensure bank bag buttons are present; create them if XML did not
function BankFrame:EnsureBagButtonsInitialized()
    local toolbar = getglobal("Guda_BankFrame_Toolbar")
    if not toolbar then return end

    local function ensureButton(suffix, bagID)
        local name = "Guda_BankFrame_Toolbar_" .. suffix
        local btn = getglobal(name)
        if not btn then
            btn = CreateFrame("Button", name, toolbar, "ItemButtonTemplate")
            -- Anchor sequenced to the left; position similar to XML
            if suffix == "BankBagMain" then
                btn:SetWidth(24)
                btn:SetHeight(24)
                btn:SetPoint("LEFT", toolbar, "LEFT", 13, 0)
            else
                -- Determine previous button
                local prev
                if bagID == 5 then prev = getglobal("Guda_BankFrame_Toolbar_BankBagMain")
                else prev = getglobal("Guda_BankFrame_Toolbar_BankBag"..tostring(bagID-1)) end
                btn:SetWidth(24)
                btn:SetHeight(24)
                if prev then
                    btn:SetPoint("LEFT", prev, "RIGHT", 2, 0)
                else
                    btn:SetPoint("LEFT", toolbar, "LEFT", 13, 0)
                end
            end

            -- Hook mouseover tooltip like XML
            btn:SetScript("OnEnter", function()
                Guda_BankBagSlot_OnEnter(this, bagID)
                Guda_BankFrame_HighlightBagSlots(bagID)
            end)
            btn:SetScript("OnLeave", function()
                GameTooltip:Hide()
                Guda_BankFrame_ClearHighlightedSlots()
            end)
            -- Handle clicks (Right-Click toggles visibility)
            if btn.RegisterForClicks then
                btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            end
            btn:SetScript("OnClick", function()
                Guda_BankBagSlot_OnClick(this, bagID, arg1)
            end)
            
            -- Enable dragging with left button
            if btn.RegisterForDrag then
                btn:RegisterForDrag("LeftButton")
            end
            btn:SetScript("OnDragStart", function()
                Guda_BankBagSlot_OnDragStart(this, bagID)
            end)
            btn:SetScript("OnDragStop", function()
                Guda_BankBagSlot_OnDragStop(this, bagID)
            end)
            
            -- Accept drops to equip bag into this slot
            btn:SetScript("OnReceiveDrag", function()
                Guda_BankBagSlot_OnReceiveDrag(this, bagID)
            end)
        end

        -- Run our OnLoad logic (will also register events and initial update)
        Guda_BankBagSlot_OnLoad(btn, bagID)
        return btn
    end

    -- Main (-1) and 5..10
    ensureButton("BankBagMain", -1)
    for bagID=5,10 do
        ensureButton("BankBag"..tostring(bagID), bagID)
    end
end

-- Helper: map bank bagID (5..10) to bankButtonID (1..6) and inventory slot id (Vanilla requires second arg = 1)
function BankFrame:GetBankInvSlotForBagID(bagID)
    if not bagID or bagID == -1 then return nil, nil end
    local bankButtonID = bagID - 4
    -- TurtleWoW (and your environment) expect passing bagID (5..10) with isBank=1
    local invSlot = BankButtonIDToInvSlotID(bagID, 1)
    return invSlot, bankButtonID
end

-- Update border visibility based on setting
function BankFrame:UpdateBorderVisibility()
    if not addon or not addon.Modules or not addon.Modules.DB then return end

    local frame = getglobal("Guda_BankFrame")
    if not frame then return end

    local hideBorders = addon.Modules.DB:GetSetting("hideBorders")
    if hideBorders == nil then
        hideBorders = false
    end

    -- Use helper function with constants
    if hideBorders then
        addon:ApplyBackdrop(frame, "MINIMALIST_BORDER", "DEFAULT")
    else
        addon:ApplyBackdrop(frame, "DEFAULT_FRAME", "DEFAULT")
    end
end

-- Update search bar visibility based on setting
function BankFrame:UpdateSearchBarVisibility()
    if not addon or not addon.Modules or not addon.Modules.DB then return end

    local searchBar = getglobal("Guda_BankFrame_SearchBar")
    local itemContainer = getglobal("Guda_BankFrame_ItemContainer")
    if not searchBar or not itemContainer then return end

    local showSearchBar = addon.Modules.DB:GetSetting("showSearchBar")
    if showSearchBar == nil then
        showSearchBar = true
    end

    if showSearchBar then
        searchBar:Show()
        -- Anchor ItemContainer to SearchBar's bottom
        itemContainer:ClearAllPoints()
        itemContainer:SetPoint("TOP", searchBar, "BOTTOM", 0, -5)
    else
        searchBar:Hide()
        -- Anchor ItemContainer directly to frame top (skip search bar space)
        itemContainer:ClearAllPoints()
        itemContainer:SetPoint("TOP", "Guda_BankFrame", "TOP", 0, -40)
    end
end

-- Update footer visibility based on settings
function BankFrame:UpdateFooterVisibility()
    local hideFooter = addon.Modules.DB:GetSetting("hideFooter")
    local toolbar = getglobal("Guda_BankFrame_Toolbar")
    local moneyFrame = getglobal("Guda_BankFrame_MoneyFrame")

    if hideFooter then
        if toolbar then toolbar:Hide() end
        if moneyFrame then moneyFrame:Hide() end
    else
        if toolbar then toolbar:Show() end
        if moneyFrame then moneyFrame:Show() end
        
        -- Trigger layout updates to ensure they are correctly positioned
        self:UpdateMoney()
    end
end

-- Initialize
function BankFrame:Initialize()
    -- Hide Blizzard bank frame on load (pfUI style)
    local blizzardBankFrame = getglobal("BankFrame")
    if blizzardBankFrame then
        blizzardBankFrame:SetScale(0.001)
        blizzardBankFrame:SetPoint("TOPLEFT", 0, 0)
        blizzardBankFrame:SetAlpha(0)
    end
    
    -- Create Guda button on Blizzard BankFrame
    self:CreateGudaButtonOnBlizzardUI()

    -- Ensure our bank bag buttons exist even if XML failed to create them
    if self.EnsureBagButtonsInitialized then
        self:EnsureBagButtonsInitialized()
    end

    -- Update when bank is opened
    addon.Modules.Events:OnBankOpen(function()
        -- Delay showing custom bank to let TransmogUI finish processing (uses pooled timer)
        Guda_ScheduleTimer(0.2, function()
            -- Show current character's bank in interactive mode
            currentViewChar = nil

            -- Do not auto-hide BagFrame when opening BankFrame
            -- Users may want both frames visible simultaneously; layout issues, if any,
            -- should be addressed via positioning rather than auto-hiding.

            -- Show and update custom bank frame
            local customBankFrame = getglobal("Guda_BankFrame")
            if customBankFrame then
                customBankFrame:Show()
            end

            -- Force disable pfUI banks if enabled (pfUI uses pfBank for its bank frame)
            if pfUI and pfUI.bag and pfUI.bag.left and pfUI.bag.left.Hide then
                pfUI.bag.left:Hide()
            end

            addon.Modules.BankFrame:EnsureBagButtonsInitialized()
            addon.Modules.BankFrame:Update()
        end)
    end, "BankFrameUI")

    -- Hide custom bank when bank is closed
    addon.Modules.Events:OnBankClose(function()
        local customBankFrame = getglobal("Guda_BankFrame")
        if customBankFrame and customBankFrame:IsShown() and not currentViewChar then
            -- Only auto-close if viewing current character's bank (not saved banks)
            customBankFrame:Hide()
        end
    end, "BankFrameUI")

    --=====================================================
    -- Efficient Update Throttling System for BankFrame
    -- Uses a single reusable frame and true debouncing
    --=====================================================
    local bankThrottle = {
        frame = nil,
        pending = false,
        delay = 0.1,
        elapsed = 0,
        minDelay = 0.05,
        maxDelay = 0.3,
    }

    local function GetBankThrottleFrame()
        if not bankThrottle.frame then
            bankThrottle.frame = CreateFrame("Frame", "Guda_BankUpdateThrottle", UIParent)
            bankThrottle.frame:Hide()
            bankThrottle.frame:SetScript("OnUpdate", function()
                bankThrottle.elapsed = bankThrottle.elapsed + arg1
                if bankThrottle.elapsed >= bankThrottle.delay then
                    bankThrottle.frame:Hide()
                    bankThrottle.pending = false
                    bankThrottle.elapsed = 0
                    -- Update if bank is open OR our frame is shown (for edge cases)
                    local bankOpen = addon.Modules.BankScanner:IsBankOpen()
                    local frameShown = Guda_BankFrame and Guda_BankFrame:IsShown()
                    addon:DebugCategory("Throttle fired: bankOpen=%s, frameShown=%s, viewingCurrent=%s",
                        tostring(bankOpen), tostring(frameShown), tostring(not currentViewChar))
                    if (bankOpen or frameShown) and not currentViewChar then
                        addon:DebugCategory("Throttle: calling BankFrame:Update()")
                        addon.Modules.BankFrame:Update()
                    else
                        addon:DebugCategory("Throttle: skipped Update (conditions not met)")
                    end
                end
            end)
        end
        return bankThrottle.frame
    end

    local function ScheduleBankFrameUpdate(delay)
        -- Allow update if bank is open OR our frame is shown
        local bankOpen = addon.Modules.BankScanner:IsBankOpen()
        local frameShown = Guda_BankFrame and Guda_BankFrame:IsShown()
        if not bankOpen and not frameShown then
            addon:DebugCategory("ScheduleBankFrameUpdate: skipped (bank not open, frame not shown)")
            return
        end
        if currentViewChar then return end

        delay = delay or bankThrottle.minDelay
        if delay < bankThrottle.minDelay then
            delay = bankThrottle.minDelay
        elseif delay > bankThrottle.maxDelay then
            delay = bankThrottle.maxDelay
        end

        -- Use longer delay if sorting is in progress
        if addon.Modules.SortEngine and addon.Modules.SortEngine.sortingInProgress then
            delay = bankThrottle.maxDelay
        end

        bankThrottle.delay = delay
        bankThrottle.elapsed = 0  -- Reset timer (true debounce)

        local wasAlreadyPending = bankThrottle.pending
        if not bankThrottle.pending then
            bankThrottle.pending = true
            GetBankThrottleFrame():Show()
        end
        addon:DebugCategory("ScheduleBankFrameUpdate: delay=%s, wasAlreadyPending=%s", tostring(delay), tostring(wasAlreadyPending))
    end

    -- NOTE: BAG_UPDATE for bank bags (5-10) is handled by the updateFrame below
    -- which provides incremental update logic. We don't need a separate OnBagUpdate
    -- handler here as it would cause duplicate processing.

    -- Update when items get locked/unlocked (debounced for trading, mailing, etc.)
    addon.Modules.Events:Register("ITEM_LOCK_CHANGED", function()
        -- Allow if bank is open OR our frame is shown
        local bankOpen = addon.Modules.BankScanner:IsBankOpen()
        local frameShown = Guda_BankFrame and Guda_BankFrame:IsShown()
        if not bankOpen and not frameShown then return end
        if currentViewChar then return end
        -- In Category View, just update lock states visually without full redraw
        local viewType = addon.Modules.DB:GetSetting("bankViewType") or "single"
        if viewType == "category" then
            -- Only update lock visual states, don't trigger full redraw
            BankFrame:UpdateLockStates()
            return
        end
        -- Use slightly longer delay for lock changes in single view
        ScheduleBankFrameUpdate(0.15)
    end, "BankFrameUI")

    -- Register bank-specific update events with incremental slot tracking
    local updateFrame = CreateFrame("Frame")
    updateFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
    updateFrame:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED")
    updateFrame:RegisterEvent("BAG_UPDATE")
    updateFrame:SetScript("OnEvent", function()
        -- Debug: log ALL events received by this handler
        addon:DebugCategory("BankFrame EVENT: %s arg1=%s", tostring(event), tostring(arg1))

        -- Check if we should process bank events:
        -- 1. Bank is officially open (IsBankOpen), OR
        -- 2. Our BankFrame is shown and we're viewing current character (for edge cases)
        local bankOpen = addon.Modules.BankScanner:IsBankOpen()
        local frameShown = Guda_BankFrame and Guda_BankFrame:IsShown()
        local viewingCurrent = not currentViewChar

        if not bankOpen and not (frameShown and viewingCurrent) then
            addon:DebugCategory("  -> ignored (bank not open, frame not shown)")
            return
        end
        if currentViewChar then
            addon:DebugCategory("  -> ignored (viewing other character)")
            return
        end

        -- Check if sorting is in progress - use full redraw with throttle
        local isSorting = addon.Modules.SortEngine and addon.Modules.SortEngine.sortingInProgress

        if event == "PLAYERBANKSLOTS_CHANGED" then
            -- arg1 is the slot number (1-28 for main bank), but can be nil in some cases
            local viewType = addon.Modules.DB:GetSetting("bankViewType") or "single"

            if arg1 and type(arg1) == "number" and arg1 >= 1 then
                -- Specific slot changed
                local rawTexture, rawCount = GetContainerItemInfo(-1, arg1)
                local rawLink = GetContainerItemLink(-1, arg1)
                local slotIsNowEmpty = (rawTexture == nil)
                addon:DebugCategory("  PLAYERBANKSLOTS_CHANGED slot=%d, slotIsNowEmpty=%s, isSorting=%s",
                    arg1, tostring(slotIsNowEmpty), tostring(isSorting))

                -- Try single-slot update if not sorting
                if not isSorting then
                    -- Invalidate bag scanner cache for fresh slot data
                    addon.Modules.BankScanner:InvalidateBag(-1)
                    -- Try single-slot update
                    local success = BankFrame:UpdateSingleSlot(-1, arg1)
                    addon:DebugCategory("  UpdateSingleSlot(-1, %d) = %s", arg1, tostring(success))
                    if success then
                        -- Incremental update succeeded
                        if slotIsNowEmpty then
                            addon:DebugCategory("  -> slot emptied, incremental update done, no full redraw needed")
                        else
                            addon:DebugCategory("  -> item added, incremental update done")
                        end
                        return
                    end
                end

                -- Fallback: full redraw needed
                -- BUT if slot just became empty and we have no button, that's OK in Category View
                if slotIsNowEmpty and viewType == "category" then
                    addon:DebugCategory("  -> slot emptied in Category View, no button exists, updating cache only")
                    addon.Modules.BankScanner:InvalidateBag(-1)
                    return
                end

                addon:DebugCategory("  -> falling through to full redraw")
                addon.Modules.BankScanner:InvalidateBag(-1)
            else
                -- arg1 is nil - generic bank change notification
                -- In Category View, check if items were removed (no need for full redraw)
                addon:DebugCategory("  PLAYERBANKSLOTS_CHANGED arg1=nil (generic)")

                if viewType == "category" then
                    -- First, count items in the CURRENT API state (this is the "after" count)
                    local realItems = 0
                    local numSlots = GetContainerNumSlots(-1) or 0
                    for slot = 1, numSlots do
                        local texture = GetContainerItemInfo(-1, slot)
                        if texture then realItems = realItems + 1 end
                    end

                    -- Get the cached count BEFORE updating (this is the "before" count)
                    -- Use GetCachedItemCount to avoid triggering mismatch detection
                    local cacheItems = addon.Modules.BankScanner:GetCachedItemCount(-1)

                    addon:DebugCategory("  -> comparing cache=%d vs API=%d", cacheItems, realItems)

                    if realItems < cacheItems then
                        -- Items were REMOVED - show empty placeholders, no full redraw
                        addon:DebugCategory("  -> items removed (%d -> %d), showing empty placeholders", cacheItems, realItems)

                        -- Find slots that became empty and update them to show empty placeholder
                        if bankSlotToButton[-1] then
                            for slotID, button in pairs(bankSlotToButton[-1]) do
                                local buttonHadItem = button.itemData and button.itemData.link
                                local currentTexture = GetContainerItemInfo(-1, slotID)

                                -- If button had item but API doesn't, this slot was emptied
                                if buttonHadItem and not currentTexture then
                                    addon:DebugCategory("  -> slot %d emptied, showing empty placeholder", slotID)
                                    -- Mark as empty placeholder so it stays visible
                                    button.inUse = true
                                    button.isEmptyPlaceholder = true
                                    -- Also mark in recentlyEmptiedSlots for full redraw support
                                    local oldItemData = button.itemData
                                    local oldCategory = "Miscellaneous"
                                    if oldItemData and oldItemData.link then
                                        oldCategory = addon.Modules.CategoryManager:CategorizeItem(oldItemData, -1, slotID) or "Miscellaneous"
                                    end
                                    self:MarkSlotAsEmptied(-1, slotID, oldCategory, oldItemData)
                                    -- Update button to show empty state
                                    local matchesFilter = self:PassesSearchFilter(nil)
                                    Guda_ItemButton_SetItem(button, -1, slotID, nil, true, nil, matchesFilter, isReadOnlyMode)
                                    -- Clear itemData so subsequent events know this slot is empty
                                    button.itemData = nil
                                    -- Ensure it stays visible
                                    button:Show()
                                end
                            end
                        end

                        -- DON'T invalidate cache here - we've already handled the visual update
                        -- Invalidating would cause cache=0, making next event think items were added
                        -- The cache will be updated on next full redraw if needed
                        return
                    elseif realItems == cacheItems then
                        -- No change in item count - might be item swap, skip update
                        addon:DebugCategory("  -> item count unchanged (%d), skipping", realItems)
                        return
                    end
                    -- Items were added - need full redraw
                    addon:DebugCategory("  -> items added (%d -> %d), need full redraw", cacheItems, realItems)
                end

                addon.Modules.BankScanner:InvalidateBag(-1)
            end
        elseif event == "BAG_UPDATE" and arg1 then
            -- Check if this is a bank bag (5-10)
            if arg1 >= 5 and arg1 <= 10 then
                -- Debug: count items in this bank bag via raw API
                local rawItemCount = 0
                local numSlots = GetContainerNumSlots(arg1) or 0
                for slot = 1, numSlots do
                    local texture = GetContainerItemInfo(arg1, slot)
                    if texture then rawItemCount = rawItemCount + 1 end
                end
                addon:DebugCategory("EVENT: BAG_UPDATE bankBag=%d, rawItems=%d, numSlots=%d, isSorting=%s",
                    arg1, rawItemCount, numSlots, tostring(isSorting))
                -- Invalidate bag scanner cache for fresh slot data
                -- NOTE: Don't clear ItemDetection cache - item properties don't change on move
                addon.Modules.BankScanner:InvalidateBag(arg1)

                -- Try incremental update if not sorting
                if not isSorting then
                    -- Try to update only changed slots
                    local result = BankFrame:UpdateChangedSlots(arg1)
                    addon:DebugCategory("  UpdateChangedSlots(%d) = %d", arg1, result)
                    if result >= 0 then
                        -- Incremental update succeeded - no need for full redraw for THIS bag
                        -- But don't cancel pending redraws - other changes might need them
                        return
                    end
                    -- Fall through to full redraw
                end
                addon:DebugCategory("  -> falling through to full redraw")
            else
                -- Not a bank bag, ignore for bank frame
                return
            end
        elseif event == "PLAYERBANKBAGSLOTS_CHANGED" then
            -- Bank container slot changed (bag added/removed)
            -- Clear bag scanner cache since structure changed
            -- NOTE: Don't clear ItemDetection cache - item properties don't change
            addon.Modules.BankScanner:ClearCache()
        end

        -- Longer delay to ensure WoW API has fully updated after item moves
        ScheduleBankFrameUpdate(0.2)
    end)

end

-- Bank Bag Slot Button Handlers

-- OnLoad handler for bank bag slot buttons
function Guda_BankBagSlot_OnLoad(button, bagID)
    -- Configure border and icon inset for consistent look with main bank bag
    local buttonName = button:GetName()

    -- Ensure the normal texture (border) is visible and uses the default quickslot border
    local normalTexture = getglobal(buttonName .. "NormalTexture")
    if normalTexture then
        normalTexture:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        normalTexture:ClearAllPoints()
        normalTexture:SetPoint("CENTER", button, "CENTER", 0, -1)
        normalTexture:SetWidth(35)
        normalTexture:SetHeight(35)
        normalTexture:Show()
    end

    -- If the template has an IconBorder, show it as well (some clients/templates provide this)
    local iconBorder = getglobal(buttonName .. "IconBorder")
    if iconBorder then
        iconBorder:Show()
    end

    -- Inset the icon slightly so equipped bag icons appear a bit smaller (match main bag feel)
    local icon = getglobal(buttonName .. "IconTexture") or getglobal(buttonName .. "Icon")
    if icon then
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
        icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end

    -- Mark this as a bag slot button, NOT an item button
    button.isBagSlot = true
    button.hasItem = nil

    -- Set up the button with proper ID
    button.bagID = bagID

    -- Set the inventory slot ID so the button knows which slot it represents
    if bagID ~= -1 then
        local invSlot = addon.Modules.BankFrame:GetBankInvSlotForBagID(bagID)
        if invSlot then
            button:SetID(invSlot)
        end
    end

    -- Register for updates
    button:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED")
    button:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
    button:RegisterEvent("ITEM_LOCK_CHANGED")
    button:RegisterEvent("PLAYER_MONEY")
    button:RegisterEvent("CURSOR_UPDATE")
    button:RegisterEvent("UNIT_INVENTORY_CHANGED")
    button:SetScript("OnEvent", function()
        Guda_BankBagSlot_Update(this, this.bagID)
    end)

    -- Ensure we respond to right-click for hide/show
    if button.RegisterForClicks then
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    end
    button:SetScript("OnClick", function()
        Guda_BankBagSlot_OnClick(this, this.bagID, arg1)
    end)

    -- Enable dragging with left button
    if button.RegisterForDrag then
        button:RegisterForDrag("LeftButton")
    end
    button:SetScript("OnDragStart", function()
        Guda_BankBagSlot_OnDragStart(this, this.bagID)
    end)
    button:SetScript("OnDragStop", function()
        Guda_BankBagSlot_OnDragStop(this, this.bagID)
    end)

    -- Accept drops to equip bag into this slot
    button:SetScript("OnReceiveDrag", function()
        Guda_BankBagSlot_OnReceiveDrag(this, this.bagID)
    end)

    -- Initial update
    Guda_BankBagSlot_Update(button, bagID)
end

-- Update bank bag slot button texture
function Guda_BankBagSlot_Update(button, bagID)
    local isHidden = hiddenBankBags[bagID]

    if bagID == -1 then
        -- Main bank bag - use bank icon
        SetItemButtonTexture(button, "Interface\\Buttons\\Button-Backpack-Up")
        -- Dim if hidden
        if isHidden then
            SetItemButtonTextureVertexColor(button, 0.4, 0.4, 0.4)
        else
            SetItemButtonTextureVertexColor(button, 1.0, 1.0, 1.0)
        end
        button:Show()
        return
    end

    -- Bank bag slots 5-10 correspond to bank buttons 1-6
    local bankButtonID = bagID - 4
    -- Centralized mapping to inventory slot (TurtleWoW: pass bagID; helper also returns bankButtonID)
    local invSlot = BankFrame:GetBankInvSlotForBagID(bagID)

    -- Check if this slot is purchased
    local numSlots = GetNumBankSlots()
    local isPurchased = (bankButtonID <= numSlots)

    -- Get bag texture directly from inventory (more reliable on 1.12)
    local texture = invSlot and GetInventoryItemTexture("player", invSlot) or nil


    if texture then
        -- Bag is equipped in this slot and we have the texture
        SetItemButtonTexture(button, texture)
        -- Dim if hidden
        if isHidden then
            SetItemButtonTextureVertexColor(button, 0.4, 0.4, 0.4)
        else
            SetItemButtonTextureVertexColor(button, 1.0, 1.0, 1.0)
        end

        -- Set texture coordinates to crop the icon (1.12 uses IconTexture)
        local icon = getglobal(button:GetName() .. "IconTexture") or getglobal(button:GetName() .. "Icon")
        if icon then
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end

        button:Show()
    elseif isPurchased then
        -- Slot is purchased but no bag equipped
        SetItemButtonTexture(button, "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
        SetItemButtonTextureVertexColor(button, 1.0, 1.0, 1.0)
        button:Show()
    else
        -- Slot not purchased - show locked/greyed placeholder
        SetItemButtonTexture(button, "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
        SetItemButtonTextureVertexColor(button, 0.5, 0.5, 0.5)
        button:Show()
    end
end

-- OnClick handler for bank bag slots
function Guda_BankBagSlot_OnClick(button, bagID, which)
    local which = which or arg1 -- Vanilla uses global arg1 for mouse button name

    -- Handle main bank container (bagID -1)
    if bagID == -1 then
        if which == "RightButton" then
            -- Toggle visibility for main bank container
            hiddenBankBags[bagID] = not hiddenBankBags[bagID]
            Guda_BankBagSlot_Update(button, bagID)
            BankFrame:Update()
        end
        return
    end

    if bagID and bagID ~= -1 then
        local invSlot, bankButtonID = BankFrame:GetBankInvSlotForBagID(bagID)
        if invSlot and bankButtonID then
            local numSlots = GetNumBankSlots()
            local isPurchased = (bankButtonID <= numSlots)
            local hasCursorItem = CursorHasItem()

            -- Handle unpurchased slots: both left and right click show purchase dialog
            if not isPurchased then
                if not hasCursorItem then
                    -- Show purchase dialog for both left and right click
                    local cost = GetBankSlotCost(numSlots)
                    local gudaBankFrame = getglobal("Guda_BankFrame")
                    if gudaBankFrame then
                        gudaBankFrame.nextSlotCost = cost
                    end
                    StaticPopup_Show("CONFIRM_BUY_BANK_SLOT")
                end
                return
            end

            -- Handle purchased slots
            if which == "RightButton" then
                -- Toggle visibility for purchased slots
                hiddenBankBags[bagID] = not hiddenBankBags[bagID]
                Guda_BankBagSlot_Update(button, bagID)
                BankFrame:Update()
                return
            end

            if which == "LeftButton" then
                if hasCursorItem then
                    -- Equip bag from cursor into this purchased bank bag slot
                    EquipCursorItem(invSlot)
                    Guda_BankBagSlot_Update(button, bagID)
                    BankFrame:Update()
                end
                return
            end
        end
    end
end

-- OnEnter handler for tooltip
function Guda_BankBagSlot_OnEnter(button, bagID)
    GameTooltip:SetOwner(button, "ANCHOR_TOP")

    if bagID == -1 then
        -- Main bank bag tooltip
        GameTooltip:SetText("Bank", 1.0, 1.0, 1.0)
        local numSlots = 24
        GameTooltip:AddLine(string.format("%d Slots", numSlots), 0.8, 0.8, 0.8)
        if hiddenBankBags[bagID] then
            GameTooltip:AddLine("(Hidden - Right-Click to show)", 0.8, 0.5, 0.5)
        else
            GameTooltip:AddLine("(Right-Click to hide)", 0.5, 0.8, 0.5)
        end
    else
        local invSlot, bankButtonID = BankFrame:GetBankInvSlotForBagID(bagID)
        local numSlots = GetNumBankSlots()
        local isPurchased = (bankButtonID and bankButtonID <= numSlots)
        local hasItem = invSlot and GetInventoryItemTexture("player", invSlot)

        if hasItem then
            -- Show bag item tooltip (with hide/show text)
            GameTooltip:SetInventoryItem("player", invSlot)
            if hiddenBankBags[bagID] then
                GameTooltip:AddLine("(Hidden - Right-Click to show)", 0.8, 0.5, 0.5)
            else
                GameTooltip:AddLine("(Right-Click to hide)", 0.5, 0.8, 0.5)
            end
            -- Reset cursor for purchased slots with items
            ResetCursor()
        elseif isPurchased then
            -- Empty purchased slot (no hide/show text, no purchase cursor)
            GameTooltip:SetText(string.format("Bank Bag Slot %d", bankButtonID or -1), 1.0, 1.0, 1.0)
            GameTooltip:AddLine("Empty", 0.8, 0.8, 0.8)
            -- Reset cursor for empty purchased slots
            ResetCursor()
        else
            -- Unpurchased slot (no hide/show text, show purchase cursor)
            GameTooltip:SetText(string.format("Bank Bag Slot %d", bankButtonID or -1), 1.0, 1.0, 1.0)
            local cost = GetBankSlotCost(numSlots)
            GameTooltip:AddLine(addon.Modules.Utils:FormatMoney(cost, false, true), 1, 1, 1)
            -- Show purchase cursor (coin icon)
            SetCursor("BUY_CURSOR")
        end
    end

    GameTooltip:Show()
end

-- OnLeave handler for bank bag slots
function Guda_BankBagSlot_OnLeave(button, bagID)
    GameTooltip:Hide()
    ResetCursor()
end

-- Highlight all item slots belonging to a specific bank bag by dimming others
function Guda_BankFrame_HighlightBagSlots(bagID)
    -- Use itemButtons tracking instead of GetChildren to avoid allocations
    local highlightCount, dimCount = 0, 0

    for _, bankBagParent in pairs(bankBagParents) do
        if bankBagParent and bankBagParent.itemButtons then
            for button in pairs(bankBagParent.itemButtons) do
                if button and button:IsShown() and button.hasItem ~= nil and not button.isBagSlot then
                    if button.bagID == bagID then
                        button:SetAlpha(1.0)
                        highlightCount = highlightCount + 1
                    else
                        button:SetAlpha(0.25)
                        dimCount = dimCount + 1
                    end
                end
            end
        end
    end

    if addon and addon.Debug then
        addon:Debug(string.format("BankFrame HighlightBagSlots: Highlighted %d slots, dimmed %d slots for bagID %d", highlightCount, dimCount, bagID))
    end
end

-- Clear all highlighting by restoring full opacity to all slots
function Guda_BankFrame_ClearHighlightedSlots()
    -- Restore alpha to search-filter state (pfUI style). If no search, full opacity.
    local searchActive = BankFrame and BankFrame.IsSearchActive and BankFrame:IsSearchActive()

    -- Use itemButtons tracking instead of GetChildren to avoid allocations
    for _, bankBagParent in pairs(bankBagParents) do
        if bankBagParent and bankBagParent.itemButtons then
            for button in pairs(bankBagParent.itemButtons) do
                if button and button:IsShown() and button.hasItem ~= nil and not button.isBagSlot then
                    if searchActive and BankFrame and BankFrame.PassesSearchFilter then
                        local matches = BankFrame:PassesSearchFilter(button.itemData)
                        button:SetAlpha(matches and 1.0 or 0.25)
                    else
                        button:SetAlpha(1.0)
                    end
                end
            end
        end
    end
end

-- Highlight a specific bank bag button in the toolbar
function Guda_BankFrame_HighlightBagButton(bagID)
    if not bagID then return end

    local buttonName
    if bagID == -1 then
        -- Main bank container
        buttonName = "Guda_BankFrame_Toolbar_BankBagMain"
    else
        -- Bank bags are bagID 5-10
        buttonName = "Guda_BankFrame_Toolbar_BankBag" .. bagID
    end

    local button = getglobal(buttonName)
    if button then
        button:LockHighlight()
    end
end

-- Clear bank bag button highlighting
function Guda_BankFrame_ClearBagButtonHighlight()
    -- Clear highlight from main bank button
    local mainButton = getglobal("Guda_BankFrame_Toolbar_BankBagMain")
    if mainButton then
        mainButton:UnlockHighlight()
    end

    -- Clear highlight from bank bag buttons (5-10)
    for bagID = 5, 10 do
        local buttonName = "Guda_BankFrame_Toolbar_BankBag" .. bagID
        local button = getglobal(buttonName)
        if button then
            button:UnlockHighlight()
        end
    end
end

-- Bank character dropdown (similar to BagFrame's bank dropdown)
local function Guda_BankCharacterMenu_Initialize()
    local characters = addon.Modules.DB:GetAllCharacters(false, true)
    local info
    local currentPlayerFullName = addon.Modules.DB:GetPlayerFullName()
    local currentViewChar = addon.Modules.BankFrame:GetCurrentViewChar()

    for i, char in ipairs(characters) do
        local charFullName = char.fullName
        local charClassToken = char.classToken
        
        -- Get class color
        local classColor = charClassToken and RAID_CLASS_COLORS[charClassToken]
        local r, g, b = 1, 1, 1
        if classColor then
            r, g, b = classColor.r, classColor.g, classColor.b
        end

        -- Create colored name
        local coloredName = addon.Modules.Utils:ColorText(char.name, r, g, b)

        info = {}
        info.text = coloredName
        info.func = function()
            if charFullName == currentPlayerFullName then
                addon.Modules.BankFrame:ShowCurrentCharacter()
            else
                addon.Modules.BankFrame:ShowCharacter(charFullName)
            end
        end
        info.checked = (currentViewChar == charFullName or (not currentViewChar and charFullName == currentPlayerFullName))
        UIDropDownMenu_AddButton(info)
    end
end

function Guda_BankFrame_ToggleBankDropdown(button)
    local menuFrame = getglobal("Guda_BankCharacterMenu")
    if not menuFrame then
        menuFrame = CreateFrame("Frame", "Guda_BankCharacterMenu", UIParent, "UIDropDownMenuTemplate")
    end
    UIDropDownMenu_Initialize(menuFrame, Guda_BankCharacterMenu_Initialize, "MENU")
    ToggleDropDownMenu(1, nil, menuFrame, "cursor", 0, 0)
end

-- Drag handlers for bank bag slots
function Guda_BankBagSlot_OnDragStart(button, bagID)
    if not bagID or bagID == -1 then return end
    if not addon.Modules.BankScanner:IsBankOpen() then return end

    local invSlot = addon.Modules.BankFrame:GetBankInvSlotForBagID(bagID)
    if not invSlot then return end

    local texture = GetInventoryItemTexture("player", invSlot)
    if texture then
        button:SetAlpha(0.6)
        PickupInventoryItem(invSlot)
        -- Instantly refresh visuals to reflect the slot is now on cursor
        Guda_BankBagSlot_Update(button, bagID)
        if BankFrame and BankFrame.Update then BankFrame:Update() end
    end
end

function Guda_BankBagSlot_OnDragStop(button, bagID)
    button:SetAlpha(1.0)
end

function Guda_BankBagSlot_OnReceiveDrag(button, bagID)
    if not bagID or bagID == -1 then return end
    if not CursorHasItem or not CursorHasItem() then return end
    if not addon.Modules.BankScanner:IsBankOpen() then return end

    local invSlot, bankButtonID = addon.Modules.BankFrame:GetBankInvSlotForBagID(bagID)
    if not invSlot then return end

    local purchased = (bankButtonID and bankButtonID <= GetNumBankSlots())
    if not purchased then return end

    if EquipCursorItem then
        EquipCursorItem(invSlot)
    elseif PutItemInBag then
        PutItemInBag(invSlot)
    end

    Guda_BankBagSlot_Update(button, bagID)
    if BankFrame and BankFrame.Update then BankFrame:Update() end
end
