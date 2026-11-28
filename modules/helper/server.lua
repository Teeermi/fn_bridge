FN_HELPER = {
    Players = {}
}

for _, resource in ipairs({ 'LegacyFuel', 'cdn-fuel', 'ps-fuel', 'lj-fuel', 'okokGasStation', 'ti_fuel', 'x-fuel', 'ox_fuel', 'qbx_seatbelt', 'qb-smallresources', 'esx_cruisecontrol' }) do FN_KNOWN[resource] = 'helper' end

local savePrint = print
FN_HELPER.print = function(...)
    local dateTime = os.date("%H:%M:%S", os.time())
    local printMsg = "[\27[46m^0"..dateTime.." | "..Config.ResourceName.."\27[0m^0]"

    savePrint(printMsg, ...)
end

print = FN_HELPER.print

FN_HELPER.GetLanguage = function()
    local lang = FN_BRIDGE.Setting('language') or GetConvar('ox:locale', 'en')

    return tostring(lang):lower()
end

FN_HELPER.NumWithCommas = function(num)
    if not tonumber(num) then return num end

    return tostring(math.floor(num)):reverse():gsub("(%d%d%d)","%1,"):gsub(",(%-?)$","%1"):reverse()
end

FN_HELPER.SafeCall = function(func, ...)
    local status, result = pcall(func, ...)
    if not status then
        print('Error in SafeCall: \n', tostring(result))
        return nil
    end

    return result
end

FN_HELPER.SendLog = function(webhookUrl, playerIdOrTitle, content, scriptName)
    local _source = playerIdOrTitle
    if not _source or _source == 0 or not content then return print('Invalid parameters for SendLog') end
    scriptName = scriptName or (GetInvokingResource() or GetCurrentResourceName())
    local steamID, licenseID, discordID, playerName = 'Unknown', 'Unknown', 'Unknown', 'Unknown'

    if tonumber(_source) then
        playerName = GetPlayerName(_source) or 'Unknown'
        local identifiers = FN_HELPER.GetIdentifiers(_source)
        steamID = identifiers.steam and ('steam:'..identifiers.steam) or steamID
        licenseID = identifiers.license and ('license:'..identifiers.license) or licenseID
        discordID = identifiers.discord and ('discord:'..identifiers.discord) or discordID
    end

    return FN_LOG.Discord(webhookUrl, {
        title = FN_LOG.Cut((tonumber(_source) and ('Player: ['.._source..'] '..playerName..'\nSteam: '..steamID..'\nLicense: '..licenseID..'\nDiscord: '..discordID) or tostring(playerIdOrTitle)), 256),
        description = FN_LOG.Cut(content, 4000),
        color = 255,
        footer = { text = os.date("%Y/%m/%d %X")..' - https://fivenuts.dev/ - '..tostring(scriptName) },
    })
end

FN_HELPER.NormalizeGroups = function(groups)
    if type(groups) ~= 'table' then return nil end

    local allowed = {}
    for key, value in pairs(groups) do
        if type(key) == 'number' then
            if type(value) == 'string' then allowed[value] = true end
        elseif value then
            allowed[key] = true
        end
    end

    return next(allowed) and allowed or nil
end

FN_HELPER.IsAdmin = function(playerId)
    playerId = tonumber(playerId)
    if playerId == 0 then return true end
    if not playerId or playerId < 0 then return false end
    if IsPlayerAceAllowed(tostring(playerId), 'fn_bridge.admin') then return true end

    return FN_FRAMEWORK and FN_FRAMEWORK.CheckPermissions(playerId, FN_BRIDGE.Setting('admins') or Config.AdminGroups) == true or false
end

FN_HELPER.RegisterCommand = function(command, groups, callback, allowConsole, suggestions, deniedMessage)
    if type(command) ~= 'string' or command == '' then return print('RegisterCommand needs a command name.') end
    if not FN_BRIDGE.IsCallable(callback) then return print('RegisterCommand for /'..command..' needs a callback.') end

    local allowed = FN_HELPER.NormalizeGroups(type(groups) == 'string' and { groups } or groups)

    RegisterCommand(command, function(playerId, args, raw)
        playerId = tonumber(playerId) or 0

        if playerId == 0 then
            if not allowConsole then return print('/'..command..' cannot be run from the console.') end

            return FN_HELPER.SafeCall(callback, 0, args or {}, raw)
        end

        if groups and not (allowed and FN_FRAMEWORK and FN_FRAMEWORK.CheckPermissions(playerId, allowed)) then
            local denied = type(deniedMessage) == 'string' and deniedMessage ~= '' and deniedMessage or 'You are not allowed to use /'..command..'.'

            return FN_NOTIFY.Notify(playerId, denied, 'error')
        end

        FN_HELPER.SafeCall(callback, playerId, args or {}, raw)
    end, false)

    if type(suggestions) == 'table' then
        TriggerClientEvent('chat:addSuggestion', -1, '/'..command, suggestions.help or '', suggestions.params or {})
    end
