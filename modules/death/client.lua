AddEventHandler('playerSpawned', function()
    if not GlobalState.fn_isDead then return end
    GlobalState.fn_isDead = false
end)

AddEventHandler('gameEventTriggered', function(event, args)
    if event ~= 'CEventNetworkEntityDamage' or GlobalState.fn_isDead then return end

    local victim = args[1]
    if not victim or victim == 0 or not IsPedAPlayer(victim) then return end
    if NetworkGetPlayerIndexFromPed(victim) ~= GlobalState.fn_playerId then return end
    if not IsPedDeadOrDying(victim, true) and not IsPedFatallyInjured(victim) then return end

    GlobalState.fn_isDead = true
end)

local LocalDeathBags = {
    'isDead', 'IsDead', 'dead', 'Dead'
}

for _, key in ipairs(LocalDeathBags) do
    AddStateBagChangeHandler(key, 'player:'..GetPlayerServerId(PlayerId()), function(bagName, _key, value, _unused, replicated)
        if replicated then return end
        if bagName ~= 'player:' .. GlobalState.fn_serverId then return end
        if type(value) ~= 'boolean' then return end

        GlobalState.fn_isDead = value
    end)
end

AddEventHandler('esx:onPlayerDeath', function()
    GlobalState.fn_isDead = true
end)

FN_DEATH = {}

local Provider
local Metadata = {}

local DownBags = { 'inlaststand', 'inLaststand', 'laststand', 'lastStand', 'isDown', 'down' }
local DeadBags = { 'isDead', 'IsDead', 'isdead', 'dead', 'Dead' }

AddEventHandler('fn_bridge/client/updatePlayerData', function(data)
    local metadata = type(data) == 'table' and data.metadata
    Metadata = type(metadata) == 'table' and { down = metadata.inlaststand == true, dead = metadata.isdead == true } or {}
end)

FN_DEATH.GetState = function()
    if Provider then
        local ok, state = pcall(Provider.impl.GetState)
        if ok and (state == 'alive' or state == 'down' or state == 'dead') then return state end
    end

    if Metadata.down then return 'down' end
    if Metadata.dead then return 'dead' end

    local state = LocalPlayer.state
    for _, key in ipairs(DownBags) do
        if state[key] == true then return 'down' end
    end
    for _, key in ipairs(DeadBags) do
        if state[key] == true then return 'dead' end
    end

    return IsEntityDead(PlayerPedId()) and 'dead' or 'alive'
end

FN_DEATH.IsDown = function()
    return FN_DEATH.GetState() ~= 'alive'
end

FN_DEATH.InArena = function()
    return LocalPlayer.state.fn_arena or false
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

RegisterNetEvent('fn_bridge:revive', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
    ped = PlayerPedId()
    SetEntityInvincible(ped, false)
    ClearPedTasksImmediately(ped)
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    GlobalState.fn_isDead = false
end)

CreateThread(function()
    local was = 'alive'
    while true do
        Wait(500)
        local now = FN_DEATH.GetState()
        if now ~= was then
            local before = was
            was = now
            if not FN_DEATH.InArena() then TriggerEvent('fn_bridge:deathChanged', now, before) end
            TriggerServerEvent('fn_bridge:died', now, now ~= 'alive' and GetPedCauseOfDeath(PlayerPedId()) or 0)
        end
    end
end)
