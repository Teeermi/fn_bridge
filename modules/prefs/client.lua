FN_PREFS = {}

local KVP = 'fn_bridge:prefs'
local KEYS = { lang = 'string', clock = 'string', units = 'string', streamer = 'boolean', motion = 'boolean', cb = 'boolean' }

local data = {}
do
    local ok, saved = pcall(json.decode, GetResourceKvpString(KVP) or '')
    for k, v in pairs(ok and type(saved) == 'table' and saved or {}) do
        if KEYS[k] and type(v) == KEYS[k] then data[k] = v end
    end
end

FN_PREFS.Keys = function()
    local out = {}
    for k in pairs(KEYS) do out[#out + 1] = k end
    table.sort(out)
    return out
end

FN_PREFS.Get = function(key)
    return data[key]
end

FN_PREFS.All = function()
    local out = {}
    for k, v in pairs(data) do out[k] = v end
    return out
end

FN_PREFS.Set = function(key, value)
    if not KEYS[key] then return false end
    if value ~= nil and (type(value) ~= KEYS[key] or (type(value) == 'string' and #value > 16)) then return false end
    if data[key] == value then return true end
    data[key] = value
    SetResourceKvp(KVP, json.encode(data))
    TriggerEvent('fn_bridge:prefs', key, value)
    return true
end
