if not FN_BRIDGE.IsInventory('core_inventory') then return end

FN_INVENTORY = {}

local function Items(playerId)
    local items = {}
    for key, item in pairs(exports.core_inventory:getInventory(playerId) or {}) do
        if type(item) == 'table' then
            items[#items + 1] = { name = item.name, label = item.label, count = item.amount or item.count, metadata = item.metadata or item.info, slot = item.id or item.slot or key }
        end
    end

    return FN_BRIDGE.NormalizeItems(items)
end

FN_INVENTORY.GetPlayerItems = function(playerId)
    local ok, items = pcall(Items, playerId)

    return ok and items or {}
end

FN_INVENTORY.AddItem = function(playerId, itemName, count, metadata)
    return exports.core_inventory:addItem(playerId, itemName, count or 1, metadata) and true or false
end

FN_INVENTORY.RemoveItem = function(playerId, itemName, count, _, slot)
    if slot then return exports.core_inventory:removeItemExact(playerId, slot, count or 1) and true or false end

    exports.core_inventory:removeItem(playerId, itemName, count or 1)

    return true
end

FN_INVENTORY.GetItemCount = function(playerId, itemName, metadata)
    if not metadata then return tonumber(exports.core_inventory:getItemCount(playerId, itemName)) or 0 end

    local count = 0
    for _, item in ipairs(FN_INVENTORY.GetPlayerItems(playerId)) do
        if item.name == itemName and FN_BRIDGE.MetadataMatches(item.metadata, metadata) then count = count + item.count end
    end

    return count
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
    local ok = pcall(function() exports.core_inventory:setMetadata(playerId, slot, metadata) end)

    return ok
end

Config.DebugPrint('inventory adapter loaded: core_inventory (server)')
