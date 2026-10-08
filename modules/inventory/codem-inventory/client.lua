if not FN_BRIDGE.IsInventory('codem-inventory') then return end

FN_INVENTORY = {}

FN_INVENTORY.OpenInventory = function(inventory, data)
    if inventory == 'stash' then
        local stashId = data.owner and data.id..'_'..data.owner or data

        TriggerServerEvent('inventory:server:OpenInventory', 'stash', stashId, {
            maxweight = 250000,
            slots = 100,
        })
    elseif inventory == 'player' then
        TriggerEvent('codem-inventory:client:openplayerinventory', data)
    elseif inventory == 'shop' then
        TriggerEvent('codem-inventory:openshop', data.type)
    end
end

FN_INVENTORY.GetItemCount = function(itemName, metadata)
    local count = 0
    for _, rawItem in pairs(exports['codem-inventory']:getUserInventory() or {}) do
        local item = FN_BRIDGE.NormalizeItem(rawItem)
        if item and item.name == itemName and FN_BRIDGE.MetadataMatches(item.metadata, metadata) then
            count = count + item.count
        end
    end

    return count
end

FN_INVENTORY.HasItem = function(itemName, metadata)
    return FN_INVENTORY.GetItemCount(itemName, metadata) > 0
end

FN_INVENTORY.GetItemData = function(itemName)
    local items = exports['codem-inventory']:GetItemList()
    local itemData = items and items[itemName]
    if not itemData then return false end

    return { name = itemData.name, label = itemData.label, description = itemData.description, image = 'https://cfx-nui-codem-inventory/html/itemimages/'..itemData.name..'.png' }
end

Config.DebugPrint('inventory adapter loaded: codem-inventory (client)')
