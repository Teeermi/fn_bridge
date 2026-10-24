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
        local ok, ret = false, nil
        if fn then ok, ret = pcall(fn) end
        configs[key] = { env = sandbox, ret = ok and ret or nil }
    end
    return configs[key].env, configs[key].ret
end

local function Keys(value)
    local t, out = Decode(value), {}
    if type(t) ~= 'table' then return out end
    for k, v in pairs(t) do
        local id = type(v) == 'string' and v or type(k) == 'string' and v == true and k or nil
        if id and #out < 50 then out[#out + 1] = id end
    end
    return out
end

local function Home(id, label, sub, coords, enter, owner, keys)
    return { id = id, label = label or id, sub = sub, coords = coords, enter = enter, owner = owner ~= false, keys = keys or {} }
end

local function Contains(column)
    return ('JSON_CONTAINS(IF(JSON_VALID(%s), %s, \'[]\'), JSON_QUOTE(?))'):format(column, column)
end

local qbLocked = {}

local Providers = {
    { resource = 'qb-houses', prefix = 'qbh', list = function(key)
        local out = {}
        for _, r in ipairs(Query('SELECT ph.house, ph.citizenid, ph.keyholders, hl.label, hl.coords FROM player_houses ph LEFT JOIN houselocations hl ON hl.name = ph.house WHERE ph.citizenid = ? OR ' .. Contains('ph.keyholders'), { key, key })) do
            out[#out + 1] = Home('qbh:' .. r.house, r.label or r.house, nil, Coords(r.coords), { event = 'qb-houses:client:enterOwnedHouse', args = { r.house } }, r.citizenid == key, Keys(r.keyholders))
        end
        return out
    end,
    forSale = 'SELECT name AS id, label, coords, price FROM houselocations WHERE owned = 0 AND price > 0 LIMIT 300',
    lock = {
        get = function(id) return qbLocked[id] ~= false end,
        set = function(id, on)
            qbLocked[id] = on
            TriggerClientEvent('qb-houses:client:lockHouse', -1, on, id)
            return on
        end,
    },
    resume = function(c)
        local inside = type(c.inside) == 'table' and c.inside
        if inside and inside.house then return { event = 'qb-houses:client:LastLocationHouse', args = { inside.house } } end
    end },
    { resource = 'qb-apartments', prefix = 'qba', list = function(key)
        local out = {}
        local cfg = ResourceConfig('qb-apartments', 'config.lua', { Apartments = {} }).Apartments
        for _, r in ipairs(Query('SELECT name, type, label FROM apartments WHERE citizenid = ?', { key })) do
            local loc = type(cfg) == 'table' and type(cfg.Locations) == 'table' and cfg.Locations[r.type] or nil
            out[#out + 1] = Home('qba:' .. r.name, r.label or r.name, loc and loc.label, loc and Coords(loc.coords), { event = 'qb-apartments:client:LastLocationHouse', args = { r.type, r.name } })
        end
        return out
    end,
    resume = function(c)
        local apt = type(c.inside) == 'table' and type(c.inside.apartment) == 'table' and c.inside.apartment or {}
        if apt.apartmentType or apt.apartmentId then return { event = 'qb-apartments:client:LastLocationHouse', args = { apt.apartmentType, apt.apartmentId } } end
    end,
    starters = function()
        if not FN_BRIDGE.IsFramework('qb') then return nil end
        local cfg = ResourceConfig('qb-apartments', 'config.lua', { Apartments = {} }).Apartments
        if type(cfg) ~= 'table' or cfg.Starting ~= true then return nil end
        local out = {}
        for name, loc in pairs(type(cfg.Locations) == 'table' and cfg.Locations or {}) do
            out[#out + 1] = Home('apt:' .. name, loc.label or name, nil, Coords(loc.coords), { event = 'apartments:server:CreateApartment', server = true, args = { name, loc.label or name, true } })
        end
        return out
    end },
    { resource = 'qbx_properties', prefix = 'qbx', list = function(key)
        local out = {}
        for _, r in ipairs(Query('SELECT id, property_name, coords, owner, keyholders FROM properties WHERE owner = ? OR ' .. Contains('keyholders'), { key, key })) do
            out[#out + 1] = Home('qbx:' .. r.id, r.property_name, nil, Coords(r.coords), { event = 'qbx_properties:server:enterProperty', server = true, args = { { id = r.id, isSpawn = true } } }, r.owner == key, Keys(r.keyholders))
        end
        return out
    end,
    forSale = 'SELECT id, property_name AS label, coords, price FROM properties WHERE owner IS NULL AND price > 0 LIMIT 300',
    resume = function(c)
        if c.property then return { event = 'qbx_properties:server:enterProperty', server = true, args = { { id = c.property, isSpawn = true } } } end
    end,
    handled = function()
        return FN_BRIDGE.IsFramework('qbx') and (LoadResourceFile('qbx_core', 'config/client.lua') or ''):find('startingApartment%s*=%s*true') ~= nil
    end,
    starters = function(self)
        if not FN_BRIDGE.IsFramework('qbx') or self.handled() then return nil end
        local _, cfg = ResourceConfig('qbx_properties', 'config/shared.lua')
        local out = {}
        for i, a in ipairs(type(cfg) == 'table' and type(cfg.apartmentOptions) == 'table' and cfg.apartmentOptions or {}) do
            out[#out + 1] = Home('apt:' .. i, a.label, a.description, Coords(a.enter), { event = 'qbx_properties:server:apartmentSelect', server = true, args = { i } })
        end
        return out
    end },
    { resource = 'ps-housing', prefix = 'ps', list = function(key)
        local out = {}
        for _, r in ipairs(Query('SELECT property_id, owner_citizenid, street, region, apartment, has_access, door_data, garage_data FROM properties WHERE owner_citizenid = ? OR ' .. Contains('has_access'), { key, key })) do
            local label = r.apartment and r.apartment ~= '' and r.apartment or r.street
            out[#out + 1] = Home('ps:' .. r.property_id, label, r.region, Coords(r.door_data) or Coords(r.garage_data), { event = 'ps-housing:server:enterProperty', server = true, args = { tostring(r.property_id), 'spawn' } }, r.owner_citizenid == key, Keys(r.has_access))
        end
        return out
    end,
    forSale = 'SELECT property_id AS id, street AS label, door_data AS coords, price FROM properties WHERE for_sale = 1 AND price > 0 LIMIT 300',
    resume = function(c)
        local inside = type(c.inside) == 'table' and c.inside
        if inside and inside.property_id then return { event = 'ps-housing:server:enterProperty', server = true, args = { tostring(inside.property_id), 'spawn' } } end
    end },
    { resource = 'esx_property', prefix = 'esx', list = function(key)
        local out = {}
        local ok, all = pcall(function() return exports.esx_property:GetProperties() end)
        for id, p in pairs(ok and type(all) == 'table' and all or {}) do
            if type(p) == 'table' and p.Owned and p.Owner == key then
                out[#out + 1] = Home('esx:' .. id, (p.setName and p.setName ~= '' and p.setName) or p.Name or tostring(id), nil, Coords(p.Entrance))
            end
        end
        return out
    end,
    forSale = function()
        local out = {}
        local ok, all = pcall(function() return exports.esx_property:GetProperties() end)
        for id, p in pairs(ok and type(all) == 'table' and all or {}) do
            if type(p) == 'table' and not p.Owned and tonumber(p.Price) and tonumber(p.Price) > 0 then
                out[#out + 1] = { id = id, label = p.Name or tostring(id), coords = p.Entrance, price = p.Price }
            end
        end
        return out
    end,
    prepare = function(id, key, coords)
        if not FN_DB.HasColumn('users', 'last_property') then return end
        MySQL.update.await('UPDATE users SET last_property = ? WHERE identifier = ?', { json.encode({ id = tonumber(id) or id, coords = coords and { x = coords.x, y = coords.y, z = coords.z } }), key })
    end },
    { resource = 'qs-housing', prefix = 'qs', list = function(key)
        local out = {}
        for _, r in ipairs(Query('SELECT ph.house, ph.citizenid, ph.keyholders, hl.label, hl.coords FROM player_houses ph LEFT JOIN houselocations hl ON hl.name = ph.house WHERE ph.citizenid = ? OR ' .. Contains('ph.keyholders'), { key, key })) do
            out[#out + 1] = Home('qs:' .. r.house, r.label or r.house, nil, Coords(r.coords), nil, r.citizenid == key, Keys(r.keyholders))
        end
        return out
    end,
    forSale = 'SELECT name AS id, label, coords, price FROM houselocations WHERE owned = 0 AND price > 0 LIMIT 300' },
    { resource = 'bcs_housing', prefix = 'bcs', list = function(key)
        local out = {}
        local ok, homes = pcall(function() return exports.bcs_housing:GetOwnedHomeKeys(key) end)
        for _, h in ipairs(ok and type(homes) == 'table' and homes or {}) do
            local id = h.identifier or h.id or h.homeId
            if id then out[#out + 1] = Home('bcs:' .. tostring(id), h.name or h.label or tostring(id), h.complex, Coords(h.entry or h.coords or h.door), nil, h.owner == key) end
        end
        return out
    end,
    lock = {
        get = function(id) return exports.bcs_housing:isLocked(id) == true end,
        set = function(id, on)
            if (exports.bcs_housing:isLocked(id) == true) ~= on then exports.bcs_housing:LockHome(id) end
            return exports.bcs_housing:isLocked(id) == true
        end,
    } },
}

for _, p in ipairs(Providers) do FN_KNOWN[p.resource] = true end

local function Hook()
    local hook = FN_BRIDGE.Setting('housing')
    if FN_BRIDGE.Callable(hook) then return { list = hook } end
    return type(hook) == 'table' and hook or nil
end

local function HookFn(name)
    local hook = Hook()
    local fn = hook and hook[name]
    return FN_BRIDGE.Callable(fn) and fn or nil
end

local function Active()
    local out = {}
    local list = HookFn('list')
    if list then out[1] = { resource = 'hook', hook = true, list = list } end
    for _, p in ipairs(Providers) do
        if Started(p.resource) then out[#out + 1] = p end
    end
    return out
end

local function Owner(id)
    local prefix = type(id) == 'string' and id:match('^(%l+):')
    for _, p in ipairs(Providers) do
        if p.prefix == prefix then return p, id:sub(#prefix + 2) end
    end
end

FN_HOUSING.Running = function()
    local out = {}
    for _, p in ipairs(Active()) do out[#out + 1] = p.resource end
    return out
end

FN_HOUSING.List = function(playerId, key, opts)
    if not key and playerId then
        local player = FN_BRIDGE.FRAMEWORK and FN_BRIDGE.FRAMEWORK.GetPlayerFromId(playerId)
        key = player and player.identifier
    end
    if type(key) ~= 'string' or key == '' then return {} end
    local keys = type(opts) == 'table' and opts.keys == true
    local out = {}
    for _, p in ipairs(Active()) do
        local ok, list = pcall(p.list, key, playerId)
        if not ok then print(('^1[fn_bridge] housing %s: %s^0'):format(p.resource, tostring(list))) end
        for _, h in ipairs(ok and type(list) == 'table' and list or {}) do
            if #out < 20 and type(h) == 'table' and h.id ~= nil and (keys or h.owner ~= false) then
                h.id = tostring(h.id)
                h.owner = h.owner ~= false
                h.keys = type(h.keys) == 'table' and h.keys or {}
                h.coords = Coords(h.coords)
                out[#out + 1] = h
            end
        end
    end
    return out
end

local function Lock(id)
    if type(id) ~= 'string' or id == '' or #id > 64 then return nil end
    local get, set = HookFn('isLocked'), HookFn('setLocked')
    if get and set then
        local ok, locked = pcall(get, id)
        if ok and locked ~= nil then return { get = get, set = set }, id end
    end
    local p, raw = Owner(id)
    if p and p.lock and Started(p.resource) then return p.lock, raw end
end

FN_HOUSING.IsLocked = function(id)
    local lock, raw = Lock(id)
    if not lock then return nil end
    local ok, locked = pcall(lock.get, raw)
    if not ok or locked == nil then return nil end
    return locked == true
end

FN_HOUSING.SetLocked = function(id, locked, playerId)
    local lock, raw = Lock(id)
    if not lock or type(locked) ~= 'boolean' then return nil end
    local ok, now = pcall(lock.set, raw, locked, tonumber(playerId))
    if not ok then return nil end
    if type(now) ~= 'boolean' then now = select(2, pcall(lock.get, raw)) == true end
    return now
end

FN_HOUSING.ForSale = function()
    local out = {}
    local function add(resource, rows)
        for _, r in ipairs(type(rows) == 'table' and rows or {}) do
            local c, price = Coords(r.coords), tonumber(r.price)
            if c and price and #out < 1000 then out[#out + 1] = { id = resource .. ':' .. tostring(r.id), label = tostring(r.label or r.id), coords = c, price = math.floor(price) } end
        end
    end
    local hook = HookFn('forSale')
    if hook then
        local ok, rows = pcall(hook)
        if ok then add('hook', rows) end
    end
    for _, p in ipairs(Providers) do
        if p.forSale and Started(p.resource) then
            if type(p.forSale) == 'string' then add(p.resource, Query(p.forSale, {})) else
                local ok, rows = pcall(p.forSale)
                if ok then add(p.resource, rows) end
            end
        end
    end
    return out
end

FN_HOUSING.Starters = function()
    local hook = HookFn('starters')
    if hook then
        local ok, list = pcall(hook)
        if ok and type(list) == 'table' then return list, false end
    end
    for _, p in ipairs(Providers) do
        if Started(p.resource) and p.handled and p.handled() then return {}, true end
    end
    local out = {}
    for _, p in ipairs(Providers) do
        if p.starters and Started(p.resource) then
            local ok, list = pcall(p.starters, p)
            for _, h in ipairs(ok and type(list) == 'table' and list or {}) do
                if h.coords then out[#out + 1] = h end
            end
        end
    end
    table.sort(out, function(a, b) return tostring(a.label) < tostring(b.label) end)
    return out, false
end

FN_HOUSING.Resume = function(character)
    if type(character) ~= 'table' then return nil end
    local hook = HookFn('resume')
    if hook then
        local ok, enter = pcall(hook, character)
        if ok and type(enter) == 'table' then return enter end
    end
    for _, p in ipairs(Providers) do
        if p.resume and Started(p.resource) then
            local ok, enter = pcall(p.resume, character)
            if ok and type(enter) == 'table' then return enter end
        end
    end
end

FN_HOUSING.Prepare = function(id, key, coords)
    if type(key) ~= 'string' or key == '' then return false end
    local hook = HookFn('prepare')
    if hook then pcall(hook, id, key, coords) end
    local p, raw = Owner(id)
    if p and p.prepare and Started(p.resource) then return (pcall(p.prepare, raw, key, coords)) end
    return true
end

local Givers = {
    { resource = 'bcs_housing', house = true,
        give = function(playerId, home) return exports.bcs_housing:GiveHouse(home.house, playerId, playerId) end },
    { resource = 'nolag_properties', house = true, starter = true, offline = true,
        give = function(_, home, key)
            if home.starter then return exports.nolag_properties:AddStarterApartment(key, tonumber(home.starter)) end
            return exports.nolag_properties:TransferProperty(tonumber(home.house) or home.house, 'user', key, tostring(home.reason or 'fn_bridge'))
        end },
}

for _, g in ipairs(Givers) do FN_KNOWN[g.resource] = true end

local function Giver()
    local hook = FN_BRIDGE.Setting('giveHome')
    if FN_BRIDGE.Callable(hook) then return { resource = 'hook', house = true, starter = true, give = hook } end
    for _, g in ipairs(Givers) do
        if Started(g.resource) then return g end
    end
end

FN_HOUSING.Giver = function()
    local g = Giver()
    return g and { name = g.resource, house = g.house == true, starter = g.starter == true, offline = g.offline == true } or false
end

FN_HOUSING.Give = function(playerId, home, key)
    local g = Giver()
    if not g then return false, 'none' end
    if type(home) ~= 'table' then return false, 'invalid' end

    local mode = home.starter ~= nil and 'starter' or 'house'
    local id = home[mode]
    if not g[mode] or (type(id) ~= 'string' and type(id) ~= 'number') or id == '' then return false, 'unsupported' end

    playerId = tonumber(playerId)
    if playerId and not GetPlayerName(playerId) then playerId = nil end
    if not playerId and not g.offline then return false, 'offline' end
    if type(key) ~= 'string' and playerId then
        local player = FN_BRIDGE.FRAMEWORK and FN_BRIDGE.FRAMEWORK.GetPlayerFromId(playerId)
        key = player and player.identifier
    end
    if g.offline and (type(key) ~= 'string' or key == '') then return false, 'identifier' end

    local ok, done, why = pcall(g.give, playerId, home, key)
    if not ok then
        print(('^1[fn_bridge] housing %s give: %s^0'):format(g.resource, tostring(done)))
        return false, 'failed'
    end
    if done == false then return false, type(why) == 'string' and why or 'failed' end

    return true
end
