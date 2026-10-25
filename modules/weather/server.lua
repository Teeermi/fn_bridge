FN_WEATHER = {}

local W = FN_WEATHER

local Systems = { 'Renewed-Weathersync', 'qb-weathersync' }

for _, resource in ipairs(Systems) do FN_KNOWN[resource] = true end

local Kinds = {
    RAIN = 'rain', CLEARING = 'rain', RAIN_HALLOWEEN = 'rain',
    THUNDER = 'storm',
    SNOW = 'snow', SNOWLIGHT = 'snow', BLIZZARD = 'snow', XMAS = 'snow', SNOW_HALLOWEEN = 'snow',
    FOGGY = 'fog', SMOG = 'fog',
}

local function Started(resource)
    return GetResourceState(resource) == 'started'
end

local function Hook()
    local hook = FN_BRIDGE.Setting('weather')
    if FN_BRIDGE.Callable(hook) then return { weather = hook } end
    return type(hook) == 'table' and hook or nil
end

local function Kind(raw)
    if type(raw) ~= 'string' then return 'clear', nil end
    local up = raw:upper()
    if up == 'CLEAR' or up == 'RAIN' or up == 'STORM' or up == 'SNOW' or up == 'FOG' then
        return up == 'CLEAR' and 'clear' or up == 'RAIN' and 'rain' or up == 'STORM' and 'storm' or up == 'SNOW' and 'snow' or 'fog', up
    end
    return Kinds[up] or 'clear', up
end

local Read = {
    ['Renewed-Weathersync'] = {
        weather = function()
            local w = GlobalState.weather
            return type(w) == 'table' and w.weather or nil
        end,
        time = function()
            local t = GlobalState.currentTime
            return type(t) == 'table' and tonumber(t.hour) or nil
        end,
    },
    ['qb-weathersync'] = {
        weather = function() return exports['qb-weathersync']:getWeatherState() end,
        time = function() return (exports['qb-weathersync']:getTime()) end,
    },
}

W.Name = function()
    if Hook() then return 'hook' end

    local forced = Config.Weather
    if forced == 'none' then return false end
    if forced ~= 'auto' then return Read[forced] and Started(forced) and forced or false end

    for _, resource in ipairs(Systems) do
        if Started(resource) then return resource end
    end

    return false
end

local function Source()
    local name = W.Name()
    if name == 'hook' then return Hook() end
    return name and Read[name] or nil
end

W.Weather = function()
    local src = Source()
    local fn = src and src.weather
    if not FN_BRIDGE.Callable(fn) then return nil end
    local ok, raw = pcall(fn)
    if not ok or raw == nil then return nil end
    return Kind(raw)
end

W.Time = function()
    local src = Source()
    local fn = src and src.time
    if not FN_BRIDGE.Callable(fn) then return nil end
    local ok, hour = pcall(fn)
    hour = ok and tonumber(hour) or nil
    if not hour or hour < 0 or hour > 23 then return nil end
    return math.floor(hour)
end

local listeners, last, watching = {}, nil, false

local function Emit()
    local kind, raw = W.Weather()
    if kind == nil or kind == last then return end
    last = kind
    for i = #listeners, 1, -1 do
        local l = listeners[i]
        if GetResourceState(l.resource) ~= 'started' then
            table.remove(listeners, i)
        else
            local ok, err = pcall(l.cb, kind, raw)
            if not ok then print(('^1[fn_bridge] weather listener %s: %s^0'):format(l.resource, tostring(err))) end
        end
    end
end

W.OnWeather = function(cb)
    local resource = GetInvokingResource() or FN_BRIDGE.resourceName
    if not FN_BRIDGE.Callable(cb) then return false end
    listeners[#listeners + 1] = { resource = resource, cb = cb }
    if not watching then
        watching = true
        last = W.Weather()
        AddStateBagChangeHandler('weather', 'global', function() SetTimeout(0, Emit) end)
        CreateThread(function()
            while #listeners > 0 do
                Wait(10000)
                Emit()
            end
            watching = false
        end)
    end
    return true
end

FN_WEATHER_PROBE = function()
    local name, read = W.Name, Read['qb-weathersync']
    local function restore() W.Name, Read['qb-weathersync'] = name, read end
    local ok, err = pcall(function()
        local now, hour = 'THUNDER', 23
        W.Name = function() return 'qb-weathersync' end
        Read['qb-weathersync'] = { weather = function() return now end, time = function() return hour end }
        assert(W.Weather() == 'storm', 'THUNDER is storm')
        now = 'XMAS'
        assert(W.Weather() == 'snow', 'XMAS is snow')
        now = 'EXTRASUNNY'
        assert(W.Weather() == 'clear', 'EXTRASUNNY is clear')
        now = 'rain'
        assert(W.Weather() == 'rain', 'hook kinds pass through')
        assert(W.Time() == 23, 'time')
        hour = 31
        assert(W.Time() == nil, 'bad hour')
        Read['qb-weathersync'] = { weather = function() error('boom') end }
        assert(W.Weather() == nil and W.Time() == nil, 'broken adapter')
    end)
    restore()
    return ok, err
end
