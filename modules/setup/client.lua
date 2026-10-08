if not Config.Setup or not Config.Setup.command then return end

local Setup = {
    active = false,
    mode = 'point',
    heading = 0.0,
    preview = nil,
    modes = { 'point', 'ped', 'prop' },
    controls = { 21, 38, 47, 241, 242, 194 },
}

Setup.Round = function(value)
    return math.floor((tonumber(value) or 0.0) * 100 + 0.5) / 100
end

Setup.NextMode = function()
    for index, mode in ipairs(Setup.modes) do
        if mode == Setup.mode then return Setup.modes[index + 1] or Setup.modes[1] end
    end

    return Setup.modes[1]
end

Setup.ClearPreview = function()
    if not Setup.preview then return end
    if DoesEntityExist(Setup.preview) then DeleteEntity(Setup.preview) end

    Setup.preview = nil
end

Setup.LoadModel = function(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return false end

    RequestModel(hash)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(10) end
    if not HasModelLoaded(hash) then return false end

    return hash
end

Setup.SpawnPreview = function(coords)
    Setup.ClearPreview()
    if Setup.mode == 'point' then return end

    local requested = Setup.mode
    local hash = Setup.LoadModel(requested == 'ped' and Config.Setup.ped or Config.Setup.prop)
    if not hash then
        Setup.mode = 'point'
        return print('^3the '..requested..' model in Config.Setup could not be loaded^7 - /setup stayed in point mode.')
    end

    local entity = Setup.mode == 'ped'
        and CreatePed(4, hash, coords.x, coords.y, coords.z, Setup.heading, false, false)
        or CreateObject(hash, coords.x, coords.y, coords.z, false, false, false)

    SetEntityAlpha(entity, 180, false)
    SetEntityCollision(entity, false, false)
    FreezeEntityPosition(entity, true)
    SetEntityInvincible(entity, true)
    if Setup.mode == 'ped' then SetBlockingOfNonTemporaryEvents(entity, true) end
    SetModelAsNoLongerNeeded(hash)

    Setup.preview = entity
end

Setup.Aim = function()
    local hit, _, endCoords = lib.raycast.fromCamera(511, 4, Config.Setup.distance or 25.0)
    if hit and endCoords then return endCoords end

    local ped = PlayerPedId()

    return GetEntityCoords(ped) + (GetEntityForwardVector(ped) * 3.0)
end

Setup.Format = function(coords)
    local x, y, z = Setup.Round(coords.x), Setup.Round(coords.y), Setup.Round(coords.z)
    if Setup.mode == 'point' then return ('vector3(%s, %s, %s)'):format(x, y, z) end

    return ('vector4(%s, %s, %s, %s)'):format(x, y, z, Setup.Round(Setup.heading))
end

Setup.Instructions = function()
    return table.concat({
        'fn_bridge setup  |  mode: '..Setup.mode,
        '[E] copy   [G] mode   [scroll] rotate',
        '[shift + scroll] rotate fast   [backspace] exit',
    }, '  \n')
end

Setup.Stop = function()
    if not Setup.active then return end
    Setup.active = false
    Setup.ClearPreview()
    lib.hideTextUI()
end

Setup.Start = function()
    if Setup.active then return Setup.Stop() end

    Setup.active = true
    Setup.mode = 'point'
    Setup.heading = GetEntityHeading(PlayerPedId())
    lib.showTextUI(Setup.Instructions(), { position = 'left-center' })

    CreateThread(function()
        while Setup.active do
            for _, control in ipairs(Setup.controls) do
                DisableControlAction(0, control, true)
            end

            local coords = Setup.Aim()

            if Setup.mode == 'point' then
                DrawMarker(28, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.12, 0.12, 0.12, 255, 255, 255, 160, false, false, 2, false)
            elseif Setup.preview and DoesEntityExist(Setup.preview) then
                SetEntityCoordsNoOffset(Setup.preview, coords.x, coords.y, coords.z, false, false, false)
                SetEntityHeading(Setup.preview, Setup.heading)
            end

            local step = IsDisabledControlPressed(0, 21) and 22.5 or 5.0
            if IsDisabledControlJustPressed(0, 241) then Setup.heading = (Setup.heading + step) % 360.0 end
            if IsDisabledControlJustPressed(0, 242) then Setup.heading = (Setup.heading - step) % 360.0 end

            if IsDisabledControlJustReleased(0, 47) then
                Setup.mode = Setup.NextMode()
                Setup.SpawnPreview(coords)
                lib.showTextUI(Setup.Instructions(), { position = 'left-center' })
            end

            if IsDisabledControlJustReleased(0, 38) then
                local formatted = Setup.Format(coords)
                lib.setClipboard(formatted)
                FN_NOTIFY.Notify('Copied '..formatted..' to your clipboard.', 'success')
            end

            if IsDisabledControlJustReleased(0, 194) then Setup.Stop() end

            Wait(0)
        end
    end)
end

RegisterNetEvent('fn_bridge/client/setup', Setup.Start)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= Config.ResourceName then return end
    Setup.Stop()
end)

Config.DebugPrint('setup tool loaded: /'..tostring(Config.Setup.command)..' (client)')
