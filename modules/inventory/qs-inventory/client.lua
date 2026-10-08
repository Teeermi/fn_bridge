if not FN_BRIDGE.IsInventory('qs-inventory') then return end

FN_INVENTORY = {}

FN_INVENTORY.OpenInventory = function(inventory, data)
    if inventory == 'stash' then
        local stashId = data.owner and data.id..'_'..data.owner or data.id or data

        TriggerServerEvent('inventory:server:OpenInventory', 'stash', stashId, {
            maxweight = 250000,
            slots = 100,
        })
        TriggerEvent('inventory:client:SetCurrentStash', stashId)
    elseif inventory == 'shop' then
        if not data.label then
            data.label = data.type
        end

        if data.items then
            for i = 1, #data.items, 1 do
                data.items[i].slot = i
                if not data.items[i].amount then
                    data.items[i].amount = 1000
                end
                if not data.items[i].price then
                    data.items[i].price = 0
                end
            end
        end
        TriggerServerEvent('inventory:server:OpenInventory', 'shop', data.type..'_'..data.id, {
            label = data.label,
            items = data.items,
        })
    elseif inventory == 'player' then
        TriggerServerEvent('inventory:server:OpenInventory', 'otherplayer', data)
        TriggerEvent('inventory:client:SetCurrentStash', 'otherplayer')
    end
end

FN_INVENTORY.GetItemCount = function(itemName, metadata)
    if metadata then Config.DebugPrint('qs-inventory cannot filter by metadata on the client, counting by name only') end

    return exports['qs-inventory']:Search(itemName) or 0
end

FN_INVENTORY.HasItem = function(itemName, metadata)
    return FN_INVENTORY.GetItemCount(itemName, metadata) > 0
end

FN_INVENTORY.GetItemData = function(itemName)
    local items = exports['qs-inventory']:GetItemList()
    local itemData = items and items[itemName]
    if not itemData then return false end

    return { name = itemName, label = itemData.label, description = itemData.description, image = 'https://cfx-nui-qs-inventory/html/images/'..itemName..'.png' }
end

Config.DebugPrint('inventory adapter loaded: qs-inventory (client)')
