if not FN_BRIDGE.IsFramework('qb') then return end

local function GetCoreObject()
    local ok, coreObject = pcall(function()
        return exports['qb-core']:GetCoreObject()
    end)

    if not ok or type(coreObject) ~= 'table' then
        ok, coreObject = pcall(function()
            return exports['qb-core']:getSharedObject()
        end)
    end

    if not ok or type(coreObject) ~= 'table' then return nil end

    return coreObject
end

FN_FRAMEWORK = {}
FN_FRAMEWORK.obj = GetCoreObject()

if not FN_FRAMEWORK.obj then
    CreateThread(function()
        local deadline = GetGameTimer() + 30000
        repeat
            Wait(100)
            FN_FRAMEWORK.obj = GetCoreObject()
        until FN_FRAMEWORK.obj or GetGameTimer() > deadline

        if not FN_FRAMEWORK.obj then
            print('^1qb-core never returned a core object^7 - start fn_bridge after qb-core.')
        end
    end)
end

FN_FRAMEWORK.GetFrameworkName = function()
    return 'qb'
end

FN_FRAMEWORK.accountNames = {
    cash = 'cash',
    bank = 'bank',
}

FN_FRAMEWORK.ResolveAccount = function(accountName)
    return FN_FRAMEWORK.accountNames[accountName]
end

local GroupPrecedence = { 'god', 'superadmin', 'admin', 'mod' }

local function ResolveGroup(playerId)
    local ok, permission = pcall(function()
        return FN_FRAMEWORK.obj.Functions.GetPermission(playerId)
    end)

    if not ok then return 'user' end
    if type(permission) == 'string' then return permission end

    if type(permission) == 'table' then
        for _, group in ipairs(GroupPrecedence) do
            if permission[group] then return group end
        end
    end

    return 'user'
end

local function ResolveSex(gender)
    if gender == 1 or gender == '1' then return 'f' end

    return 'm'
end

local function LicenceKey(metadata)
    if type(metadata) ~= 'table' then return 'licences' end
    if metadata.licences ~= nil then return 'licences' end
    if metadata.licenses ~= nil then return 'licenses' end

    return 'licences'
end

local function FindGrade(sharedJob, jobGrade)
    local wanted = tonumber(jobGrade) or 0

    for gradeKey, grade in pairs(sharedJob.grades or {}) do
        if (tonumber(gradeKey) or -1) == wanted then return wanted, grade end
    end

    return nil, nil
end

local function TrimName(firstName, lastName)
    return ((firstName or '') .. ' ' .. (lastName or '')):match('^%s*(.-)%s*$')
end

local function GetQbPlayer(playerId)
    if not FN_FRAMEWORK.obj then return nil end
    if not tonumber(playerId) then return nil end

    return FN_FRAMEWORK.obj.Functions.GetPlayer(tonumber(playerId))
end

