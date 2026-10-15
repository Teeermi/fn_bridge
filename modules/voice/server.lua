FN_VOICE = {}

local V = FN_VOICE

local Systems = { 'pma-voice', 'saltychat', 'yaca-voice', 'mumble-voip' }

for _, resource in ipairs(Systems) do FN_KNOWN[resource] = true end

local calls, callOf, muted, told, radioOf = {}, {}, {}, {}, {}

local function Started(resource)
    return GetResourceState(resource) == 'started'
end

local function Online(playerId)
    playerId = tonumber(playerId)

    return playerId and playerId > 0 and GetPlayerName(playerId) and playerId or nil
end

local function Hook()
    local hook = FN_BRIDGE.Setting('voice')

    return type(hook) == 'table' and hook or nil
end

local function HookFn(name)
    local hook = Hook()
    local fn = hook and hook[name]

    return FN_BRIDGE.Callable(fn) and fn or nil
end

V.Name = function()
    if Hook() then return 'hook' end

    local forced = Config.Voice
    if forced == 'none' then return false end
    if forced ~= 'auto' then return Started(forced) and forced or false end

    for _, resource in ipairs(Systems) do
        if Started(resource) then return resource end
    end

    return false
end

V.Mumble = function()
    local name = V.Name()
    if name == 'hook' then return Hook().mumble == true end

    return name == 'pma-voice' or name == 'mumble-voip'
end

local Pair = {
    saltychat = function(a, b, on)
        if on then exports.saltychat:EstablishCall(a, b) else exports.saltychat:EndCall(a, b) end
    end,
    ['yaca-voice'] = function(a, b, on) exports['yaca-voice']:callPlayer(a, b, on) end,
}

local Channel = {
    ['pma-voice'] = function(playerId, id)
        if id then exports['pma-voice']:addPlayerToCall(playerId, id) else exports['pma-voice']:removePlayerFromCall(playerId) end
    end,
    ['mumble-voip'] = function(playerId, id) TriggerClientEvent('fn_bridge:voice', playerId, 'call', id or 0) end,
    hook = function(playerId, id)
        local fn = HookFn('call')
        if fn then fn(playerId, id) end
    end,
}

local Hush = {
    saltychat = function(speaker, listener, on)
        if on then TriggerClientEvent('SaltyChat_EndCall', listener, tostring(speaker)) else exports.saltychat:EstablishCall(speaker, listener) end
    end,
}

