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

    -- Set How to Use text
    local instructions = getglobal("Guda_SettingsPopup_GuideTab_Instructions")
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

-- Tab switching logic (GudaPlates style)
function Guda_SettingsPopup_SelectTab(tabName)
    -- Hide all tab content frames
    local generalTab = getglobal("Guda_SettingsPopup_GeneralTab")
    local iconsTab = getglobal("Guda_SettingsPopup_IconsTab")
    local categoriesTab = getglobal("Guda_SettingsPopup_CategoriesTab")
    local guideTab = getglobal("Guda_SettingsPopup_GuideTab")

    if generalTab then generalTab:Hide() end
    if iconsTab then iconsTab:Hide() end
    if categoriesTab then categoriesTab:Hide() end
    if guideTab then guideTab:Hide() end

    -- Reset all tab button backgrounds to inactive (0.1 alpha)
    local generalBg = getglobal("Guda_SettingsPopup_GeneralTabButton_Bg")
    local iconsBg = getglobal("Guda_SettingsPopup_IconsTabButton_Bg")
    local categoriesBg = getglobal("Guda_SettingsPopup_CategoriesTabButton_Bg")
    local guideBg = getglobal("Guda_SettingsPopup_GuideTabButton_Bg")

    if generalBg then generalBg:SetTexture(1, 1, 1, 0.1) end
    if iconsBg then iconsBg:SetTexture(1, 1, 1, 0.1) end
    if categoriesBg then categoriesBg:SetTexture(1, 1, 1, 0.1) end
    if guideBg then guideBg:SetTexture(1, 1, 1, 0.1) end

    -- Show selected tab and highlight its button
    if tabName == "general" then
        if generalTab then generalTab:Show() end
        if generalBg then generalBg:SetTexture(1, 1, 1, 0.3) end
    elseif tabName == "icons" then
        if iconsTab then iconsTab:Show() end
        if iconsBg then iconsBg:SetTexture(1, 1, 1, 0.3) end
    elseif tabName == "categories" then
        if categoriesTab then categoriesTab:Show() end
        if categoriesBg then categoriesBg:SetTexture(1, 1, 1, 0.3) end
        Guda_SettingsPopup_CategoriesTab_Update()
    elseif tabName == "guide" then
        if guideTab then guideTab:Show() end
        if guideBg then guideBg:SetTexture(1, 1, 1, 0.3) end
    end
end

-- OnShow
function Guda_SettingsPopup_OnShow(self)
    -- Default to General tab
    Guda_SettingsPopup_SelectTab("general")

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
    local bagViewType = Guda.Modules.DB:GetSetting("bagViewType") or "single"
    local bankViewType = Guda.Modules.DB:GetSetting("bankViewType") or "single"
    local questBarSize = Guda.Modules.DB:GetSetting("questBarSize") or 36
    local trackedBarSize = Guda.Modules.DB:GetSetting("trackedBarSize") or 36

    -- Update sliders and checkboxes
    local bagSlider = getglobal("Guda_SettingsPopup_BagColumnsSlider")
    local bankSlider = getglobal("Guda_SettingsPopup_BankColumnsSlider")
    local iconSizeSlider = getglobal("Guda_SettingsPopup_IconSizeSlider")
    local iconFontSizeSlider = getglobal("Guda_SettingsPopup_IconFontSizeSlider")
    local iconSpacingSlider = getglobal("Guda_SettingsPopup_IconSpacingSlider")
    local bgTransparencySlider = getglobal("Guda_SettingsPopup_BgTransparencySlider")
    local questBarSizeSlider = getglobal("Guda_SettingsPopup_QuestBarSizeSlider")
    local trackedBarSizeSlider = getglobal("Guda_SettingsPopup_TrackedBarSizeSlider")
    local lockCheckbox = getglobal("Guda_SettingsPopup_LockBagsCheckbox")
    local hideBordersCheckbox = getglobal("Guda_SettingsPopup_HideBordersCheckbox")
    local qualityBorderEquipmentCheckbox = getglobal("Guda_SettingsPopup_QualityBorderEquipmentCheckbox")
    local qualityBorderOtherCheckbox = getglobal("Guda_SettingsPopup_QualityBorderOtherCheckbox")
    local showSearchBarCheckbox = getglobal("Guda_SettingsPopup_ShowSearchBarCheckbox")
    local showQuestBarCheckbox = getglobal("Guda_SettingsPopup_ShowQuestBarCheckbox")
    local hoverBaglineCheckbox = getglobal("Guda_SettingsPopup_HoverBaglineCheckbox")
    local hideFooterCheckbox = getglobal("Guda_SettingsPopup_HideFooterCheckbox")
    local showTooltipCountsCheckbox = getglobal("Guda_SettingsPopup_ShowTooltipCountsCheckbox")
    local bagViewButton = getglobal("Guda_SettingsPopup_BagViewTypeButton")
    local bankViewButton = getglobal("Guda_SettingsPopup_BankViewTypeButton")

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

    if questBarSizeSlider then
        questBarSizeSlider:SetValue(questBarSize)
    end

    if trackedBarSizeSlider then
        trackedBarSizeSlider:SetValue(trackedBarSize)
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

    if bagViewButton then
        if bagViewType == "single" then
            bagViewButton:SetText("Bag View: Single")
        else
            bagViewButton:SetText("Bag View: Category")
        end
    end

    if bankViewButton then
        if bankViewType == "single" then
            bankViewButton:SetText("Bank View: Single")
        else
            bankViewButton:SetText("Bank View: Category")
        end
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
    
    local frames = { "Guda_BagFrame", "Guda_BankFrame", "Guda_MailboxFrame", "Guda_SettingsPopup", "Guda_QuestItemBar" }
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
    getglobal(self:GetName().."Low"):SetText("22px")
    getglobal(self:GetName().."High"):SetText("64px")

    local text = getglobal(self:GetName().."Text")
    text:SetText("Icon size")

    -- Increase font size
    local font, _, flags = text:GetFont()
    if font then
        text:SetFont(font, 12, flags)
    end

    self:SetMinMaxValues(22, 64)
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

