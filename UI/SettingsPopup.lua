-- Guda Settings Popup
-- UI for adjusting addon settings

local addon = Guda

local SettingsPopup = {}
addon.Modules.SettingsPopup = SettingsPopup

-- Global function to open settings (called from XML)
function Guda_OpenSettings()
    local frame = getglobal("Guda_SettingsPopup")
    if frame then
        frame:Show()
    end
end

-- OnLoad
function Guda_SettingsPopup_OnLoad(self)
    -- Set up initial backdrop
    Guda:ApplyBackdrop(self, "DEFAULT_FRAME")

    local title = getglobal(self:GetName().."_Title")
    title:SetText("Guda Settings")
    -- Increase title font size
    local titleFont, _, titleFlags = title:GetFont()
    if titleFont then
        title:SetFont(titleFont, 16, titleFlags)
    end

    -- Set tab names
    PanelTemplates_SetNumTabs(self, 2)
    getglobal(self:GetName().."Tab1"):SetText("General")
    getglobal(self:GetName().."Tab2"):SetText("Quick Guide")
    PanelTemplates_SetTab(self, 1)

    -- Set How to Use text
    local instructions = getglobal(self:GetName().."_HowToUseTab_Instructions")
    if instructions then
        local text = "|cffffd100Tracking Items:|r\n" ..
                     "Alt + Left Click on any item in your bags to track it.\n" ..
                     "Tracked items will appear in the Tracked Item Bar.\n" ..
                     "Left Click on an item in the bar to use it.\n" ..
                     "Alt + Left Click on an item in the bar to untrack it.\n\n" ..
                     "|cffffd100Moving Bars:|r\n" ..
                     "Shift + Left Click and drag any item on the Quest Item Bar or Tracked Item Bar to move the bar.\n" ..
                     "You can also drag the bar background if it's visible.\n\n" ..
                     "|cffffd100Quest Item Bar:|r\n" ..
                     "Alt + Left Click on a quest item in your bags to pin it.\n" ..
                     "Alt + Right Click on an item in the bar to unpin it."
        instructions:SetText(text)
    end

    Guda:Debug("Settings popup loaded")
end

-- Tab switching logic
function Guda_SettingsPopup_Tab_OnClick(id)
    local frame = Guda_SettingsPopup
    PanelTemplates_SetTab(frame, id)
    
    if id == 1 then
        getglobal(frame:GetName().."_GeneralTab"):Show()
        getglobal(frame:GetName().."_HowToUseTab"):Hide()
    else
        getglobal(frame:GetName().."_GeneralTab"):Hide()
        getglobal(frame:GetName().."_HowToUseTab"):Show()
    end
end

