local Relay = { ['pickle_prisons:jailPlayer'] = true }

RegisterNetEvent('fn_bridge:jail', function(event, ...)
    if Relay[event] then TriggerServerEvent(event, ...) end
end)