end

local BanText = {
    ar = 'تم حظرك من هذا الخادم.',
    cs = 'Na tomto serveru jsi zabanován.',
    de = 'Du wurdest von diesem Server gebannt.',
    en = 'You have been banned from this server.',
    es = 'Has sido baneado de este servidor.',
    fr = 'Tu as été banni de ce serveur.',
    it = 'Sei stato bannato da questo server.',
    nl = 'Je bent verbannen van deze server.',
    pl = 'Zostałeś zbanowany na tym serwerze.',
    ['pt-br'] = 'Você foi banido deste servidor.',
    ro = 'Ai primit ban pe acest server.',
    tr = 'Bu sunucudan yasaklandın.',
}

FN_HELPER.BanRoute = function()
    local value = GetConvar('fn_bridge:ban', 'auto')
    if value == '' or value == 'auto' then return GetResourceState('APIAC') == 'started' and 'APIAC:banPlayer' or 'drop' end
    if value:match('^[%w_%-]+:[%w_]+$') then return value end

    return 'drop'
end

local function BanByExport(route, playerId, reason, details, duration)
    local resource, name = route:match('^(.-):(.+)$')
    if GetResourceState(resource) ~= 'started' then return false, resource..' is not started' end

    return pcall(function()
        local target = exports[resource]
        if route == 'APIAC:banPlayer' then return target[name](target, playerId, reason, details, duration) end

        return target[name](target, playerId, reason, details)
    end)
end

local function Evidence(playerId)
    local evidence = {}
    for key, value in pairs(FN_HELPER.GetIdentifiers(playerId)) do
        if key ~= 'ip' and key ~= 'license' then evidence[key] = value end
    end

    return evidence
end

local function Strings(list)
    local out = {}
    if type(list) ~= 'table' then return out end
    for _, value in ipairs(list) do
        if type(value) == 'string' and value ~= '' and #value <= 128 and #out < 64 then out[#out + 1] = value end
    end

    return out
end

