if not FN_BRIDGE.IsInventory('ak47_inventory') then return end

FN_INVENTORY = {}

FN_INVENTORY.GetPlayerItems = function(playerId)
    return FN_BRIDGE.NormalizeItems(exports['ak47_inventory']:GetInventoryItems(playerId))
end

FN_INVENTORY.AddItem = function(playerId, itemName, count, metadata, slot)
    return exports['ak47_inventory']:AddItem(playerId, itemName, count, slot, metadata) and true or false
end

FN_INVENTORY.RemoveItem = function(playerId, itemName, count, metadata, slot)
    return exports['ak47_inventory']:RemoveItem(playerId, itemName, count, slot, metadata) and true or false
end

FN_INVENTORY.GetItemCount = function(playerId, itemName, metadata)
    return exports['ak47_inventory']:GetAmount(playerId, itemName, metadata) or 0
end

FN_INVENTORY.HasItem = function(playerId, itemName, metadata)
    return FN_INVENTORY.GetItemCount(playerId, itemName, metadata) > 0
end

FN_INVENTORY.GetItemSlot = function(playerId, slot)
    return FN_BRIDGE.NormalizeItem(exports['ak47_inventory']:GetSlot(playerId, slot))
end

Config.DebugPrint('inventory adapter loaded: ak47_inventory (server)')
