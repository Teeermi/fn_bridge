if not FN_INVENTORY then return end

local function Missing(items)
    local missing = {}
    for _, item in ipairs(items) do
        if not FN_INVENTORY.ItemExists(item.name) then missing[#missing + 1] = item.name end
    end

    return missing
end

FN_INVENTORY.DefineItems = function(items)
    items = type(items) == 'table' and items or {}

    if FN_BRIDGE.IsFramework('qb') and not FN_BRIDGE.IsInventory('ox_inventory') then
        for _, item in ipairs(items) do
            pcall(function()
                exports['qb-core']:AddItem(item.name, { name = item.name, label = item.label, weight = item.weight or 0, type = 'item', image = item.name .. '.png', unique = item.unique == true, useable = item.use == true, shouldClose = true, description = item.description or item.desc or '' })
            end)
        end

        return { kind = 'qb', missing = {} }
    end

    if FN_BRIDGE.IsFramework('esx') and not FN_BRIDGE.inventoryName and FN_DB.HasTable('items') then
        local added = 0
        for _, item in ipairs(items) do
            added = added + (MySQL.update.await('INSERT IGNORE INTO items (name, label, weight) VALUES (?, ?, ?)', { item.name, tostring(item.label):sub(1, 50), 1 }) or 0)
        end

        return { kind = 'esx', missing = {}, added = added, restart = added > 0 }
    end

    return { kind = FN_BRIDGE.inventoryName or FN_BRIDGE.frameworkName, missing = Missing(items) }
end
