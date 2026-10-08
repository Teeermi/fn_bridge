if not FN_BRIDGE.IsFramework('vrp') then return end

FN_FRAMEWORK = {}
FN_FRAMEWORK.obj = {}

FN_FRAMEWORK.GetFrameworkName = function()
    return 'vrp'
end

FN_FRAMEWORK.accountNames = {
    cash = 'cash',
    bank = 'bank',
    black_money = 'black_money',
}

FN_FRAMEWORK.ResolveAccount = function(accountName)
    return FN_FRAMEWORK.accountNames[accountName]
end

local ProxyId = 'fn_bridge_vrp'
local ProxySeq, ProxyWaiting = 0, {}

AddEventHandler(('vRP:%s:proxy_res'):format(ProxyId), function(requestId, results)
    local pending = ProxyWaiting[requestId]
    if not pending then return end

    ProxyWaiting[requestId] = nil
    pending:resolve(type(results) == 'table' and results or {})
end)

local function Vrp(member, ...)
    ProxySeq = ProxySeq + 1

    local requestId, pending = ProxySeq, promise.new()
    ProxyWaiting[requestId] = pending
    TriggerEvent('vRP:proxy', member, { ... }, ProxyId, requestId)

    SetTimeout(5000, function()
        if ProxyWaiting[requestId] then
            ProxyWaiting[requestId] = nil
            pending:resolve(false)
        end
    end)

    local results = Citizen.Await(pending)
    if not results then return nil, nil, true end

    return results[1], results[2]
end

FN_FRAMEWORK.obj.call = Vrp

local function UserId(playerId)
    playerId = tonumber(playerId)
    if not playerId or playerId <= 0 or not GetPlayerName(playerId) then return nil end

    return tonumber((Vrp('getUserId', playerId)))
end

local function TrimName(firstName, lastName)
    return ((firstName or '') .. ' ' .. (lastName or '')):match('^%s*(.-)%s*$')
end

local function IdentityName(identity)
    if type(identity) ~= 'table' then return nil end

    return TrimName(identity.firstname, identity.name)
end

local JobTypes = { job = true, primario = true }

local function JobName(userId)
    for groupType in pairs(JobTypes) do
        local group = Vrp('getUserGroupByType', userId, groupType)
        if type(group) == 'string' and group ~= '' then return group end
    end

    return nil
end

local function DirtyItem()
    local configured = type(FN_BRIDGE.Setting('dirtyMoney')) == 'table' and FN_BRIDGE.Setting('dirtyMoney').vrp

    return type(configured) == 'table' and configured.item or 'dinheirosujo'
end

local function PositiveAmount(amount)
    amount = math.floor(tonumber(amount) or 0)

    return amount > 0 and amount or nil
end

local function ResolveGroup(playerId)
    local userId = UserId(playerId)
    for _, group in ipairs({ 'god', 'superadmin', 'admin', 'mod' }) do
        if userId and Vrp('hasGroup', userId, group) then return group end
    end

    return IsPlayerAceAllowed(tostring(playerId), 'command') and 'admin' or 'user'
end

local JobCache

FN_FRAMEWORK.GetJobs = function()
    if JobCache then return JobCache end

    local jobs = {}
    for _, path in ipairs({ 'cfg/groups.lua', 'zirix/groups.lua' }) do
        local code = LoadResourceFile('vrp', path)
        local env = setmetatable({}, { __index = _G })
        local chunk = code and load(code, '@vrp/' .. path, 't', env)
        local ok, result = pcall(chunk or error)
        local list = ok and (type(result) == 'table' and result.groups or type(env.groups) == 'table' and env.groups.list or type(env.cfg) == 'table' and env.cfg.groups)

        for name, group in pairs(type(list) == 'table' and list or {}) do
            local config = type(group) == 'table' and group._config or {}
            if type(name) == 'string' and JobTypes[config.gtype] then
                local label = config.title or name
                jobs[name] = { name = name, label = label, grades = { [0] = { name = label, label = label, grade = 0, job_name = name, isBoss = false } } }
            end
        end

        if next(jobs) then break end
    end

    JobCache = jobs

    return jobs
end

FN_FRAMEWORK.RawPlayer = UserId

FN_FRAMEWORK.GetIdentifier = function(playerId)
    local userId = UserId(playerId)

    return userId and tostring(userId) or false
