GlobalState.fn_playerPed
GlobalState.fn_playerId
GlobalState.fn_serverId
GlobalState.fn_isDead
GlobalState.fn_vehicle
GlobalState.fn_vehicleDriver
GlobalState.fn_playerCoords
GlobalState.fn_playerWeapon
GlobalState.fn_jobCounter

local policeOnline = GlobalState.fn_jobCounter?.police or 0

AddStateBagChangeHandler('fn_jobCounter', 'global', function(bagName, key, value)

end)

RegisterNetEvent("fn_bridge/client/updatePlayerData", function(playerData)
    
end)

AddEventHandler("fn_bridge/client/isDead", function(isDead)

end)

AddEventHandler("fn_bridge/client/onVehicleEnter", function(vehicle, isDriver)

end)

AddEventHandler("fn_bridge/client/onVehicleLeave", function(vehicle, wasDriver)

end)

AddEventHandler("fn_bridge/server/playerLoaded", function(playerId, player)

end)

AddEventHandler("fn_bridge/server/onJobChange", function(playerId, job, lastJob)

end)

AddEventHandler("fn_bridge/server/jobCountChanged", function(jobName, count, previous)

end)

FN_BRIDGE.FRAMEWORK.GetCounter('police')
FN_BRIDGE.FRAMEWORK.GetJobPlayerCount('police')
FN_BRIDGE.FRAMEWORK.GetPlayerJobEntry(playerId)

for _, entry in ipairs(FN_BRIDGE.FRAMEWORK.GetJobPlayers('police')) do
    print(entry.source, entry.identifier, entry.charId, entry.grade, entry.grade_label, entry.onDuty)
end

local items = FN_BRIDGE.INVENTORY.GetPlayerItems(playerId)
for _, item in ipairs(items) do
    print(item.name, item.label, item.count, item.slot, json.encode(item.metadata))
end

FN_BRIDGE.INVENTORY.AddItem(playerId, 'water', 1, nil, nil)
FN_BRIDGE.INVENTORY.RemoveItem(playerId, 'water', 1, nil, nil)
FN_BRIDGE.INVENTORY.GetItemCount(playerId, 'water')
FN_BRIDGE.INVENTORY.HasItem(playerId, 'water')
FN_BRIDGE.INVENTORY.GetItemSlot(playerId, 1)

FN_BRIDGE.INVENTORY.OpenInventory('stash', { id = 'garage', owner = 'char1:abc' })
FN_BRIDGE.INVENTORY.GetItemCount('water')
FN_BRIDGE.INVENTORY.HasItem('water')
FN_BRIDGE.INVENTORY.GetItemData('water')

FN_BRIDGE.HELPER.RegisterCommand('givecrate', { 'admin' }, function(playerId, args)
    FN_BRIDGE.INVENTORY.AddItem(tonumber(args[1]), 'crate', 1)
end, false, { help = 'Give a crate to a player', params = { { name = 'id', help = 'server id' } } })

local netId = FN_BRIDGE.HELPER.GetNetIdFromEntity(entity)
local entity = FN_BRIDGE.HELPER.GetEntityFromNetId(netId)
