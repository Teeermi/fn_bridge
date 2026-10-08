if not FN_BRIDGE.IsInventory('qs-inventory') then return end

FN_INVENTORY = {}

FN_INVENTORY.GetPlayerItems = function(playerId)
    return FN_BRIDGE.NormalizeItems(exports['qs-inventory']:GetInventory(playerId))
end

FN_INVENTORY.AddItem = function(playerId, itemName, count, metadata, slot)
    return exports['qs-inventory']:AddItem(playerId, itemName, count, slot, metadata) and true or false
end

FN_INVENTORY.RemoveItem = function(playerId, itemName, count, metadata, slot)
    return exports['qs-inventory']:RemoveItem(playerId, itemName, count, slot, metadata) and true or false
end

FN_INVENTORY.GetItemCount = function(playerId, itemName, metadata)
    if not metadata then return exports['qs-inventory']:GetItemTotalAmount(playerId, itemName) or 0 end

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
    for _, item in ipairs(FN_INVENTORY.GetPlayerItems(playerId)) do
        if item.slot == slot then return item end
    end

    return false
end

Config.DebugPrint('inventory adapter loaded: qs-inventory (server)')

FN_INVENTORY.CanCarry = function(playerId, itemName, count)
    local ok, result = pcall(function() return exports['qs-inventory']:CanCarryItem(playerId, itemName, count or 1) end)

    return not ok or result ~= false
end

FN_INVENTORY.SetMetadata = function(playerId, slot, metadata)
    local ok = pcall(function() exports['qs-inventory']:SetItemMetadata(playerId, slot, metadata) end)

    return ok
end
