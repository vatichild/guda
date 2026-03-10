-- Guda Settings Popup
-- UI for adjusting addon settings

local addon = Guda

local SettingsPopup = {}
addon.Modules.SettingsPopup = SettingsPopup

-- Section header helper: creates gold-colored section label with separator line
local function CreateSectionHeader(parent, text, yOffset)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, yOffset)
    label:SetText(text)
    label:SetTextColor(1, 0.82, 0, 1)

    -- Separator line extending from label to the right edge
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("LEFT", label, "RIGHT", 8, 0)
    line:SetPoint("RIGHT", parent, "RIGHT", -5, 0)
    line:SetTexture(0.6, 0.6, 0.6, 0.3)

    return label
end

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
                     "Shift + Left Click and drag any item on the Quest Item Bar or Tracked Item Bar to move the bar.\n"
        instructions:SetText(text)
    end

    -- Create section headers for each tab
    local generalTab = getglobal("Guda_SettingsPopup_GeneralTab")
    if generalTab then
        CreateSectionHeader(generalTab, "Appearance", -12)
        CreateSectionHeader(generalTab, "Options", -140)
        CreateSectionHeader(generalTab, "Automation", -250)
    end

    local layoutTab = getglobal("Guda_SettingsPopup_LayoutTab")
    if layoutTab then
        CreateSectionHeader(layoutTab, "View", -12)
        CreateSectionHeader(layoutTab, "Columns", -100)
        CreateSectionHeader(layoutTab, "Options", -240)
    end

    local iconsTab = getglobal("Guda_SettingsPopup_IconsTab")
    if iconsTab then
        CreateSectionHeader(iconsTab, "Icon", -12)
        CreateSectionHeader(iconsTab, "Icon Options", -190)
    end

    local barTab = getglobal("Guda_SettingsPopup_BarTab")
    if barTab then
        CreateSectionHeader(barTab, "Quest Bar", -12)
        CreateSectionHeader(barTab, "Tracked", -120)
    end

    Guda:Debug("Settings popup loaded")
end

-- Tab switching logic (GudaPlates style)
function Guda_SettingsPopup_SelectTab(tabName)
    -- Hide all tab content frames
    local tabs = {
        general = getglobal("Guda_SettingsPopup_GeneralTab"),
        layout = getglobal("Guda_SettingsPopup_LayoutTab"),
        icons = getglobal("Guda_SettingsPopup_IconsTab"),
        bar = getglobal("Guda_SettingsPopup_BarTab"),
        categories = getglobal("Guda_SettingsPopup_CategoriesTab"),
        guide = getglobal("Guda_SettingsPopup_GuideTab"),
    }

    local bgs = {
        general = getglobal("Guda_SettingsPopup_GeneralTabButton_Bg"),
        layout = getglobal("Guda_SettingsPopup_LayoutTabButton_Bg"),
        icons = getglobal("Guda_SettingsPopup_IconsTabButton_Bg"),
        bar = getglobal("Guda_SettingsPopup_BarTabButton_Bg"),
        categories = getglobal("Guda_SettingsPopup_CategoriesTabButton_Bg"),
        guide = getglobal("Guda_SettingsPopup_GuideTabButton_Bg"),
    }

    -- Hide all tabs and reset backgrounds
    for _, tab in pairs(tabs) do
        if tab then tab:Hide() end
    end
    for _, bg in pairs(bgs) do
        if bg then bg:SetTexture(1, 1, 1, 0.1) end
    end

    -- Show selected tab and highlight its button
    if tabs[tabName] then tabs[tabName]:Show() end
    if bgs[tabName] then bgs[tabName]:SetTexture(1, 1, 1, 0.3) end

    -- Special handling for categories tab
    if tabName == "categories" then
        Guda_SettingsPopup_CategoriesTab_Update()
    end
end

