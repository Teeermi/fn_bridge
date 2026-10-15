local ReadyTimeoutMs = 30000
local isReady = false
local Finish

exports('GetBridge', function()
    if not isReady and FN_FRAMEWORK and FN_HELPER then Finish() end
    if not isReady then return nil end

    return FN_BRIDGE
end)

exports('Provide', FN_BRIDGE.Provide)

FN_BRIDGE.IsReady = function()
    return isReady
end

local function ReportMissingFramework()
    if not FN_BRIDGE.frameworkName then
        print('^1no supported framework detected^7 - checked '..table.concat(FN_BRIDGE.FrameworkResources(), ', ')..'. Start fn_bridge after your framework, or force one with setr fn_bridge:framework in server.cfg.')
        return
    end

    print('^1the '..FN_BRIDGE.frameworkName..' adapter never finished loading^7 - fn_bridge is running without a framework and every fivenuts script will fail to start.')
end

local function ResolveInventory()
    if not FN_INVENTORY then return FN_BRIDGE.UnavailableNamespace('INVENTORY', 'no inventory adapter loaded', FN_BRIDGE.InventoryContract.client) end

    local adapterName = FN_BRIDGE.inventoryName or '_default'
    local missing = {}

    for _, key in ipairs(FN_BRIDGE.InventoryContract.client) do
        if type(FN_INVENTORY[key]) ~= 'function' then
            missing[#missing + 1] = key
            FN_INVENTORY[key] = FN_BRIDGE.UnsupportedFunction('INVENTORY', key, 'the '..adapterName..' adapter does not implement it')
        end
    end

    if #missing > 0 then
        print('^3the '..adapterName..' inventory adapter does not implement^7 '..table.concat(missing, ', ')..' - calling one logs and returns false instead of erroring.')
    end

    return FN_INVENTORY
end

local function ResolveTarget()
    if not FN_TARGET then
        return FN_BRIDGE.UnavailableNamespace('TARGET', 'no target resource detected - checked '..table.concat(FN_BRIDGE.TargetResources(), ', ')..', or check setr fn_bridge:target in server.cfg', FN_BRIDGE.TargetContract)
    end

    local adapterName = FN_BRIDGE.targetName
    local missing = {}

    for _, key in ipairs(FN_BRIDGE.TargetContract) do
        if type(FN_TARGET[key]) ~= 'function' then
            missing[#missing + 1] = key
            FN_TARGET[key] = FN_BRIDGE.UnsupportedFunction('TARGET', key, 'the '..adapterName..' adapter does not implement it')
        end
    end

    if #missing > 0 then
        print('^3the '..adapterName..' target adapter does not implement^7 '..table.concat(missing, ', ')..' - calling one logs and returns false instead of erroring.')
    end

    return FN_TARGET
end

Finish = function()
    if isReady then return true end

    FN_BRIDGE.FRAMEWORK = FN_FRAMEWORK
    FN_BRIDGE.INVENTORY = ResolveInventory()
    FN_BRIDGE.NOTIFY = FN_NOTIFY
    FN_BRIDGE.TARGET = ResolveTarget()
    FN_BRIDGE.HELPER = FN_HELPER
    FN_BRIDGE.PICKER = FN_PICKER
    FN_BRIDGE.SOCIETY = FN_BRIDGE.UnavailableNamespace('SOCIETY', 'server side only', FN_BRIDGE.SocietyContract)
    FN_BRIDGE.VEHICLES = FN_BRIDGE.UnavailableNamespace('VEHICLES', 'server side only', FN_BRIDGE.VehiclesContract)
    FN_BRIDGE.DISPATCH = FN_BRIDGE.UnavailableNamespace('DISPATCH', 'server side only', { 'Name', 'Send' })
    FN_BRIDGE.PHONE = FN_BRIDGE.UnavailableNamespace('PHONE', 'server side only', { 'Name', 'Supports', 'Number', 'Notify', 'Mail', 'Message', 'Numbers', 'NumberTaken', 'CanSetNumber', 'SetNumber' })
    FN_BRIDGE.MEDIA = FN_BRIDGE.UnavailableNamespace('MEDIA', 'server side only', { 'IsUrl', 'Capturer', 'Provider', 'Missing', 'Ready', 'Capture', 'Upload', 'Shot', 'Delete', 'Ticket' })
    FN_BRIDGE.KEYS = FN_KEYS
    FN_BRIDGE.DEATH = FN_DEATH
    FN_BRIDGE.VOICE = FN_VOICE
    for _, key in ipairs({ 'Mumble', 'SetCall', 'GetCall', 'MuteCall', 'CallMuted', 'RadioCount' }) do FN_VOICE[key] = FN_BRIDGE.UnsupportedFunction('VOICE', key, 'server side only') end
    FN_BRIDGE.PREFS = FN_PREFS
    FN_BRIDGE.HOUSING = FN_BRIDGE.UnavailableNamespace('HOUSING', 'server side only', { 'Running', 'List', 'IsLocked', 'SetLocked', 'ForSale', 'Starters', 'Resume', 'Prepare', 'Giver', 'Give' })
    FN_BRIDGE.CHARACTERS = FN_CHARACTERS or FN_BRIDGE.UnavailableNamespace('CHARACTERS', 'no framework adapter loaded', FN_BRIDGE.CharactersContract.client)
    FN_BRIDGE.APPEARANCE = FN_APPEARANCE
    for namespace, keys in pairs(FN_BRIDGE.ServerOnly) do FN_BRIDGE[namespace] = FN_BRIDGE.UnavailableNamespace(namespace, 'server side only', keys) end
    FN_BRIDGE.INTERACT = FN_INTERACT
    for _, key in ipairs({ 'Has', 'Do', 'Is' }) do FN_INTERACT[key] = FN_BRIDGE.UnsupportedFunction('INTERACT', key, 'server side only') end

    for _, namespace in ipairs({ 'FRAMEWORK', 'INVENTORY', 'NOTIFY', 'TARGET', 'HELPER', 'PICKER', 'KEYS', 'DEATH', 'VOICE', 'PREFS', 'CHARACTERS', 'APPEARANCE', 'INTERACT' }) do
        FN_BRIDGE.Overridable(namespace, FN_BRIDGE[namespace])
    end

    isReady = true
    CreateThread(function()
        FN_BRIDGE.PrintBanner({
            { 'framework', FN_BRIDGE.frameworkName, 'ok' },
            { 'inventory', FN_BRIDGE.inventoryName or 'framework inventory', FN_BRIDGE.inventoryName and 'ok' or 'fallback' },
            { 'target', FN_BRIDGE.targetName or 'none detected', FN_BRIDGE.targetName and 'ok' or 'fallback' },
            { 'notify', FN_BRIDGE.notifyName, 'ok' },
            { 'help text', FN_BRIDGE.helpTextName, 'ok' },
        })
    end)

    return true
end

local function FrameworkLoadedModule()
    local deadline = GetGameTimer() + ReadyTimeoutMs
    while (not FN_FRAMEWORK or not FN_HELPER) and GetGameTimer() < deadline do
        Wait(100)
    end

    if not FN_FRAMEWORK or not FN_HELPER then return ReportMissingFramework() end

    return Finish()
end

local function PedChangeModule()
    local triggerEntered = false
    local wasDead = false
    GlobalState.fn_playerPed = PlayerPedId()
    GlobalState.fn_playerId = PlayerId()
    GlobalState.fn_serverId = GetPlayerServerId(GlobalState.fn_playerId)
    GlobalState.fn_isDead = IsEntityDead(GlobalState.fn_playerPed)
    local vehicle = GetVehiclePedIsIn(GlobalState.fn_playerPed, false)
    GlobalState.fn_vehicle = vehicle ~= 0 and vehicle or false
    GlobalState.fn_vehicleDriver = GlobalState.fn_vehicle and GetPedInVehicleSeat(GlobalState.fn_vehicle, -1) == GlobalState.fn_playerPed or false
    GlobalState.fn_playerCoords = GetEntityCoords(GlobalState.fn_playerPed)
    GlobalState.fn_playerWeapon = GetSelectedPedWeapon(GlobalState.fn_playerPed)

    CreateThread(function()
        while true do
            Wait(250)
            local playerPed = PlayerPedId()
            if playerPed and GlobalState.fn_playerPed ~= playerPed then
                GlobalState.fn_playerPed = playerPed
            end

            local playerCoords = GetEntityCoords(playerPed)
            GlobalState.fn_playerCoords = playerCoords

            local playerWeapon = GetSelectedPedWeapon(playerPed)
            if playerWeapon ~= GlobalState.fn_playerWeapon then
                GlobalState.fn_playerWeapon = playerWeapon
            end

            if wasDead ~= GlobalState.fn_isDead then
                wasDead = GlobalState.fn_isDead
                TriggerEvent("fn_bridge/client/isDead", GlobalState.fn_isDead)
            end
        end
    end)

    AddEventHandler("gameEventTriggered", function(name, data)
        if name ~= "CEventNetworkPlayerEnteredVehicle" or triggerEntered then return end

        local pId = data[1]
        local playerVehicle = data[2]
        local playerPed = GlobalState.fn_playerPed

        if pId ~= GlobalState.fn_playerId or not playerVehicle or playerVehicle == 0 then return end
        while not IsPedInAnyVehicle(playerPed, false) do Wait(100) end

        local isDriver = GetPedInVehicleSeat(playerVehicle, -1) == playerPed

        GlobalState.fn_vehicle = playerVehicle
        GlobalState.fn_vehicleDriver = isDriver
        triggerEntered = true

        TriggerEvent('fn_bridge/client/onVehicleEnter', playerVehicle, isDriver)

        while (DoesEntityExist(playerVehicle) and GetVehiclePedIsIn(playerPed, false) == playerVehicle) do
            local currentDriver = GetPedInVehicleSeat(playerVehicle, -1) == playerPed
            if currentDriver ~= GlobalState.fn_vehicleDriver then
                GlobalState.fn_vehicleDriver = currentDriver
                TriggerEvent('fn_bridge/client/onVehicleEnter', playerVehicle, currentDriver)
            end
            Wait(250)
        end

        GlobalState.fn_vehicle = false
        GlobalState.fn_vehicleDriver = false
        triggerEntered = false

        TriggerEvent("fn_bridge/client/onVehicleLeave", playerVehicle, isDriver)
    end)
end

CreateThread(function()
    if not FrameworkLoadedModule() then return end
    PedChangeModule()
end)
