FN_DEATH = {}

local Provider

local Revivers = {
    { resource = 'qbx_medical', revive = function(playerId) exports.qbx_medical:Revive(playerId) end },
    { resource = 'qb-ambulancejob', revive = function(playerId) TriggerClientEvent('hospital:client:Revive', playerId) end },
    { resource = 'esx_ambulancejob', revive = function(playerId) TriggerClientEvent('esx_ambulancejob:revive', playerId) end },
}

for _, reviver in ipairs(Revivers) do FN_KNOWN[reviver.resource] = true end

local DownBags = { 'inlaststand', 'inLaststand', 'laststand', 'lastStand', 'isDown', 'down' }
local DeadBags = { 'isDead', 'IsDead', 'isdead', 'dead', 'Dead' }

local function Online(playerId)
    playerId = tonumber(playerId)
    return playerId and GetPlayerPing(playerId) > 0 and playerId or nil
end

local function QbPlayer(playerId)
    local resource = FN_BRIDGE.IsFramework('qbx') and 'qbx_core' or FN_BRIDGE.IsFramework('qb') and 'qb-core'
    if not resource then return nil end

    local ok, player = pcall(function() return exports[resource]:GetPlayer(playerId) end)

    return ok and type(player) == 'table' and player or nil
end

local function Generic(playerId)
    local player = QbPlayer(playerId)
    local metadata = player and player.PlayerData and player.PlayerData.metadata
    if type(metadata) == 'table' then
        if metadata.inlaststand == true then return 'down' end
        if metadata.isdead == true then return 'dead' end
    end

    local state = Player(playerId).state
    for _, key in ipairs(DownBags) do
        if state[key] == true then return 'down' end
    end
    for _, key in ipairs(DeadBags) do
        if state[key] == true then return 'dead' end
    end

    local ped = GetPlayerPed(playerId)
    if ped ~= 0 and GetEntityHealth(ped) <= 0 then return 'dead' end

    return 'alive'
end

FN_DEATH.GetState = function(playerId)
    playerId = Online(playerId)
    if not playerId then return 'alive' end

    if Provider then
        local ok, state = pcall(Provider.impl.GetState, playerId)
        if ok and (state == 'alive' or state == 'down' or state == 'dead') then return state end
    end

    return Generic(playerId)
end

FN_DEATH.IsDown = function(playerId)
    return FN_DEATH.GetState(playerId) ~= 'alive'
end

FN_DEATH.SetFlag = function(playerId, on)
    playerId = Online(playerId)
    if not playerId then return false end
    on = on == true

    local player = QbPlayer(playerId)
    if player then
        if not player.Functions or not player.Functions.SetMetaData then return false end
        player.Functions.SetMetaData('isdead', on)
        if not on then player.Functions.SetMetaData('inlaststand', false) end

        return true
    end

    if FN_BRIDGE.IsFramework('esx') and FN_DB.HasColumn('users', 'is_dead') then
        local identifier = FN_FRAMEWORK.GetIdentifier(playerId)
        if identifier then MySQL.update('UPDATE users SET is_dead = ? WHERE identifier = ?', { on and 1 or 0, identifier }) end
    end

    local state = Player(playerId).state
    if (state.isDead == true) ~= on then state:set('isDead', on, true) end

    return true
end

FN_DEATH.Revive = function(playerId)
    playerId = Online(playerId)
    if not playerId then return false end

    local caller = GetInvokingResource()
    if Provider and Provider.resource ~= caller then
        local ok, done = pcall(Provider.impl.Revive, playerId)

        return ok and done ~= false and Provider.resource or false
    end

    local via
    local hook = FN_BRIDGE.Setting('revive', caller)
    if FN_BRIDGE.Callable(hook) then
        local ok, done = pcall(hook, playerId)
        if ok and done ~= false then via = 'hook' end
    end

    if not via then
        for _, reviver in ipairs(Revivers) do
            if GetResourceState(reviver.resource) == 'started' and pcall(reviver.revive, playerId) then
                via = reviver.resource
                break
            end
        end
    end

    if not via then
        TriggerClientEvent('fn_bridge:revive', playerId)
        via = 'bridge'
    end

    FN_DEATH.SetFlag(playerId, false)

    return via
end

FN_DEATH.Reviver = function()
    if Provider then return Provider.resource end

    for _, reviver in ipairs(Revivers) do
        if GetResourceState(reviver.resource) == 'started' then return reviver.resource end
    end

    return false
end

local Ambulances = { 'esx_ambulancejob', 'qb-ambulancejob', 'qbx_medical', 'wasabi_ambulance', 'ars_ambulancejob', 'ak47_ambulancejob' }

for _, resource in ipairs(Ambulances) do FN_KNOWN[resource] = true end
FN_KNOWN['qbx_ambulancejob'] = true

FN_DEATH.Ambulances = function()
    local out = {}
    local caller = GetInvokingResource()
    if Provider and Provider.resource ~= caller then out[1] = Provider.resource end
    if FN_BRIDGE.Callable(FN_BRIDGE.Setting('revive', caller)) then out[#out + 1] = 'hook' end
    for _, resource in ipairs(Ambulances) do
        local state = GetResourceState(resource)
        if state == 'started' or state == 'starting' then out[#out + 1] = resource end
    end

    return out
end

FN_DEATH.Provide = function(impl)
    local resource = GetInvokingResource()
    if not resource then return false end

    if not impl then
        if Provider and Provider.resource == resource then Provider = nil end
        return true
    end

    if type(impl) ~= 'table' or not FN_BRIDGE.Callable(impl.GetState) then return false end
    Provider = { resource = resource, impl = impl }

    return true
end

AddEventHandler('onResourceStop', function(resource)
    if Provider and Provider.resource == resource then Provider = nil end
end)

local LastHit, Reported = {}, {}

AddEventHandler('weaponDamageEvent', function(sender, data)
    sender = tonumber(sender)
    if not sender or type(data) ~= 'table' then return end

    local ids = type(data.hitGlobalIds) == 'table' and data.hitGlobalIds or { data.hitGlobalId }
    for _, netId in ipairs(ids) do
        local ped = tonumber(netId) and NetworkGetEntityFromNetworkId(netId) or 0
        local victim = ped ~= 0 and GetEntityType(ped) == 1 and IsPedAPlayer(ped) and NetworkGetEntityOwner(ped)
        if victim and victim ~= sender then LastHit[victim] = { killer = sender, weapon = tonumber(data.weaponType) or false, at = os.time() } end
    end
end)

RegisterNetEvent('fn_bridge:died', function(state, cause)
    local victim = source
    if state == 'alive' then
        Reported[victim] = nil
        return
    end
    if (state ~= 'down' and state ~= 'dead') or Reported[victim] or FN_DEATH.GetState(victim) == 'alive' then return end

    Reported[victim] = true
    local hit = LastHit[victim]
    LastHit[victim] = nil
    local fresh = hit and os.time() - hit.at <= 10 and GetPlayerName(hit.killer) and hit
    local ped = GetPlayerPed(victim)

    TriggerEvent('fn_bridge/server/playerDied', victim, {
        state = state,
        killer = fresh and fresh.killer or false,
        weapon = fresh and fresh.weapon or false,
        coords = ped ~= 0 and GetEntityCoords(ped) or nil,
        cause = math.tointeger(tonumber(cause)) or 0,
    })
end)

AddEventHandler('playerDropped', function()
    LastHit[source], Reported[source] = nil, nil
end)
