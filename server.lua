local ReadyTimeoutMs = 30000
local isReady = false
local Finish

exports('GetBridge', function()
    if not isReady and FN_FRAMEWORK and FN_HELPER then Finish() end
    if not isReady then return nil end

    return FN_BRIDGE
end)

exports('Provide', FN_BRIDGE.Provide)

FN_BRIDGE.IsReady = function()
    return isReady
end

local function ReportMissingFramework()
    if not FN_BRIDGE.frameworkName then
        print('^1no supported framework detected^7 - checked '..table.concat(FN_BRIDGE.FrameworkResources(), ', ')..'. Start fn_bridge after your framework, or force one with setr fn_bridge:framework in server.cfg.')
        return
    end

    print('^1the '..FN_BRIDGE.frameworkName..' adapter never finished loading^7 - fn_bridge is running without a framework and every op script will fail to start.')
end

local function Resolve(namespace, target, contract, adapterName)
    if not target then return FN_BRIDGE.UnavailableNamespace(namespace, 'no '..namespace:lower()..' adapter loaded', contract) end

    local missing = FN_BRIDGE.FillContract(namespace, target, contract, adapterName)
    if #missing > 0 then
        Config.DebugPrint(('the %s %s adapter does not implement %s - calling one logs and returns false.'):format(adapterName, namespace:lower(), table.concat(missing, ', ')))
    end

    return target
end

local function FrameworkItemExists(itemName)
    local core = FN_FRAMEWORK and FN_FRAMEWORK.obj
    local shared = type(core) == 'table' and rawget(core, 'Shared')
    local items = type(core) == 'table' and (rawget(core, 'Items') or type(shared) == 'table' and shared.Items)

    if type(items) == 'table' and next(items) then return items[itemName] ~= nil end
    if FN_BRIDGE.IsFramework('esx') and FN_DB.HasTable('items') then return MySQL.scalar.await('SELECT 1 FROM items WHERE name = ? LIMIT 1', { itemName }) ~= nil end

    return true
end

local function InventoryDefaults(inventory)
    if not inventory then return nil end

    inventory.CanCarry = inventory.CanCarry or function() return true end
    inventory.ItemExists = inventory.ItemExists or FrameworkItemExists
    inventory.GetLoadout = inventory.GetLoadout or function() return {} end
    inventory.RemoveLoadout = inventory.RemoveLoadout or function() return false end

    return inventory
end

