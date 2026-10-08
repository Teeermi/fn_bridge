FN_NOTIFY = {}

FN_NOTIFY.Notify = function(playerId, message, messageType, time)
    playerId = tonumber(playerId)

    if not playerId or playerId == 0 then return print(message) end

    TriggerClientEvent('fn_bridge/client/notify', playerId, message, messageType or 'info', time or 5000, GetInvokingResource())
end

FN_NOTIFY.Chat = function(playerId, author, message, color)
    playerId = tonumber(playerId) or -1

    local chat = FN_BRIDGE.Setting('chat')
    if FN_BRIDGE.Callable(chat) then return chat(playerId, author, message, color) end

    TriggerClientEvent('chat:addMessage', playerId, { color = color, multiline = true, args = { author, message } })
end

Config.DebugPrint('notify adapter loaded: forwards to the client (server)')