-- OnShow
function Guda_SettingsPopup_OnShow(self)
    -- Default to General tab
    Guda_SettingsPopup_SelectTab("general")

    -- Load current settings
    local bagColumns = Guda.Modules.DB:GetSetting("bagColumns") or 10
    local bankColumns = Guda.Modules.DB:GetSetting("bankColumns") or 10
    local iconSize = Guda.Modules.DB:GetSetting("iconSize") or 37
    local iconFontSize = Guda.Modules.DB:GetSetting("iconFontSize") or 12
    local iconSpacing = Guda.Modules.DB:GetSetting("iconSpacing") or 4
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
    local hideBagline = Guda.Modules.DB:GetSetting("hideBagline")
    if hideBagline == nil then
        hideBagline = true  -- default: hidden (Show All Bags unchecked)
    end
    local bgTransparency = Guda.Modules.DB:GetSetting("bgTransparency") or 0.15
    local bagViewType = Guda.Modules.DB:GetSetting("bagViewType") or "single"
    local bankViewType = Guda.Modules.DB:GetSetting("bankViewType") or "single"
    local questBarSize = Guda.Modules.DB:GetSetting("questBarSize") or 36
    local trackedBarSize = Guda.Modules.DB:GetSetting("trackedBarSize") or 36
    local junkOpacity = Guda.Modules.DB:GetSetting("junkOpacity") or 0.6

    -- Update sliders and checkboxes
    local bagSlider = getglobal("Guda_SettingsPopup_BagColumnsSlider")
    local bankSlider = getglobal("Guda_SettingsPopup_BankColumnsSlider")
    local iconSizeSlider = getglobal("Guda_SettingsPopup_IconSizeSlider")
    local iconFontSizeSlider = getglobal("Guda_SettingsPopup_IconFontSizeSlider")
    local iconSpacingSlider = getglobal("Guda_SettingsPopup_IconSpacingSlider")
    local bgTransparencySlider = getglobal("Guda_SettingsPopup_BgTransparencySlider")
    local questBarSizeSlider = getglobal("Guda_SettingsPopup_QuestBarSizeSlider")
    local trackedBarSizeSlider = getglobal("Guda_SettingsPopup_TrackedBarSizeSlider")
    local junkOpacitySlider = getglobal("Guda_SettingsPopup_JunkOpacitySlider")
    local lockCheckbox = getglobal("Guda_SettingsPopup_LockBagsCheckbox")
    local hideBordersCheckbox = getglobal("Guda_SettingsPopup_HideBordersCheckbox")
    local qualityBorderEquipmentCheckbox = getglobal("Guda_SettingsPopup_QualityBorderEquipmentCheckbox")
    local qualityBorderOtherCheckbox = getglobal("Guda_SettingsPopup_QualityBorderOtherCheckbox")
    local showSearchBarCheckbox = getglobal("Guda_SettingsPopup_ShowSearchBarCheckbox")
    local showQuestBarCheckbox = getglobal("Guda_SettingsPopup_ShowQuestBarCheckbox")
    local hoverBaglineCheckbox = getglobal("Guda_SettingsPopup_HoverBaglineCheckbox")
    local hideFooterCheckbox = getglobal("Guda_SettingsPopup_HideFooterCheckbox")
    local showTooltipCountsCheckbox = getglobal("Guda_SettingsPopup_ShowTooltipCountsCheckbox")
    local showEquipSetCategoriesCheckbox = getglobal("Guda_SettingsPopup_ShowEquipSetCategoriesCheckbox")
    local markEquipmentSetsCheckbox = getglobal("Guda_SettingsPopup_MarkEquipmentSetsCheckbox")
    local bagViewDropdown = getglobal("Guda_SettingsPopup_BagViewDropdown")
    local bankViewDropdown = getglobal("Guda_SettingsPopup_BankViewDropdown")
    local themeDropdown = getglobal("Guda_SettingsPopup_ThemeDropdown")

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

    if junkOpacitySlider then
        junkOpacitySlider:SetValue(junkOpacity)
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
        -- Inverted: checked = show bags = NOT hidden
        hoverBaglineCheckbox:SetChecked(hideBagline and 0 or 1)
    end

    if showTooltipCountsCheckbox then
        showTooltipCountsCheckbox:SetChecked(showTooltipCounts and 1 or 0)
    end

    -- New checkboxes
    local showEquipSetCategories = Guda.Modules.DB:GetSetting("showEquipSetCategories")
    if showEquipSetCategories == nil then showEquipSetCategories = true end
    if showEquipSetCategoriesCheckbox then
        showEquipSetCategoriesCheckbox:SetChecked(showEquipSetCategories and 1 or 0)
    end

    local markEquipmentSets = Guda.Modules.DB:GetSetting("markEquipmentSets")
    if markEquipmentSets == nil then markEquipmentSets = true end
    if markEquipmentSetsCheckbox then
        markEquipmentSetsCheckbox:SetChecked(markEquipmentSets and 1 or 0)
    end

    -- Show Category Count checkbox
    local showCategoryCountCheckbox = getglobal("Guda_SettingsPopup_ShowCategoryCountCheckbox")
    local showCategoryCount = Guda.Modules.DB:GetSetting("showCategoryCount")
    if showCategoryCount == nil then showCategoryCount = true end
    if showCategoryCountCheckbox then
        showCategoryCountCheckbox:SetChecked(showCategoryCount and 1 or 0)
    end

    -- Automation checkboxes
    local autoVendorJunkCheckbox = getglobal("Guda_SettingsPopup_AutoVendorJunkCheckbox")
    local autoVendorJunk = Guda.Modules.DB:GetSetting("autoVendorJunk")
    if autoVendorJunk == nil then autoVendorJunk = true end
    if autoVendorJunkCheckbox then
        autoVendorJunkCheckbox:SetChecked(autoVendorJunk and 1 or 0)
    end

    -- White Items as Junk checkbox
    local whiteItemsJunkCheckbox = getglobal("Guda_SettingsPopup_WhiteItemsJunkCheckbox")
    local whiteItemsJunk = Guda.Modules.DB:GetSetting("whiteItemsJunk")
    if whiteItemsJunk == nil then whiteItemsJunk = false end
    if whiteItemsJunkCheckbox then
        whiteItemsJunkCheckbox:SetChecked(whiteItemsJunk and 1 or 0)
    end

    if bagViewDropdown then
        UIDropDownMenu_SetSelectedValue(bagViewDropdown, bagViewType)
        UIDropDownMenu_SetText(bagViewType == "single" and "Single" or "Category", bagViewDropdown)
    end

    if bankViewDropdown then
        UIDropDownMenu_SetSelectedValue(bankViewDropdown, bankViewType)
        UIDropDownMenu_SetText(bankViewType == "single" and "Single" or "Category", bankViewDropdown)
    end

    -- Initialize theme dropdown
    local themeDropdown = getglobal("Guda_SettingsPopup_ThemeDropdown")
    if themeDropdown then
        local currentTheme = Guda.Modules.DB:GetSetting("theme") or "guda"
        local names = { guda = "Guda", blizzard = "Blizzard" }
        UIDropDownMenu_SetSelectedValue(themeDropdown, currentTheme)
        UIDropDownMenu_SetText(names[currentTheme] or currentTheme, themeDropdown)
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
    -- If Theme module is available, delegate to it (handles both themes correctly)
    if Guda.Modules and Guda.Modules.Theme then
        Guda.Modules.Theme:ApplyToAllFrames()
        return
    end

    -- Fallback: original behavior
    local transparency = Guda.Modules.DB:GetSetting("bgTransparency") or 0.15
    local alpha = 1.0 - transparency

    local frames = { "Guda_BagFrame", "Guda_BankFrame", "Guda_MailboxFrame", "Guda_SettingsPopup", "Guda_QuestItemBar" }
    for _, frameName in ipairs(frames) do
        local frame = getglobal(frameName)
        if frame then
            frame:SetAlpha(1.0)
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

    local currentValue = Guda.Modules.DB:GetSetting("iconSize") or 37
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
    getglobal(self:GetName().."Low"):SetText("0px")
    getglobal(self:GetName().."High"):SetText("20px")

    local text = getglobal(self:GetName().."Text")
    text:SetText("Icon spacing")

    -- Increase font size
    local font, _, flags = text:GetFont()
    if font then
        text:SetFont(font, 12, flags)
    end

    self:SetMinMaxValues(0, 20)
    self:SetValueStep(1)

    local currentValue = Guda.Modules.DB:GetSetting("iconSpacing") or 4
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
        text:SetText("Lock Window")

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

    -- Update bank frame draggability
    if Guda and Guda.Modules and Guda.Modules.BankFrame and Guda.Modules.BankFrame.UpdateLockState then
        Guda.Modules.BankFrame:UpdateLockState()
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

    -- Apply theme to all frames (respects hideBorders setting)
    if Guda.Modules and Guda.Modules.Theme then
        Guda.Modules.Theme:ApplyToAllFrames()
    else
        -- Fallback if theme module not loaded
        local bagFrame = getglobal("Guda_BagFrame")
        if bagFrame then
            Guda:ApplyBackdrop(bagFrame, isChecked and "MINIMALIST_BORDER" or "DEFAULT_FRAME", "DEFAULT")
        end
        local bankFrame = getglobal("Guda_BankFrame")
        if bankFrame then
            Guda:ApplyBackdrop(bankFrame, isChecked and "MINIMALIST_BORDER" or "DEFAULT_FRAME", "DEFAULT")
        end
        local mailboxFrame = getglobal("Guda_MailboxFrame")
        if mailboxFrame then
            Guda:ApplyBackdrop(mailboxFrame, isChecked and "MINIMALIST_BORDER" or "DEFAULT_FRAME", "DEFAULT")
        end
        if SettingsPopup.UpdateBorderVisibility then
            SettingsPopup:UpdateBorderVisibility()
        end
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
        text:SetText("Show All Bags")

        -- Increase font size
        local font, _, flags = text:GetFont()
        if font then
            text:SetFont(font, 13, flags)
        end
    end

    -- Tooltip
    self.tooltipText = L_HIDE_BAGLINE_TT

    local hideBagline = true
    if Guda and Guda.Modules and Guda.Modules.DB then
        local val = Guda.Modules.DB:GetSetting("hideBagline")
        if val == nil then
            hideBagline = true  -- default: hidden (Show All Bags unchecked)
        else
            hideBagline = val
        end
    end

    -- Inverted: checked = NOT hidden
    self:SetChecked(hideBagline and 0 or 1)
end

-- Show All Bags Checkbox OnClick (inverted hideBagline)
function Guda_SettingsPopup_HoverBaglineCheckbox_OnClick(self)
    local isChecked = self:GetChecked() == 1

    -- Save setting (inverted: checked means show, so hideBagline = false)
    if Guda and Guda.Modules and Guda.Modules.DB then
        Guda.Modules.DB:SetSetting("hideBagline", not isChecked)
    end

    -- Update bag0 icon
    local bag0 = getglobal("Guda_BagFrame_Toolbar_BagSlot0")
    if bag0 then
        Guda_BagSlot_Update(bag0, 0)
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

-- Junk Opacity Slider OnLoad
function Guda_SettingsPopup_JunkOpacitySlider_OnLoad(self)
    getglobal(self:GetName().."Low"):SetText("10%")
    getglobal(self:GetName().."High"):SetText("100%")

    local text = getglobal(self:GetName().."Text")
    text:SetText("Junk item opacity")

    -- Increase font size
    local font, _, flags = text:GetFont()
    if font then
        text:SetFont(font, 12, flags)
    end

    self:SetMinMaxValues(0.1, 1.0)
    self:SetValueStep(0.05)

    local currentValue = Guda.Modules.DB:GetSetting("junkOpacity") or 0.6
    self:SetValue(currentValue)
end

-- Junk Opacity Slider OnValueChanged
function Guda_SettingsPopup_JunkOpacitySlider_OnValueChanged(self)
    local value = self:GetValue()
    -- Round to 2 decimal places
    value = math.floor(value * 100 + 0.5) / 100

    -- Update display text
    getglobal(self:GetName().."Text"):SetText("Junk item opacity: " .. math.floor(value * 100) .. "%")

    -- Save setting
    Guda.Modules.DB:SetSetting("junkOpacity", value)

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

-- Show Equipment Set Categories Checkbox OnLoad
function Guda_SettingsPopup_ShowEquipSetCategoriesCheckbox_OnLoad(self)
    local text = getglobal(self:GetName().."Text")
    if text then
        text:SetText("Equip Set Categories")

        local font, _, flags = text:GetFont()
        if font then
            text:SetFont(font, 13, flags)
        end
    end

    self.tooltipText = "Show equipment set categories in category view."

    local enabled = true
    if Guda and Guda.Modules and Guda.Modules.DB then
        enabled = Guda.Modules.DB:GetSetting("showEquipSetCategories")
        if enabled == nil then enabled = true end
    end

    self:SetChecked(enabled and 1 or 0)
