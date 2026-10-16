FN_KEYS = {}

local function NetId(vehicle)
    return vehicle and DoesEntityExist(vehicle) and NetworkGetNetworkIdFromEntity(vehicle) or nil
end

FN_KEYS.Give = function(playerId, vehicle, plate)
    if GetResourceState('qbx_vehiclekeys') == 'started' then
        return pcall(function() exports.qbx_vehiclekeys:GiveKeys(playerId, vehicle, true) end)
    end

    local netId = NetId(vehicle)
    if not netId then return false end

    TriggerClientEvent('fn_bridge/client/giveKeys', playerId, netId, plate)

    return true
end

FN_KEYS.SetLocked = function(vehicle, locked)
    if not vehicle or not DoesEntityExist(vehicle) then return false end

    SetVehicleDoorsLocked(vehicle, locked and 2 or 1)

    local owner = NetworkGetEntityOwner(vehicle)
    if owner and owner > 0 then TriggerClientEvent('fn_bridge/client/setLocked', owner, NetworkGetNetworkIdFromEntity(vehicle), locked == true) end

    return true
end

FN_KEYS.Remove = function(playerId, vehicle, plate)
    if GetResourceState('qbx_vehiclekeys') == 'started' then pcall(function() exports.qbx_vehiclekeys:RemoveKeys(playerId, vehicle) end) end
    if GetResourceState('qb-vehiclekeys') == 'started' then pcall(function() exports['qb-vehiclekeys']:RemoveKeys(playerId, plate) end) end

    local netId = NetId(vehicle)
    if netId then TriggerClientEvent('fn_bridge/client/removeKeys', playerId, netId, plate) end

    return true
end
