local I = FN_INVENTORY
if not I then return end

local Ox, Qb = FN_BRIDGE.IsInventory('ox_inventory') or FN_BRIDGE.IsInventory('fn_inventory'), FN_BRIDGE.IsInventory('qb-inventory')
local OxRes = FN_BRIDGE.IsInventory('fn_inventory') and 'fn_inventory' or 'ox_inventory'
local Stashes, Hooks, Usable = {}, {}, {}

local function Id(value)
    return type(value) == 'string' and #value <= 64 and value:match('^[%w_%-:%.]+$') and value or nil
end

local function Count(value)
    value = math.floor(tonumber(value) or 0)

    return value > 0 and value or nil
end

local function Export(resource, name, ...)
    local args = table.pack(...)
    local ok, result = pcall(function() return exports[resource][name](exports[resource], table.unpack(args, 1, args.n)) end)

    return ok and result or nil, ok
end

local function Allowed(playerId, stash)
    if not stash then return false end

    if type(stash.owner) == 'string' and stash.owner ~= FN_FRAMEWORK.GetIdentifier(playerId) then return false end
    if type(stash.groups) ~= 'table' or next(stash.groups) == nil then return true end

    local job, gang = FN_BRIDGE.FRAMEWORK.GetJob(playerId), FN_BRIDGE.FRAMEWORK.GetGang(playerId)
    for _, group in ipairs({ job, gang }) do
        local need = group and tonumber(stash.groups[group.name])
        if need and (group.grade or 0) >= need then return true end
    end

    return false
end

FN_STASH = {
    CanOpen = function(playerId, kind, data)
        if kind == 'player' then
            local target = tonumber(data)
            local a, b = GetPlayerPed(playerId), target and GetPlayerPed(target) or 0
            return target and a ~= 0 and b ~= 0 and #(GetEntityCoords(a) - GetEntityCoords(b)) <= 3.0 and target or false
        end

        local id = Id(type(data) == 'table' and data.id or data)

        return id and Allowed(playerId, Stashes[id]) and id or false
    end,
    Data = function(id)
        local stash = Stashes[id] or {}

        return { label = stash.label, maxweight = stash.weight, slots = stash.slots }
    end,
}

if Ox or Qb then
    I.RegisterStash = function(id, opts)
        id, opts = Id(id), type(opts) == 'table' and opts or {}
        if not id then return false end

        local stash = {
            label = type(opts.label) == 'string' and opts.label:sub(1, 64) or id,
            slots = math.min(math.max(math.floor(tonumber(opts.slots) or 50), 1), 500),
            weight = math.max(math.floor(tonumber(opts.weight) or 100000), 1),
            owner = (type(opts.owner) == 'string' or opts.owner == true) and opts.owner or nil,
            groups = type(opts.groups) == 'table' and opts.groups or nil,
        }
        Stashes[id] = stash

        if Ox then return select(2, Export(OxRes, 'RegisterStash', id, stash.label, stash.slots, stash.weight, stash.owner, stash.groups, opts.coords)) end

        return select(2, Export('qb-inventory', 'CreateInventory', id, { label = stash.label, maxweight = stash.weight, slots = stash.slots }))
    end

    I.GetStashItems = function(id)
        id = Id(id)
        if not id then return {} end
        if Ox then return FN_BRIDGE.NormalizeItems(Export(OxRes, 'GetInventoryItems', id)) end

        Export('qb-inventory', 'CreateInventory', id, FN_STASH.Data(id))
        local inventory = Export('qb-inventory', 'GetInventory', id)

        return FN_BRIDGE.NormalizeItems(type(inventory) == 'table' and inventory.items)
    end

    I.AddStashItem = function(id, itemName, count, metadata)
        id, count = Id(id), Count(count)
        if not id or not count or type(itemName) ~= 'string' then return false end
        if Ox then return Export(OxRes, 'AddItem', id, itemName, count, metadata) and true or false end

        Export('qb-inventory', 'CreateInventory', id, FN_STASH.Data(id))

        return Export('qb-inventory', 'AddItem', id, itemName, count, false, metadata, 'fn_bridge') and true or false
    end

    I.RemoveStashItem = function(id, itemName, count, metadata)
        id, count = Id(id), Count(count)
        if not id or not count or type(itemName) ~= 'string' then return false end
        if Ox then return Export(OxRes, 'RemoveItem', id, itemName, count, metadata) and true or false end

        local slot
        for _, item in ipairs(I.GetStashItems(id)) do
            if item.name == itemName and item.count >= count and FN_BRIDGE.MetadataMatches(item.metadata, metadata) then
                slot = item.slot
                break
            end
        end

        return slot and Export('qb-inventory', 'RemoveItem', id, itemName, count, slot, 'fn_bridge') and true or false
    end

    I.ClearStash = function(id)
        id = Id(id)
        if not id then return false end
        if Ox then return select(2, Export(OxRes, 'ClearInventory', id)) end

        Export('qb-inventory', 'CreateInventory', id, FN_STASH.Data(id))

        return select(2, Export('qb-inventory', 'ClearStash', id))
    end

    I.OpenStash = function(playerId, id)
        playerId, id = tonumber(playerId), Id(id)
        if not playerId or not id or not GetPlayerName(playerId) then return false end
        if Ox then return select(2, Export(OxRes, 'forceOpenInventory', playerId, 'stash', id)) end

        return select(2, Export('qb-inventory', 'OpenInventory', playerId, id, FN_STASH.Data(id)))
    end