end

-- Show Equipment Set Categories Checkbox OnClick
function Guda_SettingsPopup_ShowEquipSetCategoriesCheckbox_OnClick(self)
    local isChecked = self:GetChecked() == 1

    if Guda and Guda.Modules and Guda.Modules.DB then
        Guda.Modules.DB:SetSetting("showEquipSetCategories", isChecked)
    end

    local bagFrame = getglobal("Guda_BagFrame")
    if bagFrame and bagFrame:IsShown() then
        Guda.Modules.BagFrame:Update()
    end

    local bankFrame = getglobal("Guda_BankFrame")
    if bankFrame and bankFrame:IsShown() then
        Guda.Modules.BankFrame:Update()
    end
end

-- Mark Equipment Sets Checkbox OnLoad
function Guda_SettingsPopup_MarkEquipmentSetsCheckbox_OnLoad(self)
    local text = getglobal(self:GetName().."Text")
    if text then
        text:SetText("Mark Equipment Sets")

        local font, _, flags = text:GetFont()
        if font then
            text:SetFont(font, 13, flags)
        end
    end

    self.tooltipText = "Show a special icon on items that belong to an equipment set."

    local enabled = true
    if Guda and Guda.Modules and Guda.Modules.DB then
        enabled = Guda.Modules.DB:GetSetting("markEquipmentSets")
        if enabled == nil then enabled = true end
    end

    self:SetChecked(enabled and 1 or 0)
end

-- Mark Equipment Sets Checkbox OnClick
function Guda_SettingsPopup_MarkEquipmentSetsCheckbox_OnClick(self)
    local isChecked = self:GetChecked() == 1

    if Guda and Guda.Modules and Guda.Modules.DB then
        Guda.Modules.DB:SetSetting("markEquipmentSets", isChecked)
    end

    local bagFrame = getglobal("Guda_BagFrame")
    if bagFrame and bagFrame:IsShown() then
        Guda.Modules.BagFrame:Update()
    end

    local bankFrame = getglobal("Guda_BankFrame")
    if bankFrame and bankFrame:IsShown() then
        Guda.Modules.BankFrame:Update()
    end
end

-- Show Category Count Checkbox OnLoad
function Guda_SettingsPopup_ShowCategoryCountCheckbox_OnLoad(self)
    local text = getglobal(self:GetName().."Text")
    if text then
        text:SetText("Show Category Count")

        local font, _, flags = text:GetFont()
        if font then
            text:SetFont(font, 13, flags)
        end
    end

    self.tooltipText = "Show the item count next to each category header in category view."

    local enabled = true
    if Guda and Guda.Modules and Guda.Modules.DB then
        enabled = Guda.Modules.DB:GetSetting("showCategoryCount")
        if enabled == nil then enabled = true end
    end

    self:SetChecked(enabled and 1 or 0)
end

-- Show Category Count Checkbox OnClick
function Guda_SettingsPopup_ShowCategoryCountCheckbox_OnClick(self)
    local isChecked = self:GetChecked() == 1

    if Guda and Guda.Modules and Guda.Modules.DB then
        Guda.Modules.DB:SetSetting("showCategoryCount", isChecked)
    end

    local bagFrame = getglobal("Guda_BagFrame")
    if bagFrame and bagFrame:IsShown() then
        Guda.Modules.BagFrame:Update()
    end

    local bankFrame = getglobal("Guda_BankFrame")
    if bankFrame and bankFrame:IsShown() then
        Guda.Modules.BankFrame:Update()
    end
end

-- Auto Vendor Junk Checkbox OnLoad
function Guda_SettingsPopup_AutoVendorJunkCheckbox_OnLoad(self)
    local text = getglobal(self:GetName().."Text")
    if text then
        text:SetText("Auto Sell Junk")

        local font, _, flags = text:GetFont()
        if font then
            text:SetFont(font, 13, flags)
        end
    end

    self.tooltipText = "Automatically sell gray (junk) items when you visit a vendor."

    local enabled = true
    if Guda and Guda.Modules and Guda.Modules.DB then
        enabled = Guda.Modules.DB:GetSetting("autoVendorJunk")
        if enabled == nil then enabled = true end
    end

    self:SetChecked(enabled and 1 or 0)
end

-- Auto Vendor Junk Checkbox OnClick
function Guda_SettingsPopup_AutoVendorJunkCheckbox_OnClick(self)
    local isChecked = self:GetChecked() == 1

    if Guda and Guda.Modules and Guda.Modules.DB then
        Guda.Modules.DB:SetSetting("autoVendorJunk", isChecked)
    end
end

-- Auto Open Bags Checkbox OnLoad
function Guda_SettingsPopup_AutoOpenBagsCheckbox_OnLoad(self)
    local text = getglobal(self:GetName().."Text")
    if text then
        text:SetText("Auto Open Bags")

        local font, _, flags = text:GetFont()
        if font then
            text:SetFont(font, 13, flags)
        end
    end

    self.tooltipText = "Automatically open bags when interacting with bank, auction house, mail, or trade."

    local enabled = true
    if Guda and Guda.Modules and Guda.Modules.DB then
        enabled = Guda.Modules.DB:GetSetting("autoOpenBags")
        if enabled == nil then enabled = true end
    end

    self:SetChecked(enabled and 1 or 0)
end

-- Auto Open Bags Checkbox OnClick
function Guda_SettingsPopup_AutoOpenBagsCheckbox_OnClick(self)
    local isChecked = self:GetChecked() == 1

    if Guda and Guda.Modules and Guda.Modules.DB then
        Guda.Modules.DB:SetSetting("autoOpenBags", isChecked)
    end
end

-- White Items as Junk Checkbox OnLoad
function Guda_SettingsPopup_WhiteItemsJunkCheckbox_OnLoad(self)
    local text = getglobal(self:GetName().."Text")
    if text then
        text:SetText("White Items as Junk")

        local font, _, flags = text:GetFont()
        if font then
            text:SetFont(font, 13, flags)
        end
    end

    self.tooltipText = "Treat white (common) equippable items as junk. They will be dimmed and auto-sold if auto-sell is enabled."

    local enabled = false
    if Guda and Guda.Modules and Guda.Modules.DB then
        enabled = Guda.Modules.DB:GetSetting("whiteItemsJunk")
        if enabled == nil then enabled = false end
    end

    self:SetChecked(enabled and 1 or 0)
end

-- White Items as Junk Checkbox OnClick
function Guda_SettingsPopup_WhiteItemsJunkCheckbox_OnClick(self)
    local isChecked = self:GetChecked() == 1

    if Guda and Guda.Modules and Guda.Modules.DB then
        Guda.Modules.DB:SetSetting("whiteItemsJunk", isChecked)
    end

    -- Clear item detection cache so junk status is re-evaluated
    if Guda.Modules.ItemDetection and Guda.Modules.ItemDetection.ClearCache then
        Guda.Modules.ItemDetection:ClearCache()
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

-- Theme Dropdown (Blizzard UIDropDownMenu)
local themeOptions = {
    { text = "Guda", value = "guda" },
    { text = "Blizzard", value = "blizzard" },
}

local function Guda_ThemeDropdown_Initialize()
    local currentTheme = Guda.Modules.DB:GetSetting("theme") or "guda"
    for _, option in ipairs(themeOptions) do
        local info = {}
        info.text = option.text
        info.value = option.value
        info.func = function()
            local val = this.value
            UIDropDownMenu_SetSelectedValue(getglobal("Guda_SettingsPopup_ThemeDropdown"), val)
            Guda_SettingsPopup_ApplyTheme(val)
        end
        info.checked = (currentTheme == option.value)
        UIDropDownMenu_AddButton(info)
    end
end

function Guda_SettingsPopup_ThemeDropdown_OnLoad(self)
    UIDropDownMenu_Initialize(self, Guda_ThemeDropdown_Initialize)
    UIDropDownMenu_SetWidth(130, self)
    local currentTheme = Guda.Modules.DB:GetSetting("theme") or "guda"
    local names = { guda = "Guda", blizzard = "Blizzard" }
    UIDropDownMenu_SetSelectedValue(self, currentTheme)
    UIDropDownMenu_SetText(names[currentTheme] or currentTheme, self)

    -- Add label above dropdown
    local label = self:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 20, 2)
    label:SetText("Theme")
    label:SetTextColor(1, 0.82, 0, 1)
