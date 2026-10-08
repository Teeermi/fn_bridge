if not FN_BRIDGE.IsInventory('tgiann-inventory') then return end

FN_INVENTORY = {}

FN_INVENTORY.OpenInventory = FN_BRIDGE.UnsupportedFunction('INVENTORY', 'OpenInventory', 'tgiann-inventory has no client open export')

FN_INVENTORY.GetItemCount = function(itemName)
    return exports['tgiann-inventory']:GetItemCount(itemName, nil, false) or 0
end

FN_INVENTORY.HasItem = function(itemName)
    return FN_INVENTORY.GetItemCount(itemName) > 0
end

FN_INVENTORY.GetItemData = function(itemName)
    local items = exports['tgiann-inventory']:GetItemList()
    local itemData = items and items[itemName]
    if not itemData then return false end

    return { name = itemName, label = itemData.label, description = itemData.description, image = 'https://cfx-nui-tgiann-inventory/html/images/'..itemName..'.png' }
end

Config.DebugPrint('inventory adapter loaded: tgiann-inventory (client)')
