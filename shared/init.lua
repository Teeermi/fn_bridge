local NativePrint = print

FN_BRIDGE = {}

FN_BRIDGE.resourceName = Config.ResourceName
FN_BRIDGE.isServer = IsDuplicityVersion() and true or false

local Scripts = {}
local Overridden = {}

FN_BRIDGE.Configure = function(settings)
    local resource = GetInvokingResource()
    if not resource or resource == FN_BRIDGE.resourceName then return false end

    Scripts[resource] = type(settings) == 'table' and settings or nil

    for key in pairs(Scripts[resource] or {}) do
        if type(key) == 'string' and key:find('.', 1, true) then Overridden[key] = true end
    end

    return true
end

local Provided = {}

local function Drop(key, resource)
    local list = Provided[key]
    if not list then return end

    for i = #list, 1, -1 do
        if list[i].resource == resource then table.remove(list, i) end
    end
    if #list == 0 then Provided[key] = nil end
end

local function Top(key, skip)
    local list = Provided[key] or {}
    for i = #list, 1, -1 do
        if list[i].resource ~= skip then return list[i] end
    end
end

FN_BRIDGE.Provide = function(key, value)
    local resource = GetInvokingResource()
    if not resource or resource == FN_BRIDGE.resourceName or type(key) ~= 'string' then return false end

    Drop(key, resource)
    if value == nil or value == false then return true end
    if type(value) ~= 'table' and type(value) ~= 'function' then return false end

    Provided[key] = Provided[key] or {}
    table.insert(Provided[key], { resource = resource, value = value })
    if key:find('.', 1, true) then Overridden[key] = true end

    return true
end

FN_BRIDGE.Providers = function()
    local out = {}
    for key in pairs(Provided) do out[key] = FN_BRIDGE.Provider(key) end

    return out
end

FN_BRIDGE.ProvidersOf = function(key)
    local out = {}
    for i, entry in ipairs(Provided[key] or {}) do out[i] = { resource = entry.resource, value = entry.value } end

    return out
end

FN_BRIDGE.Provider = function(key)
    local top = Top(key)

    return top and top.resource or nil
end

FN_BRIDGE.Setting = function(key, resource)
    resource = resource or GetInvokingResource() or ''
    local settings = Scripts[resource]
    local own = settings and settings[key]
    if own ~= nil then return own end

    local provided = Top(key, resource)

    return provided and provided.value or nil
end

FN_BRIDGE.Callable = function(value)
    if type(value) == 'function' then return true end

    local meta = type(value) == 'table' and getmetatable(value)

    return type(meta) == 'table' and meta.__call ~= nil
end

local Hooked = {}

FN_BRIDGE.Hookable = function(target, name, key)
    local adapter = target[name]
    local wrapper = function(...)
        local hook = FN_BRIDGE.Setting(key)
        if FN_BRIDGE.Callable(hook) then
            local ok, value = pcall(hook, ...)
            if ok and value ~= nil then return value end
        end

        return adapter(...)
    end

    Hooked[wrapper] = { adapter = adapter, key = key }
    target[name] = wrapper
end

FN_BRIDGE.Overridable = function(namespace, target)
    if type(target) ~= 'table' then return target end

    for name, adapter in pairs(target) do
        if type(adapter) == 'function' then
            local key = namespace .. '.' .. name
            local wrapper = function(...)
                if Overridden[key] then
                    local override = FN_BRIDGE.Setting(key)
                    if FN_BRIDGE.Callable(override) then return override(...) end
                end

                return adapter(...)
            end

            Hooked[wrapper] = { adapter = adapter, key = key }
            target[name] = wrapper
        end
    end

    return target
end

AddEventHandler('onResourceStop', function(resource)
    Scripts[resource] = nil

    for key in pairs(Provided) do Drop(key, resource) end
end)

local FrameworkOrder = {
    { name = 'esx', resource = 'es_extended' },
    { name = 'qbx', resource = 'qbx_core' },
    { name = 'qb', resource = 'qb-core' },
    { name = 'ox', resource = 'ox_core' },
    { name = 'vrp', resource = 'vrp' },
}

local InventoryOrder = {
    { name = 'ox_inventory', resource = 'ox_inventory' },
    { name = 'qb-inventory', resource = 'qb-inventory' },
    { name = 'ps-inventory', resource = 'ps-inventory' },
    { name = 'qs-inventory', resource = 'qs-inventory' },
    { name = 'codem-inventory', resource = 'codem-inventory' },
    { name = 'tgiann-inventory', resource = 'tgiann-inventory' },
    { name = 'ak47_inventory', resource = 'ak47_inventory' },
    { name = 'core_inventory', resource = 'core_inventory' },
    { name = 'origen_inventory', resource = 'origen_inventory' },
}

