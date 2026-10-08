FN_PICKER = {}

local State = {
    active = false,
    mode = 'point',
    coords = nil,
    heading = 0.0,
    zOffset = 0.0,
    size = nil,
    axis = 1,
    entity = nil,
    preview = nil,
    previewHash = nil,
    outlined = nil,
    owner = nil,
}

local Axes = { 'x', 'y', 'z' }

local Edges = {
    { 1, 2 }, { 2, 3 }, { 3, 4 }, { 4, 1 },
    { 5, 6 }, { 6, 7 }, { 7, 8 }, { 8, 5 },
    { 1, 5 }, { 2, 6 }, { 3, 7 }, { 4, 8 },
}

local function Settings()
    return Config.Picker or {}
end

local function KeyFor(options, name)
    local overrides = options.keys
    if overrides and overrides[name] then return overrides[name] end

    return (Settings().keys or {})[name] or 0
end

local function Round(value, precision)
    local factor = 10 ^ (tonumber(precision) or 3)

    return math.floor((tonumber(value) or 0.0) * factor + 0.5) / factor
end

local function CameraForward()
    local rot = GetFinalRenderedCamRot(2)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local flat = math.abs(math.cos(rx))

    return vector3(-math.sin(rz) * flat, math.cos(rz) * flat, math.sin(rx))
end

local function Aim(options)
    local distance = tonumber(options.distance) or Settings().distance or 25.0
    local hit, entity, endCoords = lib.raycast.fromCamera(tonumber(options.flags) or 511, 4, distance)

    if hit and endCoords and endCoords.x then return endCoords, entity end

    return GetFinalRenderedCamCoord() + (CameraForward() * distance), nil
end

local function ClearPreview()
    if State.preview and DoesEntityExist(State.preview) then
        SetEntityAsMissionEntity(State.preview, true, true)
        DeleteEntity(State.preview)
    end

    if State.previewHash then SetModelAsNoLongerNeeded(State.previewHash) end

    State.preview = nil
    State.previewHash = nil
end

local function ClearOutline()
    if State.outlined and DoesEntityExist(State.outlined) then
        SetEntityDrawOutline(State.outlined, false)
    end

    State.outlined = nil
end

local function LoadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return false end

    RequestModel(hash)

    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(10) end
    if not HasModelLoaded(hash) then return false end

    return hash
end

local function SpawnPreview(options, coords)
    local hash = LoadModel(options.model)
    if not hash then return false end

    local entity = options.entityType == 'ped'
        and CreatePed(4, hash, coords.x, coords.y, coords.z, State.heading, false, false)
        or CreateObjectNoOffset(hash, coords.x, coords.y, coords.z, false, false, false)

    SetEntityAlpha(entity, 180, false)
    SetEntityCollision(entity, false, false)
    FreezeEntityPosition(entity, true)
    SetEntityInvincible(entity, true)
    SetEntityAsMissionEntity(entity, true, true)
    if options.entityType == 'ped' then SetBlockingOfNonTemporaryEvents(entity, true) end

    State.preview = entity
    State.previewHash = hash

    return true
end

local function DrawBox(center, size, heading, colour)
    local rad = math.rad(heading or 0.0)
    local cos, sin = math.cos(rad), math.sin(rad)
    local hx, hy, hz = size.x * 0.5, size.y * 0.5, size.z * 0.5
    local offsets = {
        { -hx, -hy, -hz }, { hx, -hy, -hz }, { hx, hy, -hz }, { -hx, hy, -hz },
        { -hx, -hy, hz }, { hx, -hy, hz }, { hx, hy, hz }, { -hx, hy, hz },
    }
    local corners = {}

    for index, offset in ipairs(offsets) do
        corners[index] = vector3(
            center.x + (offset[1] * cos - offset[2] * sin),
            center.y + (offset[1] * sin + offset[2] * cos),
            center.z + offset[3]
        )
    end

    for _, edge in ipairs(Edges) do
        local a, b = corners[edge[1]], corners[edge[2]]
        DrawLine(a.x, a.y, a.z, b.x, b.y, b.z, colour[1], colour[2], colour[3], 220)
    end
