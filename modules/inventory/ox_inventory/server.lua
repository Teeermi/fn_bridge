if not FN_BRIDGE.IsInventory('ox_inventory') then return end

FN_INVENTORY = {}

FN_INVENTORY.GetPlayerItems = function(playerId)
    return FN_BRIDGE.NormalizeItems(exports['ox_inventory']:GetInventoryItems(playerId))
end

FN_INVENTORY.AddItem = function(playerId, itemName, count, metadata, slot)
    return exports['ox_inventory']:AddItem(playerId, itemName, count, metadata, slot) and true or false
end

FN_INVENTORY.RemoveItem = function(playerId, itemName, count, metadata, slot)
    return exports['ox_inventory']:RemoveItem(playerId, itemName, count, metadata, slot) and true or false
end

FN_INVENTORY.GetItemCount = function(playerId, itemName, metadata)
    return FN_BRIDGE.NormalizeCount(exports['ox_inventory']:Search(playerId, 'count', itemName, metadata), itemName)
end

FN_INVENTORY.HasItem = function(playerId, itemName, metadata)
    return FN_INVENTORY.GetItemCount(playerId, itemName, metadata) > 0
end

FN_INVENTORY.GetItemSlot = function(playerId, slot)
    return FN_BRIDGE.NormalizeItem(exports['ox_inventory']:GetSlot(playerId, slot))
end

FN_INVENTORY.SetMetadata = function(playerId, slot, metadata)
    return exports['ox_inventory']:SetMetadata(playerId, slot, metadata) and true or false
end

FN_INVENTORY.CustomDrop = function(prefix, items, coords, slots, maxWeight, instance, model)
    return exports['ox_inventory']:CustomDrop(prefix, items, coords, slots, maxWeight, instance, model)
end

FN_INVENTORY.CreateShop = function(shopName, data)
    exports['ox_inventory']:RegisterShop(shopName, data)
end

Config.DebugPrint('inventory adapter loaded: ox_inventory (server)')

FN_INVENTORY.CanCarry = function(playerId, itemName, count, metadata)
    local ok, result = pcall(function() return exports['ox_inventory']:CanCarryItem(playerId, itemName, count or 1, metadata) end)

    return ok and result ~= false
end

FN_INVENTORY.GetMaxWeight = function(playerId)
    local ok, inventory = pcall(function() return exports['ox_inventory']:GetInventory(playerId) end)

    return ok and type(inventory) == 'table' and tonumber(inventory.maxWeight) or false
end

FN_INVENTORY.SetMaxWeight = function(playerId, grams)
    local ok = pcall(function() exports['ox_inventory']:SetMaxWeight(playerId, math.floor(grams)) end)

    return ok
end

FN_INVENTORY.ItemExists = function(itemName)
    local ok, item = pcall(function() return exports['ox_inventory']:Items(itemName) end)

    return not ok or item ~= nil
end