local function BuildPlayerData(playerId, player)
    local playerData = player.PlayerData or {}
    local charInfo = playerData.charinfo or {}
    local job = playerData.job or {}
    local metadata = playerData.metadata or {}

    return {
        source = playerId,
        identifier = playerData.citizenid,
        group = ResolveGroup(playerId),
        job = {
            name = job.name or 'unemployed',
            label = job.label or 'Unemployed',
            grade = job?.grade?.level or 0,
            grade_name = job?.grade?.name or 'unemployed',
            grade_label = job?.grade?.name or 'Unemployed',
        },
        char = {
            firstName = charInfo.firstname or '',
            lastName = charInfo.lastname or '',
            sex = ResolveSex(charInfo.gender),
            badge = metadata.callsign or '',
        },
        showNotification = function(message, _type, duration)
            TriggerClientEvent('fn_bridge/client/notify', playerId, message, _type, duration)
        end,
        getName = function(separate)
            if separate then return { firstname = charInfo.firstname or '', lastname = charInfo.lastname or '' } end

            return TrimName(charInfo.firstname, charInfo.lastname)
        end,
        setJob = function(jobName, jobGrade, onDuty)
            player.Functions.SetJob(jobName, tonumber(jobGrade) or 0)
            if onDuty ~= nil then player.Functions.SetJobDuty(onDuty and true or false) end
        end,
        addAccountMoney = function(accountName, amount)
            if type(amount) ~= 'number' or amount <= 0 then return false end

            local moneyType = FN_FRAMEWORK.ResolveAccount(accountName)
            if not moneyType then return false end

            return player.Functions.AddMoney(moneyType, amount, 'fn_bridge') and true or false
        end,
        removeAccountMoney = function(accountName, amount)
            if type(amount) ~= 'number' or amount <= 0 then return false end

            local moneyType = FN_FRAMEWORK.ResolveAccount(accountName)
            if not moneyType then return false end

            return player.Functions.RemoveMoney(moneyType, amount, 'fn_bridge') and true or false
        end,
        getAccounts = function()
            local money = player.PlayerData?.money or {}

            return {
                cash = money.cash or 0,
                bank = money.bank or 0,
                black_money = 0,
            }
        end,
        addInventoryItem = function(itemName, amount, metadata)
            player.Functions.AddItem(itemName, amount, nil, metadata)
        end,
        removeInventoryItem = function(itemName, amount, metadata)
            player.Functions.RemoveItem(itemName, amount, nil, metadata)
        end,
        updateChar = function(key, value)
            if not key then return end

            player.Functions.SetCharInfo(key, value)
        end,
    }
end

FN_FRAMEWORK.RawPlayer = GetQbPlayer

FN_FRAMEWORK.GetPlayerFromId = function(playerId)
    local player = GetQbPlayer(playerId)
    if not player then return false end

    return BuildPlayerData(tonumber(playerId), player)
end

FN_FRAMEWORK.GetPlayerFromIdentifier = function(identifier)
    if not FN_FRAMEWORK.obj then return false end
    if type(identifier) ~= 'string' then return false end

    local player = FN_FRAMEWORK.obj.Functions.GetPlayerByCitizenId(identifier)
    if not player?.PlayerData then return false end

    return BuildPlayerData(player.PlayerData.source, player)
end

local function PublishGroup(playerId)
    local player = Player(playerId)
    if not player then return end

    player.state:set('fnGroup', ResolveGroup(playerId), true)
end

local function OnPlayerLoaded(player)
    local playerId = tonumber(player?.PlayerData?.source)
    if not playerId then return end

    PublishGroup(playerId)
    FN_JOBS.Seed(playerId)
    TriggerEvent('fn_bridge/server/playerLoaded', playerId, FN_FRAMEWORK.GetPlayerFromId(playerId) or player)
end

AddEventHandler('QBCore:Server:PlayerLoaded', OnPlayerLoaded)
AddEventHandler('QBCore:Server:OnPlayerLoaded', OnPlayerLoaded)

AddEventHandler('QBCore:Server:OnJobUpdate', function(playerId)
    FN_JOBS.Publish(playerId)
end)

AddEventHandler('QBCore:Server:SetDuty', function(playerId)
    FN_JOBS.Publish(playerId)
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(playerId)
    FN_JOBS.Forget(playerId)
end)

FN_FRAMEWORK.GetPlayers = function()
    local players = {}
    if not FN_FRAMEWORK.obj then return players end

    for _, playerId in ipairs(FN_FRAMEWORK.obj.Functions.GetPlayers() or {}) do
        players[#players + 1] = tonumber(playerId)
    end

    return players
end

FN_FRAMEWORK.GetOfflineCharName = function(identifier, separate)
    local player = FN_FRAMEWORK.GetPlayerFromIdentifier(identifier)
    if player then return player.getName(separate) end

    local row = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ?', {identifier})
    if not row?.charinfo then return false end

    local charInfo = json.decode(row.charinfo)
    if type(charInfo) ~= 'table' then return false end
    if separate then return { firstname = charInfo.firstname or '', lastname = charInfo.lastname or '' } end

    return TrimName(charInfo.firstname, charInfo.lastname)
end

local SearchLimit = 10
local SearchNameClause = [[ OR JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')) LIKE ? OR JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')) LIKE ?]]
local HasLastSeen

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

