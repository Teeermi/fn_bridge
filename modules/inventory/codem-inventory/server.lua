if not FN_BRIDGE.IsInventory('codem-inventory') then return end

FN_INVENTORY = {}

FN_INVENTORY.GetPlayerItems = function(playerId)
    local player = FN_FRAMEWORK.GetPlayerFromId(playerId)
    if not player then return {} end

    return FN_BRIDGE.NormalizeItems(exports['codem-inventory']:GetInventory(player.identifier, playerId))
end

FN_INVENTORY.CanCarry = function(playerId, itemName, count)
    local ok, result = pcall(function() return exports['codem-inventory']:CanCarryItem(playerId, itemName, count or 1) end)

    return not ok or result ~= false
end

FN_INVENTORY.AddItem = function(playerId, itemName, count, metadata, slot)
    return exports['codem-inventory']:AddItem(playerId, itemName, count, slot, metadata) and true or false
end

FN_INVENTORY.RemoveItem = function(playerId, itemName, count, metadata, slot)
    if not slot and metadata then
        for _, item in ipairs(FN_INVENTORY.GetPlayerItems(playerId)) do
            if item.name == itemName and FN_BRIDGE.MetadataMatches(item.metadata, metadata) then
                slot = item.slot
                break
            end
        end

        if not slot then return false end
    end

    return exports['codem-inventory']:RemoveItem(playerId, itemName, count, slot) and true or false
end

FN_INVENTORY.GetItemCount = function(playerId, itemName, metadata)
    if not metadata then return exports['codem-inventory']:GetItemsTotalAmount(playerId, itemName) or 0 end

    local count = 0
    for _, item in ipairs(FN_INVENTORY.GetPlayerItems(playerId)) do
        if item.name == itemName and FN_BRIDGE.MetadataMatches(item.metadata, metadata) then
            count = count + item.count
        end
    end

    return count
end

FN_INVENTORY.HasItem = function(playerId, itemName, metadata)
    return FN_INVENTORY.GetItemCount(playerId, itemName, metadata) > 0
end

FN_INVENTORY.GetItemSlot = function(playerId, slot)
    return FN_BRIDGE.NormalizeItem(exports['codem-inventory']:GetItemBySlot(playerId, slot))
end

Config.DebugPrint('inventory adapter loaded: codem-inventory (server)')

FN_INVENTORY.SetMetadata = function(playerId, slot, metadata)
    local ok, result = pcall(function() return exports['codem-inventory']:SetItemMetadata(playerId, slot, metadata) end)

    return ok and result ~= false
end
