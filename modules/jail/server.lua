FN_JAIL = {}

local J = FN_JAIL

local function Started(resource)
    return GetResourceState(resource) == 'started'
end

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

local function Identifier(playerId)
    return FN_FRAMEWORK.GetIdentifier(playerId) or nil
end

local function UserColumn(playerId, column, value)
    local identifier = Identifier(playerId)
    if not identifier or not FN_DB.HasColumn('users', column) then return nil end
    if value == nil then return tonumber(MySQL.scalar.await(('SELECT %s FROM users WHERE identifier = ?'):format(column), { identifier })) end

    return MySQL.update.await(('UPDATE users SET %s = ? WHERE identifier = ?'):format(column), { value, identifier })
end

local Adapters = {
    { resource = 'xt-prison',
        send = function(id, minutes) return lib.callback.await('xt-prison:client:enterJail', id, minutes) == true end,
        release = function(id)
            exports['xt-prison']:SetJailTime(id, 0)
            return lib.callback.await('xt-prison:client:exitJail', id, true) ~= false
        end,
        get = function(id) return tonumber(Player(id).state.jailTime) end,
        offline = function(key) return tonumber(MySQL.scalar.await('SELECT jailtime FROM xt_prison WHERE identifier = ?', { key })) end },
    { resource = 'qb-prison',
        send = function(id, minutes)
            Meta(id, 'injail', minutes)
            TriggerClientEvent(Started('qb-policejob') and 'police:client:SendToJail' or 'prison:client:Enter', id, minutes)
            return true
        end,
        release = function(id)
            TriggerClientEvent('prison:client:UnjailPerson', id)
            return true
        end,
        get = function(id) return tonumber(Meta(id, 'injail')) end,
        offline = function(key) return tonumber(MySQL.scalar.await("SELECT JSON_UNQUOTE(JSON_EXTRACT(metadata, '$.injail')) FROM players WHERE citizenid = ?", { key })) end },
    { resource = 'pickle_prisons',
        send = function(id, minutes, opts)
            local by = Online(opts.by)
            if not by then return false, 'officer' end
            TriggerClientEvent('fn_bridge:jail', by, 'pickle_prisons:jailPlayer', id, minutes, 'default')
            return true
        end,
        release = false,
        get = function(id)
            local identifier = Identifier(id)
            return identifier and tonumber(MySQL.scalar.await('SELECT time FROM pickle_prisons WHERE identifier = ?', { identifier })) or tonumber(Meta(id, 'injail'))
        end,
        offline = function(key) return tonumber(MySQL.scalar.await('SELECT time FROM pickle_prisons WHERE identifier = ?', { key })) end },
    { resource = 'esx_jail',
        send = function(id, minutes)
            TriggerEvent('esx_jail:sendToJail', id, minutes * 60, true)
            return true
        end,
        release = function(id)
            ExecuteCommand(('unjail %d'):format(id))
            return true
        end,
        get = function(id)
            local seconds = UserColumn(id, 'jail_time')
            return seconds and math.ceil(seconds / 60)
        end,
        offline = function(key)
            local seconds = FN_DB.HasColumn('users', 'jail_time') and tonumber(MySQL.scalar.await('SELECT jail_time FROM users WHERE identifier = ?', { key }))
            return seconds and math.ceil(seconds / 60)
        end },
    { resource = 'esx-qalle-jail',
        send = function(id, minutes)
            TriggerClientEvent('esx-qalle-jail:jailPlayer', id, minutes)
            UserColumn(id, 'jail', minutes)
            return true
        end,
        release = function(id)
            TriggerClientEvent('esx-qalle-jail:unJailPlayer', id)
            UserColumn(id, 'jail', 0)
            return true
        end,
        get = function(id) return UserColumn(id, 'jail') end,
        offline = function(key) return FN_DB.HasColumn('users', 'jail') and tonumber(MySQL.scalar.await('SELECT jail FROM users WHERE identifier = ?', { key })) end },
}

for _, adapter in ipairs(Adapters) do FN_KNOWN[adapter.resource] = true end
FN_KNOWN['esx_communityservice'] = true

local function Pick()
    local hook = FN_BRIDGE.Setting('jail')
    if type(hook) == 'table' then return hook, 'hook' end

    for _, adapter in ipairs(Adapters) do
        if Started(adapter.resource) then return adapter, adapter.resource end
    end
end

local function Run(fn, ...)
    if not FN_BRIDGE.Callable(fn) then return false, 'none' end

    local ok, done, why = pcall(fn, ...)
    if not ok then return false, 'failed' end

    return done, why
end

J.Name = function()
    local _, name = Pick()

    return name or false
end

J.Send = function(playerId, minutes, opts)
    playerId, minutes, opts = Online(playerId), math.floor(tonumber(minutes) or 0), type(opts) == 'table' and opts or {}
    if not playerId then return false, 'offline' end
    if minutes < 1 or minutes > 100000 then return false, 'invalid' end

    local adapter = Pick()
    if not adapter then return false, 'none' end

    local done, why = Run(adapter.send, playerId, minutes, opts)

    return done == true, done ~= true and (why or 'failed') or nil
end

J.Release = function(playerId, opts)
    playerId = Online(playerId)
    if not playerId then return false, 'offline' end

    local adapter = Pick()
    if not adapter then return false, 'none' end

    if not FN_BRIDGE.Callable(adapter.release) then return false, 'unsupported' end

    local done, why = Run(adapter.release, playerId, type(opts) == 'table' and opts or {})

    return done == true, done ~= true and (why or 'failed') or nil
end

J.Get = function(playerId)
    playerId = Online(playerId)
    local adapter = playerId and Pick()
    if not adapter then return false end

    local minutes = Run(adapter.get, playerId)
    if type(minutes) == 'table' then return minutes end

    minutes = tonumber(minutes)

    return minutes and minutes > 0 and { minutes = math.ceil(minutes) } or false
end

J.GetOffline = function(identifier)
    if type(identifier) ~= 'string' or identifier == '' or #identifier > 64 then return false end

    local adapter = Pick()
    if not adapter or not FN_BRIDGE.Callable(adapter.offline) then return false end

    local minutes = Run(adapter.offline, identifier)
    if type(minutes) == 'table' then return minutes end

    minutes = tonumber(minutes)

    return minutes and minutes > 0 and { minutes = math.ceil(minutes) } or false
end

J.CommunityService = function(playerId, actions, opts)
    playerId, actions = Online(playerId), math.floor(tonumber(actions) or -1)
    if not playerId then return false, 'offline' end
    if actions < 0 or actions > 10000 then return false, 'invalid' end

    local hook = FN_BRIDGE.Setting('communityService')
    if FN_BRIDGE.Callable(hook) then
        local done = Run(hook, playerId, actions, type(opts) == 'table' and opts or {})
        return done ~= false, done == false and 'failed' or nil
    end

    if not Started('esx_communityservice') then return false, 'none' end

    if actions == 0 then
        TriggerEvent('esx_communityservice:endCommunityServiceCommand', playerId)
    else
        TriggerEvent('esx_communityservice:sendToCommunityService', playerId, actions)
    end

    return true
end

FN_BRIDGE.SupportedWhen('JAIL', 'Release', function()
    local adapter = Pick()

    return adapter ~= nil and FN_BRIDGE.Callable(adapter.release)
end)
