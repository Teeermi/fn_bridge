FN_HELPER = {
    Players = {}
}

for _, resource in ipairs({ 'LegacyFuel', 'cdn-fuel', 'ps-fuel', 'lj-fuel', 'okokGasStation', 'ti_fuel', 'x-fuel', 'ox_fuel', 'qbx_seatbelt', 'qb-smallresources', 'esx_cruisecontrol' }) do FN_KNOWN[resource] = true end

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
        for k, v in ipairs(GetPlayerIdentifiers(_source)) do
            if string.sub(v, 1, string.len("steam:")) == "steam:" then
                steamID = v
            elseif string.sub(v, 1, string.len("license:")) == "license:" then
                licenseID = v
            elseif string.sub(v, 1, string.len("discord:")) == "discord:" then
                discordID = v
            end
        end
    end

    local EmbedData = {
        {
            ['title'] = tonumber(_source) and ('Player: ['.._source..'] '..playerName..'\nSteam: '..steamID..'\nLicense: '..licenseID..'\nDiscord: '..discordID) or playerIdOrTitle,
            ['description'] = content,
            ['color'] = '255',
            ['footer'] = {
                ['text'] = os.date("%Y/%m/%d %X")..' - https://fivenuts.dev/ - '..scriptName,
            },
        }
    }

    PerformHttpRequest(webhookUrl, nil, 'POST', json.encode({embeds = EmbedData}), {['Content-Type'] = 'application/json'})
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

    local allowed = FN_HELPER.NormalizeGroups(groups)

    RegisterCommand(command, function(playerId, args, raw)
        playerId = tonumber(playerId) or 0

        if playerId == 0 then
            if not allowConsole then return print('/'..command..' cannot be run from the console.') end

            return FN_HELPER.SafeCall(callback, 0, args or {}, raw)
        end

        if allowed and not (FN_FRAMEWORK and FN_FRAMEWORK.CheckPermissions(playerId, allowed)) then
            local denied = type(deniedMessage) == 'string' and deniedMessage ~= '' and deniedMessage or 'You are not allowed to use /'..command..'.'

            return FN_NOTIFY.Notify(playerId, denied, 'error')
        end

        FN_HELPER.SafeCall(callback, playerId, args or {}, raw)
    end, false)

    if type(suggestions) == 'table' then
        TriggerClientEvent('chat:addSuggestion', -1, '/'..command, suggestions.help or '', suggestions.params or {})
    end
end

FN_HELPER.BanPlayer = function(playerId, reason)
    local webhook = FN_BRIDGE.Setting('banWebhook')
    if type(webhook) ~= 'string' or webhook == '' then return print('BanPlayer called for '..tostring(playerId)..' ('..tostring(reason)..') but Config.Bridge.banWebhook is empty in '..tostring(GetInvokingResource())..', nothing was logged.') end

    FN_HELPER.SendLog(webhook, playerId, 'Player has been banned for: '..reason)
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

RegisterNetEvent('fn_bridge/server/banPlayer', function(reason)
    local playerId = source
    if not playerId or playerId == 0 then return end

    FN_HELPER.BanPlayer(playerId, 'spoofed a net event guarded by fn_bridge ('..tostring(reason)..')')
end)

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
