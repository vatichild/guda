-- Guda ClamOpener
-- Walks the player's bags and uses each clam in turn until none remain.
-- Triggered by /guda openclams. Stops on UI_ERROR_MESSAGE so a full inventory
-- (or any other error from UseContainerItem) cleanly aborts the run.

local addon = Guda
local L = Guda_L

local ClamOpener = {}
addon.Modules.ClamOpener = ClamOpener

-- Hardcoded vanilla clam item IDs
local CLAM_IDS = {
    [5523]  = true,  -- Small Barnacled Clam
    [5524]  = true,  -- Thick-shelled Clam
    [7973]  = true,  -- Big-mouth Clam
    [15874] = true,  -- Soft-shelled Clam
}

local OPEN_DELAY = 0.3   -- seconds between opens; lets loot/bag updates settle
local running = false
local silentRun = false

-- Find the next clam in player bags. Returns bagID, slotID, itemLink or nil.
local function FindNextClam()
    for bagID = 0, 4 do
        local numSlots = GetContainerNumSlots(bagID)
        if numSlots and numSlots > 0 then
            for slotID = 1, numSlots do
                local link = GetContainerItemLink(bagID, slotID)
                if link then
                    local _, _, idStr = string.find(link, "item:(%d+)")
                    local itemID = idStr and tonumber(idStr)
                    if itemID and CLAM_IDS[itemID] then
                        return bagID, slotID
                    end
                end
            end
        end
    end
    return nil
end

local function StopRun(reason)
    if not running then return end
    running = false
    -- Don't unregister BAG_UPDATE — it's the auto-trigger. Only drop the
    -- per-run UI_ERROR_MESSAGE listener.
    addon.Modules.Events:UnregisterOwner("ClamOpener_Run")
    if reason and not silentRun then
        addon:Print(reason)
    end
    silentRun = false
end

local function OpenNext()
    if not running then return end

    if CursorHasItem() then
        -- Cursor is busy with something else; try again shortly.
        Guda_ScheduleTimer(OPEN_DELAY, OpenNext)
        return
    end

    local bagID, slotID = FindNextClam()
    if not bagID then
        StopRun(L["No more clams to open."])
        return
    end

    UseContainerItem(bagID, slotID)
    Guda_ScheduleTimer(OPEN_DELAY, OpenNext)
end

-- Stop on UI_ERROR_MESSAGE (e.g. inventory full). UseContainerItem fires this
-- the same frame on failure, so any error after we start counts as an abort.
local function OnUIError()
    if not running then return end
    local msg = arg1
    StopRun(string.format(L["Clam opener stopped: %s"], tostring(msg or "error")))
end

-- silent: true to suppress chat messages (used by auto-trigger).
function ClamOpener:Open(silent)
    if running then
        if not silent then
            addon:Print(L["Clam opener is already running."])
        end
        return
    end

    -- Quick sanity check so we don't print "stopped" without ever starting.
    if not FindNextClam() then
        if not silent then
            addon:Print(L["No clams found in your bags."])
        end
        return
    end

    running = true
    silentRun = silent and true or false
    addon.Modules.Events:Register("UI_ERROR_MESSAGE", OnUIError, "ClamOpener_Run")
    if not silent then
        addon:Print(L["Opening clams..."])
    end
    OpenNext()
end

-- Returns true if any blocking window (loot/mail/trade/merchant/bank/auction)
-- is currently open. We don't want to UseContainerItem while these are active —
-- it can race the open window or get queued and lost.
local function IsBlockingWindowOpen()
    local frames = {
        "LootFrame", "MailFrame", "TradeFrame", "MerchantFrame",
        "BankFrame", "AuctionFrame",
        -- Guda's own bank/mail frames too
        "Guda_BankFrame", "Guda_MailboxFrame",
    }
    for _, name in ipairs(frames) do
        local f = getglobal(name)
        if f and f.IsShown and f:IsShown() then
            return true
        end
    end
    return false
end

-- Initialize auto-open. Triggers:
--   * BAG_UPDATE      — catches clams that arrived without a blocking window.
--   * LOOT_CLOSED     — the common case: clam looted from a corpse.
--   * MAIL_CLOSED     — clam received via mail.
--   * TRADE_CLOSED    — clam received via trade.
--   * BANKFRAME_CLOSED — clam withdrawn from bank.
-- Each trigger defers ~0.15s and then attempts a silent Open(); the running
-- guard, the FindNextClam check, and the IsBlockingWindowOpen guard absorb
-- the noise of multiple events firing in quick succession.
function ClamOpener:Initialize()
    local function tryAutoOpen()
        if running then return end
        if not (Guda.Modules.DB and Guda.Modules.DB:GetSetting("autoOpenClams")) then
            return
        end
        Guda_ScheduleTimer(0.15, function()
            if running then return end
            if IsBlockingWindowOpen() then return end
            ClamOpener:Open(true)
        end)
    end

    addon.Modules.Events:Register("BAG_UPDATE",        tryAutoOpen, "ClamOpener")
    addon.Modules.Events:Register("LOOT_CLOSED",       tryAutoOpen, "ClamOpener")
    addon.Modules.Events:Register("MAIL_CLOSED",       tryAutoOpen, "ClamOpener")
    addon.Modules.Events:Register("TRADE_CLOSED",      tryAutoOpen, "ClamOpener")
    addon.Modules.Events:Register("BANKFRAME_CLOSED",  tryAutoOpen, "ClamOpener")
end
