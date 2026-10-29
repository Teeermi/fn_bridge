if not FN_BRIDGE.IsFramework('qbx') then return end

FN_FRAMEWORK = {}
FN_FRAMEWORK.obj = exports['qbx_core']

FN_FRAMEWORK.GetFrameworkName = function()
    return 'qbx'
end

FN_FRAMEWORK.accountNames = {
    cash = 'cash',
    bank = 'bank',
}

FN_FRAMEWORK.ResolveAccount = function(accountName)
    return FN_FRAMEWORK.accountNames[accountName]
end

local GroupPrecedence = { 'god', 'superadmin', 'admin', 'mod' }

local function CallCore(exportName, ...)
    local args = table.pack(...)

    return pcall(function()
        return exports['qbx_core'][exportName](exports['qbx_core'], table.unpack(args, 1, args.n))
    end)
end

local function CoreValue(exportName, ...)
    local ok, result = CallCore(exportName, ...)
    if not ok then return nil end

    return result
end

local function ResolveGroup(playerId)
    for _, group in ipairs(GroupPrecedence) do
        if CoreValue('HasPermission', tonumber(playerId), group) then return group end
    end

    return 'user'
end

local function ResolveSex(gender)
    if gender == 1 or gender == '1' or gender == 'f' or gender == 'female' then return 'f' end

    return 'm'
end

local function LicenceKey(metadata)
    if type(metadata) ~= 'table' then return 'licences' end
    if metadata.licences ~= nil then return 'licences' end
    if metadata.licenses ~= nil then return 'licenses' end

    return 'licences'
end

local function TrimName(firstName, lastName)
    return ((firstName or '') .. ' ' .. (lastName or '')):match('^%s*(.-)%s*$')
end

local function GetSharedJobs()
    local jobs = CoreValue('GetJobs')
    if type(jobs) ~= 'table' then return {} end

    return jobs
end

local function FindGrade(sharedJob, jobGrade)
    local wanted = tonumber(jobGrade) or 0

    for gradeKey, grade in pairs(sharedJob.grades or {}) do
        if (tonumber(gradeKey) or -1) == wanted then return wanted, grade end
    end

    return nil, nil
end

local function GetQbxPlayer(playerId)
    if not tonumber(playerId) then return nil end

    local player = CoreValue('GetPlayer', tonumber(playerId))
    if type(player) ~= 'table' then return nil end

    return player
end

local function GetOnlinePlayers()
    local players = CoreValue('GetQBPlayers')
    if type(players) == 'table' then return players end

    local result = {}
    for _, playerId in ipairs(GetPlayers()) do
        local player = GetQbxPlayer(playerId)
        if player then result[tonumber(playerId)] = player end
    end

    return result
end

local function AddItem(playerId, itemName, amount, metadata)
    if FN_INVENTORY then
        local ok, result = pcall(FN_INVENTORY.AddItem, playerId, itemName, amount, metadata)
        if ok and result ~= false then return end
    end

    pcall(function()
        exports['ox_inventory']:AddItem(playerId, itemName, amount, metadata)
    end)
end

local function RemoveItem(playerId, itemName, amount, metadata)
    if FN_INVENTORY then
        local ok, result = pcall(FN_INVENTORY.RemoveItem, playerId, itemName, amount, metadata)
        if ok and result ~= false then return end
    end

    pcall(function()
        exports['ox_inventory']:RemoveItem(playerId, itemName, amount, metadata)
    end)
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
        addInventoryItem = function(itemName, amount, itemMetadata)
            AddItem(playerId, itemName, amount, itemMetadata)
        end,
        removeInventoryItem = function(itemName, amount, itemMetadata)
            RemoveItem(playerId, itemName, amount, itemMetadata)
        end,
        updateChar = function(key, value)
            if not key then return end

            local currentInfo = player.PlayerData?.charinfo or {}
            currentInfo[key] = value
            player.Functions.SetPlayerData('charinfo', currentInfo)
        end,
    }
end

FN_FRAMEWORK.RawPlayer = GetQbxPlayer

FN_FRAMEWORK.GetPlayerFromId = function(playerId)
    local player = GetQbxPlayer(playerId)
    if not player then return false end

    return BuildPlayerData(tonumber(playerId), player)
end

FN_FRAMEWORK.GetPlayerFromIdentifier = function(identifier)
    if type(identifier) ~= 'string' then return false end

    local player = CoreValue('GetPlayerByCitizenId', identifier)
    if not player?.PlayerData then return false end

    return BuildPlayerData(player.PlayerData.source, player)
end