local function LastSeenColumn()
    if HasLastSeen ~= nil then return HasLastSeen end

    local column = MySQL.single.await('SHOW COLUMNS FROM players LIKE ?', { 'last_updated' })
    HasLastSeen = column and true or false

    return HasLastSeen
end

FN_FRAMEWORK.SearchCharacters = function(query, limit)
    local needle, safe = SearchNeedle(query)
    if not needle then return {} end

    local charId = FN_CHARID.Source()
    local selection = LastSeenColumn()
        and 'citizenid, charinfo, job, UNIX_TIMESTAMP(last_updated) AS last_seen'
        or 'citizenid, charinfo, job, NULL AS last_seen'

    local sql = ('SELECT %s, %s AS char_id FROM players WHERE citizenid = ? OR license = ?'):format(selection, charId and charId.value or 'NULL')
    local params = { needle, needle }

    if charId then
        sql = ('%s OR %s = ?'):format(sql, charId.value)
        params[#params + 1] = needle
    end

    if safe then
        sql = sql .. SearchNameClause
        params[#params + 1] = safe .. '%'
        params[#params + 1] = safe .. '%'
    end

    local rows = MySQL.query.await(sql .. (' LIMIT %d'):format(ClampSearchLimit(limit)), params)

    local result = {}
    for _, row in ipairs(rows or {}) do
        local charInfo = row.charinfo and json.decode(row.charinfo)
        if type(charInfo) == 'table' then
            local jobData = row.job and json.decode(row.job)
            local jobName, grade

            if type(jobData) == 'table' then
                jobName = jobData.name
                grade = tonumber(jobData?.grade?.level) or 0
            end

            result[#result + 1] = {
                identifier = row.citizenid,
                charId = row.char_id or row.citizenid,
                firstName = charInfo.firstname or '',
                lastName = charInfo.lastname or '',
                name = TrimName(charInfo.firstname, charInfo.lastname),
                job = jobName,
                grade = grade or 0,
                lastSeen = tonumber(row.last_seen),
                dateOfBirth = charInfo.birthdate ~= '' and charInfo.birthdate or nil,
                sex = charInfo.gender ~= nil and ResolveSex(charInfo.gender) or nil,
                nationality = charInfo.nationality ~= '' and charInfo.nationality or nil,
            }
        end
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

    return ('%s AND citizenid %s (%s)'):format(sql, operator, string.rep('?', count, ', ')), count
end

FN_FRAMEWORK.GetJobMembers = function(jobName, options)
    local jobs = type(jobName) == 'table' and jobName or { jobName }
    if #jobs == 0 then return {} end

    for _, job in ipairs(jobs) do
        if type(job) ~= 'string' or job == '' then return {} end
    end

    options = type(options) == 'table' and options or {}

    local sql = ([[SELECT citizenid, charinfo, job FROM players WHERE JSON_UNQUOTE(JSON_EXTRACT(job, '$.name')) IN (%s)]]):format(string.rep('?', #jobs, ', '))
    local params = { table.unpack(jobs) }

    if options.search ~= nil then
        local _, safe = SearchNeedle(options.search)
        if not safe then return {} end

        sql = sql .. [[ AND CONCAT(JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')), ' ', JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname'))) LIKE ?]]
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
    local rows = MySQL.query.await(sql .. (' ORDER BY citizenid LIMIT %d OFFSET %d'):format(limit, offset), params)

    local result = {}
    for _, row in ipairs(rows or {}) do
        local charInfo = row.charinfo and json.decode(row.charinfo)
        local jobData = row.job and json.decode(row.job)

        if type(charInfo) == 'table' and type(jobData) == 'table' then
            result[#result + 1] = {
                identifier = row.citizenid,
                firstName = charInfo.firstname or '',
                lastName = charInfo.lastname or '',
                name = TrimName(charInfo.firstname, charInfo.lastname),
                job = jobData.name,
                grade = tonumber(jobData?.grade?.level) or 0,
                gradeLabel = jobData?.grade?.name or '',
            }
        end
    end

    return result
end

FN_FRAMEWORK.SetJobOffline = function(identifier, jobName, jobGrade)
    if type(identifier) ~= 'string' or type(jobName) ~= 'string' then return false end

    local sharedJobs = FN_FRAMEWORK.obj?.Shared?.Jobs
    local sharedJob = sharedJobs and sharedJobs[jobName]
    if not sharedJob then return false end

    local gradeLevel, grade = FindGrade(sharedJob, jobGrade)
    if not grade then return false end

    local job = {
        name = jobName,
        label = sharedJob.label or jobName,
        payment = grade.payment or 0,
        onduty = sharedJob.defaultDuty and true or false,
        isboss = grade.isboss and true or false,
        type = sharedJob.type,
        grade = { name = grade.name or tostring(gradeLevel), level = gradeLevel },
    }

    local affected = MySQL.update.await('UPDATE players SET job = ? WHERE citizenid = ?', {json.encode(job), identifier})

    return affected > 0
end

FN_FRAMEWORK.CheckJobDuty = function(playerId)
    local player = GetQbPlayer(playerId)
    if not player?.PlayerData?.job then return false end

    return player.PlayerData.job.onduty and true or false
end

FN_FRAMEWORK.SetJobDuty = function(playerId, dutyStatus)
    if type(dutyStatus) ~= 'boolean' then return false end

    local player = GetQbPlayer(playerId)
    if not player?.PlayerData?.job then return false end

    player.Functions.SetJobDuty(dutyStatus)

    return FN_FRAMEWORK.CheckJobDuty(playerId) == dutyStatus
end

FN_FRAMEWORK.GetJobs = function()
    local jobs = {}
    local sharedJobs = FN_FRAMEWORK.obj?.Shared?.Jobs
    if not sharedJobs then return jobs end

    for jobName, sharedJob in pairs(sharedJobs) do
        jobs[jobName] = { name = jobName, label = sharedJob.label or jobName, grades = {} }

        for gradeKey, grade in pairs(sharedJob.grades or {}) do
            local gradeLevel = tonumber(gradeKey)
            if gradeLevel then
                jobs[jobName].grades[gradeLevel] = {
                    name = grade.name or tostring(gradeLevel),
                    label = grade.name or tostring(gradeLevel),
                    grade = gradeLevel,
                    job_name = jobName,
                    isBoss = grade.isboss == true,
                }
            end
        end
    end

    return jobs
end

FN_FRAMEWORK.CheckPermissions = function(playerId, groups)
    groups = FN_HELPER.NormalizeGroups(groups)
    if not groups then return false end
    if not GetQbPlayer(playerId) then return false end

    for groupName, wanted in pairs(groups) do
        if wanted then
            local ok, allowed = pcall(function()
                return FN_FRAMEWORK.obj.Functions.HasPermission(tonumber(playerId), groupName)
            end)

            if ok and allowed then return true end
        end
    end

    return groups[ResolveGroup(tonumber(playerId))] or false
end

FN_FRAMEWORK.RegisterUsableItem = function(itemName, callback)
    if not FN_FRAMEWORK.obj then return end

    FN_FRAMEWORK.obj.Functions.CreateUseableItem(itemName, function(playerId, item)
        local player = FN_FRAMEWORK.GetPlayerFromId(playerId)
        if not player then return end

        callback(player, { name = itemName, slot = type(item) == 'table' and tonumber(item.slot) or nil, metadata = type(item) == 'table' and (item.info or item.metadata) or nil })
    end)
end

FN_FRAMEWORK.UseItem = function(playerId, itemName)
    if not FN_FRAMEWORK.obj then return end

    local ok = pcall(function()
        FN_FRAMEWORK.obj.Functions.UseItem(tonumber(playerId), itemName)
    end)

    if not ok then print(('^1qb-core could not use item^7 %s'):format(tostring(itemName))) end
end

FN_FRAMEWORK.GetItemLabel = function(itemName)
    local sharedItems = FN_FRAMEWORK.obj?.Shared?.Items
    local item = sharedItems and sharedItems[itemName]
    if not item then return itemName end

    return item.label or itemName
end

local function BuildVehicleData(row)
    return {
        owner = row.citizenid,
        plate = row.plate,
        vehicle = row.mods and json.decode(row.mods) or {},
        stored = row.state == 1,
    }
end

FN_FRAMEWORK.GetVehicleByPlate = function(plate)
    local row = MySQL.single.await('SELECT citizenid, plate, mods, state FROM player_vehicles WHERE plate = ?', {plate})
    if not row then return false end

    return BuildVehicleData(row)
end

FN_FRAMEWORK.GetPlayerVehicles = function(identifier)
    local result = {}
    local rows = MySQL.query.await('SELECT citizenid, plate, mods, state FROM player_vehicles WHERE citizenid = ?', {identifier})
    if not rows then return result end

    for _, row in ipairs(rows) do
        result[#result + 1] = BuildVehicleData(row)
    end

    return result
end

local function ReadOfflineMetadata(identifier)
    local row = MySQL.single.await('SELECT metadata FROM players WHERE citizenid = ?', {identifier})
    if not row?.metadata then return nil end

    local metadata = json.decode(row.metadata)
    if type(metadata) ~= 'table' then return nil end

    return metadata
end

local function GetLoadedPlayerByIdentifier(identifier)
    if not FN_FRAMEWORK.obj then return nil end

    return FN_FRAMEWORK.obj.Functions.GetPlayerByCitizenId(identifier)
end

FN_FRAMEWORK.CheckLicense = function(identifier, license)
    if type(identifier) ~= 'string' or type(license) ~= 'string' then return false end

    local player = GetLoadedPlayerByIdentifier(identifier)
    local metadata = player?.PlayerData?.metadata or ReadOfflineMetadata(identifier)
    if not metadata then return false end

    local licences = metadata[LicenceKey(metadata)]

    return type(licences) == 'table' and licences[license] and true or false
end

local function SetLicense(identifier, license, granted)
    if type(identifier) ~= 'string' or type(license) ~= 'string' then return false end

    local player = GetLoadedPlayerByIdentifier(identifier)
    if player?.PlayerData then
        local metadata = player.PlayerData.metadata or {}
        local key = LicenceKey(metadata)
        local licences = type(metadata[key]) == 'table' and metadata[key] or {}
        licences[license] = granted
        player.Functions.SetMetaData(key, licences)

        return true
    end

    local metadata = ReadOfflineMetadata(identifier)
    if not metadata then return false end

    local key = LicenceKey(metadata)
    local licences = type(metadata[key]) == 'table' and metadata[key] or {}
    licences[license] = granted
    metadata[key] = licences

    MySQL.update.await('UPDATE players SET metadata = ? WHERE citizenid = ?', {json.encode(metadata), identifier})

    return true
end

FN_FRAMEWORK.AddLicense = function(identifier, license)
    return SetLicense(identifier, license, true)
end

FN_FRAMEWORK.RemoveLicense = function(identifier, license)
    return SetLicense(identifier, license, false)
end

lib.callback.register('fn_bridge/server/checkPermissions', FN_FRAMEWORK.CheckPermissions)

lib.callback.register('fn_bridge/server/getAccounts', function(source)
    local player = FN_FRAMEWORK.GetPlayerFromId(source)
    if not player then return end

    return player.getAccounts()
end)

Config.DebugPrint('framework adapter loaded: qb (server)')
