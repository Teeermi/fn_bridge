if not FN_BRIDGE.IsFramework('ox') then return end

FN_FRAMEWORK = {}
FN_FRAMEWORK.obj = exports.ox_core

FN_FRAMEWORK.GetFrameworkName = function()
    return 'ox'
end

FN_FRAMEWORK.accountNames = {
    cash = 'cash',
    bank = 'bank',
    black_money = 'black_money',
}

FN_FRAMEWORK.ResolveAccount = function(accountName)
    return FN_FRAMEWORK.accountNames[accountName]
end

local GroupPrecedence = { 'god', 'superadmin', 'admin', 'mod' }

local function TrimName(firstName, lastName)
    return ((firstName or '') .. ' ' .. (lastName or '')):match('^%s*(.-)%s*$')
end

local function OxPlayer(playerId)
    playerId = tonumber(playerId)
    if not playerId or playerId <= 0 then return nil end

    local ok, player = pcall(function() return exports.ox_core:GetPlayer(playerId) end)

    return ok and type(player) == 'table' and player.charId and player or nil
end

local function Get(playerId, key)
    local ok, value = pcall(function() return exports.ox_core:CallPlayer(playerId, 'get', key) end)

    return ok and value or nil
end

local function Call(playerId, method, ...)
    local args = table.pack(...)
    local ok, value = pcall(function() return exports.ox_core:CallPlayer(playerId, method, table.unpack(args, 1, args.n)) end)

    return ok and value or nil
end

local function ResolveGroup(playerId)
    for _, group in ipairs(GroupPrecedence) do
        if IsPlayerAceAllowed(tostring(playerId), 'group.' .. group) then return group end
    end

    return IsPlayerAceAllowed(tostring(playerId), 'command') and 'admin' or 'user'
end

local function BankAccount(playerId)
    local player = OxPlayer(playerId)
    local ok, account = pcall(function() return player and exports.ox_core:GetCharacterAccount(player.charId) end)

    return ok and type(account) == 'table' and account or nil
end

local function DirtyItem()
    local configured = type(FN_BRIDGE.Setting('dirtyMoney')) == 'table' and FN_BRIDGE.Setting('dirtyMoney').ox

    return type(configured) == 'table' and configured.item or 'black_money'
end

local function PositiveAmount(amount)
    amount = math.floor(tonumber(amount) or 0)

    return amount > 0 and amount or nil
end

local JobCache, JobCacheAt = nil, 0

FN_FRAMEWORK.ClearJobCache = function()
    JobCache = nil
end

FN_FRAMEWORK.GetJobs = function()
    if JobCache and GetGameTimer() - JobCacheAt < 60000 then return JobCache end

    local jobs = {}
    for _, group in ipairs(MySQL.query.await('SELECT name, label FROM ox_groups') or {}) do
        jobs[group.name] = { name = group.name, label = group.label or group.name, grades = { [0] = { name = '-', label = '-', grade = 0, job_name = group.name, isBoss = false } } }
    end

    for _, row in ipairs(MySQL.query.await('SELECT `group`, grade, label, accountRole FROM ox_group_grades') or {}) do
        local job = jobs[row.group]
        local grade = tonumber(row.grade)
        if job and grade then
            job.grades[grade] = { name = row.label, label = row.label, grade = grade, job_name = row.group, isBoss = row.accountRole == 'owner' }
        end
    end

    jobs.unemployed = jobs.unemployed or { name = 'unemployed', label = 'Unemployed', virtual = true, grades = { [0] = { name = 'Unemployed', label = 'Unemployed', grade = 0, job_name = 'unemployed', isBoss = false } } }
    JobCache, JobCacheAt = jobs, GetGameTimer()

    return jobs
end