end

-- Apply selected theme
function Guda_SettingsPopup_ApplyTheme(themeId)
    Guda.Modules.DB:SetSetting("theme", themeId)

    -- Clear theme cache
    if Guda.Modules.Theme then
        Guda.Modules.Theme:ClearCache()
    end

    -- Update dropdown text
    local dropdown = getglobal("Guda_SettingsPopup_ThemeDropdown")
    if dropdown then
        local names = { guda = "Guda", blizzard = "Blizzard" }
        UIDropDownMenu_SetSelectedValue(dropdown, themeId)
        UIDropDownMenu_SetText(names[themeId] or themeId, dropdown)
    end

    -- Apply theme to all frames (also updates slot background alphas)
    if Guda.Modules.Theme then
        Guda.Modules.Theme:ApplyToAllFrames()
    end
end

-- Bag View Dropdown
local bagViewOptions = {
    { text = "Category", value = "category" },
    { text = "Single", value = "single" },
}

local function Guda_BagViewDropdown_Initialize()
    local current = Guda.Modules.DB:GetSetting("bagViewType") or "single"
    for _, option in ipairs(bagViewOptions) do
        local info = {}
        info.text = option.text
        info.value = option.value
        info.func = function()
            local val = this.value
            UIDropDownMenu_SetSelectedValue(getglobal("Guda_SettingsPopup_BagViewDropdown"), val)
            UIDropDownMenu_SetText(val == "single" and "Single" or "Category", getglobal("Guda_SettingsPopup_BagViewDropdown"))
            Guda.Modules.DB:SetSetting("bagViewType", val)
            if Guda_ReleaseAllButtons then Guda_ReleaseAllButtons() end
            if Guda_BagFrame:IsShown() then Guda.Modules.BagFrame:Update() end
            if Guda_BankFrame and Guda_BankFrame:IsShown() then Guda.Modules.BankFrame:Update() end
        end
        info.checked = (current == option.value)
        UIDropDownMenu_AddButton(info)
    end
end

function Guda_SettingsPopup_BagViewDropdown_OnLoad(self)
    UIDropDownMenu_Initialize(self, Guda_BagViewDropdown_Initialize)
    UIDropDownMenu_SetWidth(130, self)
    local current = Guda.Modules.DB:GetSetting("bagViewType") or "single"
    UIDropDownMenu_SetSelectedValue(self, current)
    UIDropDownMenu_SetText(current == "single" and "Single" or "Category", self)

    local label = self:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 20, 2)
    label:SetText("Bag View")
    label:SetTextColor(1, 0.82, 0, 1)
end

-- Bank View Dropdown
local bankViewOptions = {
    { text = "Category", value = "category" },
    { text = "Single", value = "single" },
}

local function Guda_BankViewDropdown_Initialize()
    local current = Guda.Modules.DB:GetSetting("bankViewType") or "single"
    for _, option in ipairs(bankViewOptions) do
        local info = {}
        info.text = option.text
        info.value = option.value
        info.func = function()
            local val = this.value
            UIDropDownMenu_SetSelectedValue(getglobal("Guda_SettingsPopup_BankViewDropdown"), val)
            UIDropDownMenu_SetText(val == "single" and "Single" or "Category", getglobal("Guda_SettingsPopup_BankViewDropdown"))
            Guda.Modules.DB:SetSetting("bankViewType", val)
            if Guda_ReleaseAllButtons then Guda_ReleaseAllButtons() end
            if Guda_BankFrame and Guda_BankFrame:IsShown() then Guda.Modules.BankFrame:Update() end
            if Guda_BagFrame:IsShown() then Guda.Modules.BagFrame:Update() end
        end
        info.checked = (current == option.value)
        UIDropDownMenu_AddButton(info)
    end
end

function Guda_SettingsPopup_BankViewDropdown_OnLoad(self)
    UIDropDownMenu_Initialize(self, Guda_BankViewDropdown_Initialize)
    UIDropDownMenu_SetWidth(130, self)
    local current = Guda.Modules.DB:GetSetting("bankViewType") or "single"
    UIDropDownMenu_SetSelectedValue(self, current)
    UIDropDownMenu_SetText(current == "single" and "Single" or "Category", self)

    local label = self:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 20, 2)
    label:SetText("Bank View")
    label:SetTextColor(1, 0.82, 0, 1)
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
    nameText:SetWidth(160)
    nameText:SetJustifyH("LEFT")
    row.nameText = nameText

    -- Edit button
    local editBtn = CreateFrame("Button", rowName .. "_EditBtn", row, "UIPanelButtonTemplate")
    editBtn:SetWidth(40)
    editBtn:SetHeight(18)
    editBtn:SetPoint("LEFT", nameText, "RIGHT", 5, 0)
    editBtn:SetText("Edit")
    editBtn:SetScript("OnClick", function()
        local catId = this:GetParent().categoryId
        if catId then
            Guda_CategoryEditor_Open(catId)
        end
    end)
    row.editBtn = editBtn

    -- Move Up button
    local upBtn = CreateFrame("Button", rowName .. "_UpBtn", row)
    upBtn:SetWidth(20)
    upBtn:SetHeight(20)
    upBtn:SetPoint("LEFT", editBtn, "RIGHT", 5, 0)
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

    -- Merge checkbox (shown on group header rows)
    local mergeCheckbox = CreateFrame("CheckButton", rowName .. "_MergeCheckbox", row, "UICheckButtonTemplate")
    mergeCheckbox:SetWidth(20)
    mergeCheckbox:SetHeight(20)
    mergeCheckbox:SetPoint("RIGHT", row, "RIGHT", -5, 0)
    mergeCheckbox:SetScript("OnClick", function()
        local groupName = this:GetParent().groupName
        if groupName then
            local mergedGroups = Guda.Modules.DB:GetSetting("mergedGroups") or {}
            if this:GetChecked() == 1 then
                mergedGroups[groupName] = true
            else
                mergedGroups[groupName] = nil
            end
            Guda.Modules.DB:SetSetting("mergedGroups", mergedGroups)
            Guda_SettingsPopup_RefreshBagFrames()
        end
    end)
    local mergeLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mergeLabel:SetPoint("RIGHT", mergeCheckbox, "LEFT", -2, 0)
    mergeLabel:SetText("Merge")
    mergeLabel:SetTextColor(0.8, 0.8, 0.8)
    row.mergeCheckbox = mergeCheckbox
    row.mergeLabel = mergeLabel

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

-- Build a flat display list with group headers inserted
local function BuildCategoryDisplayList()
    if not Guda.Modules.CategoryManager then return {}, 0 end

    local categoryOrder = Guda.Modules.CategoryManager:GetCategoryOrder()
    local displayList = {}  -- entries: { type = "header"|"category", groupName, categoryId, categoryDef }
    local lastGroup = nil

    for _, catId in ipairs(categoryOrder) do
        local catDef = Guda.Modules.CategoryManager:GetCategory(catId)
        if catDef then
            local group = catDef.group or "Main"
            -- Insert group header if group changed
            if group ~= lastGroup then
                table.insert(displayList, { type = "header", groupName = group })
                lastGroup = group
            end
            table.insert(displayList, { type = "category", categoryId = catId, categoryDef = catDef })
        end
    end

    return displayList, table.getn(displayList)
end