local function BanOffline(resource, target, reason, details, encoded, duration)
    local license = type(target.license) == 'string' and target.license:match('^license:%x+$') or nil
    local entry = { license = license, identifiers = Strings(target.identifiers), tokens = Strings(target.tokens), name = type(target.name) == 'string' and target.name:sub(1, 64) or nil }
    if not license and #entry.identifiers + #entry.tokens == 0 then return false end

    local route, result = 'offline', nil
    local hook = FN_BRIDGE.Setting('banOffline', resource)
    if FN_BRIDGE.Callable(hook) then
        local ok, done = pcall(hook, entry, reason, details, duration)
        if not ok then print('^1banOffline hook failed, using the next ban route: '..tostring(done)..'^7') end
        if ok and done ~= nil and done ~= false then route, result = 'hook', done end
    end

    if route ~= 'hook' and FN_HELPER.BanRoute() == 'APIAC:banPlayer' then
        local by = type(details.by) == 'string' and details.by ~= '' and details.by:sub(1, 64) or resource
        local ok, id = pcall(function() return exports.APIAC:banIdentifiers(entry, reason, details, tonumber(duration), by) end)
        if ok and id then route, result = 'APIAC:banIdentifiers', id else print('^1APIAC:banIdentifiers failed, the offline ban is only logged: '..tostring(id)..'^7') end
    end

    if route == 'offline' then print(('^3BanPlayer from %s: no ban route takes offline players, the ban is only logged^7'):format(resource)) end
    FN_LOG.Write(resource, 'anticheat', 'player.ban', nil, { reason = reason, details = encoded, route = route, result = result ~= nil and tostring(result) or nil, duration = tonumber(duration), offline = true, identifiers = #entry.identifiers, tokens = #entry.tokens }, { license = license, name = entry.name })

    if route == 'offline' then return false end

    return route, result
end

FN_HELPER.BanPlayer = function(playerId, reason, details, duration)
    local resource = GetInvokingResource() or GetCurrentResourceName()
    local offline = type(playerId) == 'table' and playerId or nil
    if not offline then
        playerId = tonumber(playerId)
        if not playerId or playerId <= 0 then return false end
    end

    reason = type(reason) == 'string' and reason ~= '' and reason or 'banned by '..resource
    if details ~= nil and type(details) ~= 'table' then details = { info = tostring(details) } end
    details = details or {}
    local encodedOk, encoded = pcall(json.encode, details)
    encoded = encodedOk and encoded or tostring(details)

    if offline then return BanOffline(resource, offline, reason, details, encoded, duration) end

    if not GetPlayerName(playerId) then
        print(('^3BanPlayer from %s: player %s is no longer on the server, the ban is only logged^7'):format(resource, playerId))
        FN_LOG.Write(resource, 'anticheat', 'player.ban', playerId, { reason = reason, details = encoded, route = 'offline', duration = tonumber(duration) }, FN_LOG.Gone(playerId) or { serverId = playerId })

        return false
    end

    local identity, evidence = FN_LOG.Identity(playerId), Evidence(playerId)
    local route, result = 'drop', nil

    local hook = FN_BRIDGE.Setting('ban', resource)
    if FN_BRIDGE.Callable(hook) then
        local ok, done = pcall(hook, playerId, reason, details, duration)
        if not ok then print('^1ban hook failed, using the next ban route: '..tostring(done)..'^7') end
        if ok and done ~= nil and done ~= false then route, result = 'hook', done end
    end

    if route ~= 'hook' then
        local configured = FN_HELPER.BanRoute()
        if configured ~= 'drop' then
            local ok, done = BanByExport(configured, playerId, reason, details, duration)
            if ok and done ~= false then route, result = configured, done else print('^1ban export '..configured..' failed, the player is only dropped: '..tostring(done)..'^7') end
        end
    end

    if route == 'drop' then
        local lang = FN_HELPER.GetLanguage()
        DropPlayer(tostring(playerId), BanText[lang] or BanText[lang:sub(1, 2)] or BanText.en)
        print(('^3Player %s was dropped by BanPlayer from %s (%s). Set fn_bridge:ban to a ban resource for a real ban.^7'):format(playerId, resource, reason))
    end

    evidence.reason = reason
    evidence.details = encoded
    evidence.route = route
    evidence.result = result ~= nil and tostring(result) or nil
    evidence.duration = tonumber(duration)
    FN_LOG.Write(resource, 'anticheat', 'player.ban', playerId, evidence, identity)

    return route
end

FN_HELPER.GetNetIdFromEntity = function(entity, timeout)
    if type(entity) ~= 'number' or entity == 0 then return false end

    local deadline = GetGameTimer() + (tonumber(timeout) or 1000)
    repeat
        if DoesEntityExist(entity) then
            local netId = NetworkGetNetworkIdFromEntity(entity)
            if netId and netId ~= 0 then return netId end
        end
        Wait(50)
    until GetGameTimer() >= deadline

    return false
end

FN_HELPER.GetEntityFromNetId = function(netId, timeout)
    netId = tonumber(netId)
    if not netId or netId == 0 then return false end

    local deadline = GetGameTimer() + (tonumber(timeout) or 1000)
    repeat
        local entity = NetworkGetEntityFromNetworkId(netId)
        if entity and entity ~= 0 and DoesEntityExist(entity) then return entity end
        Wait(50)
    until GetGameTimer() >= deadline

    return false
end

FN_HELPER.SetPlayerBucket = function(playerId, bucket)
    SetPlayerRoutingBucket(playerId, bucket)
end

local Reported = {}

RegisterNetEvent('fn_bridge/server/banPlayer', function(reason)
    local playerId = source
    if not playerId or playerId == 0 or Reported[playerId] then return end

    Reported[playerId] = true
    FN_HELPER.BanPlayer(playerId, 'spoofed a net event guarded by fn_bridge ('..FN_LOG.Cut(reason, 64)..')')
end)

AddEventHandler('playerDropped', function() Reported[source] = nil end)

FN_HELPER.GetFuel = function(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return nil end

    local hook = FN_BRIDGE.Setting('fuel')
    if FN_BRIDGE.Callable(hook) then
        local ok, level = pcall(hook, vehicle)
        if ok and tonumber(level) then return tonumber(level) end
    end

    local bag = Entity(vehicle).state.fuel

    return type(bag) == 'number' and bag or nil
end

FN_HELPER.GetIdentifiers = function(playerId)
    local identifiers = {}
    for _, v in ipairs(GetPlayerIdentifiers(playerId)) do
        local idType, idValue = v:match("([^:]+):(.+)")
        if idType and idValue then
            identifiers[idType] = idValue
        end
    end
    return identifiers
end

FN_HELPER.GetPlayer = function(playerId)
    return FN_HELPER.Players[tonumber(playerId)]
end

local function AddPlayer(playerId)
    playerId = tonumber(playerId)
    FN_HELPER.Players[playerId] = {
        id = playerId,
        name = GetPlayerName(playerId),
        identifiers = FN_HELPER.GetIdentifiers(playerId),
    }
end

CreateThread(function()
    while not FN_FRAMEWORK do Wait(100) end

    for _, playerId in ipairs(GetPlayers()) do
        AddPlayer(playerId)
    end
end)

AddEventHandler('fn_bridge/server/playerLoaded', AddPlayer)

AddEventHandler('playerDropped', function()
    FN_HELPER.Players[source] = nil
end)

exports('GetPlayer', FN_HELPER.GetPlayer)