local function ActiveJob(playerId)
    local name = Get(playerId, 'activeGroup')
    if type(name) ~= 'string' or name == '' then return nil end

    local grade = tonumber(Call(playerId, 'getGroup', name)) or 0
    local job = FN_FRAMEWORK.GetJobs()[name] or { label = name, grades = {} }
    local gradeData = job.grades[grade] or {}

    return {
        name = name,
        label = job.label or name,
        grade = grade,
        grade_name = gradeData.name or '',
        grade_label = gradeData.label or '',
        isBoss = gradeData.isBoss == true,
        onDuty = true,
    }
end

local function BuildPlayerData(playerId)
    local job = ActiveJob(playerId) or { name = 'unemployed', label = 'Unemployed', grade = 0, grade_name = 'unemployed', grade_label = 'Unemployed' }
    local firstName, lastName = Get(playerId, 'firstName') or '', Get(playerId, 'lastName') or ''

    return {
        source = playerId,
        identifier = FN_FRAMEWORK.GetIdentifier(playerId),
        group = ResolveGroup(playerId),
        job = {
            name = job.name,
            label = job.label,
            grade = job.grade,
            grade_name = job.grade_name,
            grade_label = job.grade_label,
        },
        char = {
            firstName = firstName,
            lastName = lastName,
            sex = Get(playerId, 'gender') == 'female' and 'f' or 'm',
            badge = '',
        },
        showNotification = function(message, _type, duration)
            TriggerClientEvent('fn_bridge/client/notify', playerId, message, _type, duration)
        end,
        getName = function(separate)
            if separate then return { firstname = firstName, lastname = lastName } end

            return TrimName(firstName, lastName)
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
        addInventoryItem = function(itemName, amount, metadata)
            if FN_INVENTORY then FN_INVENTORY.AddItem(playerId, itemName, amount, metadata) end
        end,
        removeInventoryItem = function(itemName, amount, metadata)
            if FN_INVENTORY then FN_INVENTORY.RemoveItem(playerId, itemName, amount, metadata) end
        end,
        updateChar = function()
        end,
    }
end

FN_FRAMEWORK.RawPlayer = OxPlayer

FN_FRAMEWORK.GetIdentifier = function(playerId)
    local player = OxPlayer(playerId)

    return player and tostring(player.charId) or false
end

FN_FRAMEWORK.GetPlayerFromId = function(playerId)
    if not OxPlayer(playerId) then return false end

    return BuildPlayerData(tonumber(playerId))
end

FN_FRAMEWORK.GetPlayerFromIdentifier = function(identifier)
    local ok, player = pcall(function() return exports.ox_core:GetPlayerFromCharId(tonumber(identifier)) end)
    if not ok or type(player) ~= 'table' or not player.source then return false end

    return FN_FRAMEWORK.GetPlayerFromId(player.source)
end