end

FN_FRAMEWORK.GetMoney = function(playerId, accountName)
    local userId = UserId(playerId)
    if not userId then return 0 end

    accountName = accountName or 'bank'
    if accountName == 'black_money' then return math.floor(tonumber(Vrp('getInventoryItemAmount', userId, DirtyItem())) or 0) end

    return math.floor(tonumber(Vrp(accountName == 'cash' and 'getMoney' or 'getBankMoney', userId)) or 0)
end

FN_FRAMEWORK.AddMoney = function(playerId, accountName, amount)
    amount = PositiveAmount(amount)
    local userId = UserId(playerId)
    if not amount or not userId then return false end

    accountName = accountName or 'bank'
    if accountName == 'black_money' then
        Vrp('giveInventoryItem', userId, DirtyItem(), amount)
        return true
    end

    local before = FN_FRAMEWORK.GetMoney(playerId, accountName)
    if accountName == 'cash' then
        Vrp('giveMoney', userId, amount)
        if FN_FRAMEWORK.GetMoney(playerId, 'cash') == before then Vrp('giveDinheirama', userId, amount) end
    else
        Vrp('giveBankMoney', userId, amount)
    end

    return FN_FRAMEWORK.GetMoney(playerId, accountName) > before
end

FN_FRAMEWORK.RemoveMoney = function(playerId, accountName, amount)
    amount = PositiveAmount(amount)
    local userId = UserId(playerId)
    accountName = accountName or 'bank'
    if not amount or not userId or FN_FRAMEWORK.GetMoney(playerId, accountName) < amount then return false end

    if accountName == 'black_money' then return Vrp('tryGetInventoryItem', userId, DirtyItem(), amount) == true end
    if accountName == 'cash' then return Vrp('tryPayment', userId, amount) == true end

    local balance = FN_FRAMEWORK.GetMoney(playerId, 'bank')
    Vrp('setBankMoney', userId, balance - amount)

    return FN_FRAMEWORK.GetMoney(playerId, 'bank') == balance - amount
end

local function Job(playerId)
    local userId = UserId(playerId)
    local name = userId and JobName(userId)
    if not name then return nil end

    local label = (FN_FRAMEWORK.GetJobs()[name] or {}).label or name

    return { name = name, label = label, grade = 0, grade_name = label, grade_label = label, isBoss = false, onDuty = true }
end

FN_FRAMEWORK.GetJob = function(playerId)
    return Job(playerId) or false
end

local function BuildPlayerData(playerId, userId)
    local identity = Vrp('getUserIdentity', userId)
    identity = type(identity) == 'table' and identity or {}
    local job = Job(playerId) or { name = 'unemployed', label = 'Unemployed', grade = 0, grade_name = 'unemployed', grade_label = 'Unemployed' }

    return {
        source = playerId,
        identifier = tostring(userId),
        group = ResolveGroup(playerId),
        job = {
            name = job.name,
            label = job.label,
            grade = job.grade,
            grade_name = job.grade_name,
            grade_label = job.grade_label,
        },
        char = {
            firstName = identity.firstname or '',
            lastName = identity.name or '',
            sex = 'm',
            badge = '',
        },
        showNotification = function(message, _type, duration)
            TriggerClientEvent('fn_bridge/client/notify', playerId, message, _type, duration)
        end,
        getName = function(separate)
            if separate then return { firstname = identity.firstname or '', lastname = identity.name or '' } end

            return IdentityName(identity) or ''
        end,
        setJob = function(jobName, jobGrade)
            FN_FRAMEWORK.SetJob(playerId, jobName, jobGrade)
        end,
        addAccountMoney = function(accountName, amount)
            return FN_FRAMEWORK.AddMoney(playerId, accountName, amount)
        end,
        removeAccountMoney = function(accountName, amount)
            return FN_FRAMEWORK.RemoveMoney(playerId, accountName, amount)
        end,
        getAccounts = function()
            return {
                cash = FN_FRAMEWORK.GetMoney(playerId, 'cash'),
                bank = FN_FRAMEWORK.GetMoney(playerId, 'bank'),
                black_money = FN_FRAMEWORK.GetMoney(playerId, 'black_money'),
            }
        end,
        addInventoryItem = function(itemName, amount)
            Vrp('giveInventoryItem', userId, itemName, amount)
        end,
        removeInventoryItem = function(itemName, amount)
            Vrp('tryGetInventoryItem', userId, itemName, amount)
        end,
        updateChar = function()
        end,
    }
