if FN_BRIDGE.inventoryName then return end

if FN_FRAMEWORK and FN_FRAMEWORK.NativeInventory then
    FN_INVENTORY = FN_FRAMEWORK.NativeInventory
    Config.DebugPrint('inventory adapter loaded: '..FN_BRIDGE.frameworkName..' native (server)')
    return
end

FN_INVENTORY = {}

local NoFrameworkInventory = not FN_BRIDGE.IsFramework('esx') and not FN_BRIDGE.IsFramework('qb')

local function UnsupportedWithoutInventory(key)
    return FN_BRIDGE.UnsupportedFunction('INVENTORY', key, FN_BRIDGE.frameworkName..' has no framework inventory fn_bridge can use, install a supported inventory')
end

local function EsxPlayer(playerId)
    return FN_FRAMEWORK and FN_FRAMEWORK.RawPlayer and FN_FRAMEWORK.RawPlayer(playerId)
end

local function QbPlayer(playerId)
    local frameworkObject = FN_FRAMEWORK and FN_FRAMEWORK.obj
    if not frameworkObject then return nil end

    return frameworkObject.Functions.GetPlayer(playerId)
end

local function RawItems(playerId)
    if FN_BRIDGE.IsFramework('esx') then
        local xPlayer = EsxPlayer(playerId)

        return FN_FRAMEWORK.Call(xPlayer, 'getInventory') or {}
    end

    local player = QbPlayer(playerId)

    return player and player.PlayerData.items or {}
end

FN_INVENTORY.GetPlayerItems = function(playerId)
    if NoFrameworkInventory then return {} end

    return FN_BRIDGE.NormalizeItems(RawItems(playerId))
end

FN_INVENTORY.AddItem = function(playerId, itemName, count, metadata, slot)
    if NoFrameworkInventory then return UnsupportedWithoutInventory('AddItem')() end

    if FN_BRIDGE.IsFramework('esx') then
        local xPlayer = EsxPlayer(playerId)
        return select(2, FN_FRAMEWORK.Call(xPlayer, 'addInventoryItem', itemName, count, metadata))
    end

    local player = QbPlayer(playerId)
    if not player then return false end

    return player.Functions.AddItem(itemName, count, slot, metadata) and true or false
end

FN_INVENTORY.RemoveItem = function(playerId, itemName, count, metadata, slot)
    if NoFrameworkInventory then return UnsupportedWithoutInventory('RemoveItem')() end

    if FN_BRIDGE.IsFramework('esx') then
        local xPlayer = EsxPlayer(playerId)
        return select(2, FN_FRAMEWORK.Call(xPlayer, 'removeInventoryItem', itemName, count, metadata))
    end

    local player = QbPlayer(playerId)
    if not player then return false end

    return player.Functions.RemoveItem(itemName, count, slot, metadata) and true or false
end

FN_INVENTORY.GetItemCount = function(playerId, itemName, metadata)
    if NoFrameworkInventory then return 0 end

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
    if NoFrameworkInventory then return UnsupportedWithoutInventory('GetItemSlot')() end

    if FN_BRIDGE.IsFramework('esx') then
        return FN_BRIDGE.UnsupportedFunction('INVENTORY', 'GetItemSlot', 'the ESX framework inventory has no slots')()
    end

    for _, item in ipairs(FN_INVENTORY.GetPlayerItems(playerId)) do
        if item.slot == slot then return item end
    end

    return false
end

FN_INVENTORY.CanCarry = function(playerId, itemName, count)
    if not FN_BRIDGE.IsFramework('esx') then return true end

    local xPlayer = EsxPlayer(playerId)
    if not xPlayer then return false end

    return FN_FRAMEWORK.Call(xPlayer, 'canCarryItem', itemName, count or 1) ~= false
end

FN_BRIDGE.SupportedWhen('INVENTORY', 'SetMetadata', function() return FN_BRIDGE.IsFramework('qb') end)

FN_INVENTORY.SetMetadata = function(playerId, slot, metadata)
    if not FN_BRIDGE.IsFramework('qb') then return UnsupportedWithoutInventory('SetMetadata')() end

    local player = QbPlayer(playerId)
    local items = player and player.PlayerData.items
    local item = items and items[slot]
    if not item then return false end

    item.info = metadata
    player.Functions.SetInventory(items)

    return true
end

FN_INVENTORY.GetLoadout = function(playerId)
    if not FN_BRIDGE.IsFramework('esx') then return {} end

    local xPlayer = EsxPlayer(playerId)
    local out = {}
    for _, weapon in ipairs(FN_FRAMEWORK.Call(xPlayer, 'getLoadout') or {}) do
        out[#out + 1] = { name = weapon.name, label = weapon.label or weapon.name, ammo = tonumber(weapon.ammo) or 0 }
    end

    return out
end

FN_INVENTORY.RemoveLoadout = function(playerId, weaponName)
    if not FN_BRIDGE.IsFramework('esx') then return false end

    local xPlayer = EsxPlayer(playerId)
    if not FN_FRAMEWORK.Call(xPlayer, 'hasWeapon', weaponName) then return false end
    FN_FRAMEWORK.Call(xPlayer, 'removeWeapon', weaponName)

    return true
end

FN_INVENTORY.AddLoadout = function(playerId, weaponName, ammo)
    if not FN_BRIDGE.IsFramework('esx') or type(weaponName) ~= 'string' then return false end

    local xPlayer = EsxPlayer(playerId)
    if not xPlayer or FN_FRAMEWORK.Call(xPlayer, 'hasWeapon', weaponName) then return false end
    FN_FRAMEWORK.Call(xPlayer, 'addWeapon', weaponName, math.max(0, math.floor(tonumber(ammo) or 0)))

    return true
end

Config.DebugPrint('inventory adapter loaded: _default (server)')