FN_FRAMEWORK.GetPlayers = function()
    local players = {}
    for _, playerId in ipairs(GetPlayers()) do
        if OxPlayer(playerId) then players[#players + 1] = tonumber(playerId) end
    end

    return players
end

FN_FRAMEWORK.GetMoney = function(playerId, accountName)
    accountName = accountName or 'bank'
    if not OxPlayer(playerId) then return 0 end

    local ok, value = pcall(function()
        if accountName == 'cash' then return exports.ox_inventory:GetItemCount(playerId, 'money') end
        if accountName == 'black_money' then return exports.ox_inventory:GetItemCount(playerId, DirtyItem()) end

        local account = BankAccount(playerId)

        return account and account.balance
    end)

    return ok and math.floor(tonumber(value) or 0) or 0
end

FN_FRAMEWORK.AddMoney = function(playerId, accountName, amount, reason)
    amount = PositiveAmount(amount)
    accountName = accountName or 'bank'
    if not amount or not OxPlayer(playerId) then return false end

    local ok, done = pcall(function()
        if accountName == 'cash' then return exports.ox_inventory:AddItem(playerId, 'money', amount) == true end
        if accountName == 'black_money' then return exports.ox_inventory:AddItem(playerId, DirtyItem(), amount) == true end

        local account = BankAccount(playerId)
        local result = account and exports.ox_core:CallAccount(account.accountId, 'addBalance', { amount = amount, message = reason or 'fn_bridge' })

        return type(result) == 'table' and result.success == true
    end)

    return ok and done == true
end

FN_FRAMEWORK.RemoveMoney = function(playerId, accountName, amount, reason)
    amount = PositiveAmount(amount)
    accountName = accountName or 'bank'
    if not amount or FN_FRAMEWORK.GetMoney(playerId, accountName) < amount then return false end

    local ok, done = pcall(function()
        if accountName == 'cash' then return exports.ox_inventory:RemoveItem(playerId, 'money', amount) == true end
        if accountName == 'black_money' then return exports.ox_inventory:RemoveItem(playerId, DirtyItem(), amount) == true end

        local account = BankAccount(playerId)
        local result = account and exports.ox_core:CallAccount(account.accountId, 'removeBalance', { amount = amount, message = reason or 'fn_bridge' })

        return type(result) == 'table' and result.success == true
    end)

    return ok and done == true
end

FN_FRAMEWORK.GetJob = function(playerId)
    if not OxPlayer(playerId) then return false end

    return ActiveJob(playerId) or false
end

FN_FRAMEWORK.SetJob = function(target, jobName, grade)
    grade = math.floor(tonumber(grade) or 0)
    local job = FN_FRAMEWORK.GetJobs()[jobName]
    if not job or not job.grades[grade] then return false end

    if job.virtual then
        if type(target) ~= 'number' or not OxPlayer(target) then return false end

        return pcall(function() exports.ox_core:CallPlayer(target, 'setActiveGroup') end)
    end

    if type(target) == 'number' then
        if not OxPlayer(target) then return false end

        local ok = pcall(function()
            exports.ox_core:CallPlayer(target, 'setGroup', jobName, grade)
            exports.ox_core:CallPlayer(target, 'setActiveGroup', jobName)
        end)

        return ok
    end

    return FN_FRAMEWORK.SetJobOffline(target, jobName, grade)
end

FN_FRAMEWORK.SetJobOffline = function(identifier, jobName, jobGrade)
    local charId = tonumber(identifier)
    if not charId or type(jobName) ~= 'string' then return false end

    local ok, affected = pcall(MySQL.update.await, 'INSERT INTO character_groups (charId, name, grade) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE grade = VALUES(grade)', { charId, jobName, math.max(math.floor(tonumber(jobGrade) or 1), 1) })

    return ok and (affected or 0) > 0
end

FN_FRAMEWORK.RemoveJob = function(target, jobName)
    if type(target) == 'number' then
        if not OxPlayer(target) then return false end

        return pcall(function() exports.ox_core:CallPlayer(target, 'setGroup', jobName, 0) end)
    end

    local ok, affected = pcall(MySQL.update.await, 'DELETE FROM character_groups WHERE charId = ? AND name = ?', { tonumber(target), jobName })

    return ok and (affected or 0) > 0
end

FN_FRAMEWORK.CheckJobDuty = function(playerId)
    return OxPlayer(playerId) ~= nil
end

FN_FRAMEWORK.SetJobDuty = function()
    return false
end

FN_FRAMEWORK.GetGang = function()
    return false
end

local function Percent(value)
    value = tonumber(value)

    return value and math.max(0, math.min(100, math.floor(value + 0.5))) or nil
end

FN_FRAMEWORK.GetNeeds = function(playerId)
    if not OxPlayer(playerId) then return {} end

    return {
        hunger = Percent(Call(playerId, 'getStatus', 'hunger')),
        thirst = Percent(Call(playerId, 'getStatus', 'thirst')),
        stress = Percent(Call(playerId, 'getStatus', 'stress')),
    }
end

FN_FRAMEWORK.GetPlayTime = function()
    return false
end

FN_FRAMEWORK.GetPhoneNumber = function(playerId)
    if not OxPlayer(playerId) then return false end

    local number = Get(playerId, 'phoneNumber')

    return number and tostring(number) or false
end

FN_FRAMEWORK.SetPhoneNumber = function(playerId, number)
    local player = OxPlayer(playerId)
    if not player then return false end

    local ok, affected = pcall(MySQL.update.await, 'UPDATE characters SET phoneNumber = ? WHERE charId = ?', { number, player.charId })
    if not ok or (affected or 0) < 1 then return false end

    pcall(function() exports.ox_core:CallPlayer(playerId, 'set', 'phoneNumber', number, true) end)

    return true
end

FN_FRAMEWORK.IsPhoneNumberTaken = function(number)
    return MySQL.scalar.await('SELECT 1 FROM characters WHERE phoneNumber = ? LIMIT 1', { tostring(number) }) ~= nil
end

FN_FRAMEWORK.SetName = function()
    return false
end

FN_FRAMEWORK.IsNameTaken = function(firstName, lastName)
    return MySQL.scalar.await('SELECT 1 FROM characters WHERE firstName = ? AND lastName = ? AND deleted IS NULL LIMIT 1', { firstName, lastName }) ~= nil
end

FN_FRAMEWORK.GetOfflineCharName = function(identifier, separate)
    local row = MySQL.single.await('SELECT firstName, lastName FROM characters WHERE charId = ?', { tonumber(identifier) })
    if not row then return false end
    if separate then return { firstname = row.firstName or '', lastname = row.lastName or '' } end

    return TrimName(row.firstName, row.lastName)
end

local function CharacterRow(row)
    return {
        identifier = tostring(row.charId),
        charId = tostring(row.stateId or row.charId),
        firstName = row.firstName or '',
        lastName = row.lastName or '',
        name = TrimName(row.firstName, row.lastName),
        lastSeen = tonumber(row.last_seen),
        dateOfBirth = row.dob,
        sex = row.gender == 'female' and 'f' or row.gender and 'm' or nil,
    }
end

local CharacterColumns = 'charId, stateId, firstName, lastName, gender, DATE_FORMAT(dateOfBirth, "%Y-%m-%d") AS dob, UNIX_TIMESTAMP(lastPlayed) AS last_seen'

FN_FRAMEWORK.SearchCharacters = function(query, limit)
    if type(query) ~= 'string' then return {} end

    local needle = query:match('^%s*(.-)%s*$')
    if #needle < 2 or #needle > 64 then return {} end

    local safe = needle:gsub('[%%_]', '')
    local rows = MySQL.query.await(('SELECT %s FROM characters WHERE deleted IS NULL AND (charId = ? OR stateId = ? OR fullName LIKE ?) LIMIT %d'):format(CharacterColumns, math.min(math.max(math.floor(tonumber(limit) or 10), 1), 10)), { tonumber(needle) or -1, needle, '%' .. safe .. '%' })

    local result = {}
    for _, row in ipairs(rows or {}) do
        result[#result + 1] = CharacterRow(row)
    end

    return result
end

FN_FRAMEWORK.GetCharacter = function(identifier)
    local charId = tonumber(identifier)
    if not charId then return false end

    local row = MySQL.single.await(('SELECT %s FROM characters WHERE charId = ?'):format(CharacterColumns), { charId })
    if not row then return false end

    local character = CharacterRow(row)
    character.licenses = {}
    for _, license in ipairs(MySQL.query.await('SELECT name FROM character_licenses WHERE charId = ?', { charId }) or {}) do
        character.licenses[#character.licenses + 1] = license.name
    end

    return character
end

FN_FRAMEWORK.GetCharactersByIds = function(identifiers)
    local list = {}
    for _, identifier in ipairs(type(identifiers) == 'table' and identifiers or {}) do
        if tonumber(identifier) and #list < 500 then list[#list + 1] = tonumber(identifier) end
    end
    if #list == 0 then return {} end

    local result = {}
    for _, row in ipairs(MySQL.query.await(('SELECT %s FROM characters WHERE charId IN (%s)'):format(CharacterColumns, FN_DB.Placeholders(#list)), list) or {}) do
        result[#result + 1] = CharacterRow(row)
    end

    return result
end

FN_FRAMEWORK.GetCharacters = function(license)
    local hash = type(license) == 'string' and (license:match('^license2?:(%w+)$') or license:match('^%w+$'))
    if not hash then return {} end

    local characters = {}
    for _, row in ipairs(MySQL.query.await('SELECT c.charId, c.firstName, c.lastName FROM characters c JOIN users u ON u.userId = c.userId WHERE c.deleted IS NULL AND u.license2 IN (?, ?)', { hash, 'license2:' .. hash }) or {}) do
        local name = TrimName(row.firstName, row.lastName)
        characters[#characters + 1] = { identifier = tostring(row.charId), name = name ~= '' and name or tostring(row.charId) }
    end

    return characters
end

FN_FRAMEWORK.AddCharacterSlots = function()
    return false
end

FN_FRAMEWORK.GetJobMembers = function(jobName, options)
    local jobs = type(jobName) == 'table' and jobName or { jobName }
    if #jobs == 0 then return {} end

    options = type(options) == 'table' and options or {}
    local limit = math.min(math.max(math.floor(tonumber(options.limit) or 500), 1), 500)
    local offset = math.max(math.floor(tonumber(options.offset) or 0), 0)
    local rows = MySQL.query.await(('SELECT c.charId, c.firstName, c.lastName, g.name, g.grade FROM character_groups g JOIN characters c ON c.charId = g.charId WHERE g.name IN (%s) AND c.deleted IS NULL ORDER BY c.charId LIMIT %d OFFSET %d'):format(FN_DB.Placeholders(#jobs), limit, offset), jobs) or {}
    local jobList = FN_FRAMEWORK.GetJobs()

    local result = {}
    for _, row in ipairs(rows) do
        local grade = tonumber(row.grade) or 0
        local gradeData = (jobList[row.name] or { grades = {} }).grades[grade] or {}
        result[#result + 1] = {
            identifier = tostring(row.charId),
            firstName = row.firstName or '',
            lastName = row.lastName or '',
            name = TrimName(row.firstName, row.lastName),
            job = row.name,
            grade = grade,
            gradeLabel = gradeData.label or tostring(grade),
        }
    end

    return result
end

FN_FRAMEWORK.CheckPermissions = function(playerId, groups)
    groups = FN_HELPER.NormalizeGroups(groups)
    if not groups or not OxPlayer(playerId) then return false end

    for groupName, wanted in pairs(groups) do
        if wanted and IsPlayerAceAllowed(tostring(playerId), 'group.' .. groupName) then return true end
    end

    return groups[ResolveGroup(playerId)] or false
end

local Usable = {}

FN_FRAMEWORK.RegisterUsableItem = function(itemName, callback)
    Usable[itemName] = callback
end

exports('useItem', function(event, item, inventory, slot)
    if event ~= 'usingItem' then return end

    local callback = Usable[item and item.name]
    local player = callback and FN_FRAMEWORK.GetPlayerFromId(inventory and inventory.id)
    if not player then return end

    callback(player, { name = item.name, slot = tonumber(slot), metadata = item.metadata })
end)

FN_FRAMEWORK.UseItem = function(playerId, itemName)
    local callback = Usable[itemName]
    local player = callback and FN_FRAMEWORK.GetPlayerFromId(playerId)
    if player then callback(player, { name = itemName }) end
end

FN_FRAMEWORK.GetItemLabel = function(itemName)
    local ok, item = pcall(function() return exports.ox_inventory:Items(itemName) end)

    return ok and type(item) == 'table' and item.label or itemName
end

FN_FRAMEWORK.GetVehicleByPlate = function(plate)
    return FN_VEHICLES.Get(plate)
end

FN_FRAMEWORK.GetPlayerVehicles = function(identifier)
    return FN_VEHICLES.List(identifier)
end

FN_FRAMEWORK.CheckLicense = function(identifier, license)
    return MySQL.scalar.await('SELECT 1 FROM character_licenses WHERE charId = ? AND name = ?', { tonumber(identifier), license }) ~= nil
end

FN_FRAMEWORK.AddLicense = function(identifier, license)
    local ok = pcall(MySQL.insert.await, 'INSERT IGNORE INTO character_licenses (charId, name, data) VALUES (?, ?, ?)', { tonumber(identifier), license, json.encode({ issued = os.time() }) })

    return ok
end

FN_FRAMEWORK.RemoveLicense = function(identifier, license)
    local ok = pcall(MySQL.query.await, 'DELETE FROM character_licenses WHERE charId = ? AND name = ?', { tonumber(identifier), license })

    return ok
end

FN_FRAMEWORK.GetName = function(playerId)
    if not OxPlayer(playerId) then return false end

    return TrimName(Get(playerId, 'firstName'), Get(playerId, 'lastName'))
end

FN_FRAMEWORK.GetVehicleCatalog = function()
    local ok, vehicles = pcall(function() return exports.ox_core:GetVehicleData() end)
    local catalog = {}

    for model, vehicle in pairs(ok and type(vehicles) == 'table' and vehicles or {}) do
        if type(model) == 'string' and type(vehicle) == 'table' then
            catalog[model:lower()] = { model = model:lower(), label = vehicle.name or model, brand = vehicle.make, price = math.floor(tonumber(vehicle.price) or 0), category = vehicle.class }
        end
    end

    return catalog
end

local Features = {
    money = function() return true end,
    phoneNumber = function() return true end,
    characterSlots = function() return false end,
    needs = function() return true end,
    playTime = function() return false end,
    gangs = function() return false end,
    vehicles = function() return FN_VEHICLES.Available() end,
}

FN_FRAMEWORK.Supports = function(feature)
    local check = Features[feature]

    return check and check() == true or false
end

local LoadedPlayers = {}

local function OnPlayerLoaded(playerId)
    playerId = tonumber(playerId)
    if not playerId or LoadedPlayers[playerId] then return end

    LoadedPlayers[playerId] = true
    Player(playerId).state:set('fnGroup', ResolveGroup(playerId), true)
    FN_JOBS.Seed(playerId)
    TriggerEvent('fn_bridge/server/playerLoaded', playerId, FN_FRAMEWORK.GetPlayerFromId(playerId))
end

local function OnPlayerUnloaded(playerId)
    playerId = tonumber(playerId)
    if not playerId then return end

    LoadedPlayers[playerId] = nil
    FN_JOBS.Forget(playerId)
end

AddEventHandler('ox:playerLoaded', OnPlayerLoaded)
AddEventHandler('ox:playerLogout', OnPlayerUnloaded)
AddEventHandler('playerDropped', function() OnPlayerUnloaded(source) end)
AddEventHandler('ox:setGroup', function(playerId) FN_JOBS.Publish(playerId) end)
AddEventHandler('ox:setActiveGroup', function(playerId) FN_JOBS.Publish(playerId) end)

CreateThread(function()
    for _, playerId in ipairs(FN_FRAMEWORK.GetPlayers()) do
        OnPlayerLoaded(playerId)
    end
end)

lib.callback.register('fn_bridge/server/checkPermissions', FN_FRAMEWORK.CheckPermissions)

lib.callback.register('fn_bridge/server/getAccounts', function(source)
    local player = FN_FRAMEWORK.GetPlayerFromId(source)
    if not player then return end

    return player.getAccounts()
end)

Config.DebugPrint('framework adapter loaded: ox (server)')
