-- Guda SharedData Module
-- Cross-account character data sharing via GudaIO DLL (optional)
-- The DLL merges all accounts' SavedVariables at startup into GudaShared.lua
-- which is loaded via .toc and sets Guda_SharedCharacters global.
--
-- IMPORTANT: Shared characters are stored in addon.sharedCharacters (in-memory only),
-- NOT in Guda_DB.characters, to prevent them from leaking into SavedVariables.

local addon = Guda

local SharedData = {}
addon.Modules.SharedData = SharedData

function SharedData:Initialize()
    -- Clean up any leaked shared characters from the old approach
    if Guda_DB and Guda_DB.characters then
        for fullName, data in pairs(Guda_DB.characters) do
            if data.isShared then
                Guda_DB.characters[fullName] = nil
            else
                -- Strip leaked fields from own characters
                data.isShared = nil
                data.account = nil
            end
        end
    end

    -- Initialize in-memory shared characters table
    addon.sharedCharacters = {}

    if not Guda_SharedCharacters or type(Guda_SharedCharacters) ~= "table" then
        return
    end

    -- Determine which characters belong to the current account
    local myChars = {}
    if Guda_DB and Guda_DB.characters then
        for fullName in pairs(Guda_DB.characters) do
            myChars[fullName] = true
        end
    end

    -- Find which account name belongs to us by checking overlap
    local myAccount = nil
    local accountChars = {}
    for fullName, charData in pairs(Guda_SharedCharacters) do
        local acct = charData.account
        if acct then
            if not accountChars[acct] then accountChars[acct] = {} end
            accountChars[acct][fullName] = true
        end
    end

    for acct, chars in pairs(accountChars) do
        for fullName in pairs(chars) do
            if myChars[fullName] then
                myAccount = acct
                break
            end
        end
        if myAccount then break end
    end

    -- Import characters from other accounts into in-memory table
    local importCount = 0
    for fullName, charData in pairs(Guda_SharedCharacters) do
        if charData.account and charData.account ~= myAccount then
            if not myChars[fullName] then
                addon.sharedCharacters[fullName] = {
                    name = charData.name,
                    realm = charData.realm,
                    faction = charData.faction,
                    class = charData.class,
                    classToken = charData.classToken,
                    level = charData.level,
                    money = charData.money,
                    bags = charData.bags,
                    bank = charData.bank,
                    mailbox = charData.mailbox,
                    equipped = charData.equipped,
                    lastUpdate = charData.lastUpdate,
                    account = charData.account,
                    isShared = true,
                }
                importCount = importCount + 1
            end
        end
    end

    if importCount > 0 then
        addon:Print("Imported " .. importCount .. " character(s) from other accounts")
    end

    -- Clean up the global to free memory
    Guda_SharedCharacters = nil
end