local function Tell(listener)
    local id, list = callOf[listener], {}
    for member in pairs(id and calls[id] or {}) do
        if member ~= listener and muted[member] then list[#list + 1] = member end
    end
    table.sort(list)

    local key = table.concat(list, ',')
    if (told[listener] or '') == key then return end
    told[listener] = key ~= '' and key or nil
    if listener > 0 and GetPlayerName(listener) then TriggerClientEvent('fn_bridge:callmute', listener, list) end
end

local function Silence(id, speaker, on, name)
    if name == 'yaca-voice' then return pcall(function() exports['yaca-voice']:muteOnPhone(speaker, on) end) end

    local mute = name == 'hook' and HookFn('mute')
    if mute then
        local ok, done = pcall(mute, speaker, on)
        if ok and done == true then return true end
    end

    for member in pairs(calls[id] or {}) do
        if member ~= speaker then
            if Hush[name] then pcall(Hush[name], speaker, member, on) else Tell(member) end
        end
    end

    return true
end

V.SetCall = function(playerId, callId)
    playerId = tonumber(playerId)
    if not playerId then return false end
    if callId ~= nil and type(callId) ~= 'number' and type(callId) ~= 'string' then return false end

    local name = V.Name()
    if not name then return false end

    local old, pair, channel = callOf[playerId], Pair[name], Channel[name]
    if old == callId and not channel then return true end

    if old ~= callId then
        if old and muted[playerId] then
            muted[playerId] = nil
            Silence(old, playerId, false, name)
        end
        if old and calls[old] then
            calls[old][playerId] = nil
            for member in pairs(calls[old]) do
                if pair then
                    pcall(pair, playerId, member, false)
                    pcall(pair, member, playerId, false)
                end
                Tell(member)
            end
            if not next(calls[old]) then calls[old] = nil end
        end
        callOf[playerId] = callId
    end

    if channel then pcall(channel, playerId, callId) end

    if callId ~= nil and old ~= callId then
        calls[callId] = calls[callId] or {}
        for member in pairs(calls[callId]) do
            if pair then
                pcall(pair, playerId, member, true)
                pcall(pair, member, playerId, true)
            end
            if muted[member] and Hush[name] then pcall(Hush[name], member, playerId, true) end
        end
        calls[callId][playerId] = true
    end
    Tell(playerId)

    return true
end

V.GetCall = function(playerId)
    return callOf[tonumber(playerId)]
end

V.MuteCall = function(playerId, on)
    playerId = tonumber(playerId)
    local name, id = V.Name(), playerId and callOf[playerId]
    if not name or id == nil then return false end

    on = on == true
    if (muted[playerId] == true) == on then return true end

    muted[playerId] = on or nil
    if Silence(id, playerId, on, name) == false then
        muted[playerId] = (not on) or nil
        return false
    end

    return true
end

V.CallMuted = function(playerId)
    return muted[tonumber(playerId)] == true
end

local Radio = {
    ['pma-voice'] = {
        set = function(playerId, channel) exports['pma-voice']:setPlayerRadio(playerId, channel) end,
        get = function(playerId) return Player(playerId).state.radioChannel end,
        count = function(channel) return exports['pma-voice']:getPlayersInRadioChannel(channel) end,
    },
    saltychat = {
        set = function(playerId, channel)
            local current = exports.saltychat:GetPlayerRadioChannel(playerId, true)
            if current and current ~= '' then exports.saltychat:RemovePlayerRadioChannel(playerId, current) end
            if channel > 0 then exports.saltychat:SetPlayerRadioChannel(playerId, tostring(channel), true) end
        end,
        get = function(playerId) return exports.saltychat:GetPlayerRadioChannel(playerId, true) end,
        count = function(channel) return exports.saltychat:GetPlayersInRadioChannel(tostring(channel)) end,
    },
    ['yaca-voice'] = {
        set = function(playerId, channel) exports['yaca-voice']:setPlayerRadioChannel(playerId, 1, channel > 0 and tostring(channel) or '0') end,
    },
    ['mumble-voip'] = {
        set = function(playerId, channel) TriggerClientEvent('fn_bridge:voice', playerId, 'radio', channel) end,
    },
    hook = {
        set = function(playerId, channel)
            local fn = HookFn('radio')
            if not fn then error('the voice hook has no radio function') end
            if fn(playerId, channel) == false then error('the voice hook refused') end
        end,
        get = function(playerId)
            local fn = HookFn('getRadio')
            if fn then return fn(playerId) end
        end,
        count = function(channel)
            local fn = HookFn('radioCount')
            if fn then return fn(channel) end
        end,
    },
}

V.GetRadio = function(playerId)
    playerId = Online(playerId)
    local name = V.Name()
    if not playerId or not name then return false end

    local get = Radio[name] and Radio[name].get
    if get then
        local ok, channel = pcall(get, playerId)
        if ok and tonumber(channel) then return math.floor(tonumber(channel)) end
    end

    return radioOf[playerId] or 0
end

V.SetRadio = function(playerId, channel)
    playerId, channel = Online(playerId), tonumber(channel)
    local name = V.Name()
    if not playerId or not channel or channel < 0 or channel > 100000 or not name or not Radio[name] then return false end

    channel = math.floor(channel)
    local ok = pcall(Radio[name].set, playerId, channel)
    if ok then radioOf[playerId] = channel > 0 and channel or nil end

    return ok
end

V.RadioCount = function(channel)
    channel = tonumber(channel)
    if not channel or channel <= 0 then return 0 end

    local count = Radio[V.Name() or ''] and Radio[V.Name()].count
    if count then
        local ok, list = pcall(count, channel)
        if ok and type(list) == 'number' then return list end
        if ok and type(list) == 'table' then
            local n = 0
            for _ in pairs(list) do n = n + 1 end
            return n
        end
    end

    local n = 0
    for _, c in pairs(radioOf) do
        if c == channel then n = n + 1 end
    end

    return n
end

AddEventHandler('playerDropped', function()
    local playerId = source
    if callOf[playerId] ~= nil then V.SetCall(playerId, nil) end
    radioOf[playerId], told[playerId], muted[playerId] = nil, nil, nil
end)

FN_VOICE_PROBE = function()
    local name, pair, hush, channel = V.Name, Pair.saltychat, Hush.saltychat, Channel['pma-voice']
    local seen, got = {}, {}
    local function restore()
        V.Name, Pair.saltychat, Hush.saltychat, Channel['pma-voice'] = name, pair, hush, channel
    end

    local ok, err = pcall(function()
        V.Name = function() return 'saltychat' end
        Pair.saltychat = function(a, b, on) seen[#seen + 1] = ('%d%s%d'):format(a, on and '+' or '-', b) end
        V.SetCall(-1, 77)
        V.SetCall(-2, 77)
        V.SetCall(-1, nil)
        V.SetCall(-2, nil)
        assert(table.concat(seen, ' ') == '-2+-1 -1+-2 -1--2 -2--1', 'pairs ' .. table.concat(seen, ' '))

        Pair.saltychat = function() end
        Hush.saltychat = function(s, m, on) got[('%d%s%d'):format(s, on and 'x' or 'o', m)] = true end
        V.SetCall(-1, 77)
        V.SetCall(-2, 77)
        assert(V.MuteCall(-1, true) and V.CallMuted(-1) and got['-1x-2'], 'mute')
        V.SetCall(-3, 77)
        assert(got['-1x-3'], 'late joiner hears the mute')
        V.MuteCall(-1, false)
        assert(got['-1o-2'] and got['-1o-3'] and not V.CallMuted(-1), 'unmute')
        V.MuteCall(-2, true)
        V.SetCall(-2, nil)
        assert(not V.CallMuted(-2) and got['-2o-1'] and got['-2o-3'], 'leaving clears the mute')
        V.SetCall(-1, nil)
        V.SetCall(-3, nil)
        assert(not V.MuteCall(-1, true), 'mute outside a call')

        V.Name = function() return 'pma-voice' end
        Channel['pma-voice'] = function() end
        V.SetCall(-4, 78)
        V.SetCall(-5, 78)
        V.MuteCall(-4, true)
        local heard = told[-5]
        V.SetCall(-4, nil)
        local after = told[-5]
        V.SetCall(-5, nil)
        assert(heard == '-4' and after == nil and told[-4] == nil, 'client mute list')
    end)
    restore()

    return ok, err
end
