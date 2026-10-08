FN_VOICE = {}

FN_VOICE.Name = function()
    if GetResourceState('pma-voice') == 'started' then return 'pma-voice' end
    if GetResourceState('saltychat') == 'started' then return 'saltychat' end

    return false
end

FN_VOICE.GetRadio = function(playerId)
    playerId = tonumber(playerId)
    local name = FN_VOICE.Name()
    if not playerId or not name or not GetPlayerName(playerId) then return false end
    if name == 'pma-voice' then return math.floor(tonumber(Player(playerId).state.radioChannel) or 0) end

    local ok, channel = pcall(function() return exports.saltychat:GetPlayerRadioChannel(playerId, true) end)

    return ok and tonumber(channel) or 0
end

FN_VOICE.SetRadio = function(playerId, channel)
    playerId, channel = tonumber(playerId), tonumber(channel)
    local name = FN_VOICE.Name()
    if not playerId or not channel or channel < 0 or channel > 100000 or not name or not GetPlayerName(playerId) then return false end

    if name == 'pma-voice' then
        return pcall(function() exports['pma-voice']:setPlayerRadio(playerId, channel) end)
    end

    return pcall(function()
        local current = exports.saltychat:GetPlayerRadioChannel(playerId, true)
        if current and current ~= '' then exports.saltychat:RemovePlayerRadioChannel(playerId, current) end
        if channel > 0 then exports.saltychat:SetPlayerRadioChannel(playerId, tostring(channel), true) end
    end)
end
