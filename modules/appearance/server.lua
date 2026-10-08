FN_APPEARANCE = {}

local A = FN_APPEARANCE

for _, resource in ipairs({ 'illenium-appearance', 'fivem-appearance', 'qb-clothing', 'skinchanger' }) do FN_KNOWN[resource] = true end

local function Online(playerId)
    playerId = tonumber(playerId)

    return playerId and GetPlayerName(playerId) and playerId or nil
end

local function Clean(outfit)
    if type(outfit) ~= 'table' then return nil end

    local out = { model = tonumber(outfit.model), components = {}, props = {} }
    for _, key in ipairs({ 'components', 'props' }) do
        for i, part in ipairs(type(outfit[key]) == 'table' and outfit[key] or {}) do
            if i > 20 or type(part) ~= 'table' then break end
            local id, drawable, texture = math.tointeger(tonumber(part.id)), math.tointeger(tonumber(part.drawable)), math.tointeger(tonumber(part.texture) or 0)
            if id and drawable and texture and id >= 0 and id <= 11 and drawable >= -1 and drawable < 1000 and texture >= 0 and texture < 100 then
                out[key][#out[key] + 1] = { id = id, drawable = drawable, texture = texture }
            end
        end
    end

    return out
end

A.Name = function()
    for _, resource in ipairs({ 'illenium-appearance', 'fivem-appearance', 'qb-clothing', 'skinchanger' }) do
        if GetResourceState(resource) == 'started' then return resource end
    end

    return false
end

A.Get = function(playerId)
    playerId = Online(playerId)
    if not playerId then return false end

    local ok, outfit = pcall(lib.callback.await, 'fn_bridge:appearance:get', playerId)

    return ok and Clean(outfit) or false
end

A.Set = function(playerId, outfit)
    playerId, outfit = Online(playerId), Clean(outfit)
    if not playerId or not outfit then return false end

    TriggerClientEvent('fn_bridge:appearance', playerId, 'set', outfit)

    return true
end

A.Restore = function(playerId)
    playerId = Online(playerId)
    if not playerId then return false end

    TriggerClientEvent('fn_bridge:appearance', playerId, 'restore')

    return true
end

A.FromCode = function(code)
    if type(code) ~= 'string' or #code > 50 or not FN_DB.HasTable('player_outfit_codes') then return false end

    local row = MySQL.single.await('SELECT o.model, o.components, o.props FROM player_outfit_codes c JOIN player_outfits o ON o.id = c.outfitid WHERE c.code = ? LIMIT 1', { code })
    if not row then return false end

    local outfit = { model = type(row.model) == 'string' and joaat(row.model) or tonumber(row.model), components = {}, props = {} }
    for _, c in ipairs(FN_DB.Json(row.components)) do
        outfit.components[#outfit.components + 1] = { id = c.component_id, drawable = c.drawable, texture = c.texture }
    end
    for _, p in ipairs(FN_DB.Json(row.props)) do
        outfit.props[#outfit.props + 1] = { id = p.prop_id, drawable = p.drawable, texture = p.texture }
    end

    return Clean(outfit)
end
