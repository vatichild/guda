-- Guda Mailbox Scanner
-- Scans and stores mailbox contents

local addon = Guda

local MailboxScanner = {}
addon.Modules.MailboxScanner = MailboxScanner

local mailboxOpen = false

-- Scan all mailbox items and return data
function MailboxScanner:ScanMailbox()
    if not mailboxOpen then
        addon:Debug("Cannot scan mailbox - not open")
        return {}
    end

    local mailboxData = {}
    local numItems = GetInboxNumItems()

    for i = 1, numItems do
        local mailRows = self:ScanMailItemRows(i)
        for _, row in ipairs(mailRows) do
            table.insert(mailboxData, row)
        end
    end

    return mailboxData
end

-- Scan a single mail into one or more rows (flattened)
function MailboxScanner:ScanMailItemRows(index)
    -- GetInboxHeaderInfo(index) returns: packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, hasItem, wasRead, wasReturned, textCreated, canReply, isGM
    local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, hasItem, wasRead, wasReturned, textCreated, canReply, isGM = GetInboxHeaderInfo(index)

    local rows = {}
    
    if hasItem then
        -- Turtle WoW supports up to 12 attachments per mail.
        -- We use GetInboxNumAttachments if available to avoid over-scanning on servers
        -- that might ignore the second argument of GetInboxItem.
        local numAttachments = 0
        if GetInboxNumAttachments then
            numAttachments = GetInboxNumAttachments(index) or 0
        end

        -- Fallback: if we don't have the count but header says there's an item, assume at least 1.
        if numAttachments == 0 and hasItem then
            numAttachments = 1
        end

        for itemIndex = 1, numAttachments do
            -- GetInboxItem(index, itemIndex) returns: name, texture, count, quality, canUse
            local name, texture, count, quality, canUse = GetInboxItem(index, itemIndex)
            if not name then break end

            local itemLink = addon.Modules.Utils:GetInboxItemLink(index, itemIndex)
            local itemID = itemLink and addon.Modules.Utils:ExtractItemID(itemLink)

            -- Fallback 1: If link/itemID is missing, try GetItemInfo(name) which might be cached now
            if not itemID or not itemLink then
                local _, link = GetItemInfo(name)
                if link then
                    itemLink = link
                    itemID = addon.Modules.Utils:ExtractItemID(link)
                    addon:Debug("Recovered link from GetItemInfo for %s", name)
                end
            end

            -- Fallback 2: If still missing, try to recover from existing database (any character)
            if not itemID or not itemLink then
                itemID, itemLink = addon.Modules.DB:FindItemByName(name)
                if itemID then
                    addon:Debug("Recovered link from DB for %s", name)
                end
            end
            
            local itemData = {
                link = itemLink,
                texture = texture or "Interface\\Icons\\INV_Misc_Bag_08",
                count = count or 1,
                quality = quality or 0,
                name = name,
                itemID = itemID,
            }

            -- Ensure we have a link if we have an itemID
            if itemData.itemID and not itemData.link then
                itemData.link = "item:" .. itemData.itemID .. ":0:0:0"
            end

            -- If we have a link, try to get more detailed info from cache
            if itemData.link then
                local itemName, link, itemQuality, iLevel, itemCategory, itemType, itemStackCount, itemSubType, itemTexture, itemEquipLoc, itemSellPrice = addon.Modules.Utils:GetItemInfo(itemData.link)
                if itemName then
                    itemData.name = itemName
                    itemData.quality = itemQuality or itemData.quality
                    itemData.iLevel = iLevel
                    itemData.type = itemType
                    itemData.class = itemCategory
                    itemData.subclass = itemSubType
                    itemData.equipSlot = itemEquipLoc
                    if itemTexture then itemData.texture = itemTexture end
                end
            end

            table.insert(rows, {
                sender = sender,
                subject = subject,
                money = (itemIndex == 1) and money or 0, -- Attach money only to the first row of this mail
                CODAmount = (itemIndex == 1) and CODAmount or 0,
                daysLeft = daysLeft,
                hasItem = true,
                item = itemData,
                mailIndex = index,
                itemIndex = itemIndex,
                wasRead = wasRead,
                packageIcon = packageIcon,
            })
        end
    end

    -- If no items found but there is money or it's just a letter
    if table.getn(rows) == 0 then
        table.insert(rows, {
            sender = sender,
            subject = subject,
            money = money,
            CODAmount = CODAmount,
            daysLeft = daysLeft,
            hasItem = false,
            item = nil,
            mailIndex = index,
            itemIndex = 1,
            wasRead = wasRead,
            packageIcon = packageIcon,
        })
    end

    return rows
end

-- Save current mailbox to database
function MailboxScanner:SaveToDatabase()
    if not mailboxOpen then
        return
    end

    local mailboxData = self:ScanMailbox()
    addon.Modules.DB:SaveMailbox(mailboxData)
    addon:Debug("Mailbox data saved")
end

