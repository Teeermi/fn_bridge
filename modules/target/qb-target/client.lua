if not FN_BRIDGE.IsTarget('qb-target') then return end

local QB_TARGET = exports['qb-target']

FN_TARGET = {
    zones = {},
    globalPlayerLabels = {},
    labels = {},
}

FN_TARGET.FixOptions = function(options)
    for index, option in pairs(options) do
        local action = option.onSelect or option.action
        options[index].action = function(entityOrData)
            if type(entityOrData) == 'table' then
                return action(entityOrData.entity)
            end

            return action(entityOrData)
        end
        options[index].job = option.job or option.groups
        if option.name and option.label then FN_TARGET.labels[option.name] = option.label end
    end

    return options
end

FN_TARGET.Distance = function(options)
    local distance = tonumber(options.distance) or 0

    for _, option in pairs(options) do
        if type(option) == 'table' then
            local optionDistance = tonumber(option.distance)
            if optionDistance and optionDistance > distance then distance = optionDistance end
        end
    end

    return distance > 0 and distance or 1.5
end

FN_TARGET.LabelsOf = function(options)
    local labels = {}
    for _, option in pairs(options) do
        if type(option) == 'table' then
            labels[#labels + 1] = option.label or option.name
        end
    end

    return labels
end

FN_TARGET.TrackZone = function(name)
    FN_TARGET.zones[#FN_TARGET.zones + 1] = {
        name = name,
        creator = GetInvokingResource() or Config.ResourceName,
    }
end

FN_TARGET.DropZones = function(shouldDrop)
    for index = #FN_TARGET.zones, 1, -1 do
        local zone = FN_TARGET.zones[index]
        if shouldDrop(zone) then
            QB_TARGET:RemoveZone(zone.name)
            table.remove(FN_TARGET.zones, index)
        end
    end
end

local function Labels(list)
    if list == nil then return nil end

    local labels = {}
    for _, entry in pairs(type(list) == 'table' and list or { list }) do
        labels[#labels + 1] = type(entry) == 'table' and (entry.label or entry.name) or FN_TARGET.labels[entry] or entry
    end

    return labels
end

FN_TARGET.AddGlobalPed = function(options)
    QB_TARGET:AddGlobalPed({
        options = FN_TARGET.FixOptions(options),
        distance = FN_TARGET.Distance(options),
    })
end

FN_TARGET.RemoveGlobalPed = function(options)
    QB_TARGET:RemoveGlobalPed(Labels(options))
end

FN_TARGET.AddGlobalPlayer = function(options)
    local labels = FN_TARGET.LabelsOf(options)
    for _, label in ipairs(labels) do
        FN_TARGET.globalPlayerLabels[#FN_TARGET.globalPlayerLabels + 1] = label
    end

    QB_TARGET:AddGlobalPlayer({
        options = FN_TARGET.FixOptions(options),
        distance = FN_TARGET.Distance(options),
    })
end

FN_TARGET.RemoveGlobalPlayer = function()
    QB_TARGET:RemoveGlobalPlayer(FN_TARGET.globalPlayerLabels)
    FN_TARGET.globalPlayerLabels = {}
end

FN_TARGET.AddGlobalVehicle = function(options)
    QB_TARGET:AddGlobalVehicle({
        options = FN_TARGET.FixOptions(options),
        distance = FN_TARGET.Distance(options),
    })
end

FN_TARGET.RemoveGlobalVehicle = function(options)
    QB_TARGET:RemoveGlobalVehicle(FN_TARGET.LabelsOf(options))
end

FN_TARGET.AddLocalEntity = function(entities, options)
    QB_TARGET:AddTargetEntity(entities, {
        options = FN_TARGET.FixOptions(options),
        distance = FN_TARGET.Distance(options),
    })
end

FN_TARGET.RemoveLocalEntity = function(entity, options)
    QB_TARGET:RemoveTargetEntity(entity, Labels(options))
end

FN_TARGET.AddModel = function(models, options)
    QB_TARGET:AddTargetModel(models, {
        options = FN_TARGET.FixOptions(options),
        distance = FN_TARGET.Distance(options),
    })
end

FN_TARGET.RemoveModel = function(model, options)
    QB_TARGET:RemoveTargetModel(model, Labels(options))
end

FN_TARGET.AddBoxZone = function(name, coords, size, heading, options)
    QB_TARGET:AddBoxZone(name, coords, size.x, size.y, {
        name = name,
        heading = heading,
        debugPoly = Config.Debug,
        minZ = coords.z - (size.z * 0.5),
        maxZ = coords.z + (size.z * 0.5),
    }, {
        options = FN_TARGET.FixOptions(options),
        distance = FN_TARGET.Distance(options),
    })

    FN_TARGET.TrackZone(name)
end

FN_TARGET.AddSphereZone = function(name, coords, radius, options)
    QB_TARGET:AddCircleZone(name, coords, radius, {
        name = name,
        debugPoly = Config.Debug,
    }, {
        options = FN_TARGET.FixOptions(options),
        distance = FN_TARGET.Distance(options),
    })

    FN_TARGET.TrackZone(name)
end

FN_TARGET.RemoveZone = function(name)
    if not name then return end

    FN_TARGET.DropZones(function(zone)
        return zone.name == name
    end)
end

FN_TARGET.DisableTargeting = function(bool)
    QB_TARGET:AllowTargeting(not bool)
end

AddEventHandler('onResourceStop', function(stoppedResource)
    local isSelf = stoppedResource == Config.ResourceName

    FN_TARGET.DropZones(function(zone)
        return isSelf or zone.creator == stoppedResource
    end)
end)

Config.DebugPrint('target adapter loaded: qb-target (client)')
