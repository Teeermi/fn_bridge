if not FN_BRIDGE.IsInventory('ox_inventory') then return end

FN_INVENTORY = {}

FN_INVENTORY.OpenInventory = function(inventory, data)
    exports['ox_inventory']:openInventory(inventory, data)
end

FN_INVENTORY.GetItemCount = function(itemName, metadata)
    return FN_BRIDGE.NormalizeCount(exports['ox_inventory']:Search('count', itemName, metadata), itemName)
end

FN_INVENTORY.HasItem = function(itemName, metadata)
    return FN_INVENTORY.GetItemCount(itemName, metadata) > 0
end

FN_INVENTORY.GetItemData = function(itemName)
    local itemData = exports['ox_inventory']:Items(itemName)
    if not itemData then return false end

    return { name = itemData.name, label = itemData.label, description = itemData.description, image = 'https://cfx-nui-ox_inventory/web/images/'..itemData.name..'.png' }
end

FN_INVENTORY.GetPlayerItems = function()
    return FN_BRIDGE.NormalizeItems(exports['ox_inventory']:GetPlayerItems())
end

Config.DebugPrint('inventory adapter loaded: ox_inventory (client)')
