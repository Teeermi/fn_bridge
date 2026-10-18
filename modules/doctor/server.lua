local Tables = {
    esx = { 'users', 'owned_vehicles' },
    qb = { 'players', 'player_vehicles' },
    qbx = { 'players', 'player_vehicles' },
    ox = { 'characters', 'vehicles' },
    vrp = { 'vrp_user_identities', 'vrp_user_vehicles' },
    standalone = { 'fn_vehicles' },
}

local Categories = {
    { hook = 'notify', file = 'client', words = { 'notif' } },
    { hook = 'showHelp', file = 'client', words = { 'textui', 'helptext', 'hint', 'drawtext' } },
    { hook = 'seatbelt', file = 'client', words = { 'seatbelt' } },
    { hook = 'revive', file = 'server', words = { 'ambulance', 'medical', 'hospital', 'revive' } },
    { hook = 'dispatch', file = 'server', words = { 'dispatch', 'mdt', 'alert' } },
    { hook = 'housing', file = 'server', words = { 'housing', 'house', 'propert', 'apartment', 'realestate' } },
    { hook = 'phone', file = 'server', words = { 'phone' } },
    { hook = 'garage', file = 'server', words = { 'garage' } },
    { hook = 'jail', file = 'server', words = { 'jail', 'prison' } },
    { hook = 'billing', file = 'server', words = { 'billing', 'invoice' } },
    { hook = 'doors', file = 'server', words = { 'door' } },
    { hook = 'interact', file = 'server', words = { 'police', 'cuff' } },
    { hook = 'appearance', file = 'client', words = { 'appearance', 'clothing', 'skin' } },
    { hook = 'voice', file = 'server', words = { 'voice', 'voip' } },
    { hook = 'phoneNumber', file = 'server', words = { 'phone' } },
    { hook = 'fuel', file = 'client', words = { 'fuel', 'gasstation' } },
    { hook = 'spawns', file = 'server', words = { 'motel' } },
}

local Libraries = { ox_lib = true, oxmysql = true, ['mysql-async'] = true, es_extended = true, ['qb-core'] = true, qbx_core = true, ox_core = true, vrp = true, fn_bridge = true, esx_notify = true, esx_textui = true }
local Kinds = { 'shared_script', 'client_script', 'server_script' }
local Anticheats = { 'shield', 'guard', 'anticheat', 'fireac', 'electron', 'phoenix', 'valkyrie', 'tigo', 'reaper' }

local function Anticheat(name)
    name = name:lower()
    for _, word in ipairs(Anticheats) do
        if name:find(word, 1, true) then return true end
    end

    return false
end

local function Line(label, value, note)
    print(('  ^7%-12s^5%s^7%s'):format(label, tostring(value), note and ('  ^9' .. note .. '^7') or ''))
end