-- Update the category list display
function Guda_SettingsPopup_CategoriesTab_Update()
    if not Guda.Modules.CategoryManager then return end

    local scrollFrame = getglobal("Guda_SettingsPopup_CategoriesScrollFrame")
    if not scrollFrame then return end

    local displayList, totalEntries = BuildCategoryDisplayList()

    -- Update scroll frame
    FauxScrollFrame_Update(scrollFrame, totalEntries, CATEGORY_VISIBLE_ROWS, CATEGORY_ROW_HEIGHT)

    local offset = FauxScrollFrame_GetOffset(scrollFrame)

    for i = 1, CATEGORY_VISIBLE_ROWS do
        local row = GetCategoryRowFrame(i)
        if row then
            local dataIndex = i + offset
            if dataIndex <= totalEntries then
                local entry = displayList[dataIndex]

                if entry.type == "header" then
                    -- Show as group header row
                    row.categoryId = nil
                    row.groupName = entry.groupName
                    row.nameText:SetText("|cffffd100-- " .. entry.groupName .. " --|r")
                    row.nameText:SetTextColor(1, 0.82, 0)
                    row.checkbox:Hide()
                    row.editBtn:Hide()
                    row.upBtn:Hide()
                    row.downBtn:Hide()
                    row.deleteBtn:Hide()
                    row.builtInText:Hide()

                    -- Show merge checkbox for group headers
                    local mergedGroups = Guda.Modules.DB:GetSetting("mergedGroups") or {}
                    row.mergeCheckbox:SetChecked(mergedGroups[entry.groupName] and 1 or 0)
                    row.mergeCheckbox:Show()
                    row.mergeLabel:Show()

                    row:Show()
                elseif entry.type == "category" then
                    local categoryId = entry.categoryId
                    local categoryDef = entry.categoryDef

                    row.categoryId = categoryId
                    row.groupName = nil
                    row.nameText:SetText(categoryDef.name or categoryId)
                    row.checkbox:Show()
                    row.checkbox:SetChecked(categoryDef.enabled and 1 or 0)
                    row.mergeCheckbox:Hide()
                    row.mergeLabel:Hide()

                    -- Show/hide delete button based on whether it's built-in
                    if categoryDef.isBuiltIn then
                        row.deleteBtn:Hide()
                        row.builtInText:Show()
                    else
                        row.deleteBtn:Show()
                        row.builtInText:Hide()
                    end

                    -- Hide all controls for hideControls categories (only checkbox visible)
                    if categoryDef.hideControls then
                        row.editBtn:Hide()
                        row.upBtn:Hide()
                        row.downBtn:Hide()
                        row.deleteBtn:Hide()
                        row.builtInText:Hide()
                    else
                        row.editBtn:Show()
                        row.upBtn:Show()
                        row.downBtn:Show()

                        -- Enable/disable move buttons based on group-aware boundaries
                        if Guda.Modules.CategoryManager:CanMoveUp(categoryId) then
                            row.upBtn:Enable()
                        else
                            row.upBtn:Disable()
                        end

                        if Guda.Modules.CategoryManager:CanMoveDown(categoryId) then
                            row.downBtn:Enable()
                        else
                            row.downBtn:Disable()
                        end
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

    -- Set button texts
    local addBtn = getglobal("Guda_SettingsPopup_AddCategoryButton")
    if addBtn then
        addBtn:SetText("+ Add Category")
    end

    local resetBtn = getglobal("Guda_SettingsPopup_ResetCategoriesButton")
    if resetBtn then
        resetBtn:SetText("Reset Defaults")
    end
end

-- Add new custom category
function Guda_SettingsPopup_AddCategory_OnClick()
    if not Guda.Modules.CategoryManager then return end

    -- Create new category definition
    local newDef = {
        name = "Custom Category",
        icon = "Interface\\Icons\\INV_Misc_QuestionMark",
        rules = {},
        matchMode = "any",
        priority = 80,
        enabled = true,
        isBuiltIn = false,
        group = Guda.Modules.CategoryManager:GetGroupMain(),
    }

    -- Add to database with auto-generated ID
    local success, newId = Guda.Modules.CategoryManager:AddCategory(nil, newDef)
    if success and newId then
        -- Update display
        Guda_SettingsPopup_CategoriesTab_Update()
        -- Open editor for the new category
        Guda_CategoryEditor_Open(newId)
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

-------------------------------------------
-- Category Editor Functions
-------------------------------------------

local editorCategoryId = nil
local editorMatchMode = "any"
local editorGroup = "Main"
local editorMark = nil  -- current category mark texture path or nil
local editorRules = {}
local editorRuleFrames = {}

-- Available mark icons (texture paths)
local MARK_ICONS = {
    "Interface\\AddOns\\Guda\\Assets\\equipment",
    "Interface\\AddOns\\Guda\\Assets\\plus",
    "Interface\\AddOns\\Guda\\Assets\\fav",
    "Interface\\AddOns\\Guda\\Assets\\combat",
    "Interface\\AddOns\\Guda\\Assets\\Cog",
    "Interface\\AddOns\\Guda\\Assets\\guild",
}
local RULE_ROW_HEIGHT = 28
local MAX_RULES = 22

-- Rule type options for dropdown
local RULE_TYPE_OPTIONS = {
    { id = "itemType", name = "Item Type" },
    { id = "itemSubtype", name = "Item Subtype" },
    { id = "namePattern", name = "Name Contains" },
    { id = "itemID", name = "Item ID" },
    { id = "quality", name = "Quality (exact)" },
    { id = "qualityMin", name = "Quality (min)" },
    { id = "isBoE", name = "Bind on Equip" },
    { id = "isQuestItem", name = "Quest Item" },
    { id = "isJunk", name = "Is Junk" },
    { id = "restoreTag", name = "Restore Type" },
    { id = "isSoulShard", name = "Soul Shard" },
    { id = "isProjectile", name = "Projectile" },
}

-- Value options for specific rule types
local RULE_VALUE_OPTIONS = {
    itemType = { "Armor", "Weapon", "Consumable", "Container", "Trade Goods", "Projectile", "Quiver", "Reagent", "Recipe", "Key", "Miscellaneous", "Quest" },
    quality = { "0 - Poor", "1 - Common", "2 - Uncommon", "3 - Rare", "4 - Epic", "5 - Legendary" },
    qualityMin = { "0 - Poor", "1 - Common", "2 - Uncommon", "3 - Rare", "4 - Epic", "5 - Legendary" },
    isBoE = { "true", "false" },
    isQuestItem = { "true", "false" },
    isJunk = { "true", "false" },
    isSoulShard = { "true", "false" },
    isProjectile = { "true", "false" },
    restoreTag = { "eat", "drink", "restore" },
}

-- OnLoad for Category Editor
function Guda_CategoryEditor_OnLoad(self)
    Guda:ApplyBackdrop(self, "DEFAULT_FRAME")

    -- Set button texts
    local addBtn = getglobal("Guda_CategoryEditor_AddRuleButton")
    if addBtn then addBtn:SetText("+ Add Rule") end

    local saveBtn = getglobal("Guda_CategoryEditor_SaveButton")
    if saveBtn then saveBtn:SetText("Save") end

    local cancelBtn = getglobal("Guda_CategoryEditor_CancelButton")
    if cancelBtn then cancelBtn:SetText("Cancel") end

    -- Create group EditBox if it doesn't exist
    if not getglobal("Guda_CategoryEditor_GroupEditBox") then
        local nameBox = getglobal("Guda_CategoryEditor_NameEditBox")
        if nameBox then
            -- Label
            local groupLabel = self:CreateFontString("Guda_CategoryEditor_GroupLabel", "OVERLAY", "GameFontNormalSmall")
            groupLabel:SetPoint("LEFT", nameBox, "RIGHT", 14, 0)
            groupLabel:SetText("Group:")
            groupLabel:SetTextColor(0.7, 0.7, 0.7)

            -- EditBox
            local groupBox = CreateFrame("EditBox", "Guda_CategoryEditor_GroupEditBox", self, "InputBoxTemplate")
            groupBox:SetWidth(100)
            groupBox:SetHeight(22)
            groupBox:SetPoint("LEFT", groupLabel, "RIGHT", 6, 0)
            groupBox:SetAutoFocus(false)
            groupBox:SetMaxLetters(20)
            groupBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)
            groupBox:SetScript("OnEnterPressed", function() this:ClearFocus() end)
        end
    end

    -- Create mark icon selector row
    if not getglobal("Guda_CategoryEditor_MarkLabel") then
        local MARK_BTN_SIZE = 22
        local MARK_BTN_SPACING = 6

        local markLabel = self:CreateFontString("Guda_CategoryEditor_MarkLabel", "OVERLAY", "GameFontNormalSmall")
        markLabel:SetPoint("TOPLEFT", self, "TOPLEFT", 20, -78)
        markLabel:SetText("Mark:")
        markLabel:SetTextColor(0.7, 0.7, 0.7)

        -- "None" button (first)
        local noneBtn = CreateFrame("Button", "Guda_CategoryEditor_MarkNone", self)
        noneBtn:SetWidth(MARK_BTN_SIZE)
        noneBtn:SetHeight(MARK_BTN_SIZE)
        noneBtn:SetPoint("LEFT", markLabel, "RIGHT", 8, 0)
        noneBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        noneBtn:SetBackdropColor(0.15, 0.15, 0.15, 0.8)
        noneBtn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        noneBtn.markPath = nil

        local noneTex = noneBtn:CreateTexture(nil, "ARTWORK")
        noneTex:SetWidth(12)
        noneTex:SetHeight(12)
        noneTex:SetPoint("CENTER", noneBtn, "CENTER", 0, 0)
        noneTex:SetTexture("Interface\\Buttons\\UI-StopButton")
        noneTex:SetVertexColor(0.6, 0.6, 0.6)

        noneBtn:SetScript("OnClick", function()
            editorMark = nil
            Guda_CategoryEditor_UpdateMarkButtons()
        end)

        self.markButtons = { noneBtn }

        -- Icon buttons
        local prevBtn = noneBtn
        for i = 1, table.getn(MARK_ICONS) do
            local iconPath = MARK_ICONS[i]
            local btn = CreateFrame("Button", "Guda_CategoryEditor_Mark" .. i, self)
            btn:SetWidth(MARK_BTN_SIZE)
            btn:SetHeight(MARK_BTN_SIZE)
            btn:SetPoint("LEFT", prevBtn, "RIGHT", MARK_BTN_SPACING, 0)
            btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
            btn:SetBackdropColor(0.15, 0.15, 0.15, 0.8)
            btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
            btn.markPath = iconPath

            local tex = btn:CreateTexture(nil, "ARTWORK")
            tex:SetWidth(16)
            tex:SetHeight(16)
            tex:SetPoint("CENTER", btn, "CENTER", 0, 0)
            tex:SetTexture(iconPath)

            btn:SetScript("OnClick", function()
                editorMark = this.markPath
                Guda_CategoryEditor_UpdateMarkButtons()
            end)

            table.insert(self.markButtons, btn)
            prevBtn = btn
        end
    end

    -- Create radio button labels
    local anyRadio = getglobal("Guda_CategoryEditor_MatchAny")
    if anyRadio then
        local label = anyRadio:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", anyRadio, "RIGHT", 2, 0)
        label:SetText("Any rule")
    end

    local allRadio = getglobal("Guda_CategoryEditor_MatchAll")
    if allRadio then
        local label = allRadio:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", allRadio, "RIGHT", 2, 0)
        label:SetText("All rules")
    end
