if FN_BRIDGE.inventoryName then return end

FN_INVENTORY = {}

local function PlayerItems()
    if not FN_FRAMEWORK then return {} end

    local playerData = FN_FRAMEWORK.GetPlayerData()
    if type(playerData) ~= 'table' then return {} end

    return playerData.items or playerData.inventory or {}
end

local function SharedItems()
    local frameworkObject = FN_FRAMEWORK and FN_FRAMEWORK.obj

    return frameworkObject and frameworkObject.Shared and frameworkObject.Shared.Items or nil
end

FN_INVENTORY.OpenInventory = FN_BRIDGE.UnsupportedFunction('INVENTORY', 'OpenInventory', 'no inventory resource was detected, so there is no inventory UI to open')

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
    local sharedItems = SharedItems()
    local itemData = sharedItems and sharedItems[itemName]

    if not itemData then
        for _, rawItem in pairs(PlayerItems()) do
            local item = FN_BRIDGE.NormalizeItem(rawItem)
            if item and item.name == itemName then
                return { name = item.name, label = item.label, description = '', image = '' }
            end
        end

        return false
    end

    return { name = itemName, label = itemData.label or itemName, description = itemData.description or '', image = '' }
end

Config.DebugPrint('inventory adapter loaded: _default (client)')