local NotifyOrder = {
    { name = 'okok', resource = 'okokNotify' },
    { name = 'mythic', resource = 'mythic_notify' },
    { name = 'pNotify', resource = 'pNotify' },
    { name = 't-notify', resource = 't-notify' },
    { name = 'vms_notifyv2', resource = 'vms_notifyv2' },
    { name = 'brutal_notify', resource = 'brutal_notify' },
    { name = 'g-notifications', resource = 'g-notifications' },
    { name = 'r_notify', resource = 'r_notify' },
    { name = 'wasabi', resource = 'wasabi_notify' },
    { name = 'wasabi_uikit', resource = 'wasabi_uikit' },
    { name = 'lation_ui', resource = 'lation_ui' },
    { name = 'is_ui', resource = 'is_ui' },
}

local HelpTextOrder = {
    { name = 'jg', resource = 'jg-textui' },
    { name = 'okok', resource = 'okokTextUI' },
    { name = 'cd', resource = 'cd_drawtextui' },
    { name = 'lab', resource = 'lab-HintUI' },
}

local TargetOrder = {
    { name = 'ox_target', resource = 'ox_target' },
    { name = 'qb-target', resource = 'qb-target' },
}

local SocietyOrder = {
    { name = 'esx_addonaccount', resource = 'esx_addonaccount' },
    { name = 'qb-management', resource = 'qb-management' },
    { name = 'Renewed-Banking', resource = 'Renewed-Banking' },
    { name = 'qb-banking', resource = 'qb-banking' },
}

local FrameworkAliases = {
    esx = 'framework',
    qb = 'framework',
    qbx = 'framework',
}

FN_KNOWN = {}
for _, order in ipairs({ FrameworkOrder, InventoryOrder, NotifyOrder, HelpTextOrder, TargetOrder, SocietyOrder }) do
    for _, entry in ipairs(order) do FN_KNOWN[entry.resource] = true end
end

local function ResourcePresence(resourceName)
    local state = GetResourceState(resourceName)
    if state == 'started' or state == 'starting' then return 2 end
    if state == 'missing' or state == 'unknown' then return 0 end

    return 1
end

local function DetectFrom(order, configured, fallback, aliases)
    if configured ~= 'auto' then return aliases and aliases[configured] or configured end

    local pending
    for _, entry in ipairs(order) do
        local presence = ResourcePresence(entry.resource)
        if presence == 2 then return entry.name end
        if presence == 1 and not pending then pending = entry.name end
    end

    return pending or fallback
end

