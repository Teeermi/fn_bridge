if not FN_BRIDGE.IsTarget('ox_target') then return end

local OX_TARGET = exports.ox_target

FN_TARGET = {
    zones = {},
}

FN_TARGET.FixOptions = function(options)
    for index, option in pairs(options) do
        local action = option.onSelect or option.action
        options[index].onSelect = function(entityOrData)
            if type(entityOrData) == 'table' then
                return action(entityOrData.entity)
            end

            return action(entityOrData)
        end
    end

    return options
end

FN_TARGET.TrackZone = function(name, id)
    FN_TARGET.zones[#FN_TARGET.zones + 1] = {
        name = name,
        id = id,
        creator = GetInvokingResource() or Config.ResourceName,
    }
end

FN_TARGET.DropZones = function(shouldDrop)
    for index = #FN_TARGET.zones, 1, -1 do
        local zone = FN_TARGET.zones[index]
        if shouldDrop(zone) then
            OX_TARGET:removeZone(zone.id)
            table.remove(FN_TARGET.zones, index)
        end
    end
end

local function Names(list)
    if list == nil then return nil end

    local names = {}
    for _, entry in pairs(type(list) == 'table' and list or { list }) do
        names[#names + 1] = type(entry) == 'table' and (entry.name or entry.label) or entry
    end

    return names
end

FN_TARGET.AddGlobalPed = function(options)
    OX_TARGET:addGlobalPed(FN_TARGET.FixOptions(options))
end

FN_TARGET.RemoveGlobalPed = function(options)
    OX_TARGET:removeGlobalPed(Names(options))
end

FN_TARGET.AddGlobalPlayer = function(options)
    OX_TARGET:addGlobalPlayer(FN_TARGET.FixOptions(options))
end

FN_TARGET.RemoveGlobalPlayer = function()
    OX_TARGET:removeGlobalPlayer()
end

FN_TARGET.AddGlobalVehicle = function(options)
    OX_TARGET:addGlobalVehicle(FN_TARGET.FixOptions(options))
end

FN_TARGET.RemoveGlobalVehicle = function(options)
    local names = {}
    for _, option in pairs(options) do
        names[#names + 1] = option.name or option.label
    end

    OX_TARGET:removeGlobalVehicle(names)
end

FN_TARGET.AddLocalEntity = function(entities, options)
    OX_TARGET:addLocalEntity(entities, FN_TARGET.FixOptions(options))
end

FN_TARGET.RemoveLocalEntity = function(entity, options)
    OX_TARGET:removeLocalEntity(entity, Names(options))
end

FN_TARGET.AddModel = function(models, options)
    OX_TARGET:addModel(models, FN_TARGET.FixOptions(options))
end

FN_TARGET.RemoveModel = function(model, options)
    OX_TARGET:removeModel(model, Names(options))
end

FN_TARGET.AddBoxZone = function(name, coords, size, heading, options)
    local id = OX_TARGET:addBoxZone({
        name = name,
        coords = coords,
        size = size,
        rotation = heading,
        debug = Config.Debug,
        options = FN_TARGET.FixOptions(options),
    })

    FN_TARGET.TrackZone(name, id)

    return id
end

FN_TARGET.AddSphereZone = function(name, coords, radius, options)
    local id = OX_TARGET:addSphereZone({
        name = name,
        coords = coords,
        radius = radius,
        debug = Config.Debug,
        options = FN_TARGET.FixOptions(options),
    })

    FN_TARGET.TrackZone(name, id)

    return id
end

FN_TARGET.RemoveZone = function(name)
    if not name then return end

    FN_TARGET.DropZones(function(zone)
        return zone.name == name
    end)
end

FN_TARGET.DisableTargeting = function(bool)
    OX_TARGET:disableTargeting(bool)
end

AddEventHandler('onResourceStop', function(stoppedResource)
    local isSelf = stoppedResource == Config.ResourceName

    FN_TARGET.DropZones(function(zone)
        return isSelf or zone.creator == stoppedResource
    end)
end)

Config.DebugPrint('target adapter loaded: ox_target (client)')
