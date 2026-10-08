FN_KEYS = {}

local function Model(vehicle)
    return GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)):lower()
end

local Give = {
    { 'qs-vehiclekeys', function(vehicle, plate) exports['qs-vehiclekeys']:GiveKeys(plate, Model(vehicle), true) end },
    { 'Renewed-Vehiclekeys', function(_, plate) exports['Renewed-Vehiclekeys']:addKey(plate) end },
    { 'MrNewbVehicleKeys', function(_, plate) exports.MrNewbVehicleKeys:GiveKeysByPlate(plate) end },
    { 'wasabi_carlock', function(_, plate) exports.wasabi_carlock:GiveKey(plate) end },
    { 'mk_vehiclekeys', function(vehicle) exports.mk_vehiclekeys:AddKey(vehicle) end },
    { 't1ger_keys', function(vehicle, plate) exports.t1ger_keys:GiveTemporaryKeys(plate, Model(vehicle), '') end },
    { 'ak47_vehiclekeys', function(_, plate) exports.ak47_vehiclekeys:GiveKey(plate, false) end },
    { 'cd_garage', function(_, plate) TriggerEvent('cd_garage:AddKeys', plate) end },
    { 'vehicles_keys', function(_, plate) TriggerServerEvent('vehicles_keys:selfGiveVehicleKeys', plate) end },
    { 'okokGarage', function(_, plate) TriggerServerEvent('okokGarage:GiveKeys', plate) end },
    { 'F_RealCarKeysSystem', function(_, plate) TriggerServerEvent('F_RealCarKeysSystem:generateVehicleKeys', plate) end },
    { 'mVehicle', function(vehicle) exports.mVehicle:AddTemporalVehicleClient(vehicle) end },
    { 'qb-vehiclekeys', function(_, plate) TriggerEvent('vehiclekeys:client:SetOwner', plate) end },
}

local Remove = {
    { 'qs-vehiclekeys', function(vehicle, plate) exports['qs-vehiclekeys']:RemoveKeys(plate, Model(vehicle)) end },
    { 'Renewed-Vehiclekeys', function(_, plate) exports['Renewed-Vehiclekeys']:removeKey(plate) end },
    { 'MrNewbVehicleKeys', function(_, plate) exports.MrNewbVehicleKeys:RemoveKeysByPlate(plate) end },
    { 'wasabi_carlock', function(_, plate) exports.wasabi_carlock:RemoveKey(plate) end },
    { 'mk_vehiclekeys', function(vehicle) exports.mk_vehiclekeys:RemoveKey(vehicle) end },
    { 'cd_garage', function(_, plate) TriggerEvent('cd_garage:RemoveKeys', plate) end },
}

local function Run(list, vehicle, plate)
    if not vehicle or not DoesEntityExist(vehicle) then return false end

    plate = type(plate) == 'string' and plate or GetVehicleNumberPlateText(vehicle)
    for _, entry in ipairs(list) do
        if GetResourceState(entry[1]) == 'started' then
            pcall(entry[2], vehicle, plate)
            return entry[1]
        end
    end

    return false
end

FN_KEYS.Give = function(vehicle, plate)
    if GetResourceState('qbx_vehiclekeys') == 'started' then return 'qbx_vehiclekeys' end

    return Run(Give, vehicle, plate)
end

FN_KEYS.Remove = function(vehicle, plate)
    return Run(Remove, vehicle, plate)
end

local function Vehicle(netId)
    local deadline = GetGameTimer() + 3000
    while not NetworkDoesEntityExistWithNetworkId(netId) and GetGameTimer() < deadline do Wait(50) end

    local vehicle = NetworkDoesEntityExistWithNetworkId(netId) and NetToVeh(netId)

    return vehicle and vehicle ~= 0 and vehicle or nil
end

RegisterNetEvent('fn_bridge/client/giveKeys', function(netId, plate)
    FN_KEYS.Give(Vehicle(netId), plate)
end)

RegisterNetEvent('fn_bridge/client/removeKeys', function(netId, plate)
    FN_KEYS.Remove(Vehicle(netId), plate)
end)
