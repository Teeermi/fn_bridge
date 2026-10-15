FN_HELPER = {}

local savePrint = print
local allHandlers = {
    ['RegisterNetEvent'] = {},
    ['RegisterKey'] = {},
}
local keyCommands = {}

FN_HELPER.GetLanguage = function()
    local lang = FN_BRIDGE.Setting('language') or GetConvar('ox:locale', 'en')

    return tostring(lang):lower()
end

FN_HELPER.GetTimeInFormat = function(sec)
    local year, month, day, hour, minute, second = GetLocalTime()
    local formattedTime = string.format("%02d:%02d", hour, minute)
    if sec then
        formattedTime = string.format("%02d:%02d:%02d", hour, minute, second)
    end

    return formattedTime
end

FN_HELPER.print = function(...)
    local dateTime = FN_HELPER.GetTimeInFormat(true)
    local printMsg = "^0[^3"..dateTime.." ^0| ^5"..Config.ResourceName.."^0]"

    savePrint(printMsg, ...)
end

print = FN_HELPER.print

FN_HELPER.NumWithCommas = function(num)
    if not tonumber(num) then return num end

    return tostring(math.floor(num)):reverse():gsub("(%d%d%d)","%1,"):gsub(",(%-?)$","%1"):reverse()
end

FN_HELPER.SafeCall = function(func, ...)
    local status, result = pcall(func, ...)
    if not status then
        print('Error in SafeCall: ', tostring(result))
        return nil
    end

    return result
end

FN_HELPER.GetNetIdFromEntity = function(entity, timeout)
    if type(entity) ~= 'number' or entity == 0 then return false end

    local deadline = GetGameTimer() + (tonumber(timeout) or 1000)
    repeat
        if DoesEntityExist(entity) then
            if not NetworkGetEntityIsNetworked(entity) then NetworkRegisterEntityAsNetworked(entity) end

            local netId = NetworkGetNetworkIdFromEntity(entity)
            if netId and netId ~= 0 then
                SetNetworkIdExistsOnAllMachines(netId, true)

                return netId
            end
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
        if NetworkDoesNetworkIdExist(netId) then
            local entity = NetworkGetEntityFromNetworkId(netId)
            if entity and entity ~= 0 and DoesEntityExist(entity) then return entity end
        end
        Wait(50)
    until GetGameTimer() >= deadline

    return false
end

FN_HELPER.RegisterNetEvent = function(eventName, cb, safeEvent)
    local getResource = GetInvokingResource() or Config.ResourceName
    if not allHandlers['RegisterNetEvent'][getResource] then allHandlers['RegisterNetEvent'][getResource] = {} end

    local handlers = allHandlers['RegisterNetEvent'][getResource]
    handlers[#handlers + 1] = RegisterNetEvent(eventName, function(...)
        if safeEvent then local invokingResource = GetInvokingResource() if invokingResource then return TriggerServerEvent('fn_bridge/server/banPlayer', 1) end end
        FN_HELPER.SafeCall(cb, ...)
    end)
end

FN_HELPER.RegisterKey = function(key, command, description, cb)
    local getResource = GetInvokingResource() or Config.ResourceName
    if not key or not command or not description or not cb then return print('RegisterKey missing parameters.') end
    if not allHandlers['RegisterKey'][getResource] then allHandlers['RegisterKey'][getResource] = {} end
    if allHandlers['RegisterKey'][getResource][command] then
        allHandlers['RegisterKey'][getResource][command] = cb
        return print('RegisterKey ' .. command .. ' already registered.')
    end

    allHandlers['RegisterKey'][getResource][command] = cb
    if keyCommands[getResource..'.'..command] then return end
    keyCommands[getResource..'.'..command] = true

    local newCommand = '.'..math.random(111111, 999999)..'.'..getResource..'.'..command
    RegisterCommand(newCommand, function()
        if GetResourceState(getResource) ~= 'started' then return end
        if not allHandlers['RegisterKey'][getResource] or not allHandlers['RegisterKey'][getResource][command] then return end
        FN_HELPER.SafeCall(allHandlers['RegisterKey'][getResource][command])
    end, false)

    RegisterKeyMapping(newCommand, description, 'KEYBOARD', key)

    CreateThread(function()
        Wait(500)
        TriggerEvent("chat:removeSuggestion", newCommand)
        if true then return end
    end)