-- OnShow
function Guda_SettingsPopup_OnShow(self)
    -- Default to General tab
    Guda_SettingsPopup_Tab_OnClick(1)

    -- Load current settings
    local bagColumns = Guda.Modules.DB:GetSetting("bagColumns") or 10
    local bankColumns = Guda.Modules.DB:GetSetting("bankColumns") or 10
    local iconSize = Guda.Modules.DB:GetSetting("iconSize") or 40
    local iconFontSize = Guda.Modules.DB:GetSetting("iconFontSize") or 12
    local iconSpacing = Guda.Modules.DB:GetSetting("iconSpacing") or 0
    local lockBags = Guda.Modules.DB:GetSetting("lockBags")
    if lockBags == nil then
        lockBags = false
    end
    local hideBorders = Guda.Modules.DB:GetSetting("hideBorders")
    if hideBorders == nil then
        hideBorders = false
    end
    local showQualityBorderEquipment = Guda.Modules.DB:GetSetting("showQualityBorderEquipment")
    if showQualityBorderEquipment == nil then
        showQualityBorderEquipment = true
    end
    local showQualityBorderOther = Guda.Modules.DB:GetSetting("showQualityBorderOther")
    if showQualityBorderOther == nil then
        showQualityBorderOther = true
    end
    local showSearchBar = Guda.Modules.DB:GetSetting("showSearchBar")
    if showSearchBar == nil then
        showSearchBar = true
    end
    local showQuestBar = Guda.Modules.DB:GetSetting("showQuestBar")
    if showQuestBar == nil then
        showQuestBar = true
    end
    local hoverBagline = Guda.Modules.DB:GetSetting("hoverBagline")
    if hoverBagline == nil then
        hoverBagline = false
    end
    local bgTransparency = Guda.Modules.DB:GetSetting("bgTransparency") or 0.15

    -- Update sliders and checkboxes
    local bagSlider = getglobal("Guda_SettingsPopup_BagColumnsSlider")
    local bankSlider = getglobal("Guda_SettingsPopup_BankColumnsSlider")
    local iconSizeSlider = getglobal("Guda_SettingsPopup_IconSizeSlider")
    local iconFontSizeSlider = getglobal("Guda_SettingsPopup_IconFontSizeSlider")
    local iconSpacingSlider = getglobal("Guda_SettingsPopup_IconSpacingSlider")
    local bgTransparencySlider = getglobal("Guda_SettingsPopup_BgTransparencySlider")
    local lockCheckbox = getglobal("Guda_SettingsPopup_LockBagsCheckbox")
    local hideBordersCheckbox = getglobal("Guda_SettingsPopup_HideBordersCheckbox")
    local qualityBorderEquipmentCheckbox = getglobal("Guda_SettingsPopup_QualityBorderEquipmentCheckbox")
    local qualityBorderOtherCheckbox = getglobal("Guda_SettingsPopup_QualityBorderOtherCheckbox")
    local showSearchBarCheckbox = getglobal("Guda_SettingsPopup_ShowSearchBarCheckbox")
    local showQuestBarCheckbox = getglobal("Guda_SettingsPopup_ShowQuestBarCheckbox")
    local hoverBaglineCheckbox = getglobal("Guda_SettingsPopup_HoverBaglineCheckbox")
    local hideFooterCheckbox = getglobal("Guda_SettingsPopup_HideFooterCheckbox")
    local showTooltipCountsCheckbox = getglobal("Guda_SettingsPopup_ShowTooltipCountsCheckbox")

    local showTooltipCounts = Guda.Modules.DB:GetSetting("showTooltipCounts")
    if showTooltipCounts == nil then
        showTooltipCounts = true
    end

    if bagSlider then
        bagSlider:SetValue(bagColumns)
    end

    if bankSlider then
        bankSlider:SetValue(bankColumns)
    end

    if iconSizeSlider then
        iconSizeSlider:SetValue(iconSize)
    end

    if iconFontSizeSlider then
        iconFontSizeSlider:SetValue(iconFontSize)
    end

    if iconSpacingSlider then
        iconSpacingSlider:SetValue(iconSpacing)
    end

    if bgTransparencySlider then
        bgTransparencySlider:SetValue(bgTransparency)
    end

    if lockCheckbox then
        lockCheckbox:SetChecked(lockBags and 1 or 0)
    end

    if hideBordersCheckbox then
        hideBordersCheckbox:SetChecked(hideBorders and 1 or 0)
    end

    if qualityBorderEquipmentCheckbox then
        qualityBorderEquipmentCheckbox:SetChecked(showQualityBorderEquipment and 1 or 0)
    end

    if qualityBorderOtherCheckbox then
        qualityBorderOtherCheckbox:SetChecked(showQualityBorderOther and 1 or 0)
    end

    if showSearchBarCheckbox then
        showSearchBarCheckbox:SetChecked(showSearchBar and 1 or 0)
    end

    if showQuestBarCheckbox then
        showQuestBarCheckbox:SetChecked(showQuestBar and 1 or 0)
    end

    if hoverBaglineCheckbox then
        hoverBaglineCheckbox:SetChecked(hoverBagline and 1 or 0)
    end

    if showTooltipCountsCheckbox then
        showTooltipCountsCheckbox:SetChecked(showTooltipCounts and 1 or 0)
    end


    -- Update display (might be too tall for current frame size)
    local frame = getglobal("Guda_SettingsPopup")
    if frame then
        frame:SetHeight(600)
    end

    -- Apply border visibility
    if SettingsPopup.UpdateBorderVisibility then
        SettingsPopup:UpdateBorderVisibility()
    end