-- Quest Bar Size Slider OnLoad
function Guda_SettingsPopup_QuestBarSizeSlider_OnLoad(self)
    getglobal(self:GetName().."Low"):SetText("22px")
    getglobal(self:GetName().."High"):SetText("64px")

    local text = getglobal(self:GetName().."Text")
    text:SetText("Quest bar size")

    -- Increase font size
    local font, _, flags = text:GetFont()
    if font then
        text:SetFont(font, 12, flags)
    end

    self:SetMinMaxValues(22, 64)
    self:SetValueStep(1)

    local currentValue = Guda.Modules.DB:GetSetting("questBarSize") or 36
    self:SetValue(currentValue)
end

-- Quest Bar Size Slider OnValueChanged
function Guda_SettingsPopup_QuestBarSizeSlider_OnValueChanged(self)
    local value = math.floor(self:GetValue() + 0.5)

    getglobal(self:GetName().."Text"):SetText("Quest bar size: " .. value .. "px")

    Guda.Modules.DB:SetSetting("questBarSize", value)

    -- Update quest item bar
    if Guda.Modules.QuestItemBar and Guda.Modules.QuestItemBar.Update then
        Guda.Modules.QuestItemBar:Update()
    end
end

-- Tracked Bar Size Slider OnLoad
function Guda_SettingsPopup_TrackedBarSizeSlider_OnLoad(self)
    getglobal(self:GetName().."Low"):SetText("22px")
    getglobal(self:GetName().."High"):SetText("64px")

    local text = getglobal(self:GetName().."Text")
    text:SetText("Tracked bar size")

    -- Increase font size
    local font, _, flags = text:GetFont()
    if font then
        text:SetFont(font, 12, flags)
    end

    self:SetMinMaxValues(22, 64)
    self:SetValueStep(1)

    local currentValue = Guda.Modules.DB:GetSetting("trackedBarSize") or 36
    self:SetValue(currentValue)
end

-- Tracked Bar Size Slider OnValueChanged
function Guda_SettingsPopup_TrackedBarSizeSlider_OnValueChanged(self)
    local value = math.floor(self:GetValue() + 0.5)

    getglobal(self:GetName().."Text"):SetText("Tracked bar size: " .. value .. "px")

    Guda.Modules.DB:SetSetting("trackedBarSize", value)

    -- Update tracked item bar
    if Guda.Modules.TrackedItemBar and Guda.Modules.TrackedItemBar.Update then
        Guda.Modules.TrackedItemBar:Update()
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

    local mailboxFrame = getglobal("Guda_MailboxFrame")
    if mailboxFrame then
        if isChecked then
            Guda:ApplyBackdrop(mailboxFrame, "MINIMALIST_BORDER", "DEFAULT")
        else
            Guda:ApplyBackdrop(mailboxFrame, "DEFAULT_FRAME", "DEFAULT")
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

