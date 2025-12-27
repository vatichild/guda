-- Mailbox Frame
-- Mailbox viewing UI

local addon = Guda

local MailboxFrame = {}
addon.Modules.MailboxFrame = MailboxFrame

local currentViewChar = nil
local searchText = ""
local isReadOnlyMode = true -- Mailbox is always read-only in this addon (viewing offline data)
local itemButtons = {}
local mailboxRows = {}
local currentPage = 1
local ITEMS_PER_PAGE = 7
local mailboxClickCatcher = nil

-- OnLoad
function Guda_MailboxFrame_OnLoad(self)
    -- Set up initial backdrop
    addon:ApplyBackdrop(self, "DEFAULT_FRAME")

    -- Set up search box placeholder
    local searchBox = getglobal(self:GetName().."_SearchBar_SearchBox")
    if searchBox then
        searchBox:SetText("Search mailbox...")
        searchBox:SetTextColor(0.5, 0.5, 0.5, 1)
    end

    -- Create invisible full-screen frame to catch clicks outside the mailbox frame while typing in search
    if not mailboxClickCatcher then
        mailboxClickCatcher = CreateFrame("Frame", "Guda_MailboxClickCatcher", UIParent)
        mailboxClickCatcher:SetFrameStrata("BACKGROUND")
        mailboxClickCatcher:SetAllPoints(UIParent)
        mailboxClickCatcher:EnableMouse(true)
        mailboxClickCatcher:Hide()

        mailboxClickCatcher:SetScript("OnMouseDown", function()
            if Guda_MailboxFrame_ClearSearch then
                Guda_MailboxFrame_ClearSearch()
            end
        end)
    end
end

-- Clear search focus
function Guda_MailboxFrame_ClearSearch()
    local searchBox = getglobal("Guda_MailboxFrame_SearchBar_SearchBox")
    if searchBox then
        searchBox:ClearFocus()
    end
end

-- OnShow
function Guda_MailboxFrame_OnShow(self)
    -- Apply frame transparency
    if Guda_ApplyBackgroundTransparency then
        Guda_ApplyBackgroundTransparency()
    end

    MailboxFrame:Update()
end

-- OnHide
function Guda_MailboxFrame_OnHide(self)
    -- Close any open dropdown menus when the mailbox frame is hidden
    CloseDropDownMenus()
end

-- Toggle visibility
function MailboxFrame:Toggle()
    if Guda_MailboxFrame:IsShown() then
        Guda_MailboxFrame:Hide()
    else
        Guda_MailboxFrame:Show()
    end
end

-- Show specific character's mailbox
function MailboxFrame:GetCurrentViewChar()
    return currentViewChar
end

function MailboxFrame:ShowCharacter(fullName)
    currentViewChar = fullName
    currentPage = 1
    self:Update()
end

-- Pagination
function MailboxFrame:NextPage()
    currentPage = currentPage + 1
    self:Update()
end

function MailboxFrame:PrevPage()
    if currentPage > 1 then
        currentPage = currentPage - 1
        self:Update()
    end
end

-- Initialize module
function MailboxFrame:Initialize()
    -- Register events if needed
end

-- Update the mailbox frame
function MailboxFrame:Update()
    if not Guda_MailboxFrame:IsShown() then return end

    -- Determine which character to show
    local charFullName = currentViewChar or addon.Modules.DB:GetPlayerFullName()
    local mailboxData = addon.Modules.DB:GetCharacterMailbox(charFullName)
    
    -- Extract character name from fullName
    local charName = charFullName
    local dashPos = string.find(charFullName, "-")
    if dashPos then
        charName = string.sub(charFullName, 1, dashPos - 1)
    end

    getglobal("Guda_MailboxFrame_Title"):SetText(charName .. "'s Mailbox")

    -- Filter items based on search text
    local filteredItems = {}
    local totalItems = table.getn(mailboxData)
    for i, mail in ipairs(mailboxData) do
        local matchesSearch = true
        if searchText ~= "" then
            matchesSearch = false
            if mail.sender and string.find(string.lower(mail.sender), searchText) then
                matchesSearch = true
            elseif mail.subject and string.find(string.lower(mail.subject), searchText) then
                matchesSearch = true
            elseif mail.item and mail.item.name and string.find(string.lower(mail.item.name), searchText) then
                matchesSearch = true
            end
        end

        if matchesSearch then
            table.insert(filteredItems, mail)
        end
    end

    -- Display items
    self:DisplayItems(filteredItems, charFullName, totalItems)
end