end

-- Update border visibility based on setting
function SettingsPopup:UpdateBorderVisibility()
    if not addon or not addon.Modules or not addon.Modules.DB then return end

    local frame = getglobal("Guda_SettingsPopup")
    if not frame then return end

    local hideBorders = addon.Modules.DB:GetSetting("hideBorders")
    if hideBorders == nil then
        hideBorders = false
    end

    if hideBorders then
        addon:ApplyBackdrop(frame, "MINIMALIST_BORDER", "DEFAULT")
    else
        addon:ApplyBackdrop(frame, "DEFAULT_FRAME", "DEFAULT")
    end
end

-- Toggle visibility
function SettingsPopup:Toggle()
    local frame = getglobal("Guda_SettingsPopup")
    if frame then
        if frame:IsShown() then
            frame:Hide()
        else
            frame:Show()
        end
    end
end

-- Bag Columns Slider OnLoad
function Guda_SettingsPopup_BagColumnsSlider_OnLoad(self)
    getglobal(self:GetName().."Low"):SetText("5")
    getglobal(self:GetName().."High"):SetText("20")

    local text = getglobal(self:GetName().."Text")
    text:SetText("Bag columns")

    -- Increase font size
    local font, _, flags = text:GetFont()
    if font then
        text:SetFont(font, 12, flags)
    end

    self:SetMinMaxValues(5, 20)
    self:SetValueStep(1)

    local currentValue = Guda.Modules.DB:GetSetting("bagColumns") or 10
    self:SetValue(currentValue)
end

-- Bag Columns Slider OnValueChanged
function Guda_SettingsPopup_BagColumnsSlider_OnValueChanged(self)
    local value = self:GetValue()
    
    -- Update display text
    getglobal(self:GetName().."Text"):SetText("Bag columns: " .. value)
    
    -- Save setting
    Guda.Modules.DB:SetSetting("bagColumns", value)
    
    -- Refresh bag frame if it's open
    local bagFrame = getglobal("Guda_BagFrame")
    if bagFrame and bagFrame:IsShown() then
        Guda.Modules.BagFrame:Update()
    end
end

-- Bank Columns Slider OnLoad
function Guda_SettingsPopup_BankColumnsSlider_OnLoad(self)
    getglobal(self:GetName().."Low"):SetText("5")
    getglobal(self:GetName().."High"):SetText("20")

    local text = getglobal(self:GetName().."Text")
    text:SetText("Bank columns")

    -- Increase font size
    local font, _, flags = text:GetFont()
    if font then
        text:SetFont(font, 12, flags)
    end

    self:SetMinMaxValues(5, 20)
    self:SetValueStep(1)

    local currentValue = Guda.Modules.DB:GetSetting("bankColumns") or 10
    self:SetValue(currentValue)
end

-- Bank Columns Slider OnValueChanged
function Guda_SettingsPopup_BankColumnsSlider_OnValueChanged(self)
    local value = self:GetValue()
    
    -- Update display text
    getglobal(self:GetName().."Text"):SetText("Bank columns: " .. value)
    
    -- Save setting
    Guda.Modules.DB:SetSetting("bankColumns", value)
    
    -- Refresh bank frame if it's open
    local bankFrame = getglobal("Guda_BankFrame")
    if bankFrame and bankFrame:IsShown() then
        Guda.Modules.BankFrame:Update()
    end
end

-- Background Transparency Slider OnLoad
function Guda_SettingsPopup_BgTransparencySlider_OnLoad(self)
    getglobal(self:GetName().."Low"):SetText("0%")
    getglobal(self:GetName().."High"):SetText("100%")

    local text = getglobal(self:GetName().."Text")
    text:SetText("Background Transparency")

    -- Increase font size
    local font, _, flags = text:GetFont()
    if font then
        text:SetFont(font, 12, flags)
    end

    self:SetMinMaxValues(0.0, 1.0)
    self:SetValueStep(0.05)

    local currentValue = Guda.Modules.DB:GetSetting("bgTransparency") or 0.15
    self:SetValue(currentValue)
