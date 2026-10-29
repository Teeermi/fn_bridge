CreateThread(function()
    local native = {
        giveInventoryItem = vRP.giveInventoryItem,
        tryGetInventoryItem = vRP.tryGetInventoryItem,
        getInventoryItemAmount = vRP.getInventoryItemAmount,
        getInventory = vRP.getInventory,
    }

    local function Call(name, userId, ...)
        if GetResourceState('fn_bridge') ~= 'started' then return false end
        local src = tonumber(vRP.getUserSource(userId))
        if not src then return false end
        local args = table.pack(...)
        local ok, handled, result = pcall(function() return exports.fn_bridge:InventoryCall(name, src, table.unpack(args, 1, args.n)) end)
        if not ok or not handled then return false end

        return true, result
    end

    vRP.fnBridgeInventory = function()
        return true
    end

    vRP.giveInventoryItem = function(userId, itemName, amount, ...)
        local handled = Call('AddItem', userId, itemName, tonumber(amount) or 1)
        if not handled then return native.giveInventoryItem(userId, itemName, amount, ...) end
    end

    vRP.tryGetInventoryItem = function(userId, itemName, amount, ...)
        local handled, result = Call('RemoveItem', userId, itemName, tonumber(amount) or 1)
        if not handled then return native.tryGetInventoryItem(userId, itemName, amount, ...) end

        return result == true
    end

    vRP.getInventoryItemAmount = function(userId, itemName, ...)
        local handled, result = Call('GetItemCount', userId, itemName)
        if not handled then return native.getInventoryItemAmount(userId, itemName, ...) end

        return tonumber(result) or 0
    end

    vRP.getInventory = function(userId, ...)
        local handled, result = Call('GetPlayerItems', userId)
        if not handled then return native.getInventory(userId, ...) end
        local inventory = {}
        for _, item in ipairs(type(result) == 'table' and result or {}) do
            local entry = inventory[item.name] or { amount = 0 }
            entry.amount = entry.amount + (tonumber(item.count) or 0)
            inventory[item.name] = entry
        end

        return inventory
    end
end)
