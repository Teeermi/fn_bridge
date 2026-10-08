FN_VOICE = {}

local modes

local function Started(resource)
    return GetResourceState(resource) == 'started'
end

local function PmaModes()
    if modes then return modes end
    local list = {}
    local raw = LoadResourceFile('pma-voice', 'shared.lua')
    local env = setmetatable({}, { __index = _G })
    local fn = raw and load(raw, '@pma-voice/shared.lua', 't', env)
    if fn then pcall(fn) end
    local cfg = type(env.Cfg) == 'table' and type(env.Cfg.voiceModes) == 'table' and env.Cfg.voiceModes or {}
    for i, m in ipairs(cfg) do
        if type(m) == 'table' and tonumber(m[1]) then list[#list + 1] = { index = i, distance = tonumber(m[1]), name = tostring(m[2] or i) } end
    end
    modes = list
    return list
end

local function Proximity()
    local p = LocalPlayer.state.proximity
    return type(p) == 'table' and p or {}
end

local saltyModes

local function SaltyModes()
    if saltyModes then return saltyModes end
    local ok, cfg = pcall(json.decode, LoadResourceFile('saltychat', 'config.json') or '')
    local list = {}
    for i, d in ipairs(ok and type(cfg) == 'table' and type(cfg.VoiceRanges) == 'table' and cfg.VoiceRanges or {}) do
        if tonumber(d) then list[#list + 1] = { index = i, distance = tonumber(d) } end
    end
    saltyModes = list
    return list
end

local function SaltyIndex()
    local ok, range = pcall(function() return exports.saltychat:GetVoiceRange() end)
    range = ok and tonumber(range)
    for _, m in ipairs(SaltyModes()) do
        if range and math.abs(m.distance - range) < 0.01 then return m.index, range end
    end
    return nil, range
end

local Salty = {
    Get = function()
        local index, distance = SaltyIndex()
        local ok, radio = pcall(function() return exports.saltychat:GetRadioVolume() end)
        return {
            name = 'saltychat',
            modes = SaltyModes(),
            range = index,
            distance = distance,
            custom = not index and distance and true or nil,
            cycle = true,
            radio = ok and tonumber(radio) and math.min(100, math.floor(radio * 100 + 0.5)) or nil,
        }
    end,
    SetRange = function(index)
        local n, cur = #SaltyModes(), SaltyIndex()
        index = math.tointeger(tonumber(index))
        if not index or index < 1 or index > n or not cur then return false end
        for _ = 1, (index - cur) % n do ExecuteCommand('+voiceRange') end
        return SaltyIndex() == index
    end,
    SetVolume = function(kind, value)
        if kind ~= 'radio' then return false end
        return pcall(function() exports.saltychat:SetRadioVolume(value / 100) end)
    end,
}

FN_VOICE.Name = function()
    if Started('pma-voice') then return 'pma-voice' end
    if Started('saltychat') then return 'saltychat' end
    return false
end

FN_VOICE.Get = function()
    if FN_VOICE.Name() == 'saltychat' then return Salty.Get() end
    if FN_VOICE.Name() ~= 'pma-voice' then return nil end
    local pv, p = exports['pma-voice'], Proximity()
    local okR, radio = pcall(function() return pv:getRadioVolume() end)
    local okC, call = pcall(function() return pv:getCallVolume() end)
    return {
        name = 'pma-voice',
        modes = PmaModes(),
        range = tonumber(p.index),
        distance = tonumber(p.distance),
        custom = p.mode == 'Custom' or nil,
        cycle = GetConvarInt('voice_enableProximityCycle', 1) == 1,
        radio = okR and tonumber(radio) and math.floor(radio + 0.5) or nil,
        call = okC and tonumber(call) and math.floor(call + 0.5) or nil,
    }
end

FN_VOICE.SetRange = function(index)
    if FN_VOICE.Name() == 'saltychat' then return Salty.SetRange(index) end
    if FN_VOICE.Name() ~= 'pma-voice' then return false end
    local n, cur = #PmaModes(), Proximity()
    index = math.tointeger(tonumber(index))
    if not index or index < 1 or index > n or cur.mode == 'Custom' or not tonumber(cur.index) then return false end
    for _ = 1, (index - cur.index) % n do ExecuteCommand('cycleproximity') end
    return Proximity().index == index
end

FN_VOICE.SetVolume = function(kind, value)
    value = tonumber(value)
    if not value or value < 0 or value > 100 then return false end
    if FN_VOICE.Name() == 'saltychat' then return Salty.SetVolume(kind, value) end
    if FN_VOICE.Name() ~= 'pma-voice' then return false end
    local fn = kind == 'radio' and 'setRadioVolume' or kind == 'call' and 'setCallVolume' or nil
    if not fn then return false end
    return pcall(function() exports['pma-voice'][fn](exports['pma-voice'], math.floor(value + 0.5)) end)
end

FN_VOICE.GetRadio = function()
    local name = FN_VOICE.Name()
    if name == 'pma-voice' then return math.floor(tonumber(LocalPlayer.state.radioChannel) or 0) end
    if name ~= 'saltychat' then return false end

    local ok, channel = pcall(function() return exports.saltychat:GetRadioChannel(true) end)

    return ok and tonumber(channel) or 0
end

FN_VOICE.SetRadio = function(channel)
    channel = tonumber(channel)
    local name = FN_VOICE.Name()
    if not channel or channel < 0 or channel > 100000 or not name then return false end

    if name == 'pma-voice' then
        return pcall(function() exports['pma-voice']:setRadioChannel(channel) end)
    end

    return pcall(function() exports.saltychat:SetRadioChannel(channel > 0 and tostring(channel) or '', true) end)
end