end

-- Background Transparency Slider OnValueChanged
function Guda_SettingsPopup_BgTransparencySlider_OnValueChanged(self)
    local value = self:GetValue()
    -- Round to 2 decimal places
    value = math.floor(value * 100 + 0.5) / 100

    -- Update display text
    getglobal(self:GetName().."Text"):SetText("Background Transparency: " .. math.floor(value * 100) .. "%")

    -- Save setting
    Guda.Modules.DB:SetSetting("bgTransparency", value)

    -- Apply transparency
    Guda_ApplyBackgroundTransparency()
end

-- Apply background transparency to bag and bank frames
function Guda_ApplyBackgroundTransparency()
    local transparency = Guda.Modules.DB:GetSetting("bgTransparency") or 0.15
    local alpha = 1.0 - transparency
    
    local frames = { "Guda_BagFrame", "Guda_BankFrame", "Guda_SettingsPopup", "Guda_QuestItemBar" }
    for _, frameName in ipairs(frames) do
        local frame = getglobal(frameName)
        if frame then
            -- Reset frame alpha to 1.0 (previous version might have set it)
            frame:SetAlpha(1.0)
            -- Set backdrop color (background only)
            frame:SetBackdropColor(0, 0, 0, alpha)
        end
    end
end

-- Icon Size Slider OnLoad
function Guda_SettingsPopup_IconSizeSlider_OnLoad(self)
    getglobal(self:GetName().."Low"):SetText("28px")
    getglobal(self:GetName().."High"):SetText("64px")

    local text = getglobal(self:GetName().."Text")
    text:SetText("Icon size")

    -- Increase font size
    local font, _, flags = text:GetFont()
    if font then
        text:SetFont(font, 12, flags)
    end

    self:SetMinMaxValues(28, 64)
    self:SetValueStep(1)

    local currentValue = Guda.Modules.DB:GetSetting("iconSize") or addon.Constants.BUTTON_SIZE
    self:SetValue(currentValue)
end

-- Icon Size Slider OnValueChanged
function Guda_SettingsPopup_IconSizeSlider_OnValueChanged(self)
    local value = math.floor(self:GetValue() + 0.5)

    getglobal(self:GetName().."Text"):SetText("Icon size: " .. value .. "px")

    Guda.Modules.DB:SetSetting("iconSize", value)

    local bagFrame = getglobal("Guda_BagFrame")
    if bagFrame and bagFrame:IsShown() then
        Guda.Modules.BagFrame:Update()
    end

    local bankFrame = getglobal("Guda_BankFrame")
    if bankFrame and bankFrame:IsShown() then
        Guda.Modules.BankFrame:Update()
    end
end

-- Icon Font Size Slider OnLoad
function Guda_SettingsPopup_IconFontSizeSlider_OnLoad(self)
    getglobal(self:GetName().."Low"):SetText("8px")
    getglobal(self:GetName().."High"):SetText("20px")

    local text = getglobal(self:GetName().."Text")
    text:SetText("Icon font size")

    -- Increase font size
    local font, _, flags = text:GetFont()
    if font then
        text:SetFont(font, 12, flags)
    end

    self:SetMinMaxValues(8, 20)
    self:SetValueStep(1)

    local currentValue = Guda.Modules.DB:GetSetting("iconFontSize") or 12
    self:SetValue(currentValue)
end

-- Icon Font Size Slider OnValueChanged
function Guda_SettingsPopup_IconFontSizeSlider_OnValueChanged(self)
    local value = math.floor(self:GetValue() + 0.5)

    getglobal(self:GetName().."Text"):SetText("Icon font size: " .. value .. "px")

    Guda.Modules.DB:SetSetting("iconFontSize", value)

    local bagFrame = getglobal("Guda_BagFrame")
    if bagFrame and bagFrame:IsShown() then
        Guda.Modules.BagFrame:Update()
    end

    local bankFrame = getglobal("Guda_BankFrame")
    if bankFrame and bankFrame:IsShown() then
        Guda.Modules.BankFrame:Update()
    end
