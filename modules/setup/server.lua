if not Config.Setup or not Config.Setup.command then return end

CreateThread(function()
    while not FN_FRAMEWORK do Wait(100) end

    FN_HELPER.RegisterCommand(Config.Setup.command, Config.AdminGroups, function(playerId)
        TriggerClientEvent('fn_bridge/client/setup', playerId)
    end, false, { help = 'Place coordinates in the world and copy them to your clipboard' })
end)

Config.DebugPrint('setup tool loaded: /'..tostring(Config.Setup.command)..' (server)')