end

local function ControlsFor(options)
    local used = { 21, 38, 45, 47, 172, 173, 174, 175, 177, 241, 242 }

    if type(options.disableControls) == 'table' then
        for _, control in ipairs(options.disableControls) do used[#used + 1] = control end
    end

    return used
end

local function Result(options)
    local precision = tonumber(options.precision) or Settings().precision or 3
    local result = {
        x = Round(State.coords.x, precision),
        y = Round(State.coords.y, precision),
        z = Round(State.coords.z, precision),
    }

    if options.heading then result.w = Round(State.heading, 2) end
    if options.zOffset then result.zOffset = Round(State.zOffset, precision) end

    if State.size then
        result.size = {
            x = Round(State.size.x, 2),
            y = Round(State.size.y, 2),
            z = Round(State.size.z, 2),
        }
    end

    if State.entity and DoesEntityExist(State.entity) then
        result.entity = State.entity
        result.model = GetEntityModel(State.entity)
    end

    result.coords = vector3(result.x, result.y, result.z)

    return result
end

local function Finish(options, cb, result)
    State.active = false
    ClearPreview()
    ClearOutline()

    if options.hint then FN_NOTIFY.HideHelpText() end
    if cb then FN_HELPER.SafeCall(cb, result) end
end

FN_PICKER.IsActive = function()
    return State.active
end

FN_PICKER.Stop = function()
    if not State.active then return false end

    State.active = false

    return true
end

FN_PICKER.Start = function(options, cb)
    if State.active then return false end
    if type(options) ~= 'table' then options = {} end

    local mode = options.mode or 'point'
    local settings = Settings()

    State.active = true
    State.owner = GetInvokingResource() or Config.ResourceName
    State.mode = mode
    State.heading = tonumber(options.startHeading) or GetEntityHeading(GlobalState.fn_playerPed or PlayerPedId())
    State.zOffset = 0.0
    State.entity = nil
    State.axis = 1
    State.size = nil
    State.coords = Aim(options)

    if mode == 'box' then
        local size = options.size or {}
        State.size = {
            x = tonumber(size.x) or 2.0,
            y = tonumber(size.y) or 2.0,
            z = tonumber(size.z) or 2.0,
        }
    end

    if mode == 'model' and not SpawnPreview(options, State.coords) then
        State.active = false
        print('^3the picker could not load the preview model^7 - '..tostring(options.model))

        return false
    end

    if options.hint then FN_NOTIFY.ShowHelpText(options.hint, options.hintPosition or 'left-center') end

    local controls = ControlsFor(options)
    local colour = options.colour or { 233, 233, 236 }

    CreateThread(function()
        local lastFrame = GetGameTimer()

        while State.active do
            local now = GetGameTimer()
            local dt = (now - lastFrame) / 1000.0
            lastFrame = now

            for _, control in ipairs(controls) do DisableControlAction(0, control, true) end

            local aimed, entity = Aim(options)
            local fast = IsDisabledControlPressed(0, KeyFor(options, 'fast'))

            if options.heading then
                local step = fast
                    and (tonumber(options.headingStepFast) or settings.headingStepFast or 22.5)
                    or (tonumber(options.headingStep) or settings.headingStep or 5.0)

                if IsDisabledControlJustPressed(0, KeyFor(options, 'rotateRight')) then
                    State.heading = (State.heading + step) % 360.0
                elseif IsDisabledControlJustPressed(0, KeyFor(options, 'rotateLeft')) then
                    State.heading = (State.heading - step) % 360.0
                end
            end

            if options.zOffset then
                local speed = fast
                    and (tonumber(options.zSpeedFast) or settings.zSpeedFast or 2.0)
                    or (tonumber(options.zSpeed) or settings.zSpeed or 0.5)

                if IsDisabledControlPressed(0, KeyFor(options, 'zUp')) then
                    State.zOffset = State.zOffset + speed * dt
                elseif IsDisabledControlPressed(0, KeyFor(options, 'zDown')) then
                    State.zOffset = State.zOffset - speed * dt
                end

                if IsDisabledControlJustPressed(0, KeyFor(options, 'resetZ')) then State.zOffset = 0.0 end
            end

            if State.size and options.resize then
                local step = (tonumber(options.sizeStep) or settings.sizeStep or 0.25) * (fast and 4 or 1)

                if IsDisabledControlJustPressed(0, KeyFor(options, 'axis')) then
                    State.axis = State.axis % #Axes + 1
                elseif IsDisabledControlJustPressed(0, KeyFor(options, 'sizeGrow')) then
                    local axis = Axes[State.axis]
                    State.size[axis] = math.min(State.size[axis] + step, 50.0)
                elseif IsDisabledControlJustPressed(0, KeyFor(options, 'sizeShrink')) then
                    local axis = Axes[State.axis]
                    State.size[axis] = math.max(State.size[axis] - step, 0.25)
                end
            end

            State.coords = vector3(aimed.x, aimed.y, aimed.z + State.zOffset)

            if mode == 'entity' then
                local picked = entity and entity ~= 0 and DoesEntityExist(entity) and GetEntityType(entity) ~= 0 and entity or nil

                if picked and options.entityTypes then
                    local entityType = GetEntityType(picked)
                    local allowed = false

                    for _, wanted in ipairs(options.entityTypes) do
                        if entityType == wanted then
                            allowed = true

                            break
                        end
                    end

                    if not allowed then picked = nil end
                end

                if State.outlined ~= picked then
                    ClearOutline()

                    if picked and options.outline ~= false then
                        SetEntityDrawOutline(picked, true)
                        State.outlined = picked
                    end
                end

                State.entity = picked
            elseif mode == 'model' then
                if State.preview and DoesEntityExist(State.preview) then
                    SetEntityCoordsNoOffset(State.preview, State.coords.x, State.coords.y, State.coords.z, false, false, false)
                    SetEntityHeading(State.preview, State.heading)
                end
            elseif mode == 'box' then
                DrawBox(State.coords, State.size, State.heading, colour)
                DrawMarker(28, State.coords.x, State.coords.y, State.coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.08, 0.08, 0.08, colour[1], colour[2], colour[3], 200, false, false, 2, false)
            else
                DrawMarker(28, State.coords.x, State.coords.y, State.coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.12, 0.12, 0.12, colour[1], colour[2], colour[3], 180, false, false, 2, false)
            end

            if options.onTick then
                FN_HELPER.SafeCall(options.onTick, {
                    mode = mode,
                    coords = State.coords,
                    heading = State.heading,
                    zOffset = State.zOffset,
                    size = State.size,
                    entity = State.entity,
                    axis = Axes[State.axis],
                })
            end

            if IsDisabledControlJustPressed(0, KeyFor(options, 'confirm')) then
                if mode ~= 'entity' or State.entity then
                    return Finish(options, cb, Result(options))
                end

                if options.onInvalid then FN_HELPER.SafeCall(options.onInvalid) end
            elseif IsDisabledControlJustPressed(0, KeyFor(options, 'cancel')) then
                State.active = false
            end

            Wait(0)
        end

        Finish(options, cb, false)
    end)

    return true
end

FN_PICKER.Await = function(options)
    local done = promise.new()
    local started = FN_PICKER.Start(options, function(result)
        done:resolve(result)
    end)

    if not started then return false end

    return Citizen.Await(done)
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= Config.ResourceName and resourceName ~= State.owner then return end

    State.active = false
    ClearPreview()
    ClearOutline()
end)