-- Mark Unusable Items Checkbox OnLoad
function Guda_SettingsPopup_MarkUnusableCheckbox_OnLoad(self)
    local text = getglobal(self:GetName().."Text")
    if text then
        text:SetText("Mark Unusable Items")

        -- Increase font size
        local font, _, flags = text:GetFont()
        if font then
            text:SetFont(font, 13, flags)
        end
    end

    -- Tooltip
    self.tooltipText = "Show a red tint on items that your character cannot use (wrong class, level, etc.)."

    local markUnusable = true
    if Guda and Guda.Modules and Guda.Modules.DB then
        markUnusable = Guda.Modules.DB:GetSetting("markUnusableItems")
        if markUnusable == nil then
            markUnusable = true
        end
    end

    self:SetChecked(markUnusable and 1 or 0)
end

-- Mark Unusable Items Checkbox OnClick
function Guda_SettingsPopup_MarkUnusableCheckbox_OnClick(self)
    local isChecked = self:GetChecked() == 1

    -- Save setting
    if Guda and Guda.Modules and Guda.Modules.DB then
        Guda.Modules.DB:SetSetting("markUnusableItems", isChecked)
    end

    -- Update bag and bank frames to apply/remove the red tint
    local bagFrame = getglobal("Guda_BagFrame")
    if bagFrame and bagFrame:IsShown() then
        Guda.Modules.BagFrame:Update()
    end

    local bankFrame = getglobal("Guda_BankFrame")
    if bankFrame and bankFrame:IsShown() then
        Guda.Modules.BankFrame:Update()
    end
end

-- Bag View Type Button OnClick
function Guda_SettingsPopup_BagViewTypeButton_OnClick()
    local current = Guda.Modules.DB:GetSetting("bagViewType") or "single"
    local newValue = (current == "single") and "category" or "single"
    Guda.Modules.DB:SetSetting("bagViewType", newValue)
    
    local btn = getglobal("Guda_SettingsPopup_BagViewTypeButton")
    if btn then
        btn:SetText(newValue == "single" and "Bag View: Single" or "Bag View: Category")
    end
    
    -- Refresh bag frame if it's open
    if Guda_BagFrame:IsShown() then
        Guda.Modules.BagFrame:Update()
    end
end

-- Bank View Type Button OnClick
function Guda_SettingsPopup_BankViewTypeButton_OnClick()
    local current = Guda.Modules.DB:GetSetting("bankViewType") or "single"
    local newValue = (current == "single") and "category" or "single"
    Guda.Modules.DB:SetSetting("bankViewType", newValue)
    
    local btn = getglobal("Guda_SettingsPopup_BankViewTypeButton")
    if btn then
        btn:SetText(newValue == "single" and "Bank View: Single" or "Bank View: Category")
    end
    
    -- Refresh bank frame if it's open
    if Guda_BankFrame:IsShown() then
        Guda.Modules.BankFrame:Update()
    end
end

-- Reverse Stack Sort Checkbox OnLoad
function Guda_SettingsPopup_ReverseStackSortCheckbox_OnLoad(self)
    local text = getglobal(self:GetName().."Text")
    if text then
        text:SetText("Reverse Stack Sort")

        -- Increase font size
        local font, _, flags = text:GetFont()
        if font then
            text:SetFont(font, 13, flags)
        end
    end

    -- Tooltip
    self.tooltipText = "When enabled, smaller stacks of the same item will be sorted before larger stacks (e.g., stack of 16 before stack of 20)."

    local reverseStackSort = false
    if Guda and Guda.Modules and Guda.Modules.DB then
        reverseStackSort = Guda.Modules.DB:GetSetting("reverseStackSort")
        if reverseStackSort == nil then
            reverseStackSort = false
        end
    end

    self:SetChecked(reverseStackSort and 1 or 0)
end

