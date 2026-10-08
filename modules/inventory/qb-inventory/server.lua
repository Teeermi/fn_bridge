if not FN_BRIDGE.IsInventory('qb-inventory') then return end

FN_INVENTORY = {}

RegisterServerEvent('fn_bridge/server/qb-inventory/openInventory', function(inventory, data)
    local _source = source
    if inventory == 'shop' then
        exports['qb-inventory']:OpenShop(_source, type(data) == 'table' and data.type or nil)
        return
    end

    local allowed = FN_STASH and FN_STASH.CanOpen(_source, inventory, data)
    if not allowed then return end

    if inventory == 'player' then
        exports['qb-inventory']:OpenInventoryById(_source, allowed)
    else
        exports['qb-inventory']:OpenInventory(_source, allowed, FN_STASH.Data(allowed))
    end
end)

FN_INVENTORY.GetPlayerItems = function(playerId)
    local inventory = exports['qb-inventory']:GetInventory(playerId)

    return FN_BRIDGE.NormalizeItems(inventory and inventory.items)
end

FN_INVENTORY.AddItem = function(playerId, itemName, count, metadata, slot)
    return exports['qb-inventory']:AddItem(playerId, itemName, count, slot, metadata) and true or false
end

FN_INVENTORY.RemoveItem = function(playerId, itemName, count, metadata, slot)
    if not slot and metadata then
        for _, item in ipairs(FN_INVENTORY.GetPlayerItems(playerId)) do
            if item.name == itemName and FN_BRIDGE.MetadataMatches(item.metadata, metadata) then
                slot = item.slot
                break
            end
        end

        if not slot then return false end
    end

    return exports['qb-inventory']:RemoveItem(playerId, itemName, count, slot) and true or false
end

FN_INVENTORY.GetItemCount = function(playerId, itemName, metadata)
    if not metadata then return exports['qb-inventory']:GetItemCount(playerId, itemName) or 0 end

    local count = 0
    for _, item in ipairs(FN_INVENTORY.GetPlayerItems(playerId)) do
        if item.name == itemName and FN_BRIDGE.MetadataMatches(item.metadata, metadata) then
            count = count + item.count
        end
    end

    return count
end

FN_INVENTORY.HasItem = function(playerId, itemName, metadata)
    return FN_INVENTORY.GetItemCount(playerId, itemName, metadata) > 0
end

FN_INVENTORY.GetItemSlot = function(playerId, slot)
    return FN_BRIDGE.NormalizeItem(exports['qb-inventory']:GetItemBySlot(playerId, slot))
end

local registeredShops = {}

FN_INVENTORY.CreateShop = function(shopName, data)
    if registeredShops[shopName] then return true end
    registeredShops[shopName] = true

    local repackedShopItems = {}
    for _, v in pairs(data.inventory) do
        table.insert(repackedShopItems, { name = v.name, price = v.price, amount = v.count or 1000 })
    end

    exports['qb-inventory']:CreateShop({
        name = shopName,
        label = data.label,
        slots = #repackedShopItems,
        items = repackedShopItems,
    })

    return true
end

Config.DebugPrint('inventory adapter loaded: qb-inventory (server)')

FN_INVENTORY.CanCarry = function(playerId, itemName, count)
    local ok, result = pcall(function() return exports['qb-inventory']:CanAddItem(playerId, itemName, count or 1) end)

    return not ok or result ~= false
end

FN_INVENTORY.SetMetadata = function(playerId, slot, metadata)
    local player = FN_FRAMEWORK.RawPlayer(playerId)
    local items = player and player.PlayerData.items
    local item = items and items[slot]
    if not item then return false end

    item.info = metadata
    player.Functions.SetInventory(items)

    return true
end