end

-- Icon Spacing Slider OnLoad
function Guda_SettingsPopup_IconSpacingSlider_OnLoad(self)
    getglobal(self:GetName().."Low"):SetText("-10px")
    getglobal(self:GetName().."High"):SetText("20px")

    local text = getglobal(self:GetName().."Text")
    text:SetText("Icon spacing")

    -- Increase font size
    local font, _, flags = text:GetFont()
    if font then
        text:SetFont(font, 12, flags)
    end

    self:SetMinMaxValues(-10, 20)
    self:SetValueStep(1)

    local currentValue = Guda.Modules.DB:GetSetting("iconSpacing") or 0
    self:SetValue(currentValue)
end

-- Icon Spacing Slider OnValueChanged
function Guda_SettingsPopup_IconSpacingSlider_OnValueChanged(self)
    local value = math.floor(self:GetValue() + 0.5)
    local displayValue = value >= 0 and value .. "px" or value .. "px"
    getglobal(self:GetName().."Text"):SetText("Icon spacing: " .. displayValue)

    -- Save setting
    Guda.Modules.DB:SetSetting("iconSpacing", value)

    -- Update bag frame
    local bagFrame = getglobal("Guda_BagFrame")
    if bagFrame and bagFrame:IsShown() then
        Guda.Modules.BagFrame:Update()
    end

    -- Update bank frame
    local bankFrame = getglobal("Guda_BankFrame")
    if bankFrame and bankFrame:IsShown() then
        if Guda.Modules.BankFrame.UpdateFooterVisibility then
            Guda.Modules.BankFrame:UpdateFooterVisibility()
        end
        Guda.Modules.BankFrame:Update()
    end
end

-- Lock Bags Checkbox OnLoad
function Guda_SettingsPopup_LockBagsCheckbox_OnLoad(self)
    local text = getglobal(self:GetName().."Text")
    if text then
        text:SetText("Lock Bags")

        -- Increase font size
        local font, _, flags = text:GetFont()
        if font then
            text:SetFont(font, 13, flags)
        end
    end

    -- Tooltip
    self.tooltipText = L_LOCK_BAGS_TT

    local isLocked = false
    if Guda and Guda.Modules and Guda.Modules.DB then
        isLocked = Guda.Modules.DB:GetSetting("lockBags")
        if isLocked == nil then
            isLocked = false
        end
    end

    self:SetChecked(isLocked and 1 or 0)
end

-- Lock Bags Checkbox OnClick
function Guda_SettingsPopup_LockBagsCheckbox_OnClick(self)
    local isChecked = self:GetChecked() == 1

    -- Save setting
    if Guda and Guda.Modules and Guda.Modules.DB then
        Guda.Modules.DB:SetSetting("lockBags", isChecked)
    end

    -- Update bag frame draggability
    if Guda and Guda.Modules and Guda.Modules.BagFrame and Guda.Modules.BagFrame.UpdateLockState then
        Guda.Modules.BagFrame:UpdateLockState()
    end
end

-- Hide Borders Checkbox OnLoad
function Guda_SettingsPopup_HideBordersCheckbox_OnLoad(self)
    local text = getglobal(self:GetName().."Text")
    if text then
        text:SetText("Hide Frame Borders")

        -- Increase font size
        local font, _, flags = text:GetFont()
        if font then
            text:SetFont(font, 13, flags)
        end
    end

    -- Tooltip
    self.tooltipText = L_HIDE_BORDERS_TT

    local hideBorders = false
    if Guda and Guda.Modules and Guda.Modules.DB then
        hideBorders = Guda.Modules.DB:GetSetting("hideBorders")
        if hideBorders == nil then
            hideBorders = false
        end
    end

    self:SetChecked(hideBorders and 1 or 0)
end

