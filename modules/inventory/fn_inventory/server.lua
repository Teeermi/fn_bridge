if not FN_BRIDGE.IsInventory('fn_inventory') then return end

FN_INVENTORY = {}

local function Call(name, ...)
    local args = table.pack(...)
    local ok, a, b = pcall(function() return exports['fn_inventory'][name](exports['fn_inventory'], table.unpack(args, 1, args.n)) end)
    if not ok then return nil end

    return a, b
end

FN_INVENTORY.GetPlayerItems = function(playerId)
    return FN_BRIDGE.NormalizeItems(Call('GetPlayerItems', playerId))
end

FN_INVENTORY.AddItem = function(playerId, itemName, count, metadata, slot)
    return Call('AddItem', playerId, itemName, count, metadata, slot) and true or false
end

FN_INVENTORY.RemoveItem = function(playerId, itemName, count, metadata, slot)
    return Call('RemoveItem', playerId, itemName, count, metadata, slot) and true or false
end

FN_INVENTORY.GetItemCount = function(playerId, itemName, metadata)
    return tonumber(Call('GetItemCount', playerId, itemName, metadata)) or 0
end

FN_INVENTORY.HasItem = function(playerId, itemName, metadata)
    return FN_INVENTORY.GetItemCount(playerId, itemName, metadata) > 0
end

FN_INVENTORY.GetItemSlot = function(playerId, slot)
    return FN_BRIDGE.NormalizeItem(Call('GetSlot', playerId, slot))
end

FN_INVENTORY.SetMetadata = function(playerId, slot, metadata)
    return Call('SetMetadata', playerId, slot, metadata) and true or false
end

FN_INVENTORY.CustomDrop = function(prefix, items, coords, slots, maxWeight, instance, model)
    return Call('CustomDrop', prefix, items, coords, slots, maxWeight, instance, model)
end

FN_INVENTORY.CreateShop = function(shopName, data)
    Call('RegisterShop', shopName, data)
end

FN_INVENTORY.CanCarry = function(playerId, itemName, count, metadata)
    return Call('CanCarryItem', playerId, itemName, count or 1, metadata) ~= false
end

FN_INVENTORY.GetMaxWeight = function(playerId)
    local _, max = Call('GetWeight', playerId)

    return tonumber(max) or false
end

FN_INVENTORY.SetMaxWeight = function()
    return false
end

FN_INVENTORY.ItemExists = function(itemName)
    return Call('Items', itemName) ~= nil
end

Config.DebugPrint('inventory adapter loaded: fn_inventory (server)')
