if not FN_BRIDGE.IsFramework('esx') then return end

local function GetSharedObject()
    local ok, sharedObject = pcall(function()
        return exports['es_extended']:getSharedObject()
    end)

    if not ok or type(sharedObject) ~= 'table' then return nil end

    return sharedObject
end

FN_FRAMEWORK = {}
FN_FRAMEWORK.obj = GetSharedObject()

if not FN_FRAMEWORK.obj then
    CreateThread(function()
        local deadline = GetGameTimer() + 30000
        repeat
            Wait(100)
            FN_FRAMEWORK.obj = GetSharedObject()
        until FN_FRAMEWORK.obj or GetGameTimer() > deadline

        if not FN_FRAMEWORK.obj then
            print('^1es_extended never returned a shared object^7 - start fn_bridge after es_extended.')
        end
    end)
end

TriggerEvent("__cfx_export_ox_inventory_Items", function(ref)
    if not FN_FRAMEWORK.obj or not ref then return end
    FN_FRAMEWORK.obj.Items = ref()
end)

AddEventHandler("ox_inventory:itemList", function(items)
    if not FN_FRAMEWORK.obj then return end
    FN_FRAMEWORK.obj.Items = items
end)

FN_FRAMEWORK.GetFrameworkName = function()
    return 'esx'
end

FN_FRAMEWORK.accountNames = {
    cash = 'money',
    bank = 'bank',
    black_money = 'black_money',
}

FN_FRAMEWORK.ResolveAccount = function(accountName)
    return FN_FRAMEWORK.accountNames[accountName] or accountName
end

local Resource = GetCurrentResourceName()

FN_FRAMEWORK.CallFailures = {}

local function Lookup(stock, fork, key)
    local esx = FN_FRAMEWORK.obj
    if not esx or key == nil then return nil end

    local find = esx[stock] or esx[fork]
    local ok, xPlayer = pcall(find, key)

    return ok and type(xPlayer) == 'table' and xPlayer or nil
end

local function XPlayer(playerId)
    playerId = tonumber(playerId)

    return playerId and Lookup('GetPlayerFromId', 'GetPlayerFromIdClass', playerId) or nil
end

local function Call(xPlayer, method, ...)
    if type(xPlayer) ~= 'table' then return nil, false end

    local esx = FN_FRAMEWORK.obj
    local fn = xPlayer[method]
    local ok, result

    if fn ~= nil then
        ok, result = pcall(fn, ...)
    elseif esx and esx.PlayerFuncs then
        ok, result = pcall(esx.PlayerFuncs, Resource, xPlayer.source, method, ...)
    else
        FN_FRAMEWORK.CallFailures[method] = FN_FRAMEWORK.CallFailures[method] or 'missing'
        return nil, false
    end

    if ok then return result, true end

    if not FN_FRAMEWORK.CallFailures[method] then
        FN_FRAMEWORK.CallFailures[method] = tostring(result)
        print(('^3fn_bridge: xPlayer.%s failed on this ESX build^7 (%s). Run fnb_doctor.'):format(method, tostring(result)))
    end

    return nil, false
end

FN_FRAMEWORK.RawPlayer = XPlayer
FN_FRAMEWORK.Call = Call

local function Text(value)
    return type(value) == 'string' and value ~= '' and value or nil
end

local function Balance(xPlayer, account)
    local entry = Call(xPlayer, 'getAccount', account)

    return type(entry) == 'table' and math.floor(tonumber(entry.money) or 0) or 0
end

local function Names(xPlayer)
    local first = Text(Call(xPlayer, 'get', 'firstName')) or Text(xPlayer.firstName)
    local last = Text(Call(xPlayer, 'get', 'lastName')) or Text(xPlayer.lastName)
    if first or last then return first or '', last or '' end

    local full = tonumber(xPlayer.source) and Text(Player(xPlayer.source).state.identityName)
    if not full and type(xPlayer.identifier) == 'string' and FN_DB.HasColumn('users', 'firstname') then
        local row = MySQL.single.await('SELECT firstname, lastname FROM users WHERE identifier = ?', { xPlayer.identifier })
        if row and (Text(row.firstname) or Text(row.lastname)) then return row.firstname or '', row.lastname or '' end
    end

    full = full or Text(Call(xPlayer, 'getName')) or ''
    first, last = full:match('^(%S*)%s*(.-)$')

    return first, last