-- Reverse Stack Sort Checkbox OnClick
function Guda_SettingsPopup_ReverseStackSortCheckbox_OnClick(self)
    local isChecked = self:GetChecked() == 1

    -- Save setting
    if Guda and Guda.Modules and Guda.Modules.DB then
        Guda.Modules.DB:SetSetting("reverseStackSort", isChecked)
    end

    -- Note: Sorting will use the new setting on next sort operation
    -- No immediate UI update needed
end

-------------------------------------------
-- Categories Tab Functions
-------------------------------------------

-- Number of visible rows in the category list
local CATEGORY_ROW_HEIGHT = 22
local CATEGORY_VISIBLE_ROWS = 14
local categoryRowFrames = {}

-- Create or get a category row frame
local function GetCategoryRowFrame(index)
    if categoryRowFrames[index] then
        return categoryRowFrames[index]
    end

    local container = getglobal("Guda_SettingsPopup_CategoryListContainer")
    if not container then return nil end

    local rowName = "Guda_SettingsPopup_CategoryRow" .. index
    local row = CreateFrame("Frame", rowName, container)
    row:SetHeight(CATEGORY_ROW_HEIGHT)
    row:SetWidth(420)
    row:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -((index - 1) * CATEGORY_ROW_HEIGHT))

    -- Background highlight
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(row)
    bg:SetTexture(1, 1, 1, 0)
    row.bg = bg

    -- Enable checkbox
    local checkbox = CreateFrame("CheckButton", rowName .. "_Checkbox", row, "UICheckButtonTemplate")
    checkbox:SetWidth(20)
    checkbox:SetHeight(20)
    checkbox:SetPoint("LEFT", row, "LEFT", 0, 0)
    checkbox:SetScript("OnClick", function()
        local catId = this:GetParent().categoryId
        if catId and Guda.Modules.CategoryManager then
            Guda.Modules.CategoryManager:ToggleCategory(catId)
            Guda_SettingsPopup_CategoriesTab_Update()
            Guda_SettingsPopup_RefreshBagFrames()
        end
    end)
    row.checkbox = checkbox

    -- Category name
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
    nameText:SetWidth(200)
    nameText:SetJustifyH("LEFT")
    row.nameText = nameText

    -- Move Up button
    local upBtn = CreateFrame("Button", rowName .. "_UpBtn", row)
    upBtn:SetWidth(20)
    upBtn:SetHeight(20)
    upBtn:SetPoint("LEFT", nameText, "RIGHT", 10, 0)
    upBtn:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
    upBtn:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Down")
    upBtn:SetHighlightTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Highlight")
    upBtn:SetScript("OnClick", function()
        local catId = this:GetParent().categoryId
        if catId and Guda.Modules.CategoryManager then
            Guda.Modules.CategoryManager:MoveCategoryUp(catId)
            Guda_SettingsPopup_CategoriesTab_Update()
            Guda_SettingsPopup_RefreshBagFrames()
        end
    end)
    row.upBtn = upBtn

    -- Move Down button
    local downBtn = CreateFrame("Button", rowName .. "_DownBtn", row)
    downBtn:SetWidth(20)
    downBtn:SetHeight(20)
    downBtn:SetPoint("LEFT", upBtn, "RIGHT", 2, 0)
    downBtn:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
    downBtn:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Down")
    downBtn:SetHighlightTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Highlight")
    downBtn:SetScript("OnClick", function()
        local catId = this:GetParent().categoryId
        if catId and Guda.Modules.CategoryManager then
            Guda.Modules.CategoryManager:MoveCategoryDown(catId)
            Guda_SettingsPopup_CategoriesTab_Update()
            Guda_SettingsPopup_RefreshBagFrames()
        end
    end)
    row.downBtn = downBtn

    -- Delete button (only for custom categories)
    local deleteBtn = CreateFrame("Button", rowName .. "_DeleteBtn", row, "UIPanelCloseButton")
    deleteBtn:SetWidth(20)
    deleteBtn:SetHeight(20)
    deleteBtn:SetPoint("LEFT", downBtn, "RIGHT", 5, 0)
    deleteBtn:SetScript("OnClick", function()
        local catId = this:GetParent().categoryId
        if catId and Guda.Modules.CategoryManager then
            local def = Guda.Modules.CategoryManager:GetCategory(catId)
            if def and not def.isBuiltIn then
                Guda.Modules.CategoryManager:DeleteCategory(catId)
                Guda_SettingsPopup_CategoriesTab_Update()
                Guda_SettingsPopup_RefreshBagFrames()
            end
        end
    end)
    row.deleteBtn = deleteBtn

    -- Built-in indicator
    local builtInText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    builtInText:SetPoint("LEFT", deleteBtn, "RIGHT", 5, 0)
    builtInText:SetText("(Built-in)")
    builtInText:SetTextColor(0.5, 0.5, 0.5)
    row.builtInText = builtInText

    -- Hover highlight
    row:EnableMouse(true)
    row:SetScript("OnEnter", function()
        this.bg:SetTexture(1, 1, 1, 0.1)
    end)
    row:SetScript("OnLeave", function()
        this.bg:SetTexture(1, 1, 1, 0)
    end)

    categoryRowFrames[index] = row
    return row