Finish = function()
    if isReady then return true end

    FN_BRIDGE.FRAMEWORK = Resolve('FRAMEWORK', FN_FRAMEWORK, FN_BRIDGE.FrameworkContract, FN_BRIDGE.frameworkName)
    FN_BRIDGE.FillContract('FRAMEWORK', FN_BRIDGE.FRAMEWORK, FN_BRIDGE.FrameworkOptional, FN_BRIDGE.frameworkName or 'standalone')
    FN_BRIDGE.INVENTORY = Resolve('INVENTORY', InventoryDefaults(FN_INVENTORY), FN_BRIDGE.InventoryContract.server, FN_BRIDGE.inventoryName or '_default')
    FN_BRIDGE.VEHICLES = Resolve('VEHICLES', FN_VEHICLES, FN_BRIDGE.VehiclesContract, FN_BRIDGE.frameworkName)
    FN_BRIDGE.NOTIFY = FN_NOTIFY
    FN_BRIDGE.TARGET = FN_BRIDGE.UnavailableNamespace('TARGET', 'client side only', FN_BRIDGE.TargetContract)
    FN_BRIDGE.HELPER = FN_HELPER
    FN_BRIDGE.PICKER = FN_BRIDGE.UnavailableNamespace('PICKER', 'client side only', FN_BRIDGE.PickerContract)
    FN_BRIDGE.KEYS = FN_KEYS
    FN_BRIDGE.CHARACTERS = Resolve('CHARACTERS', FN_CHARACTERS, FN_BRIDGE.CharactersContract.server, FN_BRIDGE.frameworkName)
    FN_BRIDGE.DISPATCH = FN_DISPATCH
    FN_BRIDGE.MEDIA = FN_MEDIA
    FN_BRIDGE.DEATH = FN_DEATH
    FN_BRIDGE.HOUSING = FN_HOUSING
    FN_BRIDGE.VOICE = FN_VOICE
    for _, key in ipairs({ 'Get', 'SetRange', 'SetVolume' }) do FN_VOICE[key] = FN_BRIDGE.UnsupportedFunction('VOICE', key, 'client side only') end
    FN_BRIDGE.JAIL = FN_JAIL
    FN_BRIDGE.BILLING = FN_BILLING
    FN_BRIDGE.STAFF = FN_STAFF
    FN_BRIDGE.DOORS = FN_DOORS
    FN_BRIDGE.APPEARANCE = FN_APPEARANCE
    FN_BRIDGE.INTERACT = FN_INTERACT
    FN_INTERACT.IsCuffed = FN_BRIDGE.UnsupportedFunction('INTERACT', 'IsCuffed', 'client side only')
    FN_BRIDGE.PREFS = FN_BRIDGE.UnavailableNamespace('PREFS', 'client side only', { 'Keys', 'Get', 'All', 'Set' })
    FN_BRIDGE.SOCIETY = Resolve('SOCIETY', FN_SOCIETY, FN_BRIDGE.SocietyContract, FN_BRIDGE.societyName or '_default')

    for _, namespace in ipairs({ 'FRAMEWORK', 'INVENTORY', 'VEHICLES', 'NOTIFY', 'HELPER', 'KEYS', 'CHARACTERS', 'DISPATCH', 'MEDIA', 'DEATH', 'HOUSING', 'SOCIETY', 'VOICE', 'JAIL', 'BILLING', 'STAFF', 'DOORS', 'APPEARANCE', 'INTERACT' }) do
        FN_BRIDGE.Overridable(namespace, FN_BRIDGE[namespace])
    end
    FN_BRIDGE.Hookable(FN_BRIDGE.FRAMEWORK, 'GetName', 'name')
    FN_BRIDGE.Hookable(FN_BRIDGE.FRAMEWORK, 'GetJob', 'job')
    FN_BRIDGE.Hookable(FN_BRIDGE.FRAMEWORK, 'GetPhoneNumber', 'phone')
    FN_BRIDGE.Hookable(FN_BRIDGE.FRAMEWORK, 'GetGang', 'gang')
    FN_BRIDGE.Hookable(FN_BRIDGE.FRAMEWORK, 'CheckJobDuty', 'duty')

    isReady = true
    CreateThread(function()
        FN_BRIDGE.PrintBanner({
            { 'framework', FN_BRIDGE.frameworkName, FN_BRIDGE.IsFramework('standalone') and 'fallback' or 'ok' },
            { 'inventory', FN_BRIDGE.inventoryName or 'framework inventory', FN_BRIDGE.inventoryName and 'ok' or 'fallback' },
            { 'notify', FN_BRIDGE.notifyName, 'ok' },
            { 'help text', FN_BRIDGE.helpTextName, 'ok' },
            { 'society', FN_BRIDGE.societyName or 'none detected', FN_BRIDGE.societyName and 'ok' or 'fallback' },
            { 'dispatch', FN_DISPATCH.Name() or 'none detected', FN_DISPATCH.Name() and 'ok' or 'fallback' },
            { 'housing', #FN_HOUSING.Running() > 0 and table.concat(FN_HOUSING.Running(), ', ') or 'none detected', #FN_HOUSING.Running() > 0 and 'ok' or 'fallback' },
            { 'screenshots', FN_MEDIA.Capturer() or 'none detected', FN_MEDIA.Capturer() and 'ok' or 'fallback' },
            { 'vehicles', FN_VEHICLES.Available() and 'ok' or 'no garage table', FN_VEHICLES.Available() and 'ok' or 'fallback' },
            { 'jail', FN_JAIL.Name() or 'none detected', FN_JAIL.Name() and 'ok' or 'fallback' },
            { 'billing', FN_BILLING.Name() or 'none detected', FN_BILLING.Name() and 'ok' or 'fallback' },
            { 'doors', FN_DOORS.Name() or 'none detected', FN_DOORS.Name() and 'ok' or 'fallback' },
            { 'clothing', FN_APPEARANCE.Name() or 'none detected', FN_APPEARANCE.Name() and 'ok' or 'fallback' },
            { 'radio', FN_VOICE.Name() or 'none detected', FN_VOICE.Name() and 'ok' or 'fallback' },
        })
    end)

    return true
end

local function FrameworkLoadedModule()
    local deadline = GetGameTimer() + ReadyTimeoutMs
    while (not FN_FRAMEWORK or not FN_HELPER) and GetGameTimer() < deadline do
        Wait(100)
    end

    if not FN_FRAMEWORK or not FN_HELPER then return ReportMissingFramework() end

    return Finish()
end

CreateThread(FrameworkLoadedModule)