end

local function BuildPlayerData(playerId, xPlayer)
    local firstName, lastName = Names(xPlayer)

    return {
        source = playerId,
        identifier = xPlayer.identifier,
        group = xPlayer.group,
        job = {
            name = xPlayer?.job?.name or 'unemployed',
            label = xPlayer?.job?.label or 'Unemployed',
            grade = xPlayer?.job?.grade or 0,
            grade_name = xPlayer?.job?.grade_name or 'unemployed',
            grade_label = xPlayer?.job?.grade_label or 'Unemployed',
        },
        char = {
            firstName = firstName,
            lastName = lastName,
            sex = Call(xPlayer, 'get', 'sex') or xPlayer.sex,
            badge = '',
        },
        showNotification = function(message, _type, duration)
            TriggerClientEvent('fn_bridge/client/notify', playerId, message, _type, duration)
        end,
        getName = function(separate)
            local first, last = Names(xPlayer)
            if separate then return { firstname = first, lastname = last } end

            return first .. ' ' .. last
        end,
        setJob = function(jobName, jobGrade, onDuty)
            Call(xPlayer, 'setJob', jobName, jobGrade, onDuty)
        end,
        addAccountMoney = function(accountName, amount)
            if type(amount) ~= 'number' or amount <= 0 then return false end

            return select(2, Call(xPlayer, 'addAccountMoney', FN_FRAMEWORK.ResolveAccount(accountName), amount))
        end,
        removeAccountMoney = function(accountName, amount)
            if type(amount) ~= 'number' or amount <= 0 then return false end

            return select(2, Call(xPlayer, 'removeAccountMoney', FN_FRAMEWORK.ResolveAccount(accountName), amount))
        end,
        getAccounts = function()
            return {
                cash = Balance(xPlayer, 'money'),
                bank = Balance(xPlayer, 'bank'),
                black_money = Balance(xPlayer, 'black_money'),
            }
        end,
        addInventoryItem = function(itemName, amount, metadata)
            Call(xPlayer, 'addInventoryItem', itemName, amount, metadata)
        end,
        removeInventoryItem = function(itemName, amount, metadata)
            Call(xPlayer, 'removeInventoryItem', itemName, amount, metadata)
        end,
        updateChar = function(key, value)
            if not key then return end
            Call(xPlayer, 'set', key == 'firstname' and 'firstName' or key == 'lastname' and 'lastName' or key, value)
        end,
    }
end

FN_FRAMEWORK.GetPlayerFromId = function(playerId)
    local xPlayer = XPlayer(playerId)
    if not xPlayer then return false end

    return BuildPlayerData(tonumber(playerId), xPlayer)
end

FN_FRAMEWORK.GetPlayerFromIdentifier = function(identifier)
    local xPlayer = Lookup('GetPlayerFromIdentifier', 'GetPlayerFromIdentifierClass', identifier)
    if not xPlayer then return false end

    return BuildPlayerData(xPlayer.source, xPlayer)
end

AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    FN_JOBS.Seed(playerId)
    TriggerEvent('fn_bridge/server/playerLoaded', playerId, FN_FRAMEWORK.GetPlayerFromId(playerId) or xPlayer)
end)

AddEventHandler('esx:setJob', function(playerId)
    FN_JOBS.Publish(playerId)
end)

FN_FRAMEWORK.GetOfflineCharName = function(identifier, separate)
    local player = FN_FRAMEWORK.GetPlayerFromIdentifier(identifier)
    if player then return player.getName(separate) end

    local playerData = MySQL.single.await('SELECT firstname, lastname FROM users WHERE identifier = ?', {identifier})
    if not playerData then return false end
    if separate then return { firstname = playerData.firstname, lastname = playerData.lastname } end

    return playerData.firstname .. ' ' .. playerData.lastname
end