-- Handle outgoing mail
function MailboxScanner:OnSendMail(recipient, subject, body)
    if not recipient or recipient == "" then return end
    
    -- In WoW 1.12.1, SendMail(recipient, subject, body) is the signature.
    -- To get the attached item, we use GetSendMailItem().
    -- GetSendMailItem() returns: name, texture, count, quality
    local name, texture, count, quality = GetSendMailItem()
    local moneyAmount = GetSendMailMoney()
    
    local itemData = nil
    if name then
        local _, link = GetItemInfo(name)
        itemData = {
            name = name,
            texture = texture or "Interface\\Icons\\INV_Misc_Bag_08",
            count = count or 1,
            quality = quality or 0,
            link = link,
            itemID = addon.Modules.Utils:ExtractItemID(link),
        }
        
        -- Try to get more info if it's in cache
        local itemName, retLink, itemQuality, iLevel, itemCategory, itemType, itemStackCount, itemSubType, itemTexture, itemEquipLoc, itemSellPrice = addon.Modules.Utils:GetItemInfo(name)
        if itemName then
            itemData.link = retLink or itemData.link
            itemData.itemID = addon.Modules.Utils:ExtractItemID(itemData.link) or itemData.itemID
            itemData.quality = itemQuality or itemData.quality
            itemData.iLevel = iLevel
            itemData.type = itemType
            itemData.class = itemCategory
            itemData.subclass = itemSubType
            itemData.equipSlot = itemEquipLoc
            if itemTexture then itemData.texture = itemTexture end
        end

        -- Double check itemID
        if not itemData.itemID and itemData.link then
            itemData.itemID = addon.Modules.Utils:ExtractItemID(itemData.link)
        end
    end

    if itemData or moneyAmount > 0 then
        local mailRow = {
            sender = UnitName("player"),
            subject = (subject and subject ~= "") and subject or "No Subject",
            money = moneyAmount,
            CODAmount = 0,
            daysLeft = 30, -- Outgoing mail typically has 30 days
            hasItem = itemData ~= nil,
            item = itemData,
            wasRead = false,
        }
        
        addon.Modules.DB:AddMailToCharacter(recipient, nil, mailRow)
    end
end

-- Handle auction house buyouts
function MailboxScanner:OnAuctionBid(type, index, bid)
    local name, texture, count, quality, canUse, level, minBid, minIncrement, buyoutPrice, bidAmount, highBidder, owner = GetAuctionItemInfo(type, index)
    
    if name and buyoutPrice > 0 and bid >= buyoutPrice then
        local link = GetAuctionItemLink(type, index)
        local itemData = {
            name = name,
            texture = texture or "Interface\\Icons\\INV_Misc_Bag_08",
            count = count or 1,
            quality = quality or 0,
            link = link,
            itemID = addon.Modules.Utils:ExtractItemID(link),
        }
        
        -- Try to get more info if it's in cache
        local itemName, retLink, itemQuality, iLevel, itemCategory, itemType, itemStackCount, itemSubType, itemTexture, itemEquipLoc, itemSellPrice = addon.Modules.Utils:GetItemInfo(link or name)
        if itemName then
            itemData.link = retLink or itemData.link
            itemData.itemID = addon.Modules.Utils:ExtractItemID(itemData.link) or itemData.itemID
            itemData.quality = itemQuality or itemData.quality
            itemData.iLevel = iLevel
            itemData.type = itemType
            itemData.class = itemCategory
            itemData.subclass = itemSubType
            itemData.equipSlot = itemEquipLoc
            if itemTexture then itemData.texture = itemTexture end
        end

        local mailRow = {
            sender = "Auction House",
            subject = "Auction won: " .. name,
            money = 0,
            CODAmount = 0,
            daysLeft = 30,
            hasItem = true,
            item = itemData,
            wasRead = false,
        }
        
        addon.Modules.DB:AddMailToCharacter(UnitName("player"), nil, mailRow)
        addon:Debug("Captured AH buyout: %s", name)
    end
end

-- Initialize mailbox scanner
function MailboxScanner:Initialize()
    -- Hook SendMail to capture outgoing mail to alts
    local originalSendMail = SendMail
    SendMail = function(recipient, subject, body)
        MailboxScanner:OnSendMail(recipient, subject, body)
        return originalSendMail(recipient, subject, body)
    end

    -- Hook PlaceAuctionBid to capture AH buyouts
    local originalPlaceAuctionBid = PlaceAuctionBid
    PlaceAuctionBid = function(type, index, bid)
        MailboxScanner:OnAuctionBid(type, index, bid)
        return originalPlaceAuctionBid(type, index, bid)
    end

    -- Mailbox opened
    addon.Modules.Events:OnMailShow(function()
        mailboxOpen = true
        addon:Debug("Mailbox opened")
        
        -- Delay scan slightly to ensure item info is available
        local frame = CreateFrame("Frame")
        local elapsed = 0
        frame:SetScript("OnUpdate", function()
            elapsed = elapsed + arg1
            if elapsed >= 0.5 then
                frame:SetScript("OnUpdate", nil)
                if mailboxOpen then
                    MailboxScanner:SaveToDatabase()
                end
            end
        end)
    end, "MailboxScanner")

    -- Register for GET_ITEM_INFO_RECEIVED to refresh if item data arrives
    addon.Modules.Events:Register("GET_ITEM_INFO_RECEIVED", function()
        if mailboxOpen then
            addon:Debug("GET_ITEM_INFO_RECEIVED: Refreshing mailbox")
            MailboxScanner:SaveToDatabase()
        end
    end, "MailboxScanner")

    -- Register for MAIL_INBOX_UPDATE to detect when mail content changes
    addon.Modules.Events:Register("MAIL_INBOX_UPDATE", function()
        if mailboxOpen then
            addon:Debug("MAIL_INBOX_UPDATE: Refreshing mailbox")
            MailboxScanner:SaveToDatabase()
        end
    end, "MailboxScanner")

    -- Register for UI_ERROR_MESSAGE to handle "item not found" situations if needed
    -- (Some items might not be in cache and fail silently otherwise)

    -- Mailbox closed
    addon.Modules.Events:OnMailClosed(function()
        -- Final save on close
        MailboxScanner:SaveToDatabase()
        mailboxOpen = false
        addon:Debug("Mailbox closed")
    end, "MailboxScanner")
end

-- Check if mailbox is currently open
function MailboxScanner:IsMailboxOpen()
    return mailboxOpen
end
