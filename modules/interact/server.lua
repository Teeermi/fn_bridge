FN_INTERACT = {}

local X = FN_INTERACT
local Kinds = { cuff = true, ziptie = true, bag = true, escort = true, trunk = true, search = true, rob = true }
local Cuffed = {}
local CuffBags = { 'isHandcuffed', 'IsHandcuffed', 'handcuffed', 'cuffed', 'isCuffed', 'IsCuffed' }

local function Online(playerId)
    playerId = tonumber(playerId)

    return playerId and GetPlayerName(playerId) and playerId or nil
end

local function Meta(playerId, key, value)
    local player = FN_FRAMEWORK.RawPlayer and FN_FRAMEWORK.RawPlayer(playerId)
    local data = type(player) == 'table' and player.PlayerData
    if value == nil then return data and data.metadata and data.metadata[key] end
    if player and player.Functions and player.Functions.SetMetaData then player.Functions.SetMetaData(key, value) end
end

local function CuffedNow(target)
    local state = Player(target).state
    if Meta(target, 'ishandcuffed') == true then return true end
    for _, key in ipairs(CuffBags) do
        if state[key] == true then return true end
    end

    return Cuffed[target] == true
end

local function Toggle(event, extra)
    return function(playerId, target, on, kind)
        local was = CuffedNow(target)
        if on ~= nil and was == on then return true end
        TriggerClientEvent(event, target, extra and playerId or nil, kind == 'ziptie')
        Cuffed[target] = not was
        return true
    end
end

local Scripts = {
    { resource = 'qb-policejob', cuff = Toggle('police:client:GetCuffed', true), ziptie = Toggle('police:client:GetCuffed', true),
        escort = function(playerId, target)
            TriggerClientEvent('police:client:GetEscorted', target, playerId)
            return true
        end },
    { resource = 'qbx_police', cuff = function(_, target, on)
            if on == nil then on = not CuffedNow(target) end
            Meta(target, 'ishandcuffed', on)
            Player(target).state.invBusy = on
            Cuffed[target] = on
            return true
        end },
    { resource = 'esx_policejob', cuff = Toggle('esx_policejob:handcuff', false),
        escort = function(playerId, target)
            TriggerClientEvent('esx_policejob:drag', target, playerId)
            return true
        end },
}

for _, script in ipairs(Scripts) do FN_KNOWN[script.resource] = true end

local function Search(playerId, target)
    if FN_BRIDGE.IsInventory('ox_inventory') then return pcall(function() exports.ox_inventory:forceOpenInventory(playerId, 'player', target) end) end
    if FN_BRIDGE.IsInventory('qb-inventory') then return pcall(function() exports['qb-inventory']:OpenInventoryById(playerId, target) end) end

    return false
end

local function Pick(kind)
    local hook = FN_BRIDGE.Setting('interact')
    if type(hook) == 'table' and FN_BRIDGE.Callable(hook[kind]) then return hook[kind], 'hook' end

    for _, script in ipairs(Scripts) do
        if script[kind] and GetResourceState(script.resource) == 'started' then return script[kind], script.resource end
    end

    if kind == 'search' and (FN_BRIDGE.IsInventory('ox_inventory') or FN_BRIDGE.IsInventory('qb-inventory')) then return Search, FN_BRIDGE.inventoryName end
end

X.Has = function(kind)
    if not Kinds[kind] then return false end

    local _, name = Pick(kind)

    return name or false
end

X.Do = function(playerId, target, kind, on)
    playerId, target = Online(playerId), Online(target)
    if not playerId or not target or playerId == target or not Kinds[kind] then return false end

    local a, b = GetPlayerPed(playerId), GetPlayerPed(target)
    if a == 0 or b == 0 or #(GetEntityCoords(a) - GetEntityCoords(b)) > 5.0 then return false end

    local fn = Pick(kind)
    if not fn then return false end

    local ok, done = pcall(fn, playerId, target, on, kind)

    return ok and done ~= false
end

X.Is = function(target, kind)
    target = Online(target)
    if not target or not Kinds[kind] then return false end

    local hook = FN_BRIDGE.Setting('interact')
    if type(hook) == 'table' and FN_BRIDGE.Callable(hook.is) then
        local ok, value = pcall(hook.is, target, kind)
        if ok and value ~= nil then return value == true end
    end

    if kind == 'cuff' or kind == 'ziptie' then return CuffedNow(target) end

    local state = Player(target).state

    return state[kind] == true or state['is' .. kind:sub(1, 1):upper() .. kind:sub(2)] == true
end

AddEventHandler('playerDropped', function() Cuffed[source] = nil end)