end

-- Update mark button highlights (gold = selected, gray = unselected)
function Guda_CategoryEditor_UpdateMarkButtons()
    local editor = getglobal("Guda_CategoryEditor")
    if not editor or not editor.markButtons then return end
    for _, btn in ipairs(editor.markButtons) do
        if btn.markPath == editorMark then
            btn:SetBackdropBorderColor(1, 0.82, 0, 1)
        else
            btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        end
    end
end

-- OnShow for Category Editor
function Guda_CategoryEditor_OnShow(self)
    Guda_CategoryEditor_UpdateRulesDisplay()
end

-- Open Category Editor for a specific category
function Guda_CategoryEditor_Open(categoryId)
    if not Guda.Modules.CategoryManager then return end

    local categoryDef = Guda.Modules.CategoryManager:GetCategory(categoryId)
    if not categoryDef then return end

    editorCategoryId = categoryId
    editorMatchMode = categoryDef.matchMode or "any"
    editorGroup = categoryDef.group or "Main"
    editorMark = categoryDef.categoryMark or nil

    -- Copy rules
    editorRules = {}
    if categoryDef.rules then
        for i, rule in ipairs(categoryDef.rules) do
            table.insert(editorRules, { type = rule.type, value = rule.value })
        end
    end

    -- Set title
    local title = getglobal("Guda_CategoryEditor_Title")
    if title then
        if categoryDef.isBuiltIn then
            title:SetText("Edit Category (Built-in)")
        else
            title:SetText("Edit Category")
        end
    end

    -- Set name
    local nameBox = getglobal("Guda_CategoryEditor_NameEditBox")
    if nameBox then
        nameBox:SetText(categoryDef.name or categoryId)
        -- Disable name editing for built-in categories
        if categoryDef.isBuiltIn then
            nameBox:EnableMouse(false)
            nameBox:EnableKeyboard(false)
            nameBox:SetTextColor(0.5, 0.5, 0.5)
        else
            nameBox:EnableMouse(true)
            nameBox:EnableKeyboard(true)
            nameBox:SetTextColor(1, 1, 1)
        end
    end

    -- Set group EditBox
    local groupBox = getglobal("Guda_CategoryEditor_GroupEditBox")
    if groupBox then
        groupBox:SetText(editorGroup or "")
        -- Disable group editing for built-in categories
        if categoryDef.isBuiltIn then
            groupBox:EnableMouse(false)
            groupBox:EnableKeyboard(false)
            groupBox:SetTextColor(0.5, 0.5, 0.5)
        else
            groupBox:EnableMouse(true)
            groupBox:EnableKeyboard(true)
            groupBox:SetTextColor(1, 1, 1)
        end
        groupBox:ClearFocus()
    end

    -- Set match mode
    Guda_CategoryEditor_SetMatchMode(editorMatchMode)

    -- Update mark button highlights
    Guda_CategoryEditor_UpdateMarkButtons()

    -- Show editor
    local editor = getglobal("Guda_CategoryEditor")
    if editor then
        editor:Show()
    end
end

-- (Group is now an EditBox — no dropdown needed)

-- Set match mode (radio buttons)
function Guda_CategoryEditor_SetMatchMode(mode)
    editorMatchMode = mode

    local anyRadio = getglobal("Guda_CategoryEditor_MatchAny")
    local allRadio = getglobal("Guda_CategoryEditor_MatchAll")

    if anyRadio then anyRadio:SetChecked(mode == "any" and 1 or 0) end
    if allRadio then allRadio:SetChecked(mode == "all" and 1 or 0) end
end

