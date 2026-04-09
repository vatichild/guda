-- Guda AutoLoot
-- TurtleWoW with SuperWoW removes the hardcoded shift-autoloot and exposes:
--   * SetAutoloot(0|1)            — global client autoloot toggle
--   * LootSlot(slot, forceloot)   — forceloot=1 is REQUIRED to actually loot
-- We prefer SetAutoloot when present (lets the client handle everything),
-- and also fall back to a LOOT_OPENED handler that calls LootSlot(slot, 1)
-- so this works on clients without SuperWoW too.

local addon = Guda

local AutoLoot = {}
addon.Modules.AutoLoot = AutoLoot

local function ApplyClientSetting()
    local enabled = Guda.Modules.DB and Guda.Modules.DB:GetSetting("autoLoot")
    if SetAutoloot then
        SetAutoloot(enabled and 1 or 0)
    elseif SetAutoLootDefault then
        SetAutoLootDefault(enabled and true or false)
    end
end

local function OnLootOpened()
    if not (Guda.Modules.DB and Guda.Modules.DB:GetSetting("autoLoot")) then
        return
    end
    -- If SuperWoW's SetAutoloot is present and enabled, the client has
    -- already looted everything before LOOT_OPENED reaches us — this loop
    -- is a no-op safety net for normal clients and any leftovers (BoP
    -- confirms, etc.).
    local n = GetNumLootItems()
    if not n or n == 0 then return end
    for slot = n, 1, -1 do
        LootSlot(slot, 1)  -- forceloot=1 for SuperWoW compatibility
        if ConfirmLootSlot then ConfirmLootSlot(slot) end
    end
end

function AutoLoot:Initialize()
    addon.Modules.Events:Register("LOOT_OPENED", OnLootOpened, "AutoLoot")
    ApplyClientSetting()
end

-- Called by the settings checkbox so the client toggle flips immediately.
function AutoLoot:Apply()
    ApplyClientSetting()
end