local function PublishGroup(playerId)
    local player = Player(playerId)
    if not player then return end

    player.state:set('fnGroup', ResolveGroup(playerId), true)
end

local LoadedPlayers = {}

local function ResolvePlayerId(payload)
    if type(payload) == 'table' then return tonumber(payload?.PlayerData?.source or payload?.source) end

    return tonumber(payload)
end

local function OnPlayerLoaded(payload)
    local playerId = ResolvePlayerId(payload)
    if not playerId or playerId <= 0 then return end
    if LoadedPlayers[playerId] then return end

    LoadedPlayers[playerId] = true

    PublishGroup(playerId)
    FN_JOBS.Seed(playerId)
    TriggerEvent('fn_bridge/server/playerLoaded', playerId, FN_FRAMEWORK.GetPlayerFromId(playerId))
end

local function OnPlayerUnloaded(payload)
    local playerId = ResolvePlayerId(payload)
    if not playerId then return end

    LoadedPlayers[playerId] = nil
    FN_JOBS.Forget(playerId)
end

AddEventHandler('qbx_core:server:playerLoaded', OnPlayerLoaded)
AddEventHandler('QBCore:Server:PlayerLoaded', OnPlayerLoaded)
AddEventHandler('qbx_core:server:playerLoggedOut', OnPlayerUnloaded)
AddEventHandler('QBCore:Server:OnPlayerUnload', OnPlayerUnloaded)

AddEventHandler('qbx_core:server:onJobUpdate', function(playerId)
    FN_JOBS.Publish(playerId)
end)

AddEventHandler('QBCore:Server:OnJobUpdate', function(playerId)
    FN_JOBS.Publish(playerId)
end)

AddEventHandler('qbx_core:server:setDuty', function(playerId)
    FN_JOBS.Publish(playerId)
end)

AddEventHandler('QBCore:Server:SetDuty', function(playerId)
    FN_JOBS.Publish(playerId)
end)

AddEventHandler('playerDropped', function()
    OnPlayerUnloaded(source)
end)

FN_FRAMEWORK.GetPlayers = function()
    local players = {}

    for playerId in pairs(GetOnlinePlayers()) do
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