end

-- Update the category list display
function Guda_SettingsPopup_CategoriesTab_Update()
    if not Guda.Modules.CategoryManager then return end

    local scrollFrame = getglobal("Guda_SettingsPopup_CategoriesScrollFrame")
    if not scrollFrame then return end

    local categoryOrder = Guda.Modules.CategoryManager:GetCategoryOrder()
    local totalCategories = table.getn(categoryOrder)

    -- Update scroll frame
    FauxScrollFrame_Update(scrollFrame, totalCategories, CATEGORY_VISIBLE_ROWS, CATEGORY_ROW_HEIGHT)

    local offset = FauxScrollFrame_GetOffset(scrollFrame)

    for i = 1, CATEGORY_VISIBLE_ROWS do
        local row = GetCategoryRowFrame(i)
        if row then
            local dataIndex = i + offset
            if dataIndex <= totalCategories then
                local categoryId = categoryOrder[dataIndex]
                local categoryDef = Guda.Modules.CategoryManager:GetCategory(categoryId)

                if categoryDef then
                    row.categoryId = categoryId
                    row.nameText:SetText(categoryDef.name or categoryId)
                    row.checkbox:SetChecked(categoryDef.enabled and 1 or 0)

                    -- Show/hide delete button based on whether it's built-in
                    if categoryDef.isBuiltIn then
                        row.deleteBtn:Hide()
                        row.builtInText:Show()
                    else
                        row.deleteBtn:Show()
                        row.builtInText:Hide()
                    end

                    -- Enable/disable move buttons based on position
                    if dataIndex == 1 then
                        row.upBtn:Disable()
                    else
                        row.upBtn:Enable()
                    end

                    if dataIndex == totalCategories then
                        row.downBtn:Disable()
                    else
                        row.downBtn:Enable()
                    end

                    -- Set text color based on enabled state
                    if categoryDef.enabled then
                        row.nameText:SetTextColor(1, 1, 1)
                    else
                        row.nameText:SetTextColor(0.5, 0.5, 0.5)
                    end

                    row:Show()
                else
                    row:Hide()
                end
            else
                row:Hide()
            end
        end
    end

    -- Set reset button text
    local resetBtn = getglobal("Guda_SettingsPopup_ResetCategoriesButton")
    if resetBtn then
        resetBtn:SetText("Reset to Defaults")
    end
end

-- Reset categories to defaults
function Guda_SettingsPopup_ResetCategories_OnClick()
    if Guda.Modules.CategoryManager then
        Guda.Modules.CategoryManager:ResetToDefaults()
        Guda_SettingsPopup_CategoriesTab_Update()
        Guda_SettingsPopup_RefreshBagFrames()
        Guda:Print("Categories reset to defaults.")
    end
end

-- Refresh bag and bank frames after category changes
function Guda_SettingsPopup_RefreshBagFrames()
    -- Refresh category list
    Guda_RefreshCategoryList()

    -- Update bag frame if visible
    local bagFrame = getglobal("Guda_BagFrame")
    if bagFrame and bagFrame:IsShown() then
        Guda.Modules.BagFrame:Update()
    end

    -- Update bank frame if visible
    local bankFrame = getglobal("Guda_BankFrame")
    if bankFrame and bankFrame:IsShown() then
        Guda.Modules.BankFrame:Update()
    end
end

-- Initialize
function SettingsPopup:Initialize()
    Guda:Debug("Settings popup initialized")
end