-- Hide Borders Checkbox OnClick
function Guda_SettingsPopup_HideBordersCheckbox_OnClick(self)
    local isChecked = self:GetChecked() == 1

    -- Save setting
    if Guda and Guda.Modules and Guda.Modules.DB then
        Guda.Modules.DB:SetSetting("hideBorders", isChecked)
    end

    -- Update border visibility on both bag and bank frames using helper function
    local bagFrame = getglobal("Guda_BagFrame")
    if bagFrame then
        if isChecked then
            Guda:ApplyBackdrop(bagFrame, "MINIMALIST_BORDER", "DEFAULT")
        else
            Guda:ApplyBackdrop(bagFrame, "DEFAULT_FRAME", "DEFAULT")
        end
    end

    local bankFrame = getglobal("Guda_BankFrame")
    if bankFrame then
        if isChecked then
            Guda:ApplyBackdrop(bankFrame, "MINIMALIST_BORDER", "DEFAULT")
        else
            Guda:ApplyBackdrop(bankFrame, "DEFAULT_FRAME", "DEFAULT")
        end
    end

    -- Update border visibility on settings frame
    if SettingsPopup.UpdateBorderVisibility then
        SettingsPopup:UpdateBorderVisibility()
    end
end

-- Quality Border Equipment Checkbox OnLoad
function Guda_SettingsPopup_QualityBorderEquipmentCheckbox_OnLoad(self)
    local text = getglobal(self:GetName().."Text")
    if text then
        text:SetText("Equipment Borders")

        -- Increase font size
        local font, _, flags = text:GetFont()
        if font then
            text:SetFont(font, 13, flags)
        end
    end

    -- Tooltip
    self.tooltipText = L_QUALITY_BORDER_EQ_TT

    local showBorders = true
    if Guda and Guda.Modules and Guda.Modules.DB then
        showBorders = Guda.Modules.DB:GetSetting("showQualityBorderEquipment")
        if showBorders == nil then
            showBorders = true
        end
    end

    self:SetChecked(showBorders and 1 or 0)
end

-- Quality Border Equipment Checkbox OnClick
function Guda_SettingsPopup_QualityBorderEquipmentCheckbox_OnClick(self)
    local isChecked = self:GetChecked() == 1

    -- Save setting
    if Guda and Guda.Modules and Guda.Modules.DB then
        Guda.Modules.DB:SetSetting("showQualityBorderEquipment", isChecked)
    end

    -- Update bag and bank frames
    local bagFrame = getglobal("Guda_BagFrame")
    if bagFrame and bagFrame:IsShown() then
        Guda.Modules.BagFrame:Update()
    end

    local bankFrame = getglobal("Guda_BankFrame")
    if bankFrame and bankFrame:IsShown() then
        Guda.Modules.BankFrame:Update()
    end
end

-- Quality Border Other Checkbox OnLoad
function Guda_SettingsPopup_QualityBorderOtherCheckbox_OnLoad(self)
    local text = getglobal(self:GetName().."Text")
    if text then
        text:SetText("Other Item Borders")

        -- Increase font size
        local font, _, flags = text:GetFont()
        if font then
            text:SetFont(font, 13, flags)
        end
    end

    -- Tooltip
    self.tooltipText = L_QUALITY_BORDER_OTHER_TT

    local showBorders = true
    if Guda and Guda.Modules and Guda.Modules.DB then
        showBorders = Guda.Modules.DB:GetSetting("showQualityBorderOther")
        if showBorders == nil then
            showBorders = true
        end
    end

    self:SetChecked(showBorders and 1 or 0)
end

-- Quality Border Other Checkbox OnClick
function Guda_SettingsPopup_QualityBorderOtherCheckbox_OnClick(self)
    local isChecked = self:GetChecked() == 1

    -- Save setting
    if Guda and Guda.Modules and Guda.Modules.DB then
        Guda.Modules.DB:SetSetting("showQualityBorderOther", isChecked)
    end

    -- Update bag and bank frames
    local bagFrame = getglobal("Guda_BagFrame")
    if bagFrame and bagFrame:IsShown() then
        Guda.Modules.BagFrame:Update()
    end

    local bankFrame = getglobal("Guda_BankFrame")
    if bankFrame and bankFrame:IsShown() then
        Guda.Modules.BankFrame:Update()
    end