end

local function Track(id)
    local resource = GetInvokingResource() or FN_BRIDGE.resourceName
    Hooks[resource] = Hooks[resource] or {}
    table.insert(Hooks[resource], id)
end

if Ox then
    I.OnStash = function(prefix, cb)
        if (prefix ~= nil and not Id(prefix)) or not FN_BRIDGE.Callable(cb) then return false end

        local id = Export(OxRes, 'registerHook', 'swapItems', function(p)
            local put = p.toType == 'stash'
            local stash = put and p.toInventory or p.fromType == 'stash' and p.fromInventory or nil
            if type(stash) ~= 'string' or (prefix and stash:sub(1, #prefix) ~= prefix) then return end

            local item = type(p.fromSlot) == 'table' and p.fromSlot or {}
            pcall(cb, { playerId = p.source, stash = stash, action = put and 'put' or 'take', item = item.name, count = tonumber(p.count) or item.count, metadata = item.metadata })
        end, prefix and { inventoryFilter = { '^' .. prefix:gsub('[%-%.]', '%%%0') } } or {})
        if not id then return false end

        Track(id)

        return true
    end

    I.OnShopBuy = function(cb)
        if not FN_BRIDGE.Callable(cb) then return false end

        local id = Export(OxRes, 'registerHook', 'buyItem', function(p)
            pcall(cb, { playerId = p.source, shop = p.shopType, item = p.itemName, count = p.count, price = p.totalPrice or p.price, currency = p.currency or 'money' })
        end, {})
        if not id then return false end

        Track(id)

        return true
    end
end

I.RegisterUsable = function(itemName, predicate, onUse)
    local handler = type(predicate) == 'string' and onUse
    if handler then predicate, onUse = nil, nil end
    if type(itemName) ~= 'string' or itemName == '' then return false end
    if not (handler and FN_BRIDGE.Callable(handler)) and not (FN_BRIDGE.Callable(predicate) and FN_BRIDGE.Callable(onUse)) then return false end

    local resource = GetInvokingResource() or FN_BRIDGE.resourceName
    local list = Usable[itemName]
    if not list then
        list = {}
        Usable[itemName] = list
        FN_FRAMEWORK.RegisterUsableItem(itemName, function(player, item)
            local playerId = type(player) == 'table' and tonumber(player.source)
            if not playerId then return end

            for _, entry in ipairs(Usable[itemName]) do
                if entry.handler then
                    local ok, done = pcall(entry.handler, playerId, item)
                    if ok and done then return end
                else
                    local ok, yes = pcall(entry.predicate, playerId, item)
                    if ok and yes then return pcall(entry.onUse, playerId, item) end
                end
            end
        end)
    end

    for i = #list, 1, -1 do
        if list[i].resource == resource then table.remove(list, i) end
    end
    list[#list + 1] = { resource = resource, predicate = predicate, onUse = onUse, handler = handler or nil }

    return true
end

FN_STASH.Release = function(resource)
    for _, id in ipairs(Hooks[resource] or {}) do Export(OxRes, 'removeHooks', id) end
    Hooks[resource] = nil
end

AddEventHandler('onResourceStop', function(resource)
    FN_STASH.Release(resource)

    for _, list in pairs(Usable) do
        for i = #list, 1, -1 do
            if list[i].resource == resource then table.remove(list, i) end
        end
    end
end)