local function ResourceNames(order)
    local names = {}
    for _, entry in ipairs(order) do
        names[#names + 1] = entry.resource
    end

    return names
end

FN_BRIDGE.frameworkName = DetectFrom(FrameworkOrder, Config.Framework, 'standalone')
FN_BRIDGE.inventoryName = Config.InventorySystem ~= 'none' and DetectFrom(InventoryOrder, Config.InventorySystem, nil) or nil
FN_BRIDGE.notifyName = DetectFrom(NotifyOrder, Config.NotifySystem, 'framework', FrameworkAliases)
FN_BRIDGE.helpTextName = DetectFrom(HelpTextOrder, Config.ShowHelpSystem, 'framework', FrameworkAliases)
FN_BRIDGE.targetName = DetectFrom(TargetOrder, Config.TargetSystem, nil)
FN_BRIDGE.societyName = DetectFrom(SocietyOrder, Config.Society, nil)

Config.DebugPrint('framework detected:', FN_BRIDGE.frameworkName or 'none')
Config.DebugPrint('inventory detected:', FN_BRIDGE.inventoryName or 'none, falling back to the framework')
Config.DebugPrint('notify detected:', FN_BRIDGE.notifyName)
Config.DebugPrint('help text detected:', FN_BRIDGE.helpTextName)
Config.DebugPrint('target detected:', FN_BRIDGE.targetName or 'none')
Config.DebugPrint('society detected:', FN_BRIDGE.societyName or 'none, falling back to _default')

local BannerTones = {
    ok = '^2',
    fallback = '^3',
    missing = '^1',
}

FN_BRIDGE.version = GetResourceMetadata(FN_BRIDGE.resourceName, 'version', 0) or 'unversioned'

FN_BRIDGE.PrintBanner = function(rows)
    local lines = {
        '',
        '^5FIVENUTS.DEV^7  '..FN_BRIDGE.resourceName..' '..FN_BRIDGE.version..'^0',
        '^7'..string.rep('-', 40)..'^0',
    }

    for _, row in ipairs(rows) do
        lines[#lines + 1] = ('^7  %-12s%s%s^0'):format(row[1], BannerTones[row[3]] or '^7', row[2])
    end

    lines[#lines + 1] = ''

    NativePrint(table.concat(lines, '\n'))
end

FN_BRIDGE.IsInventory = function(inventoryName)
    return FN_BRIDGE.inventoryName == inventoryName
end

FN_BRIDGE.InventoryResources = function()
    return ResourceNames(InventoryOrder)
end

FN_BRIDGE.IsTarget = function(targetName)
    return FN_BRIDGE.targetName == targetName
end

FN_BRIDGE.TargetResources = function()
    return ResourceNames(TargetOrder)
end

FN_BRIDGE.IsSociety = function(societyName)
    return FN_BRIDGE.societyName == societyName
end

FN_BRIDGE.SocietyResources = function()
    return ResourceNames(SocietyOrder)
end

FN_BRIDGE.SocietyContract = {
    'GetMoney',
    'AddMoney',
    'RemoveMoney',
    'Transfer',
    'Watch',
    'GangAccount',
    'GetGangMoney',
    'AddGangMoney',
    'RemoveGangMoney',
}

FN_BRIDGE.InventoryContract = {
    client = { 'OpenInventory', 'GetItemCount', 'HasItem', 'GetItemData' },
    server = { 'GetPlayerItems', 'AddItem', 'RemoveItem', 'GetItemCount', 'HasItem', 'GetItemSlot', 'SetMetadata', 'CanCarry', 'ItemExists', 'DefineItems', 'GetMaxWeight', 'SetMaxWeight', 'GetLoadout', 'RemoveLoadout',
        'RegisterStash', 'GetStashItems', 'AddStashItem', 'RemoveStashItem', 'ClearStash', 'OpenStash', 'OnStash', 'OnShopBuy', 'RegisterUsable' },
}

FN_BRIDGE.FrameworkContract = {
    'GetIdentifier', 'GetPlayerFromId', 'GetPlayerFromIdentifier', 'GetPlayers', 'GetOfflineCharName', 'SearchCharacters',
    'GetJobMembers', 'SetJobOffline', 'CheckJobDuty', 'SetJobDuty', 'GetJobs', 'CheckPermissions', 'RegisterUsableItem',
    'UseItem', 'GetItemLabel', 'GetVehicleByPlate', 'GetPlayerVehicles', 'CheckLicense', 'AddLicense', 'RemoveLicense',
    'GetMoney', 'AddMoney', 'RemoveMoney', 'GetJob', 'SetJob', 'RemoveJob', 'GetGang', 'GetNeeds', 'GetPlayTime',
    'GetPhoneNumber', 'SetPhoneNumber', 'IsPhoneNumberTaken', 'SetName', 'IsNameTaken', 'GetCharacter', 'GetCharacters',
    'AddCharacterSlots', 'Supports', 'GetName', 'GetVehicleCatalog', 'GetCharactersByIds',
}

FN_BRIDGE.FrameworkOptional = {
    'GetJobGrades', 'GetJobOffline', 'CreateJob', 'SetJobGrades', 'DeleteJob', 'GetPlayerJobs', 'SetActiveJob', 'AddPlayerJob',
    'GetGangs', 'GetGangMembers', 'SetGang', 'RemoveGang', 'CreateGang', 'DeleteGang', 'GetInsurance', 'SetCharacter',
}

FN_BRIDGE.VehiclesContract = {
    'Available', 'GarageColumn', 'Get', 'List', 'IsPlateTaken', 'IsStored', 'GetProps', 'Add', 'Remove', 'SetOwner',
    'TransferAll', 'SetPlate', 'SetProps', 'SetState', 'Impound', 'JobColumn', 'ListJob', 'SetJob', 'Traits',
}

FN_BRIDGE.ServerOnly = {
    JAIL = { 'Name', 'Send', 'Release', 'Get', 'GetOffline', 'CommunityService' },
    BILLING = { 'Name', 'Send', 'List', 'Pay', 'Provide' },
    COINS = { 'Name', 'Get', 'Remove', 'Add', 'Provide' },
    STAFF = { 'Host', 'Call' },
    DOORS = { 'Name', 'List', 'Get', 'IsLocked', 'SetLocked', 'Allow' },
    HTTP = { 'Header', 'Tunnel', 'Origin' },
}

FN_BRIDGE.PickerContract = { 'Start', 'Await', 'Stop', 'IsActive' }

FN_BRIDGE.KeysContract = { 'Give', 'Remove' }

FN_BRIDGE.CharactersContract = {
    server = { 'Supported', 'Owner', 'List', 'Spawns', 'DeferredLogin', 'TakeOver', 'Login', 'Create', 'Delete', 'Logout', 'IsLoaded', 'StarterItems', 'Money', 'Dossier', 'HandsOver', 'Slots' },
    client = { 'IsLoggedIn', 'Prepare', 'LoadingOff', 'Spawn', 'Loaded', 'Done' },
}

FN_BRIDGE.TargetContract = {
    'AddGlobalPed',
    'RemoveGlobalPed',
    'AddGlobalPlayer',
    'RemoveGlobalPlayer',
    'AddGlobalVehicle',
    'RemoveGlobalVehicle',
    'AddLocalEntity',
    'RemoveLocalEntity',
    'AddModel',
    'RemoveModel',
    'AddBoxZone',
    'AddSphereZone',
    'RemoveZone',
    'DisableTargeting',
}

FN_BRIDGE.NormalizeItem = function(rawItem)
    if type(rawItem) ~= 'table' or not rawItem.name then return false end

    return {
        name = rawItem.name,
        label = rawItem.label or rawItem.name,
        count = tonumber(rawItem.count or rawItem.amount) or 0,
        metadata = rawItem.metadata or rawItem.info or {},
        slot = tonumber(rawItem.slot) or false,
    }
end

FN_BRIDGE.NormalizeItems = function(rawItems)
    local items = {}
    if type(rawItems) ~= 'table' then return items end

    for _, rawItem in pairs(rawItems) do
        local item = FN_BRIDGE.NormalizeItem(rawItem)
        if item then items[#items + 1] = item end
    end

    return items
end

FN_BRIDGE.NormalizeCount = function(value, itemName)
    local count = tonumber(value)
    if count then return count end

    if type(value) ~= 'table' then return 0 end

    if type(itemName) == 'string' then
        local named = tonumber(value[itemName]) or tonumber(value[itemName:upper()]) or tonumber(value[itemName:lower()])
        if named then return named end
    end

    local total = 0
    for _, entry in pairs(value) do
        total = total + (tonumber(entry) or 0)
    end

    return total
end

FN_BRIDGE.MetadataMatches = function(itemMetadata, filter)
    if type(filter) ~= 'table' then return true end
    if type(itemMetadata) ~= 'table' then return false end

    for key, value in pairs(filter) do
        if itemMetadata[key] ~= value then return false end
    end

    return true
end

FN_BRIDGE.IsCallable = function(value)
    if type(value) == 'function' then return true end

    local meta = getmetatable(value)

    return type(meta) == 'table' and type(meta.__call) == 'function'
end

FN_BRIDGE.IsFramework = function(frameworkName)
    return FN_BRIDGE.frameworkName == frameworkName
end

FN_BRIDGE.FrameworkResources = function()
    return ResourceNames(FrameworkOrder)
end

FN_BRIDGE.UnavailableNamespace = function(namespace, reason, keys)
    local stub = function(key)
        return function()
            print(('%s.%s is not available: %s'):format(namespace, tostring(key), reason))

            return false
        end
    end

    local namespaceTable = {}
    for _, key in ipairs(keys) do
        namespaceTable[key] = stub(key)
    end

    return setmetatable(namespaceTable, {
        __index = function(_, key) return stub(key) end,
    })
end

local Unsupported = {}

FN_BRIDGE.UnsupportedFunction = function(namespace, key, reason)
    local stub = function()
        print(('%s.%s is not supported by this resource: %s'):format(namespace, key, reason))

        return false
    end

    Unsupported[stub] = true

    return stub
end

FN_BRIDGE.FillContract = function(namespace, target, contract, adapterName)
    local missing = {}

    for _, key in ipairs(contract) do
        if type(target[key]) ~= 'function' then
            missing[#missing + 1] = key
            target[key] = FN_BRIDGE.UnsupportedFunction(namespace, key, 'the '..adapterName..' adapter does not implement it')
        end
    end

    return missing
end

local Conditional = {}

FN_BRIDGE.SupportedWhen = function(namespace, key, check)
    Conditional[namespace..'.'..key] = check
end

FN_BRIDGE.IsSupported = function(namespace, key)
    local target = FN_BRIDGE[namespace]
    local value = type(target) == 'table' and rawget(target, key)
    while Hooked[value] do
        if FN_BRIDGE.Callable(FN_BRIDGE.Setting(Hooked[value].key)) then return true end
        value = Hooked[value].adapter
    end

    if type(value) ~= 'function' or Unsupported[value] then return false end

    local check = Conditional[namespace..'.'..key]

    return not check or check() == true
end
