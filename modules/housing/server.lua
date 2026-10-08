FN_HOUSING = {}

local function Started(resource)
    return GetResourceState(resource) == 'started'
end

local function Decode(value)
    if type(value) == 'table' then return value end
    if type(value) ~= 'string' or value == '' then return nil end
    local ok, result = pcall(json.decode, value)
    return ok and result or nil
end

local function Coords(value)
    local c = Decode(value)
    if type(c) ~= 'table' then return nil end
    c = c.enter or c.entrance or c.door or c.coords or c
    local x, y, z = tonumber(c.x or c[1]), tonumber(c.y or c[2]), tonumber(c.z or c[3])
    if not x or not y then return nil end
    return { x = x, y = y, z = z, w = tonumber(c.w or c.h or c.heading) or 0.0 }
end

local function Query(sql, args)
    local ok, rows = pcall(MySQL.query.await, sql, args)
    return ok and rows or {}
end

local configs = {}
local function ResourceConfig(resource, file, env)
    local key = resource .. file
    if not configs[key] then
        local raw = LoadResourceFile(resource, file)
        local sandbox = setmetatable(env or {}, { __index = _G })
        local fn = raw and load(raw, ('@%s/%s'):format(resource, file), 't', sandbox)
        if fn then pcall(fn) end
        configs[key] = sandbox
    end
    return configs[key]
end

local function Home(id, label, sub, coords, enter)
    if not coords then return nil end
    return { id = id, label = label, sub = sub, coords = coords, enter = enter }
end

local Providers = {
    { resource = 'qb-houses', list = function(key)
        local out = {}
        for _, r in ipairs(Query('SELECT ph.house, hl.label, hl.coords FROM player_houses ph JOIN houselocations hl ON hl.name = ph.house WHERE ph.citizenid = ?', { key })) do
            out[#out + 1] = Home('qbh:' .. r.house, r.label or r.house, nil, Coords(r.coords), { event = 'qb-houses:client:enterOwnedHouse', args = { r.house } })
        end
        return out
    end },
    { resource = 'qb-apartments', list = function(key)
        local out = {}
        local cfg = ResourceConfig('qb-apartments', 'config.lua', { Apartments = {} }).Apartments
        for _, r in ipairs(Query('SELECT name, type, label FROM apartments WHERE citizenid = ?', { key })) do
            local loc = type(cfg) == 'table' and type(cfg.Locations) == 'table' and cfg.Locations[r.type] or nil
            out[#out + 1] = Home('qba:' .. r.name, r.label or r.name, loc and loc.label, loc and Coords(loc.coords), { event = 'qb-apartments:client:LastLocationHouse', args = { r.type, r.name } })
        end
        return out
    end },
    { resource = 'qbx_properties', list = function(key)
        local out = {}
        for _, r in ipairs(Query('SELECT id, property_name, coords FROM properties WHERE owner = ?', { key })) do
            out[#out + 1] = Home('qbx:' .. r.id, r.property_name, nil, Coords(r.coords), { event = 'qbx_properties:server:enterProperty', server = true, args = { { id = r.id, isSpawn = true } } })
        end
        return out
    end },
    { resource = 'ps-housing', list = function(key)
        local out = {}
        for _, r in ipairs(Query('SELECT property_id, street, region, apartment, door_data FROM properties WHERE owner_citizenid = ?', { key })) do
            local label = r.apartment and r.apartment ~= '' and r.apartment or r.street
            out[#out + 1] = Home('ps:' .. r.property_id, label, r.region, Coords(r.door_data), { event = 'ps-housing:server:enterProperty', server = true, args = { tostring(r.property_id), 'spawn' } })
        end
        return out
    end },
    { resource = 'esx_property', list = function(key)
        local out = {}
        local ok, all = pcall(function() return exports.esx_property:GetProperties() end)
        for id, p in pairs(ok and type(all) == 'table' and all or {}) do
            if type(p) == 'table' and p.Owned and p.Owner == key then
                out[#out + 1] = Home('esx:' .. id, (p.setName and p.setName ~= '' and p.setName) or p.Name or tostring(id), nil, Coords(p.Entrance))
            end
        end
        return out
    end },
    { resource = 'qs-housing', list = function(key)
        local out = {}
        local ok, homes = pcall(function() return exports['qs-housing']:GetPlayerPropertiesByIdentifier(key) end)
        for _, h in pairs(ok and type(homes) == 'table' and homes or {}) do
            local id = type(h) == 'table' and (h.house or h.name or h.id)
            if id then out[#out + 1] = Home('qs:' .. tostring(id), h.label or tostring(id), nil, Coords(h.coords)) end
        end
        return out
    end },
    { resource = 'bcs_housing', list = function(key, playerId)
        local out = {}
        local ok, homes = pcall(function() return exports.bcs_housing:GetOwnedHomeKeys(playerId, key) end)
        for _, h in ipairs(ok and type(homes) == 'table' and homes or {}) do
            local id = h.identifier or h.id or h.homeId
            if id then out[#out + 1] = Home('bcs:' .. tostring(id), h.name or h.label or tostring(id), h.complex, Coords(h.entry or h.coords or h.door)) end
        end
        return out
    end },
}

for _, p in ipairs(Providers) do FN_KNOWN[p.resource] = true end

local function Hooked()
    local hook = FN_BRIDGE.Setting('housing')

    return FN_BRIDGE.Callable(hook) and { resource = 'hook', hook = true, list = hook } or nil
end

local function Sources()
    local hook = Hooked()
    if not hook then return Providers end

    local all = { hook }
    for _, p in ipairs(Providers) do all[#all + 1] = p end

    return all
end

FN_HOUSING.Running = function()
    local out = {}
    for _, p in ipairs(Sources()) do
        if p.hook or Started(p.resource) then out[#out + 1] = p.resource end
    end
    return out
end

FN_HOUSING.List = function(playerId, key)
    if not key and playerId then
        local player = FN_BRIDGE.FRAMEWORK and FN_BRIDGE.FRAMEWORK.GetPlayerFromId(playerId)
        key = player and player.identifier
    end
    if type(key) ~= 'string' or key == '' then return {} end
    local out = {}
    for _, p in ipairs(Sources()) do
        if p.hook or Started(p.resource) then
            local ok, list = pcall(p.list, key, playerId)
            if not ok then print(('^1[fn_bridge] housing %s: %s^0'):format(p.resource, tostring(list))) end
            for _, h in ipairs(ok and list or {}) do
                if #out < 20 then out[#out + 1] = h end
            end
        end
    end
    return out
end