end

-- Show Search Bar Checkbox OnLoad
function Guda_SettingsPopup_ShowSearchBarCheckbox_OnLoad(self)
    local text = getglobal(self:GetName().."Text")
    if text then
        text:SetText("Show Search Bar")

        -- Increase font size
        local font, _, flags = text:GetFont()
        if font then
            text:SetFont(font, 13, flags)
        end
    end

    -- Tooltip
    self.tooltipText = L_SHOW_SEARCH_BAR_TT

    local showSearchBar = true
    if Guda and Guda.Modules and Guda.Modules.DB then
        showSearchBar = Guda.Modules.DB:GetSetting("showSearchBar")
        if showSearchBar == nil then
            showSearchBar = true
        end
    end

    self:SetChecked(showSearchBar and 1 or 0)
end

-- Show Search Bar Checkbox OnClick
function Guda_SettingsPopup_ShowSearchBarCheckbox_OnClick(self)
    local isChecked = self:GetChecked() == 1

    -- Save setting
    if Guda and Guda.Modules and Guda.Modules.DB then
        Guda.Modules.DB:SetSetting("showSearchBar", isChecked)
    end

    -- Update search bar visibility in bag frame
    local bagFrame = getglobal("Guda_BagFrame")
    if bagFrame and bagFrame:IsShown() then
        -- Use the UpdateSearchBarVisibility function which handles anchoring
        if Guda.Modules.BagFrame.UpdateSearchBarVisibility then
            Guda.Modules.BagFrame:UpdateSearchBarVisibility()
        end
        Guda.Modules.BagFrame:Update()
    end

    -- Update search bar visibility in bank frame
    local bankFrame = getglobal("Guda_BankFrame")
    if bankFrame and bankFrame:IsShown() then
        -- Use the UpdateSearchBarVisibility function which handles anchoring
        if Guda.Modules.BankFrame.UpdateSearchBarVisibility then
            Guda.Modules.BankFrame:UpdateSearchBarVisibility()
        end
        Guda.Modules.BankFrame:Update()
    end
end

-- Show Quest Bar Checkbox OnLoad
function Guda_SettingsPopup_ShowQuestBarCheckbox_OnLoad(self)
    local text = getglobal(self:GetName().."Text")
    if text then
        text:SetText("Show Quest Bar")

        -- Increase font size
        local font, _, flags = text:GetFont()
        if font then
            text:SetFont(font, 13, flags)
        end
    end

    -- Tooltip
    self.tooltipText = L_SHOW_QUEST_BAR_TT

    local showQuestBar = true
    if Guda and Guda.Modules and Guda.Modules.DB then
        showQuestBar = Guda.Modules.DB:GetSetting("showQuestBar")
        if showQuestBar == nil then
            showQuestBar = true
        end
    end

    self:SetChecked(showQuestBar and 1 or 0)
end

-- Show Quest Bar Checkbox OnClick
function Guda_SettingsPopup_ShowQuestBarCheckbox_OnClick(self)
    local isChecked = self:GetChecked() == 1

    -- Save setting
    if Guda and Guda.Modules and Guda.Modules.DB then
        Guda.Modules.DB:SetSetting("showQuestBar", isChecked)
    end

    -- Update quest bar visibility
    if Guda.Modules.QuestItemBar and Guda.Modules.QuestItemBar.Update then
        Guda.Modules.QuestItemBar:Update()
    end
end

-- Hover Bagline Checkbox OnLoad
function Guda_SettingsPopup_HoverBaglineCheckbox_OnLoad(self)
    local text = getglobal(self:GetName().."Text")
    if text then
        text:SetText("Hover Bagline")

        -- Increase font size
        local font, _, flags = text:GetFont()
        if font then
            text:SetFont(font, 13, flags)
        end
    end

    -- Tooltip
    self.tooltipText = L_HOVER_BAGLINE_TT

    local hoverBagline = false
    if Guda and Guda.Modules and Guda.Modules.DB then
        hoverBagline = Guda.Modules.DB:GetSetting("hoverBagline")
        if hoverBagline == nil then
            hoverBagline = false
        end
    end

    self:SetChecked(hoverBagline and 1 or 0)