-- Get or create a rule row frame
local function GetRuleRowFrame(index)
    if editorRuleFrames[index] then
        return editorRuleFrames[index]
    end

    local container = getglobal("Guda_CategoryEditor_RulesContainer")
    if not container then return nil end

    local rowName = "Guda_CategoryEditor_RuleRow" .. index
    local row = CreateFrame("Frame", rowName, container)
    row:SetHeight(RULE_ROW_HEIGHT)
    row:SetWidth(310)
    row:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -((index - 1) * RULE_ROW_HEIGHT))

    -- Rule type dropdown button
    local typeBtn = CreateFrame("Button", rowName .. "_TypeBtn", row, "UIPanelButtonTemplate")
    typeBtn:SetWidth(120)
    typeBtn:SetHeight(22)
    typeBtn:SetPoint("LEFT", row, "LEFT", 0, 0)
    typeBtn:SetText("Select Type")
    typeBtn.ruleIndex = index
    typeBtn:SetScript("OnClick", function()
        Guda_CategoryEditor_ShowTypeDropdown(this, this.ruleIndex)
    end)
    row.typeBtn = typeBtn

    -- Value input (editbox for text, button for dropdowns)
    local valueBox = CreateFrame("EditBox", rowName .. "_ValueBox", row, "InputBoxTemplate")
    valueBox:SetWidth(140)
    valueBox:SetHeight(22)
    valueBox:SetPoint("LEFT", typeBtn, "RIGHT", 5, 0)
    valueBox:SetAutoFocus(false)
    valueBox.ruleIndex = index
    valueBox:SetScript("OnTextChanged", function()
        local idx = this.ruleIndex
        if editorRules[idx] then
            editorRules[idx].value = this:GetText()
        end
    end)
    valueBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    valueBox:SetScript("OnEnterPressed", function() this:ClearFocus() end)
    row.valueBox = valueBox

    -- Value dropdown button (for predefined values)
    local valueBtn = CreateFrame("Button", rowName .. "_ValueBtn", row, "UIPanelButtonTemplate")
    valueBtn:SetWidth(140)
    valueBtn:SetHeight(22)
    valueBtn:SetPoint("LEFT", typeBtn, "RIGHT", 5, 0)
    valueBtn:SetText("Select Value")
    valueBtn.ruleIndex = index
    valueBtn:SetScript("OnClick", function()
        Guda_CategoryEditor_ShowValueDropdown(this, this.ruleIndex)
    end)
    valueBtn:Hide()
    row.valueBtn = valueBtn

    -- Item drop zone (visible only for itemID rule type)
    local dropZone = CreateFrame("Button", rowName .. "_DropZone", row)
    dropZone:SetWidth(22)
    dropZone:SetHeight(22)
    dropZone:SetPoint("LEFT", valueBox, "RIGHT", 4, 0)
    dropZone:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    dropZone:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    dropZone:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    -- Icon texture (shows item icon after drop)
    local dzIcon = dropZone:CreateTexture(nil, "ARTWORK")
    dzIcon:SetPoint("TOPLEFT", dropZone, "TOPLEFT", 2, -2)
    dzIcon:SetPoint("BOTTOMRIGHT", dropZone, "BOTTOMRIGHT", -2, 2)
    dzIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    dzIcon:Hide()
    dropZone.icon = dzIcon

    -- "?" hint when empty
    local dzHint = dropZone:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dzHint:SetPoint("CENTER", dropZone, "CENTER", 0, 0)
    dzHint:SetText("?")
    dzHint:SetTextColor(0.5, 0.5, 0.5)
    dropZone.hint = dzHint

    -- "(Drop Item)" label
    local dzLabel = dropZone:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dzLabel:SetPoint("LEFT", dropZone, "RIGHT", 4, 0)
    dzLabel:SetText("(Drop Item)")
    dzLabel:SetTextColor(0.5, 0.5, 0.5)
    dropZone.label = dzLabel

    dropZone:EnableMouse(true)
    dropZone:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    dropZone:RegisterForDrag("LeftButton")
    dropZone.ruleIndex = index

    -- Handle item drop via drag
    dropZone:SetScript("OnReceiveDrag", function()
        local idx = this.ruleIndex
        if not editorRules[idx] or editorRules[idx].type ~= "itemID" then return end
        if CursorHasItem and CursorHasItem() then
            -- In 1.12.1, we get item info from the cursor via tracking
            local info = Guda_GetCursorItemInfo()
            if info and info.itemID then
                -- Fill the value box with the item ID
                editorRules[idx].value = tostring(info.itemID)
                -- Update icon
                local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(info.link or info.itemID)
                if texture then
                    this.icon:SetTexture(texture)
                    this.icon:Show()
                    this.hint:Hide()
                end
                -- Put item back
                PickupContainerItem(info.bagID, info.slotID)
                Guda_ClearCursorItem()
                Guda_CategoryEditor_UpdateRulesDisplay()
            end
        end
    end)

    -- Handle click (left = drop item from cursor, right = clear)
    dropZone:SetScript("OnClick", function()
        local idx = this.ruleIndex
        if not editorRules[idx] or editorRules[idx].type ~= "itemID" then return end
        if arg1 == "LeftButton" then
            if CursorHasItem and CursorHasItem() then
                local info = Guda_GetCursorItemInfo()
                if info and info.itemID then
                    editorRules[idx].value = tostring(info.itemID)
                    local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(info.link or info.itemID)
                    if texture then
                        this.icon:SetTexture(texture)
                        this.icon:Show()
                        this.hint:Hide()
                    end
                    PickupContainerItem(info.bagID, info.slotID)
                    Guda_ClearCursorItem()
                    Guda_CategoryEditor_UpdateRulesDisplay()
                end
            end
        elseif arg1 == "RightButton" then
            -- Clear
            this.icon:SetTexture(nil)
            this.icon:Hide()
            this.hint:Show()
            editorRules[idx].value = ""
            Guda_CategoryEditor_UpdateRulesDisplay()
        end
    end)

    -- Tooltip
    dropZone:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Item ID Slot", 1, 0.82, 0)
        GameTooltip:AddLine("Drag an item here to get its ID", 1, 1, 1, true)
        GameTooltip:AddLine("Right-click to clear", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    dropZone:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    dropZone:Hide()
    row.dropZone = dropZone

    -- Delete button
    local deleteBtn = CreateFrame("Button", rowName .. "_DeleteBtn", row, "UIPanelCloseButton")
    deleteBtn:SetWidth(22)
    deleteBtn:SetHeight(22)
    deleteBtn:SetPoint("LEFT", dropZone, "RIGHT", 50, 0)
    deleteBtn.ruleIndex = index
    deleteBtn:SetScript("OnClick", function()
        Guda_CategoryEditor_RemoveRule(this.ruleIndex)
    end)
    row.deleteBtn = deleteBtn

    editorRuleFrames[index] = row
    return row
end

-- Number of visible rule rows in the scroll frame
local VISIBLE_RULES = 10

-- Update rules display with scroll support
function Guda_CategoryEditor_UpdateRulesDisplay()
    local numRules = table.getn(editorRules)
    local scrollFrame = getglobal("Guda_CategoryEditor_RulesScrollFrame")

    -- Update rules count label
    local rulesLabel = getglobal("Guda_CategoryEditor_RulesLabel")
    if rulesLabel then
        rulesLabel:SetText("Rules (" .. numRules .. "/" .. MAX_RULES .. "):")
    end

    -- Update scroll frame
    if scrollFrame then
        FauxScrollFrame_Update(scrollFrame, numRules, VISIBLE_RULES, RULE_ROW_HEIGHT)
    end

    -- Get scroll offset
    local offset = 0
    if scrollFrame then
        offset = FauxScrollFrame_GetOffset(scrollFrame) or 0
    end

    for i = 1, VISIBLE_RULES do
        local row = GetRuleRowFrame(i)
        local ruleIndex = i + offset

        if row then
            if ruleIndex <= numRules then
                local rule = editorRules[ruleIndex]
                row.ruleIndex = ruleIndex
                row.typeBtn.ruleIndex = ruleIndex
                row.valueBox.ruleIndex = ruleIndex
                row.valueBtn.ruleIndex = ruleIndex
                row.deleteBtn.ruleIndex = ruleIndex

                -- Set type button text
                local typeName = "Select Type"
                for _, opt in ipairs(RULE_TYPE_OPTIONS) do
                    if opt.id == rule.type then
                        typeName = opt.name
                        break
                    end
                end
                row.typeBtn:SetText(typeName)

                -- Show appropriate value input
                local isItemID = (rule.type == "itemID")
                if RULE_VALUE_OPTIONS[rule.type] then
                    -- Use dropdown for predefined values
                    row.valueBox:Hide()
                    row.valueBtn:Show()
                    local displayValue = tostring(rule.value or "Select")
                    -- Format quality display
                    if (rule.type == "quality" or rule.type == "qualityMin") and type(rule.value) == "number" then
                        local qualNames = { [0]="Poor", [1]="Common", [2]="Uncommon", [3]="Rare", [4]="Epic", [5]="Legendary" }
                        displayValue = rule.value .. " - " .. (qualNames[rule.value] or "")
                    end
                    row.valueBtn:SetText(displayValue)
                else
                    -- Use editbox for text input
                    row.valueBtn:Hide()
                    row.valueBox:Show()
                    row.valueBox:SetText(tostring(rule.value or ""))
                end

                -- Show/hide drop zone for itemID rules
                if row.dropZone then
                    if isItemID then
                        row.dropZone:Show()
                        row.dropZone.label:Show()
                        -- Update icon if value is a valid item ID
                        local itemID = tonumber(rule.value)
                        if itemID and itemID > 0 then
                            local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(itemID)
                            if texture then
                                row.dropZone.icon:SetTexture(texture)
                                row.dropZone.icon:Show()
                                row.dropZone.hint:Hide()
                            else
                                row.dropZone.icon:Hide()
                                row.dropZone.hint:Show()
                            end
                        else
                            row.dropZone.icon:Hide()
                            row.dropZone.hint:Show()
                        end
                        -- Reposition delete button after drop zone label
                        row.deleteBtn:ClearAllPoints()
                        row.deleteBtn:SetPoint("LEFT", row.dropZone, "RIGHT", 50, 0)
                    else
                        row.dropZone:Hide()
                        row.dropZone.label:Hide()
                        -- Reposition delete button after value input
                        row.deleteBtn:ClearAllPoints()
                        local valueAnchor = row.valueBtn
                        if row.valueBox:IsShown() then valueAnchor = row.valueBox end
                        row.deleteBtn:SetPoint("LEFT", valueAnchor, "RIGHT", 5, 0)
                    end
                end

                row:Show()
            else
                row:Hide()
            end
        end
    end

    -- Enable/disable Add Rule button
    local addBtn = getglobal("Guda_CategoryEditor_AddRuleButton")
    if addBtn then
        if numRules >= MAX_RULES then
            addBtn:Disable()
        else
            addBtn:Enable()
        end
    end
end

-- Add a new rule
function Guda_CategoryEditor_AddRule()
    if table.getn(editorRules) >= MAX_RULES then return end

    table.insert(editorRules, { type = "itemType", value = "Consumable" })
    Guda_CategoryEditor_UpdateRulesDisplay()
end

-- Remove a rule
function Guda_CategoryEditor_RemoveRule(index)
    if index > 0 and index <= table.getn(editorRules) then
        table.remove(editorRules, index)
        Guda_CategoryEditor_UpdateRulesDisplay()
    end
end

-- Helper to set rule type (called from dropdown)
function Guda_CategoryEditor_SetRuleType(ruleIndex, typeId)
    if not editorRules[ruleIndex] then return end

    editorRules[ruleIndex].type = typeId
    -- Reset value when type changes
    if RULE_VALUE_OPTIONS[typeId] then
        editorRules[ruleIndex].value = RULE_VALUE_OPTIONS[typeId][1]
        -- Convert to proper type
        if typeId == "quality" or typeId == "qualityMin" then
            editorRules[ruleIndex].value = 0
        elseif typeId == "isBoE" or typeId == "isQuestItem" or typeId == "isSoulShard" or typeId == "isProjectile" then
            editorRules[ruleIndex].value = true
        end
    else
        editorRules[ruleIndex].value = ""
    end
    Guda_CategoryEditor_UpdateRulesDisplay()
end

-- Helper to set rule value (called from dropdown)
function Guda_CategoryEditor_SetRuleValue(ruleIndex, val, ruleType)
    if not editorRules[ruleIndex] then return end

    if ruleType == "quality" or ruleType == "qualityMin" then
        local num = tonumber(string.sub(val, 1, 1))
        editorRules[ruleIndex].value = num or 0
    elseif ruleType == "isBoE" or ruleType == "isQuestItem" or ruleType == "isSoulShard" or ruleType == "isProjectile" then
        editorRules[ruleIndex].value = (val == "true")
    else
        editorRules[ruleIndex].value = val
    end
    Guda_CategoryEditor_UpdateRulesDisplay()
end

-- Show type dropdown menu
function Guda_CategoryEditor_ShowTypeDropdown(button, ruleIndex)
    local menu = {}
    for i = 1, table.getn(RULE_TYPE_OPTIONS) do
        local opt = RULE_TYPE_OPTIONS[i]
        table.insert(menu, {
            text = opt.name,
            ruleIndex = ruleIndex,
            typeId = opt.id,
        })
    end

    Guda_ShowSimpleDropdown(button, menu, "type")
end

-- Show value dropdown menu
function Guda_CategoryEditor_ShowValueDropdown(button, ruleIndex)
    local rule = editorRules[ruleIndex]
    if not rule then return end

    local options = RULE_VALUE_OPTIONS[rule.type]
    if not options then return end

    local menu = {}
    for i = 1, table.getn(options) do
        local val = options[i]
        table.insert(menu, {
            text = val,
            ruleIndex = ruleIndex,
            ruleType = rule.type,
            value = val,
        })
    end

    Guda_ShowSimpleDropdown(button, menu, "value")
end

-- Simple dropdown menu helper
local dropdownFrame = nil
function Guda_ShowSimpleDropdown(anchor, menuItems, menuType)
    if not dropdownFrame then
        dropdownFrame = CreateFrame("Frame", "Guda_SimpleDropdown", UIParent)
        dropdownFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        dropdownFrame:SetWidth(150)
        dropdownFrame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        dropdownFrame:SetBackdropColor(0, 0, 0, 1)
        dropdownFrame:EnableMouse(true)
        dropdownFrame:Hide()

        dropdownFrame:SetScript("OnLeave", function()
            -- Hide after a short delay if mouse leaves
            this.hideTimer = 0.5
        end)
        dropdownFrame:SetScript("OnUpdate", function()
            if this.hideTimer then
                this.hideTimer = this.hideTimer - arg1
                if this.hideTimer <= 0 then
                    this.hideTimer = nil
                    -- Check if mouse is over any child
                    if not MouseIsOver(this) then
                        this:Hide()
                    end
                end
            end
        end)
    end

    -- Clear old buttons
    local children = { dropdownFrame:GetChildren() }
    for _, child in ipairs(children) do
        child:Hide()
        child:SetParent(nil)
    end

    -- Create menu buttons
    local btnHeight = 20
    local totalHeight = 10
    for i, item in ipairs(menuItems) do
        local btn = CreateFrame("Button", nil, dropdownFrame)
        btn:SetWidth(140)
        btn:SetHeight(btnHeight)
        btn:SetPoint("TOPLEFT", dropdownFrame, "TOPLEFT", 5, -(5 + (i-1) * btnHeight))

        local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("LEFT", btn, "LEFT", 5, 0)
        text:SetText(item.text)
        btn.text = text

        local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints(btn)
        highlight:SetTexture(1, 1, 1, 0.2)

        -- Store data on button for vanilla Lua closure compatibility
        btn.menuType = menuType
        btn.ruleIndex = item.ruleIndex
        btn.typeId = item.typeId
        btn.ruleType = item.ruleType
        btn.value = item.value
        btn.themeId = item.themeId

        btn:SetScript("OnClick", function()
            dropdownFrame:Hide()
            if this.menuType == "type" then
                Guda_CategoryEditor_SetRuleType(this.ruleIndex, this.typeId)
            elseif this.menuType == "value" then
                Guda_CategoryEditor_SetRuleValue(this.ruleIndex, this.value, this.ruleType)
            elseif this.menuType == "theme" then
                Guda_SettingsPopup_ApplyTheme(this.themeId)
            end
        end)
        btn:SetScript("OnEnter", function()
            dropdownFrame.hideTimer = nil
        end)

        totalHeight = totalHeight + btnHeight
    end
    totalHeight = totalHeight + 5

    dropdownFrame:SetHeight(totalHeight)
    dropdownFrame:ClearAllPoints()
    dropdownFrame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, 0)
    dropdownFrame:Show()
    dropdownFrame.hideTimer = nil
