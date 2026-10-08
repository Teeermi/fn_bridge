if not FN_BRIDGE.IsInventory('qb-inventory') then return end

FN_INVENTORY = {}

local function PlayerItems()
    if not FN_FRAMEWORK then return {} end

    local playerData = FN_FRAMEWORK.GetPlayerData()

    return playerData and playerData.items or {}
end

FN_INVENTORY.OpenInventory = function(inventory, data)
    if inventory == 'stash' then
        if data.owner then
            TriggerServerEvent('inventory:server:OpenInventory', 'stash', data.id..'_'..data.owner, {
                maxweight = 250000,
                slots = 100,
            })
            TriggerEvent('inventory:client:SetCurrentStash', data.id..'_'..data.owner)
        else
            TriggerServerEvent('fn_bridge/server/qb-inventory/openInventory', inventory, data)
        end
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
        TriggerServerEvent('fn_bridge/server/qb-inventory/openInventory', inventory, data)
    elseif inventory == 'player' then
        TriggerServerEvent('inventory:server:OpenInventory', 'otherplayer', data)
        TriggerEvent('inventory:client:SetCurrentStash', 'otherplayer')
    end
end

FN_INVENTORY.GetItemCount = function(itemName, metadata)
    local count = 0
    for _, rawItem in pairs(PlayerItems()) do
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
    local itemData = exports['qb-inventory']:GetItemInfo(itemName)
    if not itemData then return false end

    return { name = itemData.name, label = itemData.label, description = itemData.description, image = 'https://cfx-nui-qb-inventory/html/images/'..itemData.name..'.png' }
end

Config.DebugPrint('inventory adapter loaded: qb-inventory (client)')