local function GroupMembers(jobs, options)
    local sql = ([[SELECT g.citizenid, g.`group` AS job, g.grade, p.charinfo FROM player_groups g JOIN players p ON p.citizenid = g.citizenid WHERE g.type = 'job' AND g.`group` IN (%s)]]):format(string.rep('?', #jobs, ', '))
    local params = { table.unpack(jobs) }

    if options.search ~= nil then
        local _, safe = SearchNeedle(options.search)
        if not safe then return {} end

        sql = sql .. [[ AND CONCAT(JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')), ' ', JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname'))) LIKE ?]]
        params[#params + 1] = '%' .. safe .. '%'
    end

    for _, filter in ipairs({ { options.identifiers, 'IN' }, { options.exclude, 'NOT IN' } }) do
        if type(filter[1]) == 'table' then
            local ids = {}
            for _, identifier in ipairs(filter[1]) do
                if type(identifier) == 'string' then ids[#ids + 1] = identifier end
            end

            if #ids == 0 and filter[2] == 'IN' then return {} end
            if #ids > 0 then
                sql = ('%s AND g.citizenid %s (%s)'):format(sql, filter[2], string.rep('?', #ids, ', '))
                for _, identifier in ipairs(ids) do params[#params + 1] = identifier end
            end
        end
    end

    local limit = math.min(math.max(math.floor(tonumber(options.limit) or MemberLimit), 1), MemberLimit)
    local offset = math.min(math.max(math.floor(tonumber(options.offset) or 0), 0), MemberMaxOffset)
    local rows = MySQL.query.await(sql .. (' ORDER BY g.citizenid LIMIT %d OFFSET %d'):format(limit, offset), params)
    local jobList = FN_FRAMEWORK.GetJobs()

    local result = {}
    for _, row in ipairs(rows or {}) do
        local charInfo = FN_DB.Json(row.charinfo)
        local grade = tonumber(row.grade) or 0
        local gradeData = (jobList[row.job] or { grades = {} }).grades[grade] or {}

        result[#result + 1] = {
            identifier = row.citizenid,
            firstName = charInfo.firstname or '',
            lastName = charInfo.lastname or '',
            name = TrimName(charInfo.firstname, charInfo.lastname),
            job = row.job,
            grade = grade,
            gradeLabel = gradeData.label or tostring(grade),
        }
    end

    return result
end

FN_FRAMEWORK.GetJobMembers = function(jobName, options)
    local jobs = type(jobName) == 'table' and jobName or { jobName }
    if #jobs == 0 then return {} end

    for _, job in ipairs(jobs) do
        if type(job) ~= 'string' or job == '' then return {} end
    end

    options = type(options) == 'table' and options or {}

    if FN_DB.HasTable('player_groups') then return GroupMembers(jobs, options) end

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

    local sharedJob = GetSharedJobs()[jobName]
    if not sharedJob then return false end

    local gradeLevel, grade = FindGrade(sharedJob, jobGrade)
    if not grade then return false end

    if CoreValue('SetJob', identifier, jobName, gradeLevel) then return true end

    local row = MySQL.single.await('SELECT job FROM players WHERE citizenid = ?', {identifier})
    if not row then return false end

    local currentJob = row.job and json.decode(row.job)

    local job = {
        name = jobName,
        label = sharedJob.label or jobName,
        payment = grade.payment or 0,
        onduty = sharedJob.defaultDuty and true or false,
        isboss = grade.isboss and true or false,
        type = sharedJob.type,
        grade = { name = grade.name or tostring(gradeLevel), level = gradeLevel },
    }

    if type(currentJob) == 'table' and currentJob.onduty ~= nil then job.onduty = currentJob.onduty end

    local affected = MySQL.update.await('UPDATE players SET job = ? WHERE citizenid = ?', {json.encode(job), identifier})

    return affected > 0
end

FN_FRAMEWORK.CheckJobDuty = function(playerId)
    local player = GetQbxPlayer(playerId)
    if not player?.PlayerData?.job then return false end

    return player.PlayerData.job.onduty and true or false
end

FN_FRAMEWORK.SetJobDuty = function(playerId, dutyStatus)
    if type(dutyStatus) ~= 'boolean' then return false end

    local player = GetQbxPlayer(playerId)
    if not player?.PlayerData?.job then return false end

    local ok = pcall(function()
        player.Functions.SetJobDuty(dutyStatus)
    end)

    if not ok then CallCore('SetJobDuty', tonumber(playerId), dutyStatus) end

    return FN_FRAMEWORK.CheckJobDuty(playerId) == dutyStatus
end

FN_FRAMEWORK.GetJobs = function()
    local jobs = {}

    for jobName, sharedJob in pairs(GetSharedJobs()) do
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
    if not GetQbxPlayer(playerId) then return false end

    for groupName, wanted in pairs(groups) do
        if wanted and CoreValue('HasPermission', tonumber(playerId), groupName) then return true end
    end

    return groups[ResolveGroup(tonumber(playerId))] or false
end

FN_FRAMEWORK.RegisterUsableItem = function(itemName, callback)
    CallCore('CreateUseableItem', itemName, function(playerId, item)
        local player = FN_FRAMEWORK.GetPlayerFromId(playerId)
        if not player then return end

        callback(player, { name = itemName, slot = type(item) == 'table' and tonumber(item.slot) or nil, metadata = type(item) == 'table' and (item.metadata or item.info) or nil })
    end)
end

FN_FRAMEWORK.UseItem = function(playerId, itemName)
    if CallCore('UseItem', tonumber(playerId), itemName) then return end

    local ok = pcall(function()
        exports['ox_inventory']:UseItem(tonumber(playerId), itemName)
    end)

    if not ok then print(('^1qbx_core could not use item^7 %s'):format(tostring(itemName))) end
end

FN_FRAMEWORK.GetUsable = function(itemName)
    local callback = CoreValue('CanUseItem', itemName)
    if not callback then return nil end

    return function(playerId, item)
        callback(playerId, item)
    end
end

FN_FRAMEWORK.GetItemLabel = function(itemName)
    local ok, item = pcall(function()
        return exports['ox_inventory']:Items(itemName)
    end)

    if not ok or type(item) ~= 'table' then return itemName end

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

FN_FRAMEWORK.CheckLicense = function(identifier, license)
    if type(identifier) ~= 'string' or type(license) ~= 'string' then return false end

    local player = CoreValue('GetPlayerByCitizenId', identifier)
    local metadata = player?.PlayerData?.metadata or ReadOfflineMetadata(identifier)
    if not metadata then return false end

    local licences = metadata[LicenceKey(metadata)]

    return type(licences) == 'table' and licences[license] and true or false
end

local function SetLicense(identifier, license, granted)
    if type(identifier) ~= 'string' or type(license) ~= 'string' then return false end

    local player = CoreValue('GetPlayerByCitizenId', identifier)
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

Config.DebugPrint('framework adapter loaded: qbx (server)')