end

-- Save category changes
function Guda_CategoryEditor_Save()
    if not editorCategoryId or not Guda.Modules.CategoryManager then return end

    local categoryDef = Guda.Modules.CategoryManager:GetCategory(editorCategoryId)
    if not categoryDef then return end

    -- Get name (only for custom categories)
    local nameBox = getglobal("Guda_CategoryEditor_NameEditBox")
    if nameBox and not categoryDef.isBuiltIn then
        categoryDef.name = nameBox:GetText()
    end

    -- Set match mode
    categoryDef.matchMode = editorMatchMode

    -- Set category mark
    categoryDef.categoryMark = editorMark

    -- Set rules
    categoryDef.rules = {}
    for _, rule in ipairs(editorRules) do
        if rule.type and rule.type ~= "" then
            table.insert(categoryDef.rules, { type = rule.type, value = rule.value })
        end
    end

    -- Read group from EditBox
    local groupBox = getglobal("Guda_CategoryEditor_GroupEditBox")
    local newGroup = "Main" -- default
    if groupBox then
        local text = groupBox:GetText() or ""
        -- Trim whitespace
        text = string.gsub(text, "^%s+", "")
        text = string.gsub(text, "%s+$", "")
        if text ~= "" then
            newGroup = text
        end
    end

    -- Set group (handle group change via SetCategoryGroup for proper reordering)
    local oldGroup = categoryDef.group or "Main"
    if newGroup ~= oldGroup then
        -- Save definition first, then move group
        Guda.Modules.CategoryManager:UpdateCategory(editorCategoryId, categoryDef)
        Guda.Modules.CategoryManager:SetCategoryGroup(editorCategoryId, newGroup)
    else
        -- Save to database
        Guda.Modules.CategoryManager:UpdateCategory(editorCategoryId, categoryDef)
    end

    -- Refresh displays
    Guda_SettingsPopup_CategoriesTab_Update()
    Guda_SettingsPopup_RefreshBagFrames()

    -- Close editor
    local editor = getglobal("Guda_CategoryEditor")
    if editor then editor:Hide() end

    Guda:Print("Category '" .. (categoryDef.name or editorCategoryId) .. "' saved.")
end

-- Initialize
function SettingsPopup:Initialize()
    Guda:Debug("Settings popup initialized")
end

