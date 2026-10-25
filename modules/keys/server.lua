FN_KEYS = {}

local Known = { 'qbx_vehiclekeys', 'qb-vehiclekeys', 'qs-vehiclekeys', 'Renewed-Vehiclekeys', 'MrNewbVehicleKeys', 'wasabi_carlock', 'mk_vehiclekeys', 't1ger_keys', 'ak47_vehiclekeys', 'vehicles_keys', 'F_RealCarKeysSystem', 'mVehicle', 'cd_garage', 'okokGarage' }

local function Garages()
    return GetResourceState('fn_garages') == 'started' and GetInvokingResource() ~= 'fn_garages'
end

FN_KEYS.Name = function()
    for _, resource in ipairs(Known) do
        if GetResourceState(resource) == 'started' then return resource end
    end
    return false
end

local function NetId(vehicle)
    return vehicle and DoesEntityExist(vehicle) and NetworkGetNetworkIdFromEntity(vehicle) or nil
end

FN_KEYS.Give = function(playerId, vehicle, plate)
    if Garages() then pcall(function() exports.fn_garages:GiveKey(playerId, vehicle) end) end
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
    if Garages() and pcall(function() exports.fn_garages:SetLocked(vehicle, locked == true) end) then return true end

    SetVehicleDoorsLocked(vehicle, locked and 2 or 1)

    local owner = NetworkGetEntityOwner(vehicle)
    if owner and owner > 0 then TriggerClientEvent('fn_bridge/client/setLocked', owner, NetworkGetNetworkIdFromEntity(vehicle), locked == true) end

    return true
end

FN_KEYS.Remove = function(playerId, vehicle, plate)
    if Garages() then pcall(function() exports.fn_garages:RemoveKey(playerId, vehicle) end) end
    if GetResourceState('qbx_vehiclekeys') == 'started' then pcall(function() exports.qbx_vehiclekeys:RemoveKeys(playerId, vehicle) end) end
    if GetResourceState('qb-vehiclekeys') == 'started' then pcall(function() exports['qb-vehiclekeys']:RemoveKeys(playerId, plate) end) end

    local netId = NetId(vehicle)
    if netId then TriggerClientEvent('fn_bridge/client/removeKeys', playerId, netId, plate) end

    return true
end