end

-- Hover Bagline Checkbox OnClick
function Guda_SettingsPopup_HoverBaglineCheckbox_OnClick(self)
    local isChecked = self:GetChecked() == 1

    -- Save setting
    if Guda and Guda.Modules and Guda.Modules.DB then
        Guda.Modules.DB:SetSetting("hoverBagline", isChecked)
    end

    -- Update bag frame
    local bagFrame = getglobal("Guda_BagFrame")
    if bagFrame and bagFrame:IsShown() then
        Guda.Modules.BagFrame:Update()
    end
end

-- Hide Footer Checkbox OnLoad
function Guda_SettingsPopup_HideFooterCheckbox_OnLoad(self)
    local text = getglobal(self:GetName().."Text")
    if text then
        text:SetText("Hide Footer")

        -- Increase font size
        local font, _, flags = text:GetFont()
        if font then
            text:SetFont(font, 13, flags)
        end
    end

    -- Tooltip
    self.tooltipText = L_HIDE_FOOTER_TT

    local hideFooter = false
    if Guda and Guda.Modules and Guda.Modules.DB then
        hideFooter = Guda.Modules.DB:GetSetting("hideFooter")
        if hideFooter == nil then
            hideFooter = false
        end
    end

    self:SetChecked(hideFooter and 1 or 0)
end

-- Hide Footer Checkbox OnClick
function Guda_SettingsPopup_HideFooterCheckbox_OnClick(self)
    local isChecked = self:GetChecked() == 1

    -- Save setting
    if Guda and Guda.Modules and Guda.Modules.DB then
        Guda.Modules.DB:SetSetting("hideFooter", isChecked)
    end

    -- Update bag frame
    local bagFrame = getglobal("Guda_BagFrame")
    if bagFrame and bagFrame:IsShown() then
        if Guda.Modules.BagFrame.UpdateFooterVisibility then
            Guda.Modules.BagFrame:UpdateFooterVisibility()
        end
        Guda.Modules.BagFrame:Update()
    end

    -- Update bank frame
    local bankFrame = getglobal("Guda_BankFrame")
    if bankFrame and bankFrame:IsShown() then
        if Guda.Modules.BankFrame.UpdateFooterVisibility then
            Guda.Modules.BankFrame:UpdateFooterVisibility()
        end
        Guda.Modules.BankFrame:Update()
    end
end

-- Show Tooltip Counts Checkbox OnLoad
function Guda_SettingsPopup_ShowTooltipCountsCheckbox_OnLoad(self)
    local text = getglobal(self:GetName().."Text")
    if text then
        text:SetText(L_SHOW_TOOLTIP_COUNTS or "Show Item Counts in Tooltip")

        -- Increase font size
        local font, _, flags = text:GetFont()
        if font then
            text:SetFont(font, 13, flags)
        end
    end
    
    -- Tooltip
    self.tooltipText = L_SHOW_TOOLTIP_COUNTS_TT or "Show how many of this item you have across all your characters in the item tooltip."

    local showTooltipCounts = true
    if Guda and Guda.Modules and Guda.Modules.DB then
        showTooltipCounts = Guda.Modules.DB:GetSetting("showTooltipCounts")
        if showTooltipCounts == nil then
            showTooltipCounts = true
        end
    end

    self:SetChecked(showTooltipCounts and 1 or 0)
end

-- Show Tooltip Counts Checkbox OnClick
function Guda_SettingsPopup_ShowTooltipCountsCheckbox_OnClick(self)
    local isChecked = self:GetChecked() == 1

    -- Save setting
    if Guda and Guda.Modules and Guda.Modules.DB then
        Guda.Modules.DB:SetSetting("showTooltipCounts", isChecked)
    end
end

-- Initialize
function SettingsPopup:Initialize()
    Guda:Debug("Settings popup initialized")
end

