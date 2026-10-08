FN_DOORS = {}

local D = FN_DOORS

for _, resource in ipairs({ 'ox_doorlock', 'qb-doorlock' }) do FN_KNOWN[resource] = true end

local function Started(resource)
    return GetResourceState(resource) == 'started'
end

local function Hook(name)
    local hook = FN_BRIDGE.Setting('doors')
    local fn = type(hook) == 'table' and hook[name]

    return FN_BRIDGE.Callable(fn) and fn or nil
end

local function Ox(name, ...)
    local args = table.pack(...)
    local ok, result = pcall(function() return exports.ox_doorlock[name](exports.ox_doorlock, table.unpack(args, 1, args.n)) end)

    return ok and result or nil, ok
end

local function OxDoor(id)
    if type(id) == 'number' then return Ox('getDoor', id) end
    if type(id) == 'string' then return Ox('getDoorFromName', id) end
end

local function Call(fn, ...)
    local ok, result = pcall(fn, ...)

    return ok and result or nil
end

D.Name = function()
    if FN_BRIDGE.Setting('doors') then return 'hook' end
    if Started('ox_doorlock') then return 'ox_doorlock' end
    if Started('qb-doorlock') then return 'qb-doorlock' end

    return false
end

D.List = function()
    local hook = Hook('list')
    if hook then return Call(hook) or {} end
    if not Started('ox_doorlock') then return {} end

    local out = {}
    for _, door in ipairs(Ox('getAllDoors') or {}) do
        out[#out + 1] = { id = door.id, name = door.name, locked = door.state == 1, coords = door.coords }
    end

    return out
end

D.IsLocked = function(id)
    local hook = Hook('isLocked')
    if hook then return Call(hook, id) == true end
    if not Started('ox_doorlock') then return false end

    local door = OxDoor(id)

    return type(door) == 'table' and door.state == 1
end

D.SetLocked = function(id, locked, playerId)
    if id == nil or type(locked) ~= 'boolean' then return false end

    local hook = Hook('setLocked')
    if hook then return Call(hook, id, locked, playerId) ~= false end

    if Started('ox_doorlock') then
        local door = OxDoor(id)
        if type(door) ~= 'table' then return false end

        return Ox('setDoorState', door.id, locked and 1 or 0) == true
    end

    if Started('qb-doorlock') and (type(id) == 'string' or type(id) == 'number') then
        local actor = tonumber(playerId) and GetPlayerName(tonumber(playerId)) and tonumber(playerId)
        actor = actor or tonumber(GetPlayers()[1])
        if not actor then return false end

        TriggerEvent('qb-doorlock:server:updateState', id, locked, false, false, true, true, false, actor)

        return true
    end

    return false
end

D.Allow = function(id, access)
    if type(access) ~= 'table' then return false end

    local hook = Hook('allow')
    if hook then return Call(hook, id, access) ~= false end
    if not Started('ox_doorlock') then return false end

    local door = OxDoor(id)
    if type(door) ~= 'table' then return false end

    local groups = type(access.groups) == 'table' and next(access.groups) and access.groups or ''
    local characters = type(access.identifiers) == 'table' and #access.identifiers > 0 and access.identifiers or ''

    return select(2, Ox('editDoor', door.id, { groups = groups, characters = characters }))
end
