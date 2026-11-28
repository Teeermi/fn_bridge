FN_STAFF = {}

local Priority = { fn_mdt = 1 }

FN_STAFF.Host = function(jobName)
    if type(jobName) ~= 'string' or jobName == '' then return nil end

    local best, rank
    for _, entry in ipairs(FN_BRIDGE.ProvidersOf('staff')) do
        if FN_BRIDGE.Callable(entry.value) and GetResourceState(entry.resource) == 'started' then
            local ok, hosts = pcall(entry.value, jobName)
            local mine = Priority[entry.resource] or 2
            if ok and hosts == true and (not rank or mine < rank) then best, rank = entry.resource, mine end
        end
    end

    return best
end

FN_STAFF.Call = function(jobName, exportName, ...)
    local host = FN_STAFF.Host(jobName)
    if not host or type(exportName) ~= 'string' then return nil end

    local args = table.pack(...)
    local ok, result, extra = pcall(function() return exports[host][exportName](exports[host], table.unpack(args, 1, args.n)) end)
    if not ok then return nil end

    return result, extra
end

local function Caller() return GetInvokingResource() or GetCurrentResourceName() end

local function Apiac() return GetResourceState('APIAC') == 'started' end

local function List(list)
    local out = {}
    if type(list) ~= 'table' then return out end
    for _, value in ipairs(list) do
        if type(value) == 'string' and value ~= '' and #value <= 128 and #out < 64 then out[#out + 1] = value end
    end

    return out
end

FN_STAFF.Unban = function(target, by)
    by = type(by) == 'string' and by ~= '' and by:sub(1, 64) or Caller()
    local id = type(target) == 'string' and #target <= 32 and target:match('^[%w%-]+$') and target or nil
    local entry = type(target) == 'table' and { identifiers = List(target.identifiers), tokens = List(target.tokens) } or nil
    if not id and (not entry or #entry.identifiers + #entry.tokens == 0) then return false, 'bad_args' end

    local hook = FN_BRIDGE.Setting('unban', Caller())
    if FN_BRIDGE.Callable(hook) then
        local ok, done = pcall(hook, id or entry, by)
        if ok and done ~= nil then
            if done == false then return false, 'not_found' end
            return true, type(done) == 'table' and done or (id and { id } or {})
        end
    end

    if not Apiac() then return false, 'unavailable' end
    local ok, done = pcall(function()
        if id then return exports.APIAC:unbanPlayer(id, by) and { id } or {} end
        return exports.APIAC:unbanIdentifiers(entry.identifiers, entry.tokens, by)
    end)
    if not ok or type(done) ~= 'table' then return false, 'unavailable' end
    if #done == 0 then return false, 'not_found' end

    return true, done
end

FN_STAFF.Bans = function(identifiers, tokens)
    identifiers, tokens = List(identifiers), List(tokens)
    if #identifiers + #tokens == 0 then return false end

    local hook = FN_BRIDGE.Setting('bans', Caller())
    if FN_BRIDGE.Callable(hook) then
        local ok, found = pcall(hook, identifiers, tokens)
        if ok and (type(found) == 'table' or found == false) then return found end
    end

    if not Apiac() then return nil end
    local ok, found = pcall(function() return exports.APIAC:findBan(identifiers, tokens) end)
    if not ok then return nil end

    return type(found) == 'table' and found or false
end

local InventorySql = {
    qb = 'SELECT inventory AS v FROM players WHERE citizenid = ? LIMIT 1',
    qbx = 'SELECT inventory AS v FROM players WHERE citizenid = ? LIMIT 1',
    esx = 'SELECT inventory AS v FROM users WHERE identifier = ? LIMIT 1',
    ox = 'SELECT inventory AS v FROM character_inventory WHERE charId = ? LIMIT 1',
}

local FrameworkInventories = { ox_inventory = true, ['qb-inventory'] = true, ['ps-inventory'] = true }

local function Decode(raw)
    if type(raw) ~= 'string' or raw == '' then return {} end
    local ok, value = pcall(json.decode, raw)

    return ok and type(value) == 'table' and value or {}
end

FN_STAFF.Inventory = function(key)
    if type(key) == 'number' and math.type(key) == 'integer' then key = tostring(key) end
    if type(key) ~= 'string' or key == '' or #key > 64 then return nil end

    local sql, owned = nil, false
    if FN_BRIDGE.IsInventory('fn_inventory') then
        sql, key, owned = 'SELECT items AS v FROM `fn_inventory_inv` WHERE id = ? LIMIT 1', 'p:'..key, true
    elseif not FN_BRIDGE.inventoryName or FrameworkInventories[FN_BRIDGE.inventoryName] then
        sql = InventorySql[FN_BRIDGE.frameworkName or '']
    end
    if not sql then return nil end

    local ok, row = pcall(MySQL.single.await, sql, { key })
    if not ok then return nil end

    local raw = Decode(row and row.v)
    local items = {}
    for k, v in pairs(raw) do
        if owned and type(v) == 'table' then
            items[#items + 1] = { name = v.n, count = v.c, metadata = v.m, slot = v.s }
        elseif type(k) == 'string' and tonumber(v) then
            if tonumber(v) > 0 then items[#items + 1] = { name = k, count = tonumber(v) } end
        else
            items[#items + 1] = v
        end
    end

    return FN_BRIDGE.NormalizeItems(items)
end

local Held = {}

FN_STAFF.Exempt = function(playerId, on)
    playerId = tonumber(playerId)
    if not playerId or not GetPlayerName(playerId) then return false end
    local seconds = type(on) == 'number' and on == on and on > 0 and math.min(math.max(1, math.floor(on)), 3600) or nil
    if not seconds and type(on) ~= 'boolean' then return false end

    local hook = FN_BRIDGE.Setting('exempt', Caller())
    if FN_BRIDGE.Callable(hook) then
        local ok, done = pcall(hook, playerId, seconds or on)
        if ok and done ~= nil then return done ~= false end
    end

    if not Apiac() then return false end
    if seconds and Held[playerId] then return true end
    Held[playerId] = not seconds and on or nil
    local ok, done = pcall(function()
        if seconds then return exports.APIAC:tempBypass(playerId, seconds) end
        return exports.APIAC:toggleBypass(playerId, on)
    end)

    return ok and done == true
end

AddEventHandler('playerDropped', function() Held[source] = nil end)
