if not FN_BRIDGE.IsInventory('fn_inventory') then return end

FN_INVENTORY = {}

local function Call(name, ...)
    local args = table.pack(...)
    local ok, a = pcall(function() return exports['fn_inventory'][name](exports['fn_inventory'], table.unpack(args, 1, args.n)) end)

    return ok and a or nil
end

FN_INVENTORY.OpenInventory = function(inventory, data)
    Call('Open', inventory, data)
end

FN_INVENTORY.GetItemCount = function(itemName, metadata)
    return tonumber(Call('GetItemCount', itemName, metadata)) or 0
end

FN_INVENTORY.HasItem = function(itemName, metadata)
    return FN_INVENTORY.GetItemCount(itemName, metadata) > 0
end

FN_INVENTORY.GetItemData = function(itemName)
    local item = Call('Items', itemName)
    if not item then return false end

    return { name = itemName, label = item.label, description = item.description, image = item.image or ('nui://fn_inventory/html/images/' .. itemName .. '.webp') }
end

FN_INVENTORY.GetPlayerItems = function()
    return FN_BRIDGE.NormalizeItems(Call('GetPlayerItems'))
end

Config.DebugPrint('inventory adapter loaded: fn_inventory (client)')