end

local Seatbelts = {
    { resource = 'qbx_seatbelt', get = function() return LocalPlayer.state.seatbelt == true or LocalPlayer.state.harness == true end },
    { resource = 'qb-smallresources', get = function() return exports['qb-smallresources']:HasSeatbeltOn() == true or exports['qb-smallresources']:HasHarness() == true end },
    { resource = 'esx_cruisecontrol', get = function() return exports.esx_cruisecontrol:isSeatbeltOn() == true end },
}

FN_HELPER.Seatbelt = function()
    local hook = FN_BRIDGE.Setting('seatbelt')
    if FN_BRIDGE.Callable(hook) then
        local ok, on = pcall(hook)
        if ok and type(on) == 'boolean' then return on end
    end

    for _, source in ipairs(Seatbelts) do
        if GetResourceState(source.resource) == 'started' then
            local ok, on = pcall(source.get)
            if ok then return on end
        end
    end

    local bag = LocalPlayer.state.seatbelt
    if type(bag) == 'boolean' then return bag end

    return nil
end

local Fuels = { 'LegacyFuel', 'cdn-fuel', 'ps-fuel', 'lj-fuel', 'okokGasStation', 'ti_fuel', 'x-fuel' }

for _, resource in ipairs(Fuels) do FN_KNOWN[resource] = true end

FN_HELPER.GetFuel = function(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return nil end

    local hook = FN_BRIDGE.Setting('fuel')
    if FN_BRIDGE.Callable(hook) then
        local ok, level = pcall(hook, vehicle)
        if ok and tonumber(level) then return tonumber(level) end
    end

    local bag = Entity(vehicle).state.fuel
    if type(bag) == 'number' then return bag end

    for _, resource in ipairs(Fuels) do
        if GetResourceState(resource) == 'started' then
            local fuel = exports[resource]
            for _, name in ipairs({ 'GetFuel', 'getFuel' }) do
                local ok, level = pcall(function() return fuel[name](fuel, vehicle) end)
                if ok and type(level) == 'number' then return level end
            end
            break
        end
    end

    return GetVehicleFuelLevel(vehicle)
end

local postals

FN_HELPER.Postal = function(coords)
    if postals == nil then
        postals = false
        local resource = Config.Postal
        if resource and GetResourceState(resource) == 'started' then
            local file = GetResourceMetadata(resource, 'postal_file', 0) or 'new-postals.json'
            local ok, list = pcall(json.decode, LoadResourceFile(resource, file) or '')
            if ok and type(list) == 'table' and #list > 0 then postals = list end
        end
    end
    if not postals or not coords then return nil end

    local best, bestDistance
    for _, postal in ipairs(postals) do
        local x, y = tonumber(postal.x), tonumber(postal.y)
        if x and y then
            local distance = (coords.x - x) ^ 2 + (coords.y - y) ^ 2
            if not bestDistance or distance < bestDistance then best, bestDistance = postal, distance end
        end
    end

    return best and best.code ~= nil and tostring(best.code) or nil
end

AddEventHandler('onResourceStop', function(resourceName)
    if allHandlers['RegisterNetEvent'][resourceName] then
        for _, handler in pairs(allHandlers['RegisterNetEvent'][resourceName]) do RemoveEventHandler(handler) end
        allHandlers['RegisterNetEvent'][resourceName] = nil
    end

    if allHandlers['RegisterKey'][resourceName] then
        allHandlers['RegisterKey'][resourceName] = nil
    end
end)