local SearchLimit = 10
local SearchNameClause = [[ OR firstname LIKE ? OR lastname LIKE ? OR CONCAT(firstname, ' ', lastname) LIKE ?]]

local function TrimName(firstName, lastName)
    return ((firstName or '') .. ' ' .. (lastName or '')):match('^%s*(.-)%s*$')
end

local function ClampSearchLimit(limit)
    limit = math.floor(tonumber(limit) or SearchLimit)
    if limit < 1 then return 1 end
    if limit > SearchLimit then return SearchLimit end

    return limit
end

local function SearchNeedle(query)
    if type(query) ~= 'string' then return nil, nil end

    local needle = query:match('^%s*(.-)%s*$')
    if #needle < 2 or #needle > 64 then return nil, nil end

    local safe = needle:gsub('[%%_]', '')
    if #safe < 2 then return needle, nil end

    return needle, safe
end

FN_FRAMEWORK.SearchCharacters = function(query, limit)
    local needle, safe = SearchNeedle(query)
    if not needle then return {} end

    local charId = FN_CHARID.Source()
    local sql = ('SELECT identifier, %s AS char_id, firstname, lastname, dateofbirth, sex, job, job_grade FROM users WHERE identifier = ?'):format(charId and charId.value or 'NULL')
    local params = { needle }

    if charId then
        sql = ('%s OR %s = ?'):format(sql, charId.value)
        params[#params + 1] = needle
    end

    if safe then
        sql = sql .. SearchNameClause
        params[#params + 1] = safe .. '%'
        params[#params + 1] = safe .. '%'
        params[#params + 1] = '%' .. safe .. '%'
    end

    local rows = MySQL.query.await(sql .. (' LIMIT %d'):format(ClampSearchLimit(limit)), params)

    local result = {}
    for _, row in ipairs(rows or {}) do
        local sex = type(row.sex) == 'string' and row.sex:lower() or ''

        result[#result + 1] = {
            identifier = row.identifier,
            charId = row.char_id or row.identifier,
            firstName = row.firstname or '',
            lastName = row.lastname or '',
            name = TrimName(row.firstname, row.lastname),
            job = row.job,
            grade = tonumber(row.job_grade) or 0,
            lastSeen = nil,
            dateOfBirth = row.dateofbirth ~= '' and row.dateofbirth or nil,
            sex = sex ~= '' and (sex:sub(1, 1) == 'f' and 'f' or 'm') or nil,
            nationality = nil,
        }
    end

    return result
end

local MemberLimit = 500
local MemberMaxOffset = 100000

local function MemberFilter(sql, params, operator, list)
    local count = 0

    for _, identifier in ipairs(list) do
        if type(identifier) == 'string' then
            count = count + 1
            params[#params + 1] = identifier
        end
    end

    if count == 0 then return sql, 0 end

    return ('%s AND identifier %s (%s)'):format(sql, operator, string.rep('?', count, ', ')), count
end

FN_FRAMEWORK.GetJobMembers = function(jobName, options)
    local jobs = type(jobName) == 'table' and jobName or { jobName }
    if #jobs == 0 then return {} end

    for _, job in ipairs(jobs) do
        if type(job) ~= 'string' or job == '' then return {} end
    end

    options = type(options) == 'table' and options or {}

    local sql = ('SELECT identifier, firstname, lastname, job, job_grade FROM users WHERE job IN (%s)'):format(string.rep('?', #jobs, ', '))
    local params = { table.unpack(jobs) }

    if options.search ~= nil then
        local _, safe = SearchNeedle(options.search)
        if not safe then return {} end

        sql = sql .. " AND CONCAT(firstname, ' ', lastname) LIKE ?"
        params[#params + 1] = '%' .. safe .. '%'
    end

    if type(options.identifiers) == 'table' then
        local count
        sql, count = MemberFilter(sql, params, 'IN', options.identifiers)
        if count == 0 then return {} end
    end

    if type(options.exclude) == 'table' then
        sql = MemberFilter(sql, params, 'NOT IN', options.exclude)
    end

    local limit = math.min(math.max(math.floor(tonumber(options.limit) or MemberLimit), 1), MemberLimit)
    local offset = math.min(math.max(math.floor(tonumber(options.offset) or 0), 0), MemberMaxOffset)
    local rows = MySQL.query.await(sql .. (' ORDER BY identifier LIMIT %d OFFSET %d'):format(limit, offset), params)
    local jobList = FN_FRAMEWORK.GetJobs()

    local result = {}
    for _, row in ipairs(rows or {}) do
        local grade = tonumber(row.job_grade) or 0
        local grades = (jobList[row.job] or {}).grades or {}

        result[#result + 1] = {
            identifier = row.identifier,
            firstName = row.firstname or '',
            lastName = row.lastname or '',
            name = TrimName(row.firstname, row.lastname),
            job = row.job,
            grade = grade,
            gradeLabel = grades[grade] and grades[grade].label or tostring(grade),
        }
    end

    return result
end

MySQL.ready(function()
    local checked, indexed = pcall(MySQL.scalar.await, "SELECT 1 FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'job' AND SEQ_IN_INDEX = 1 LIMIT 1")
    if not checked or indexed then return end

    local created, result = pcall(MySQL.query.await, 'CREATE INDEX fn_bridge_job ON users (job)')

    if created and result then
        print('^2fn_bridge added an index on users.job^7 so job member lookups stay fast.')
    else
        print('^3fn_bridge could not add an index on users.job^7 - job member lookups still work, only slower on big databases.')
    end
end)

FN_FRAMEWORK.SetJobOffline = function(identifier, jobName, jobGrade)
    local result = MySQL.update.await('UPDATE users SET job = ?, job_grade = ? WHERE identifier = ?', {jobName, jobGrade, identifier})
    return result > 0
end

FN_FRAMEWORK.CheckJobDuty = function(playerId)
    local xPlayer = XPlayer(playerId)
    if not xPlayer?.job then return false end
    if xPlayer.job.onDuty == nil then return true end

    return xPlayer.job.onDuty and true or false
end

FN_FRAMEWORK.SetJobDuty = function(playerId, dutyStatus)
    if type(dutyStatus) ~= 'boolean' then return false end

    local xPlayer = XPlayer(playerId)
    if not xPlayer?.job then return false end

    Call(xPlayer, 'setJob', xPlayer.job.name, xPlayer.job.grade, dutyStatus)

    return FN_FRAMEWORK.CheckJobDuty(playerId) == dutyStatus
end

FN_FRAMEWORK.RegisterUsableItem = function(itemName, callback)
    FN_FRAMEWORK.obj.RegisterUsableItem(itemName, function(playerId, _, item)
        local xPlayer = FN_FRAMEWORK.GetPlayerFromId(playerId)
        if not xPlayer then return end

        callback(xPlayer, { name = itemName, slot = type(item) == 'table' and tonumber(item.slot) or nil, metadata = type(item) == 'table' and item.metadata or nil })
    end)
end

FN_FRAMEWORK.UseItem = function(playerId, itemName)
    FN_FRAMEWORK.obj.UseItem(playerId, itemName)
end

FN_FRAMEWORK.GetItemLabel = function(itemName)
    local allItems = FN_FRAMEWORK.obj.Items
    if not allItems then return itemName end
    if not allItems[itemName] then return itemName end

    return allItems[itemName].label or itemName
end

FN_FRAMEWORK.GetPlayers = function()
    local players = {}
    local esx = FN_FRAMEWORK.obj
    local ok, list = pcall(esx.GetPlayers)

    if not ok or type(list) ~= 'table' then
        ok, list = pcall(esx.GetExtendedPlayers or esx.GetExtendedPlayersClass)
        if not ok or type(list) ~= 'table' then return players end
    end

    for _, entry in ipairs(list) do
        players[#players + 1] = tonumber(type(entry) == 'table' and entry.source or entry)
    end

    return players
end

FN_FRAMEWORK.GetJobs = function()
    local jobs = {}
    local grades = MySQL.query.await('SELECT jobs.name AS job_name, jobs.label AS job_label, job_grades.grade AS grade, job_grades.name AS grade_name, job_grades.label AS grade_label FROM job_grades INNER JOIN jobs ON jobs.name = job_grades.job_name')
    if not grades then return jobs end

    for _, grade in ipairs(grades) do
        if not jobs[grade.job_name] then
            jobs[grade.job_name] = { name = grade.job_name, label = grade.job_label, grades = {} }
        end

        jobs[grade.job_name].grades[grade.grade] = {
            name = grade.grade_name,
            label = grade.grade_label,
            grade = grade.grade,
            job_name = grade.job_name,
            isBoss = grade.grade_name == 'boss',
        }
    end

    return jobs
end

FN_FRAMEWORK.GetVehicleByPlate = function(plate)
    local vehicleData = MySQL.single.await('SELECT * FROM owned_vehicles WHERE plate = ?', {plate})
    if not vehicleData then return false end

    return {
        owner = vehicleData.owner,
        plate = vehicleData.plate,
        vehicle = json.decode(vehicleData.vehicle),
        stored = vehicleData.stored == 1 or vehicleData.stored == true,
    }
end

FN_FRAMEWORK.GetPlayerVehicles = function(identifier)
    local result = {}
    local vehicles = MySQL.query.await('SELECT * FROM owned_vehicles WHERE owner = ?', {identifier})
    if not vehicles then return {} end

    for _, vehicleData in ipairs(vehicles) do
        result[#result + 1] = {
            owner = vehicleData.owner,
            plate = vehicleData.plate,
            vehicle = json.decode(vehicleData.vehicle),
            stored = vehicleData.stored == 1 or vehicleData.stored == true,
        }
    end

    return result
end

FN_FRAMEWORK.CheckLicense = function(identifier, license)
    local result = MySQL.single.await('SELECT owner FROM user_licenses WHERE owner = ? AND type = ?', {identifier, license})
    if not result then return false end

    return true
end

FN_FRAMEWORK.AddLicense = function(identifier, license)
    if FN_FRAMEWORK.CheckLicense(identifier, license) then return true end

    MySQL.insert.await('INSERT INTO user_licenses (owner, type) VALUES (?, ?)', {identifier, license})

    return true
end

FN_FRAMEWORK.RemoveLicense = function(identifier, license)
    MySQL.query.await('DELETE FROM user_licenses WHERE owner = ? AND type = ?', {identifier, license})

    return true
end

FN_FRAMEWORK.CheckPermissions = function(playerId, groups)
    groups = FN_HELPER.NormalizeGroups(groups)
    if not groups then return false end

    local xPlayer = FN_FRAMEWORK.GetPlayerFromId(playerId)
    if not xPlayer then return false end

    return groups[xPlayer.group] or false
end

lib.callback.register('fn_bridge/server/checkPermissions', FN_FRAMEWORK.CheckPermissions)

lib.callback.register('fn_bridge/server/getAccounts', function(source)
    local player = FN_FRAMEWORK.GetPlayerFromId(source)
    if not player then return end

    return player.getAccounts()
end)

Config.DebugPrint('framework adapter loaded: esx (server)')

local function PositiveAmount(amount)
    amount = math.floor(tonumber(amount) or 0)

    return amount > 0 and amount or nil
end

FN_FRAMEWORK.GetIdentifier = function(playerId)
    local xPlayer = XPlayer(playerId)

    return xPlayer and xPlayer.identifier or false
end

FN_FRAMEWORK.GetMoney = function(playerId, accountName)
    return Balance(XPlayer(playerId), FN_FRAMEWORK.ResolveAccount(accountName or 'bank'))
end

FN_FRAMEWORK.AddMoney = function(playerId, accountName, amount, reason)
    amount = PositiveAmount(amount)
    local xPlayer = XPlayer(playerId)
    local account = FN_FRAMEWORK.ResolveAccount(accountName or 'bank')
    if not amount or not Call(xPlayer, 'getAccount', account) then return false end

    return select(2, Call(xPlayer, 'addAccountMoney', account, amount, reason or 'fn_bridge'))
end

FN_FRAMEWORK.RemoveMoney = function(playerId, accountName, amount, reason)
    amount = PositiveAmount(amount)
    local xPlayer = XPlayer(playerId)
    local account = FN_FRAMEWORK.ResolveAccount(accountName or 'bank')
    if not amount or not xPlayer or FN_FRAMEWORK.GetMoney(playerId, accountName) < amount then return false end

    return select(2, Call(xPlayer, 'removeAccountMoney', account, amount, reason or 'fn_bridge'))
end

local ReverseAccounts = { money = 'cash', bank = 'bank', black_money = 'black_money' }

local function MoneyChanged(sign)
    return function(playerId, accountName, amount, reason)
        amount = tonumber(amount)
        if not tonumber(playerId) or not amount or amount == 0 then return end

        TriggerEvent('fn_bridge/server/onMoneyChange', tonumber(playerId), ReverseAccounts[accountName] or accountName, sign * amount, type(reason) == 'string' and reason or '')
    end
end

AddEventHandler('esx:addAccountMoney', MoneyChanged(1))
AddEventHandler('esx:removeAccountMoney', MoneyChanged(-1))

FN_FRAMEWORK.GetJob = function(playerId)
    local xPlayer = XPlayer(playerId)
    local job = xPlayer and xPlayer.job
    if not job or not job.name then return false end

    return {
        name = job.name,
        label = job.label or job.name,
        grade = tonumber(job.grade) or 0,
        grade_name = job.grade_name or '',
        grade_label = job.grade_label or '',
        isBoss = job.grade_name == 'boss',
        onDuty = job.onDuty ~= false,
    }
end

local function JobExists(jobName, grade)
    local esx = FN_FRAMEWORK.obj
    if not esx then return false end
    if esx.DoesJobExist then return esx.DoesJobExist(jobName, grade) == true end

    local job = (esx.GetJobs and esx.GetJobs() or {})[jobName]

    return job ~= nil and (job.grades or {})[tostring(grade)] ~= nil
end

FN_FRAMEWORK.SetJob = function(target, jobName, grade)
    grade = math.floor(tonumber(grade) or 0)
    if type(jobName) ~= 'string' or not JobExists(jobName, grade) then return false end

    if type(target) == 'number' then
        local xPlayer = XPlayer(target)
        if not xPlayer then return false end

        return select(2, Call(xPlayer, 'setJob', jobName, grade))
    end

    return type(target) == 'string' and FN_FRAMEWORK.SetJobOffline(target, jobName, grade) or false
end

FN_FRAMEWORK.RemoveJob = function(target, jobName)
    if type(target) == 'number' then
        local job = FN_FRAMEWORK.GetJob(target)
        if not job or job.name ~= jobName then return false end
    elseif not MySQL.scalar.await('SELECT 1 FROM users WHERE identifier = ? AND job = ?', { target, jobName }) then
        return false
    end

    return FN_FRAMEWORK.SetJob(target, 'unemployed', 0)
end

FN_FRAMEWORK.GetGang = function()
    return false
end

local function Percent(value)
    value = tonumber(value)

    return value and math.max(0, math.min(100, math.floor(value + 0.5))) or nil
end

FN_FRAMEWORK.GetNeeds = function(playerId)
    local xPlayer = XPlayer(playerId)
    local needs = {}

    for _, status in ipairs(Call(xPlayer, 'get', 'status') or {}) do
        if status.name == 'hunger' or status.name == 'thirst' or status.name == 'stress' then
            needs[status.name] = Percent(status.percent or (tonumber(status.val) or 0) / 10000)
        end
    end

    return needs
end

FN_FRAMEWORK.GetPlayTime = function(playerId)
    local xPlayer = XPlayer(playerId)
    if not xPlayer or not xPlayer.getPlayTime then return false end

    return tonumber(Call(xPlayer, 'getPlayTime')) or false
end

local function HasPhoneColumn()
    return FN_DB.HasColumn('users', 'phone_number')
end

FN_FRAMEWORK.GetPhoneNumber = function(playerId)
    local xPlayer = XPlayer(playerId)
    if not xPlayer then return false end

    local number = Call(xPlayer, 'get', 'phoneNumber') or Call(xPlayer, 'get', 'phone_number') or xPlayer.phoneNumber or xPlayer.phone_number
    if not number and HasPhoneColumn() then
        number = MySQL.scalar.await('SELECT phone_number FROM users WHERE identifier = ?', { xPlayer.identifier })
    end

    return number and tostring(number) or false
end

FN_FRAMEWORK.SetPhoneNumber = function(playerId, number)
    local xPlayer = XPlayer(playerId)
    if not xPlayer or not HasPhoneColumn() then return false end

    local ok, affected = pcall(MySQL.update.await, 'UPDATE users SET phone_number = ? WHERE identifier = ?', { number, xPlayer.identifier })
    if not ok or (affected or 0) < 1 then return false end

    Call(xPlayer, 'set', 'phoneNumber', number)

    return true
end

FN_FRAMEWORK.IsPhoneNumberTaken = function(number)
    if not HasPhoneColumn() then return false end

    return MySQL.scalar.await('SELECT 1 FROM users WHERE phone_number = ? LIMIT 1', { number }) ~= nil
end

local function HasNameColumns()
    return FN_DB.HasColumn('users', 'firstname') and FN_DB.HasColumn('users', 'lastname')
end

FN_FRAMEWORK.SetName = function(playerId, firstName, lastName)
    local xPlayer = XPlayer(playerId)
    if not xPlayer or not HasNameColumns() then return false end

    local ok, affected = pcall(MySQL.update.await, 'UPDATE users SET firstname = ?, lastname = ? WHERE identifier = ?', { firstName, lastName, xPlayer.identifier })
    if not ok or (affected or 0) < 1 then return false end

    Call(xPlayer, 'set', 'firstName', firstName)
    Call(xPlayer, 'set', 'lastName', lastName)
    Call(xPlayer, 'setName', firstName .. ' ' .. lastName)

    return true
end

FN_FRAMEWORK.IsNameTaken = function(firstName, lastName)
    if not HasNameColumns() then return false end

    return MySQL.scalar.await([[
        SELECT 1 FROM users
        WHERE CONVERT(firstname USING utf8mb4) COLLATE utf8mb4_unicode_ci = ?
          AND CONVERT(lastname USING utf8mb4) COLLATE utf8mb4_unicode_ci = ? LIMIT 1
    ]], { firstName, lastName }) ~= nil
end

FN_FRAMEWORK.GetCharacter = function(identifier)
    if type(identifier) ~= 'string' or not HasNameColumns() then return false end

    local row = MySQL.single.await('SELECT identifier, firstname, lastname, dateofbirth, sex FROM users WHERE identifier = ?', { identifier })
    if not row then return false end

    local licenses = {}
    if FN_DB.HasTable('user_licenses') then
        for _, license in ipairs(MySQL.query.await('SELECT type FROM user_licenses WHERE owner = ?', { identifier }) or {}) do
            licenses[#licenses + 1] = license.type
        end
    end

    local sex = type(row.sex) == 'string' and row.sex:lower() or ''

    return {
        identifier = row.identifier,
        firstName = row.firstname or '',
        lastName = row.lastname or '',
        name = TrimName(row.firstname, row.lastname),
        dateOfBirth = row.dateofbirth ~= '' and row.dateofbirth and tostring(row.dateofbirth) or nil,
        sex = sex ~= '' and (sex:sub(1, 1) == 'f' and 'f' or 'm') or nil,
        licenses = licenses,
    }
end

local function IdList(identifiers)
    local list = {}
    for _, identifier in ipairs(type(identifiers) == 'table' and identifiers or {}) do
        if (type(identifier) == 'string' or type(identifier) == 'number') and #list < 500 then list[#list + 1] = identifier end
    end

    return list
end

FN_FRAMEWORK.SetCharacter = function(identifier, fields)
    if type(identifier) ~= 'string' or type(fields) ~= 'table' then return false end

    local values = {
        dateofbirth = type(fields.dateOfBirth) == 'string' and #fields.dateOfBirth <= 20 and fields.dateOfBirth or nil,
        sex = (fields.sex == 'm' or fields.sex == 'f') and fields.sex or nil,
        nationality = type(fields.nationality) == 'string' and #fields.nationality <= 50 and fields.nationality or nil,
    }
    local sets, params = {}, {}
    for column, value in pairs(values) do
        if FN_DB.HasColumn('users', column) then
            sets[#sets + 1] = column .. ' = ?'
            params[#params + 1] = value
        end
    end
    if #sets == 0 then return false end

    params[#params + 1] = identifier
    local ok = pcall(MySQL.update.await, ('UPDATE users SET %s WHERE identifier = ?'):format(table.concat(sets, ', ')), params)
    if not ok or MySQL.scalar.await('SELECT 1 FROM users WHERE identifier = ?', { identifier }) == nil then return false end

    local online = FN_FRAMEWORK.GetPlayerFromIdentifier(identifier)
    local xPlayer = online and XPlayer(online.source)
    if xPlayer then
        for column, value in pairs(values) do Call(xPlayer, 'set', column, value) end
    end

    return true
end

FN_FRAMEWORK.GetCharactersByIds = function(identifiers)
    local list = IdList(identifiers)
    if #list == 0 or not HasNameColumns() then return {} end

    local result = {}
    for _, row in ipairs(MySQL.query.await(('SELECT identifier, firstname, lastname, dateofbirth FROM users WHERE identifier IN (%s)'):format(FN_DB.Placeholders(#list)), list) or {}) do
        result[#result + 1] = { identifier = row.identifier, firstName = row.firstname or '', lastName = row.lastname or '', name = TrimName(row.firstname, row.lastname), dateOfBirth = row.dateofbirth and tostring(row.dateofbirth) or nil }
    end

    return result
end

FN_FRAMEWORK.GetCharacters = function(license)
    local hash = type(license) == 'string' and license:match('^license2?:(%w+)$') or license
    if type(hash) ~= 'string' or not hash:match('^%w+$') then return {} end

    local named = HasNameColumns()
    local rows = MySQL.query.await(('SELECT identifier%s FROM users WHERE identifier = ? OR identifier LIKE ?'):format(named and ', firstname, lastname' or ''), { hash, '%:' .. hash }) or {}

    local characters = {}
    for _, row in ipairs(rows) do
        local name = named and TrimName(row.firstname, row.lastname) or ''
        characters[#characters + 1] = { identifier = row.identifier, name = name ~= '' and name or row.identifier }
    end
    table.sort(characters, function(a, b) return a.identifier < b.identifier end)

    return characters
end

FN_FRAMEWORK.AddCharacterSlots = function(license, amount, default, max)
    local hash = type(license) == 'string' and license:match('^license2?:(%w+)$') or license
    if type(hash) ~= 'string' or not FN_DB.HasTable('multicharacter_slots') then return false end

    local ok = pcall(MySQL.update.await, [[
        INSERT INTO multicharacter_slots (identifier, slots) VALUES (?, LEAST(? + ?, ?))
        ON DUPLICATE KEY UPDATE slots = LEAST(slots + ?, ?)
    ]], { hash, default, amount, max, amount, max })

    return ok
end

FN_FRAMEWORK.GetName = function(playerId)
    local xPlayer = XPlayer(playerId)
    if not xPlayer then return false end

    return TrimName(Names(xPlayer))
end

FN_FRAMEWORK.GetVehicleCatalog = function()
    local catalog = {}
    if not FN_DB.HasTable('vehicles') then return catalog end

    for _, row in ipairs(MySQL.query.await('SELECT * FROM vehicles') or {}) do
        if type(row.model) == 'string' then
            catalog[row.model:lower()] = { model = row.model:lower(), label = row.name or row.model, price = math.floor(tonumber(row.price) or 0), category = row.category }
        end
    end

    return catalog
end

local Features = {
    money = function() return true end,
    phoneNumber = HasPhoneColumn,
    characterSlots = function() return FN_DB.HasTable('multicharacter_slots') end,
    needs = function() return GetResourceState('esx_status') == 'started' end,
    playTime = function() return true end,
    gangs = function() return FN_DB.HasColumn('users', 'hiddenjob') end,
    vehicles = function() return FN_VEHICLES.Available() end,
}

FN_FRAMEWORK.Supports = function(feature)
    local check = Features[feature]

    return check and check() == true or false
end
