if not FN_BRIDGE.IsInventory('ps-inventory') then return end

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
            TriggerServerEvent('fn_bridge/server/ps-inventory/openInventory', inventory, data)
        end
    elseif inventory == 'shop' then
        TriggerServerEvent('fn_bridge/server/ps-inventory/openInventory', inventory, data)
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
    local itemData = FN_FRAMEWORK and FN_FRAMEWORK.obj and FN_FRAMEWORK.obj.Shared and FN_FRAMEWORK.obj.Shared.Items[itemName]
    if not itemData then return false end

    return { name = itemName, label = itemData.label, description = itemData.description, image = 'https://cfx-nui-ps-inventory/html/images/'..itemName..'.png' }
end

Config.DebugPrint('inventory adapter loaded: ps-inventory (client)')
