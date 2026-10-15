if not FN_BRIDGE.IsInventory('origen_inventory') then return end

FN_INVENTORY = {}

FN_INVENTORY.GetPlayerItems = function(playerId)
    local ok, inventory = pcall(function() return exports.origen_inventory:GetInventory(playerId) end)

    return FN_BRIDGE.NormalizeItems(ok and type(inventory) == 'table' and inventory.inventory or {})
end

FN_INVENTORY.CanCarry = function(playerId, itemName, count)
    local ok, result = pcall(function() return exports['origen_inventory']:canCarryItem(playerId, itemName, count or 1) end)

    return not ok or result ~= false
end

FN_INVENTORY.AddItem = function(playerId, itemName, count, metadata, slot)
    return exports.origen_inventory:addItem(playerId, itemName, count or 1, metadata, slot, false) and true or false
end

FN_INVENTORY.RemoveItem = function(playerId, itemName, count, metadata, slot)
    return exports.origen_inventory:removeItem(playerId, itemName, count or 1, metadata, slot, false) and true or false
end

FN_INVENTORY.GetItemCount = function(playerId, itemName, metadata)
    return tonumber(exports.origen_inventory:getItemCount(playerId, itemName, metadata, false)) or 0
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

FN_INVENTORY.SetMetadata = function(playerId, slot, metadata)
    local ok = pcall(function() exports.origen_inventory:setMetadata(playerId, slot, metadata) end)

    return ok
end

Config.DebugPrint('inventory adapter loaded: origen_inventory (server)')
