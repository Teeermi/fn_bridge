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

local Systems = { 'pma-voice', 'saltychat', 'yaca-voice', 'mumble-voip' }

local function Hook(name)
    local hook = FN_BRIDGE.Setting('voice')
    local fn = type(hook) == 'table' and hook[name]
    return FN_BRIDGE.Callable(fn) and fn or nil
end

FN_VOICE.Name = function()
    if type(FN_BRIDGE.Setting('voice')) == 'table' then return 'hook' end
    local forced = Config.Voice
    if forced == 'none' then return false end
    if forced ~= 'auto' then return Started(forced) and forced or false end
    for _, resource in ipairs(Systems) do
        if Started(resource) then return resource end
    end
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
    if name ~= 'saltychat' then return false end

    return pcall(function() exports.saltychat:SetRadioChannel(channel > 0 and tostring(channel) or '', true) end)
end

FN_VOICE.RadioEnabled = function(on)
    local hook = Hook('radioEnabled')
    if hook then return pcall(hook, on == true) end
    if FN_VOICE.Name() ~= 'pma-voice' then return true end
    return pcall(function() exports['pma-voice']:setVoiceProperty('radioEnabled', on == true) end)
end

local Talk = { ['pma-voice'] = 'radiotalk', saltychat = 'primaryRadio' }

FN_VOICE.RadioTalk = function(on)
    local hook = Hook('radioTalk')
    if hook then return pcall(hook, on == true) end
    local command = Talk[FN_VOICE.Name() or '']
    if not command then return false end
    ExecuteCommand((on and '+' or '-') .. command)
    return true
end

AddEventHandler('pma-voice:setTalkingOnRadio', function(serverId, talking)
    TriggerEvent('fn_bridge:radioTalking', tonumber(serverId), talking == true)
end)

AddEventHandler('pma-voice:radioActive', function(talking)
    TriggerEvent('fn_bridge:radioTalking', nil, talking == true)
end)

RegisterNetEvent('fn_bridge:voice', function(key, value)
    if (key == 'call' or key == 'radio') and Started('mumble-voip') then TriggerServerEvent('mumble:SetVoiceData', key, tonumber(value) or 0) end
end)

local hushed, applied, hushing = {}, {}, false
local Near = 4.0

local function Hush(serverId, on)
    if Started('pma-voice') then
        local ok, was = pcall(function() return exports['pma-voice']:isPlayerMuted(serverId) end)
        if ok then
            if on and not was then
                exports['pma-voice']:toggleMutePlayer(serverId)
                applied[serverId] = 'pma'
            elseif not on and applied[serverId] then
                if was then exports['pma-voice']:toggleMutePlayer(serverId) end
                applied[serverId] = nil
                pcall(function() exports['pma-voice']:setCallVolume(exports['pma-voice']:getCallVolume()) end)
            end
            return
        end
    end
    MumbleSetVolumeOverrideByServerId(serverId, on and 0.0 or -1.0)
    applied[serverId] = on and 'raw' or nil
end

local function HushLoop()
    if hushing then return end
    hushing = true
    CreateThread(function()
        while next(hushed) or next(applied) do
            local me = GetEntityCoords(PlayerPedId())
            for serverId in pairs(hushed) do
                local player = GetPlayerFromServerId(serverId)
                local ped = player ~= -1 and GetPlayerPed(player) or 0
                local far = ped == 0 or #(GetEntityCoords(ped) - me) > Near
                if far ~= (applied[serverId] ~= nil) then Hush(serverId, far) end
            end
            for serverId in pairs(applied) do
                if not hushed[serverId] then Hush(serverId, false) end
            end
            local raw = false
            for serverId, kind in pairs(applied) do
                if kind == 'raw' then
                    MumbleSetVolumeOverrideByServerId(serverId, 0.0)
                    raw = true
                end
            end
            Wait(raw and 0 or 250)
        end
        hushing = false
    end)
end

RegisterNetEvent('fn_bridge:callmute', function(list)
    hushed = {}
    local me = GetPlayerServerId(PlayerId())
    for _, serverId in ipairs(type(list) == 'table' and list or {}) do
        serverId = math.tointeger(tonumber(serverId))
        if serverId and serverId > 0 and serverId ~= me then hushed[serverId] = true end
    end
    HushLoop()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for serverId in pairs(applied) do Hush(serverId, false) end
end)