local function Started()
    local list = {}
    for i = 0, GetNumResources() - 1 do
        local name = GetResourceByFindIndex(i)
        if name and GetResourceState(name) == 'started' then list[#list + 1] = name end
    end
    table.sort(list)

    return list
end

local function Ours(resource)
    return resource == FN_BRIDGE.resourceName or GetResourceMetadata(resource, 'fn_bridge_version', 0) ~= nil
end

local function Entries(resource, kind)
    local out = {}
    for i = 0, GetNumResourceMetadata(resource, kind) - 1 do
        out[#out + 1] = GetResourceMetadata(resource, kind, i)
    end

    return out
end

local function Why(convar, picked, fallback)
    local forced = GetConvar('fn_bridge:' .. convar, '')
    if forced ~= '' and forced ~= 'auto' then return 'setr fn_bridge:' .. convar .. ' ' .. forced end

    return picked and 'found running' or fallback
end

local function DependsOnBridge(resource)
    for _, dep in ipairs(Entries(resource, 'dependency')) do
        if dep == FN_BRIDGE.resourceName then return true end
    end

    return resource == 'fn_bridge_custom'
end

local function ClientHooks(resources)
    local found = {}
    for _, resource in ipairs(resources) do
        if DependsOnBridge(resource) and not Ours(resource) then
            for _, file in ipairs(Entries(resource, 'client_script')) do
                for key in ('\n' .. (LoadResourceFile(resource, file) or '')):gmatch("\n%s*exports%.fn_bridge:Provide%(%s*['\"]([%w_]+)['\"]") do
                    found[key] = resource
                end
            end
        end
    end

    return found
end

local function Hook(key, client)
    return FN_BRIDGE.Provider(key) or client[key]
end

local function Choices(client)
    print('^5choices^7')
    local framework = FN_BRIDGE.frameworkName
    local core = ({ esx = 'es_extended', qb = 'qb-core', qbx = 'qbx_core', ox = 'ox_core', vrp = 'vrp' })[framework]
    Line('framework', framework, Why('framework', core, 'nothing found, standalone') .. (core and (' (' .. core .. ' ' .. tostring(GetResourceMetadata(core, 'version', 0)) .. ')') or ''))
    Line('inventory', FN_BRIDGE.inventoryName or 'framework', Why('inventory', FN_BRIDGE.inventoryName, 'none found, the framework inventory'))
    Line('target', FN_BRIDGE.targetName or 'none', Why('target', FN_BRIDGE.targetName, 'none found'))
    Line('society', FN_BRIDGE.societyName or 'none', Why('society', FN_BRIDGE.societyName, 'none found'))

    local function Hooked(label, key, value, why)
        local by = Hook(key, client)
        if by then return Line(label, 'hook', 'Provide from ' .. by) end
        Line(label, value, why)
    end

    Hooked('notify', 'notify', FN_BRIDGE.notifyName, Why('notify', FN_BRIDGE.notifyName ~= 'framework', 'none found, the framework'))
    Hooked('help text', 'showHelp', FN_BRIDGE.helpTextName, Why('helptext', FN_BRIDGE.helpTextName ~= 'framework', 'none found, the framework'))
    Hooked('revive', 'revive', FN_DEATH.Reviver() or 'built-in', FN_DEATH.Reviver() and 'found running' or 'none found, fn_bridge heals the ped itself')
    Hooked('dispatch', 'dispatch', FN_DISPATCH.Name() or 'none', Why('dispatch', FN_DISPATCH.Name(), 'none found, alerts are dropped'))
    Line('phone', FN_PHONE.Name() or 'none', Why('phone', FN_PHONE.Name(), 'none found, scripts fall back to their own notifications'))
    local homes = FN_HOUSING.Running()
    Hooked('housing', 'housing', #homes > 0 and table.concat(homes, ', ') or 'none', #homes > 0 and 'found running' or 'none found')
    Hooked('garage', 'garage', FN_VEHICLES.Available() and 'stock columns' or 'no vehicle table', 'garage column ' .. tostring(FN_VEHICLES.GarageColumn()))
    for _, key in ipairs({ 'name', 'job', 'phone' }) do Hooked(key, key, 'framework') end
    Line('photos', FN_MEDIA.Capturer() or 'none', FN_MEDIA.Capturer() and 'found running' or 'install screenshot-basic or screencapture')
    Hooked('jail', 'jail', FN_JAIL.Name() or 'none', FN_JAIL.Name() and 'found running' or 'none found, sentences stay in your script')
    Hooked('billing', 'billing', FN_BILLING.Name() or 'none', FN_BILLING.Name() and 'found running' or 'none found')
    Hooked('coins', 'coins', FN_COINS.Name() or 'none', FN_COINS.Name() and 'found running' or 'none found, coin prices are off')
    Hooked('doors', 'doors', FN_DOORS.Name() or 'none', FN_DOORS.Name() and 'found running' or 'none found')
    Hooked('cuffs', 'interact', FN_INTERACT.Has('cuff') or 'none', FN_INTERACT.Has('cuff') and 'found running' or 'none found, scripts use their own')
    local gangs = FN_FRAMEWORK.Supports('gangs')
    Hooked('gangs', 'gang', gangs and 'framework' or 'none', not gangs and 'no gangs in this framework' or nil)
    Hooked('clothing', 'appearance', FN_APPEARANCE.Name() or 'natives', FN_APPEARANCE.Name() and 'found running' or 'none found, outfits use game natives')
    Hooked('voice', 'voice', FN_VOICE.Name() or 'none', FN_VOICE.Name() and 'found running' or 'none found, no calls or radio')
    local numbers, blocked, phone = FN_PHONE.Numbers()
    Hooked('numbers', 'phoneNumber', numbers and numbers.name or (phone or 'none'), numbers and 'phone numbers can change' or (blocked == 'unsupported' and 'keeps its own numbers, add the phoneNumber hook' or 'this phone setup does not let scripts change numbers'))
    Hooked('fuel', 'fuel', 'auto', 'state bag fuel, a known fuel script or the game value')
    local hosts = {}
    for _, entry in ipairs(FN_BRIDGE.ProvidersOf('staff')) do hosts[#hosts + 1] = entry.resource end
    Line('staff', #hosts > 0 and table.concat(hosts, ', ') or 'none', #hosts > 0 and 'job hosts' or 'fn_phone keeps its own work apps')

    local shown = { notify = true, showHelp = true, revive = true, dispatch = true, housing = true, garage = true, name = true, job = true, phone = true, jail = true, billing = true, doors = true, interact = true, gang = true, appearance = true, staff = true, voice = true, phoneNumber = true, fuel = true }
    local extra = {}
    for key, by in pairs(FN_BRIDGE.Providers()) do
        if not shown[key] then extra[#extra + 1] = key .. ' (' .. by .. ')' end
    end
    for key, by in pairs(client) do
        if not shown[key] and not FN_BRIDGE.Provider(key) then extra[#extra + 1] = key .. ' (' .. by .. ', client)' end
    end
    table.sort(extra)
    if #extra > 0 then Line('hooks', table.concat(extra, ', ')) end
end

local function Shape()
    local framework = FN_BRIDGE.frameworkName
    local core = FN_FRAMEWORK and FN_FRAMEWORK.obj
    print('^5framework shape^7')

    if framework == 'esx' and core then
        local stock = core.GetPlayerFromId ~= nil
        Line('xPlayer', stock and 'stock' or core.GetPlayerFromIdClass and 'fork: GetPlayerFromIdClass' or 'unknown', core.PlayerFuncs and 'methods through ESX.PlayerFuncs' or nil)
        if not stock then
            local api = {}
            for name in pairs(core) do
                if type(name) == 'string' and name:find('Player', 1, true) then api[#api + 1] = name end
            end
            table.sort(api)
            Line('ESX api', #api .. ' player functions', table.concat(api, ' '))
        end
        for method, reason in pairs(FN_FRAMEWORK.CallFailures or {}) do
            Line('method', method, reason)
        end
    elseif (framework == 'qb' or framework == 'qbx') and core then
        Line('player', type(rawget(core, 'Functions')) == 'table' and 'QBCore.Functions' or 'exports only')
    end

    for _, name in ipairs(Tables[framework] or {}) do
        local columns = {}
        for column in pairs(FN_DB.Columns(name)) do columns[#columns + 1] = column end
        table.sort(columns)
        Line(name, #columns > 0 and #columns .. ' columns' or 'missing', #columns > 0 and table.concat(columns, ' ') or nil)
    end
end

local function Unknown(resources, client)
    local wanted = {}
    for _, resource in ipairs(resources) do
        local lower = resource:lower()
        if not FN_KNOWN[resource] and not Ours(resource) and not Libraries[resource] then
            for _, category in ipairs(Categories) do
                if not Hook(category.hook, client) then
                    for _, word in ipairs(category.words) do
                        if lower:find(word, 1, true) then
                            wanted[category.hook] = wanted[category.hook] or { file = category.file, resources = {} }
                            table.insert(wanted[category.hook].resources, resource)
                            break
                        end
                    end
                end
            end
        end
    end

    if not next(wanted) then return wanted end

    print('^5running, but fn_bridge has no adapter for them^7')
    for _, category in ipairs(Categories) do
        local entry = wanted[category.hook]
        if entry then Line(category.hook, table.concat(entry.resources, ', '), 'hook it in fn_bridge_custom/' .. entry.file .. '.lua') end
    end

    return wanted
end

local function Includes(resources)
    local users, total = {}, 0
    for _, resource in ipairs(resources) do
        local any = false
        for _, kind in ipairs(Kinds) do
            for _, entry in ipairs(Entries(resource, kind)) do
                any = true
                local dep = entry:match('^@([^/]+)/')
                if dep and Anticheat(dep) then
                    local key = kind .. " '" .. entry .. "'"
                    users[key] = users[key] or {}
                    users[key][resource] = true
                end
            end
        end
        if any then total = total + 1 end
    end

    local printed = false
    for line, set in pairs(users) do
        local count, missing = 0, {}
        for _ in pairs(set) do count = count + 1 end

        if count >= 3 then
            for _, resource in ipairs(resources) do
                if Ours(resource) and not set[resource] then missing[#missing + 1] = resource end
            end

            if #missing > 0 then
                if not printed then print('^5anticheat include your resources have, ours do not^7') printed = true end
                Line('add', line, ('%d of %d resources have it; add it to the fxmanifest of %s'):format(count, total, table.concat(missing, ', ')))
            end
        end
    end
end

local Snippets = {
    { 'server', 'revive', [[exports.fn_bridge:Provide('revive', function(playerId)
    TriggerClientEvent('my_ambulance:revive', playerId)
end)]] },
    { 'server', 'phone', [[exports.fn_bridge:Provide('phone', function(playerId)
    return exports.my_phone:GetNumber(playerId)
end)]] },
    { 'server', 'dispatch', [[exports.fn_bridge:Provide('dispatch', function(playerId, alert)
    TriggerClientEvent('fn_bridge_custom:dispatch', playerId, alert)
end)]] },
    { 'server', 'housing', [[exports.fn_bridge:Provide('housing', {
    list = function(identifier, playerId) return exports.my_housing:GetOwned(identifier) end,
    isLocked = function(homeId) return exports.my_housing:IsLocked(homeId) end,
    setLocked = function(homeId, locked) return exports.my_housing:SetLocked(homeId, locked) end,
    forSale = function() return exports.my_housing:ForSale() end,
})]] },
    { 'server', 'voice', [[exports.fn_bridge:Provide('voice', {
    call = function(playerId, callId) exports.my_voice:SetCall(playerId, callId or 0) end,
    radio = function(playerId, channel) exports.my_voice:SetRadio(playerId, channel) end,
})]] },
    { 'server', 'phoneNumber', [[exports.fn_bridge:Provide('phoneNumber', {
    get = function(playerId) return exports.my_phone:GetNumber(playerId) end,
    taken = function(number) return exports.my_phone:NumberExists(number) end,
    set = function(playerId, number, old) return exports.my_phone:ChangeNumber(playerId, number) end,
})]] },
    { 'server', 'appearance', [[exports.fn_bridge:Provide('appearance', {
    skin = function(identifier) return exports.my_clothing:GetSkin(identifier) end,
})]] },
    { 'server', 'spawns', [[exports.fn_bridge:Provide('spawns', function(playerId, identifier, isNew)
    return exports.my_motel:SpawnPoints(identifier), false
end)]] },
    { 'server', 'garage', [[exports.fn_bridge:Provide('garage', {
    esx = { parkedColumn = 'state', state = 'stored', parkedOut = 'out', garageColumn = 'parking' },
})]] },
    { 'server', 'jail', [[exports.fn_bridge:Provide('jail', {
    send = function(playerId, minutes, opts) return exports.my_prison:Jail(playerId, minutes, opts.reason) end,
    release = function(playerId) return exports.my_prison:Release(playerId) end,
    get = function(playerId) return { minutes = exports.my_prison:TimeLeft(playerId) } end,
})]] },
    { 'server', 'doors', [[exports.fn_bridge:Provide('doors', {
    list = function() return exports.my_doors:List() end,
    isLocked = function(id) return exports.my_doors:IsLocked(id) end,
    setLocked = function(id, locked, playerId) return exports.my_doors:SetLocked(id, locked) end,
    allow = function(id, access) return exports.my_doors:SetAccess(id, access.groups, access.identifiers) end,
})]] },
    { 'server', 'interact', [[exports.fn_bridge:Provide('interact', {
    cuff = function(playerId, target, on) return exports.my_police:Cuff(playerId, target, on) end,
    escort = function(playerId, target, on) return exports.my_police:Escort(playerId, target, on) end,
    is = function(target, kind) return exports.my_police:Is(target, kind) end,
})]] },
    { 'client', 'notify', [[exports.fn_bridge:Provide('notify', function(message, kind, time)
    exports.my_notify:Show(message, kind, time or 5000)
end)]] },
    { 'client', 'showHelp', [[exports.fn_bridge:Provide('showHelp', function(message)
    exports.my_textui:Show(message)
end)
exports.fn_bridge:Provide('hideHelp', function()
    exports.my_textui:Hide()
end)]] },
    { 'client', 'seatbelt', [[exports.fn_bridge:Provide('seatbelt', function()
    return LocalPlayer.state.seatbelt == true
end)]] },
    { 'client', 'dispatch', [[RegisterNetEvent('fn_bridge_custom:dispatch', function(alert)
    exports.my_dispatch:Alert(alert.coords, alert.title, alert.message, alert.code)
end)]] },
    { 'client', 'appearance', [[exports.fn_bridge:Provide('appearance', {
    set = function(outfit) return exports.my_clothing:Wear(outfit) end,
    restore = function() return exports.my_clothing:Reload() end,
    apply = function(ped, data) exports.my_clothing:ApplyToPed(ped, data) end,
    creator = function(sex) exports.my_clothing:OpenCreator(sex) end,
})]] },
    { 'client', 'fuel', [[exports.fn_bridge:Provide('fuel', function(vehicle)
    return exports.my_fuel:GetFuel(vehicle)
end)]] },
    { 'client', 'interact', [[exports.fn_bridge:Provide('interact', {
    isCuffed = function() return exports.my_police:IsCuffed() end,
})]] },
}

local function Skeleton(wanted)
    if not next(wanted) then return end

    print('^5paste into fn_bridge_custom (copy the folder out of fn_bridge first) and point it at your resources^7')
    for _, file in ipairs({ 'server', 'client' }) do
        local header = false
        for _, snippet in ipairs(Snippets) do
            local entry = snippet[1] == file and wanted[snippet[2]]
            if entry then
                if not header then print('^3' .. file .. '.lua^7') header = true end
                print('^2found: ' .. table.concat(entry.resources, ', ') .. '^7')
                print(snippet[3])
                print('')
            end
        end
    end
end

local function Files()
    print('^5files^7')
    local list = FN_UPDATE.Edited()
    if not list then return Line('release', 'no checksums.json', 'running from source, nothing to compare') end
    if #list == 0 then return Line('release', 'unchanged', 'an update keeps nothing of yours, it is all outside fn_bridge') end

    for _, path in ipairs(list) do Line('changed', path, 'the next update replaces it, move the change to fn_bridge_custom') end
end

RegisterCommand('fnb_doctor', function(source)
    if source ~= 0 then return end
    if not FN_BRIDGE.IsReady() then return print('fn_bridge is not ready yet') end

    CreateThread(function()
        local resources = Started()
        local client = ClientHooks(resources)

        print(('^5fn_bridge %s doctor^7'):format(FN_BRIDGE.version))
        Choices(client)
        Files()
        Shape()
        local wanted = Unknown(resources, client)
        Includes(resources)
        Skeleton(wanted)
    end)
end, true)