-- Display mailbox items in a list
function MailboxFrame:DisplayItems(items, charFullName, totalMails)
    local container = getglobal("Guda_MailboxFrame_ItemContainer")
    
    -- Hide all existing rows first
    for _, row in pairs(mailboxRows) do
        row:Hide()
    end

    local totalItems = table.getn(items)
    local totalPages = math.max(1, math.ceil(totalItems / ITEMS_PER_PAGE))
    
    if currentPage > totalPages then
        currentPage = totalPages
    end

    local startIndex = (currentPage - 1) * ITEMS_PER_PAGE + 1
    local endIndex = math.min(startIndex + ITEMS_PER_PAGE - 1, totalItems)

    local rowIndex = 1
    for i = startIndex, endIndex do
        local mail = items[i]
        local row = mailboxRows[rowIndex]
        if not row then
            row = CreateFrame("Frame", "Guda_MailboxRow" .. rowIndex, container, "Guda_MailboxRowTemplate")
            mailboxRows[rowIndex] = row
        end
        
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -(rowIndex - 1) * 55)
        
        -- Fill row data
        getglobal(row:GetName() .. "_Sender"):SetText(mail.sender or "Unknown")
        getglobal(row:GetName() .. "_Subject"):SetText(mail.subject or "No Subject")
        
        local expireText = ""
        if mail.daysLeft then
            if mail.daysLeft < 1 then
                expireText = string.format("|cffff0000%dh|r", math.floor(mail.daysLeft * 24))
            else
                expireText = string.format("%dd", math.floor(mail.daysLeft))
            end
        end
        getglobal(row:GetName() .. "_ExpireTime"):SetText(expireText)
        
        -- Item Button
        local itemButton = getglobal(row:GetName() .. "_ItemButton")
        -- Re-assign shared namespace function if needed, but it should be available globally or via addon
        
        itemButton.isBank = false
        itemButton.otherChar = charFullName
        itemButton.mailData = mail
        itemButton.isMail = true
        itemButton.mailIndex = mail.mailIndex
        itemButton.mailItemIndex = mail.itemIndex or 1

        -- Force left alignment in case template or other code changed anchors
        if itemButton then
            itemButton:ClearAllPoints()
            itemButton:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -8)
        end
        
        if mail.item and (mail.item.texture or mail.item.link) then
            Guda_ItemButton_SetItem(itemButton, nil, nil, mail.item, false, charFullName, true, true)
            itemButton.isMail = true
            itemButton.mailData = mail
            itemButton.mailIndex = mail.mailIndex
            itemButton.mailItemIndex = mail.itemIndex or 1
        else
            Guda_ItemButton_SetItem(itemButton, nil, nil, nil, false, charFullName, true, true)
            itemButton.isMail = true
            itemButton.mailData = mail
            itemButton.mailIndex = mail.mailIndex
            itemButton.mailItemIndex = 1
            
            local icon = getglobal(itemButton:GetName().."IconTexture") or getglobal(itemButton:GetName().."Icon")
            if icon then
                if (mail.money or 0) > 0 then
                    icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
                elseif mail.packageIcon then
                    icon:SetTexture(mail.packageIcon)
                else
                    icon:SetTexture("Interface\\Icons\\INV_Letter_15")
                end
                icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                icon:Show()
            end
            if itemButton.qualityBorder then itemButton.qualityBorder:Hide() end
        end

        -- Row Money Frame
        local moneyFrame = getglobal(row:GetName() .. "_MoneyFrame")
        if moneyFrame then
            -- Force left alignment for the money frame
            moneyFrame:ClearAllPoints()
            moneyFrame:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 10, 8)
        end
        if (mail.money or 0) > 0 then
            MoneyFrame_Update(moneyFrame:GetName(), mail.money)
            moneyFrame:Show()
        else
            moneyFrame:Hide()
        end
        
        row:Show()
        rowIndex = rowIndex + 1
    end

    -- Update pagination buttons
    local prevBtn = getglobal("Guda_MailboxFrame_PrevPageButton")
    local nextBtn = getglobal("Guda_MailboxFrame_NextPageButton")
    
    if currentPage > 1 then
        prevBtn:Enable()
    else
        prevBtn:Disable()
    end
    
    if currentPage < totalPages then
        nextBtn:Enable()
    else
        nextBtn:Disable()
    end
    
    -- Update pagination text
    local paginationText = getglobal("Guda_MailboxFrame_Pagination_Text")
    if paginationText then
        paginationText:SetText(string.format("%d/%d (items: %d)", currentPage, totalPages, totalMails or 0))
    end
end

-- Search text changed
function Guda_MailboxFrame_OnSearchTextChanged()
    local searchBox = getglobal("Guda_MailboxFrame_SearchBar_SearchBox")
    local text = searchBox:GetText()
    if text == "Search mailbox..." then
        searchText = ""
    else
        searchText = string.lower(text)
    end
    currentPage = 1
    MailboxFrame:Update()
end

-- Show character selection menu
local function Guda_MailboxCharacterMenu_Initialize()
    local characters = addon.Modules.DB:GetAllCharacters(true, true)
    local info

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
        info.func = function() MailboxFrame:ShowCharacter(charFullName) end
        info.checked = (currentViewChar == char.fullName or (not currentViewChar and char.fullName == addon.Modules.DB:GetPlayerFullName()))
        UIDropDownMenu_AddButton(info)
    end
end

function Guda_MailboxFrame_ShowCharacterMenu()
    local menuFrame = getglobal("Guda_MailboxCharacterMenu")
    if not menuFrame then
        menuFrame = CreateFrame("Frame", "Guda_MailboxCharacterMenu", UIParent, "UIDropDownMenuTemplate")
    end
    UIDropDownMenu_Initialize(menuFrame, Guda_MailboxCharacterMenu_Initialize, "MENU")
    ToggleDropDownMenu(1, nil, menuFrame, "cursor", 0, 0)
end
