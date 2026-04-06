-- Guda SharedData Module
-- Cross-account character data sharing via GudaIO DLL (optional)
-- The DLL merges all accounts' SavedVariables at startup into GudaShared.lua
-- which is loaded via .toc and sets Guda_SharedCharacters global.
-- No Lua hooking needed - pure file I/O at DLL load time.

local addon = Guda

local SharedData = {}
addon.Modules.SharedData = SharedData

-- Import shared characters from other accounts
function SharedData:Initialize()
    if not Guda_SharedCharacters or type(Guda_SharedCharacters) ~= "table" then
        return
    end

    -- Determine current account by checking which characters are ours
    -- (characters in Guda_DB.characters that don't have isShared flag)
    local myChars = {}
    if Guda_DB and Guda_DB.characters then
        for fullName, data in pairs(Guda_DB.characters) do
            if not data.isShared then
                myChars[fullName] = true
            end
        end
    end

    -- Find which account name belongs to us by checking overlap
    local myAccount = nil
    local accountChars = {} -- account -> { fullName -> true }
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

    -- Import characters from other accounts
    local importCount = 0
    for fullName, charData in pairs(Guda_SharedCharacters) do
        if charData.account and charData.account ~= myAccount then
            -- Don't overwrite our own characters
            if not myChars[fullName] then
                Guda_DB.characters[fullName] = {
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