end

FN_FRAMEWORK.GetPlayerFromId = function(playerId)
    local userId = UserId(playerId)
    if not userId then return false end

    return BuildPlayerData(tonumber(playerId), userId)
end

FN_FRAMEWORK.GetPlayerFromIdentifier = function(identifier)
    local playerId = tonumber((Vrp('getUserSource', tonumber(identifier))))
    if not playerId then return false end

    return FN_FRAMEWORK.GetPlayerFromId(playerId)
end

FN_FRAMEWORK.GetPlayers = function()
    local players = {}
    for _, playerId in ipairs(GetPlayers()) do
        if UserId(playerId) then players[#players + 1] = tonumber(playerId) end
    end

    return players
end

FN_FRAMEWORK.SetJob = function(target, jobName)
    if not FN_FRAMEWORK.GetJobs()[jobName] then return false end

    local userId = type(target) == 'number' and UserId(target) or tonumber(target)
    if not userId then return false end

    Vrp('addUserGroup', userId, jobName)

    return true
end

FN_FRAMEWORK.SetJobOffline = function(identifier, jobName, jobGrade)
    return FN_FRAMEWORK.SetJob(tostring(identifier), jobName, jobGrade)
end

FN_FRAMEWORK.RemoveJob = function(target, jobName)
    local userId = type(target) == 'number' and UserId(target) or tonumber(target)
    if not userId then return false end

    Vrp('removeUserGroup', userId, jobName)

    return true
end

FN_FRAMEWORK.CheckJobDuty = function(playerId)
    return UserId(playerId) ~= nil
end

FN_FRAMEWORK.SetJobDuty = function()
    return false
end

FN_FRAMEWORK.GetGang = function()
    return false
end

FN_FRAMEWORK.GetNeeds = function()
    return {}
end

FN_FRAMEWORK.GetPlayTime = function()
    return false
end

FN_FRAMEWORK.GetPhoneNumber = function(playerId)
    local userId = UserId(playerId)
    local identity = userId and Vrp('getUserIdentity', userId)

    return type(identity) == 'table' and identity.phone and tostring(identity.phone) or false
end

FN_FRAMEWORK.SetPhoneNumber = function(playerId, number)
    local userId = UserId(playerId)
    if not userId then return false end

    local ok, affected = pcall(MySQL.update.await, 'UPDATE vrp_user_identities SET phone = ? WHERE user_id = ?', { number, userId })

    return ok and (affected or 0) > 0
end

FN_FRAMEWORK.IsPhoneNumberTaken = function(number)
    return MySQL.scalar.await('SELECT 1 FROM vrp_user_identities WHERE phone = ? LIMIT 1', { tostring(number) }) ~= nil
end

FN_FRAMEWORK.SetName = function(playerId, firstName, lastName)
    local userId = UserId(playerId)
    if not userId then return false end

    local ok, affected = pcall(MySQL.update.await, 'UPDATE vrp_user_identities SET firstname = ?, name = ? WHERE user_id = ?', { firstName, lastName, userId })

    return ok and (affected or 0) > 0
end

FN_FRAMEWORK.IsNameTaken = function(firstName, lastName)
    return MySQL.scalar.await('SELECT 1 FROM vrp_user_identities WHERE firstname = ? AND name = ? LIMIT 1', { firstName, lastName }) ~= nil
end

FN_FRAMEWORK.GetOfflineCharName = function(identifier, separate)
    local row = MySQL.single.await('SELECT firstname, name FROM vrp_user_identities WHERE user_id = ?', { tonumber(identifier) })
    if not row then return false end
    if separate then return { firstname = row.firstname or '', lastname = row.name or '' } end

    return IdentityName(row)
end

FN_FRAMEWORK.GetCharacter = function(identifier)
    local row = MySQL.single.await('SELECT user_id, firstname, name, age, driverlicense, gunlicense FROM vrp_user_identities WHERE user_id = ?', { tonumber(identifier) })
    if not row then return false end

    local licenses = {}
    if tonumber(row.driverlicense) == 1 then licenses[#licenses + 1] = 'driver' end
    if tonumber(row.gunlicense) == 1 then licenses[#licenses + 1] = 'weapon' end

    return {
        identifier = tostring(row.user_id),
        firstName = row.firstname or '',
        lastName = row.name or '',
        name = IdentityName(row),
        dateOfBirth = row.age and tostring(row.age) or nil,
        licenses = licenses,
    }
end

FN_FRAMEWORK.SearchCharacters = function(query, limit)
    if type(query) ~= 'string' or #query < 2 then return {} end

    local safe = query:gsub('[%%_]', '')
    local rows = MySQL.query.await(('SELECT user_id, firstname, name FROM vrp_user_identities WHERE user_id = ? OR CONCAT(firstname, " ", name) LIKE ? LIMIT %d'):format(math.min(math.max(math.floor(tonumber(limit) or 10), 1), 10)), { tonumber(query) or -1, '%' .. safe .. '%' })

    local result = {}
    for _, row in ipairs(rows or {}) do
        result[#result + 1] = {
            identifier = tostring(row.user_id),
            charId = tostring(row.user_id),
            firstName = row.firstname or '',
            lastName = row.name or '',
            name = IdentityName(row),
        }
    end

    return result
end

FN_FRAMEWORK.GetCharactersByIds = function(identifiers)
    local list = {}
    for _, identifier in ipairs(type(identifiers) == 'table' and identifiers or {}) do
        if tonumber(identifier) and #list < 500 then list[#list + 1] = tonumber(identifier) end
    end
    if #list == 0 then return {} end

    local result = {}
    for _, row in ipairs(MySQL.query.await(('SELECT user_id, firstname, name, age FROM vrp_user_identities WHERE user_id IN (%s)'):format(FN_DB.Placeholders(#list)), list) or {}) do
        result[#result + 1] = { identifier = tostring(row.user_id), firstName = row.firstname or '', lastName = row.name or '', name = IdentityName(row), dateOfBirth = row.age and tostring(row.age) or nil }
    end

    return result
end

FN_FRAMEWORK.GetCharacters = function(license)
    local hash = type(license) == 'string' and (license:match('^license2?:(%w+)$') or license:match('^%w+$'))
    if not hash or not FN_DB.HasTable('vrp_user_ids') then return {} end

    local characters = {}
    for _, row in ipairs(MySQL.query.await('SELECT u.user_id, i.firstname, i.name FROM vrp_user_ids u LEFT JOIN vrp_user_identities i ON i.user_id = u.user_id WHERE u.identifier = ?', { 'license:' .. hash }) or {}) do
        local name = IdentityName(row) or ''
        characters[#characters + 1] = { identifier = tostring(row.user_id), name = name ~= '' and name or tostring(row.user_id) }
    end

    return characters
end

FN_FRAMEWORK.AddCharacterSlots = function()
    return false
end

FN_FRAMEWORK.GetJobMembers = function(jobName)
    local members = {}
    for _, playerId in ipairs(FN_FRAMEWORK.GetPlayers()) do
        local userId = UserId(playerId)
        if userId and Vrp('hasGroup', userId, jobName) then
            local name = IdentityName(Vrp('getUserIdentity', userId)) or GetPlayerName(playerId)
            members[#members + 1] = { identifier = tostring(userId), name = name, firstName = name, lastName = '', job = jobName, grade = 0, gradeLabel = '' }
        end
    end

    return members
end

FN_FRAMEWORK.CheckPermissions = function(playerId, groups)
    groups = FN_HELPER.NormalizeGroups(groups)
    local userId = UserId(playerId)
    if not groups or not userId then return false end

    for groupName, wanted in pairs(groups) do
        if wanted and Vrp('hasGroup', userId, groupName) then return true end
    end

    return groups[ResolveGroup(playerId)] or false
end

local Usable = {}

FN_FRAMEWORK.RegisterUsableItem = function(itemName, callback)
    Usable[itemName] = callback
end

FN_FRAMEWORK.UseItem = function(playerId, itemName)
    local callback = Usable[itemName]
    local player = callback and FN_FRAMEWORK.GetPlayerFromId(playerId)
    if player then callback(player, { name = itemName }) end
end

FN_FRAMEWORK.GetItemLabel = function(itemName)
    local label = Vrp('itemNameList', itemName)

    return type(label) == 'string' and label or itemName
end

FN_FRAMEWORK.GetVehicleByPlate = function(plate)
    return FN_VEHICLES.Get(plate)
end

FN_FRAMEWORK.GetPlayerVehicles = function(identifier)
    return FN_VEHICLES.List(identifier)
end

local LicenseColumns = { driver = 'driverlicense', weapon = 'gunlicense' }

FN_FRAMEWORK.CheckLicense = function(identifier, license)
    local column = LicenseColumns[license]

    return column ~= nil and tonumber(MySQL.scalar.await(('SELECT %s FROM vrp_user_identities WHERE user_id = ?'):format(column), { tonumber(identifier) })) == 1
end

local function SetLicense(identifier, license, value)
    local column = LicenseColumns[license]
    if not column then return false end

    local ok = pcall(MySQL.update.await, ('UPDATE vrp_user_identities SET %s = ? WHERE user_id = ?'):format(column), { value, tonumber(identifier) })

    return ok
end

FN_FRAMEWORK.AddLicense = function(identifier, license)
    return SetLicense(identifier, license, 1)
end

FN_FRAMEWORK.RemoveLicense = function(identifier, license)
    return SetLicense(identifier, license, 0)
end

FN_FRAMEWORK.NativeInventory = {
    GetPlayerItems = function(playerId)
        local userId = UserId(playerId)
        local inventory = userId and Vrp('getInventory', userId)
        local items = {}

        for key, entry in pairs(type(inventory) == 'table' and inventory or {}) do
            local name = type(entry) == 'table' and (entry.item or entry.name) or key
            local count = type(entry) == 'table' and (entry.amount or entry.count) or entry
            if type(name) == 'string' and (tonumber(count) or 0) > 0 then
                items[#items + 1] = { name = name, label = FN_FRAMEWORK.GetItemLabel(name), count = tonumber(count), metadata = {}, slot = tonumber(key) or false }
            end
        end

        return items
    end,
    AddItem = function(playerId, itemName, count)
        local userId = UserId(playerId)
        if not userId then return false end

        Vrp('giveInventoryItem', userId, itemName, tonumber(count) or 1)

        return true
    end,
    RemoveItem = function(playerId, itemName, count)
        local userId = UserId(playerId)

        return userId ~= nil and Vrp('tryGetInventoryItem', userId, itemName, tonumber(count) or 1) == true
    end,
    GetItemCount = function(playerId, itemName)
        local userId = UserId(playerId)

        return userId and math.floor(tonumber(Vrp('getInventoryItemAmount', userId, itemName)) or 0) or 0
    end,
}

FN_FRAMEWORK.NativeInventory.HasItem = function(playerId, itemName)
    return FN_FRAMEWORK.NativeInventory.GetItemCount(playerId, itemName) > 0
end

FN_FRAMEWORK.GetName = function(playerId)
    local userId = UserId(playerId)

    return userId and IdentityName(Vrp('getUserIdentity', userId)) or false
end

FN_FRAMEWORK.GetVehicleCatalog = function()
    return {}
end

local Features = {
    money = function() return true end,
    phoneNumber = function() return true end,
    characterSlots = function() return false end,
    needs = function() return false end,
    playTime = function() return false end,
    gangs = function() return false end,
    vehicles = function() return FN_VEHICLES.Available() end,
}

FN_FRAMEWORK.Supports = function(feature)
    local check = Features[feature]

    return check and check() == true or false
end

FN_FRAMEWORK.Probe = function()
    local _, _, timedOut = Vrp('getUserByRegistration', 'OPPROBE0')

    return not timedOut
end

AddEventHandler('vRP:playerSpawn', function(userId, playerId, firstSpawn)
    if not firstSpawn then return end

    playerId = tonumber(playerId)
    if not playerId then return end

    FN_JOBS.Seed(playerId)
    TriggerEvent('fn_bridge/server/playerLoaded', playerId, FN_FRAMEWORK.GetPlayerFromId(playerId))
end)

AddEventHandler('playerDropped', function()
    FN_JOBS.Forget(source)
end)

lib.callback.register('fn_bridge/server/checkPermissions', FN_FRAMEWORK.CheckPermissions)

lib.callback.register('fn_bridge/server/getAccounts', function(source)
    local player = FN_FRAMEWORK.GetPlayerFromId(source)
    if not player then return end

    return player.getAccounts()
end)

Config.DebugPrint('framework adapter loaded: vrp (server)')
