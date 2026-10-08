local Mirrored = { ox = true, vrp = true, standalone = true }
if not Mirrored[FN_BRIDGE.frameworkName] then return end

local function Snapshot(playerId)
    local player = FN_FRAMEWORK.GetPlayerFromId(playerId)
    if not player then return nil end

    return {
        identifier = player.identifier,
        name = player.getName(),
        group = player.group,
        job = FN_FRAMEWORK.GetJob(playerId) or player.job,
    }
end

local function Push(playerId)
    TriggerClientEvent('fn_bridge/client/mirror', playerId, Snapshot(playerId))
end

AddEventHandler('fn_bridge/server/playerLoaded', Push)
AddEventHandler('fn_bridge/server/onJobChange', Push)

lib.callback.register('fn_bridge/server/mirror', function(source)
    return Snapshot(source)
end)
