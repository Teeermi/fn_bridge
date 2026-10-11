FN_HTTP = {}

local Loopback = { ['127.0.0.1'] = true, ['::1'] = true, ['::ffff:127.0.0.1'] = true }

local function Proxies()
    local raw = GetConvar('fn_bridge:tunnel', 'off'):lower()
    if raw == '' or raw == 'off' or raw == 'false' then return nil end

    local list = {}
    for ip in raw:gmatch('[^%s,]+') do list[ip] = true end

    return list
end

local function Peer(address)
    address = tostring(address or '')
    local bracketed = address:match('^%[(.-)%]')
    if bracketed then return bracketed end

    local _, colons = address:gsub(':', '')

    return colons == 1 and address:match('^(.-):%d+$') or address
end

FN_HTTP.Header = function(headers, name)
    name = tostring(name):lower()
    for key, value in pairs(type(headers) == 'table' and headers or {}) do
        if type(key) == 'string' and key:lower() == name then return value end
    end

    return nil
end

FN_HTTP.Tunnel = function()
    return Proxies() ~= nil
end

FN_HTTP.Origin = function(address, headers)
    local peer = Peer(address)
    local proxies = Proxies()
    if not proxies then return peer end
    if not Loopback[peer] and not proxies[peer] then return nil end

    local real = tostring(FN_HTTP.Header(headers, 'x-forwarded-for') or ''):match('([^,%s]+)%s*$')
        or FN_HTTP.Header(headers, 'cf-connecting-ip')

    return type(real) == 'string' and #real <= 45 and real:match('^[%x%.:]+$') and real or peer
end
