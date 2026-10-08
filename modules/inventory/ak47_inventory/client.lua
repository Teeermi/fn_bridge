if not FN_BRIDGE.IsInventory('ak47_inventory') then return end

FN_INVENTORY = {}

FN_INVENTORY.OpenInventory = function(inventory, data)
    exports['ak47_inventory']:OpenInventory(data)
end

FN_INVENTORY.GetItemCount = function(itemName, metadata)
    return exports['ak47_inventory']:Search('amount', itemName, metadata) or 0
end

FN_INVENTORY.HasItem = function(itemName, metadata)
    return FN_INVENTORY.GetItemCount(itemName, metadata) > 0
end

FN_INVENTORY.GetItemData = function(itemName)
    local itemData = exports['ak47_inventory']:Items(itemName)
    if not itemData then return false end

    return { name = itemData.name, label = itemData.label, description = itemData.description, image = 'https://cfx-nui-ak47-inventory/web/images/'..itemData.name..'.png' }
end

Config.DebugPrint('inventory adapter loaded: ak47_inventory (client)')
