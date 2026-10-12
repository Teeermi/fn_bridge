local F = FN_FRAMEWORK
if not F then return end

local Fw = FN_BRIDGE.frameworkName
local Esx, Qb, Qbx, Ox = Fw == 'esx', Fw == 'qb', Fw == 'qbx', Fw == 'ox'
local QbFamily = Qb or Qbx

local function Text(value, max)
    return type(value) == 'string' and value ~= '' and #value <= max and value or nil
end

local function Key(value)
    return type(value) == 'string' and #value <= 50 and value:match('^[%w_%-]+$') and value or nil
end

local function CleanGrades(grades)
    if type(grades) ~= 'table' or #grades == 0 or #grades > 50 then return nil end

    local out, seen = {}, {}
    for _, g in ipairs(grades) do
        local grade = type(g) == 'table' and math.tointeger(tonumber(g.grade))
        local name = grade and Text(g.name, 50)
        local label = name and Text(g.label or g.name, 50)
        if not label or grade < 0 or grade > 100 or seen[grade] then return nil end

        seen[grade] = true
        out[#out + 1] = { grade = grade, name = name, label = label, salary = math.max(0, math.floor(tonumber(g.salary) or 0)), isBoss = g.isBoss == true }
    end
    table.sort(out, function(a, b) return a.grade < b.grade end)

    return out
end

local function Export(resource, name, ...)
    local args = table.pack(...)
    local ok, a, b = pcall(function() return exports[resource][name](exports[resource], table.unpack(args, 1, args.n)) end)
    if not ok then return nil, a end

    return a, b
end

local function Done(ok, why)
    if ok == true then return true, 'live' end

    return false, type(why) == 'string' and why or type(why) == 'table' and tostring(why.message or why.code) or 'failed'
end

local function Online(target)
    return type(target) == 'number' and GetPlayerName(target) ~= nil
end

local function Shared(kind)
    if Qbx then
        local list = Export('qbx_core', kind == 'Jobs' and 'GetJobs' or 'GetGangs')
        return type(list) == 'table' and list or {}
    end

    local list = Export('qb-core', 'GetShared', kind)
    if type(list) == 'table' then return list end

    local core = F.obj

    return type(core) == 'table' and type(core.Shared) == 'table' and core.Shared[kind] or {}
end

if Qb then
    AddEventHandler('QBCore:Server:UpdateObject', function()
        local ok, core = pcall(function() return exports['qb-core']:GetCoreObject() end)
        if ok and type(core) == 'table' then F.obj = core end
    end)
end

local function QbData(label, grades, opts, gang)
    local data = { label = label, grades = {} }
    if not gang then
        data.type = Text(opts.type, 20)
        data.defaultDuty = opts.defaultDuty ~= false
        data.offDutyPay = opts.offDutyPay == true
    end

    for _, g in ipairs(grades) do
        data.grades[Qbx and g.grade or tostring(g.grade)] = { name = g.label, payment = not gang and g.salary or nil, isboss = g.isBoss or nil }
    end

    return data
end

local function Keep(opts)
    return not (type(opts) == 'table' and opts.persist == false)
end

local function QbSave(kind, name, data, opts)
    if not Keep(opts) then return end
    MySQL.query.await('CREATE TABLE IF NOT EXISTS fn_bridge_groups (kind VARCHAR(8) NOT NULL, name VARCHAR(50) NOT NULL, data LONGTEXT NULL, PRIMARY KEY (kind, name)) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci')
    MySQL.query.await('INSERT INTO fn_bridge_groups (kind, name, data) VALUES (?, ?, NULLIF(?, \'\')) ON DUPLICATE KEY UPDATE data = VALUES(data)', { kind, name, data and json.encode(data) or '' })
end

local function QbApply(kind, name, data)
    local single = kind == 'job' and 'Job' or 'Gang'
    if data == nil then return Export('qb-core', 'Remove' .. single, name) == true end

    if Shared(kind == 'job' and 'Jobs' or 'Gangs')[name] then
        if kind == 'job' then return Export('qb-core', 'UpdateJob', name, data) == true end
        Export('qb-core', 'RemoveGang', name)
    end

    return Export('qb-core', 'Add' .. single, name, data) == true
end

if Qb then
    MySQL.ready(function()
        if not FN_DB.HasTable('fn_bridge_groups') then return end

        for _, row in ipairs(MySQL.query.await('SELECT kind, name, data FROM fn_bridge_groups') or {}) do
            QbApply(row.kind, row.name, row.data and FN_DB.Json(row.data) or nil)
        end
    end)
end

local function EsxRefresh()
    local esx = F.obj
    if type(esx) == 'table' and esx.RefreshJobs and pcall(esx.RefreshJobs) then return 'live' end

    return 'restart'
end

local function EsxGrades(name, grades)
    local boss = false
    for _, g in ipairs(grades) do
        local gradeName = g.name
        if g.isBoss and not boss then gradeName, boss = 'boss', true end
        if not FN_DB.InsertRow('job_grades', { job_name = name, grade = g.grade, name = gradeName, label = g.label, salary = g.salary, skin_male = '{}', skin_female = '{}' }) then return false end
    end

    return true
end

local function OxGrades(grades)
    local out = {}
    for i, g in ipairs(grades) do out[i] = { label = g.label, accountRole = g.isBoss and 'owner' or nil } end

    return out
end

local function Jobs()
    return F.GetJobs and F.GetJobs() or {}
end

F.GetJobGrades = function(jobName)
    if type(jobName) ~= 'string' then return {} end

    local out = {}
    if Esx then
        for _, row in ipairs(MySQL.query.await('SELECT grade, name, label, salary FROM job_grades WHERE job_name = ? ORDER BY grade', { jobName }) or {}) do
            out[#out + 1] = { grade = tonumber(row.grade) or 0, name = row.name, label = row.label or row.name, salary = tonumber(row.salary) or 0, isBoss = row.name == 'boss' }
        end

        return out
    end

    if QbFamily then
        local job = Shared('Jobs')[jobName]
        for key, g in pairs(type(job) == 'table' and job.grades or {}) do
            local grade = tonumber(key)
            if grade then out[#out + 1] = { grade = grade, name = g.name or tostring(grade), label = g.name or tostring(grade), salary = tonumber(g.payment) or 0, isBoss = g.isboss == true } end
        end
    else
        local job = Jobs()[jobName]
        for grade, g in pairs(job and job.grades or {}) do
            if not Ox or grade > 0 then out[#out + 1] = { grade = grade, name = g.name, label = g.label or g.name, salary = tonumber(g.salary) or 0, isBoss = g.isBoss == true } end
        end
    end
    table.sort(out, function(a, b) return a.grade < b.grade end)

    return out
end

local function JobView(name, grade)
    local job = Jobs()[name]
    local g = job and job.grades[grade] or {}

    return { name = name, label = job and job.label or name, grade = grade, grade_name = g.name or '', grade_label = g.label or g.name or '', isBoss = g.isBoss == true }
end

F.GetJobOffline = function(identifier)
    if type(identifier) ~= 'string' or identifier == '' then return false end

    if Esx then
        local row = MySQL.single.await('SELECT job, job_grade FROM users WHERE identifier = ?', { identifier })
        return row and row.job and JobView(row.job, tonumber(row.job_grade) or 0) or false
    end

    if QbFamily then
        local row = MySQL.single.await('SELECT job FROM players WHERE citizenid = ?', { identifier })
        local job = row and FN_DB.Json(row.job)
        if not job or not job.name then return false end

        return JobView(job.name, tonumber(type(job.grade) == 'table' and job.grade.level or job.grade) or 0)
    end

    if Ox then
        local active = FN_DB.HasColumn('character_groups', 'isActive') and ' ORDER BY isActive DESC' or ''
        local row = MySQL.single.await('SELECT name, grade FROM character_groups WHERE charId = ?' .. active .. ' LIMIT 1', { tonumber(identifier) })
        return row and JobView(row.name, tonumber(row.grade) or 0) or false
    end

    return false
end

if Esx or QbFamily or Ox then
    F.CreateJob = function(name, label, grades, opts)
        name, label, grades, opts = Key(name), Text(label, 50), CleanGrades(grades), type(opts) == 'table' and opts or {}
        if not name or not label or not grades then return false, 'invalid' end
        if Jobs()[name] then return false, 'exists' end

        if Esx then
            if not FN_DB.InsertRow('jobs', { name = name, label = label, whitelisted = opts.whitelisted and 1 or 0, type = Text(opts.type, 20) }) or not EsxGrades(name, grades) then return false, 'failed' end
            return true, EsxRefresh()
        end

        if Qbx then
            local _, why = Export('qbx_core', 'CreateJob', name, QbData(label, grades, opts), Keep(opts))
            return Done(Shared('Jobs')[name] ~= nil, why)
        end

        if Qb then
            local data = QbData(label, grades, opts)
            if not QbApply('job', name, data) then return false, 'failed' end
            QbSave('job', name, data, opts)
            return true, 'live'
        end

        local ok = pcall(function() exports.ox_core:CreateGroup({ name = name, label = label, type = Text(opts.type, 20), grades = OxGrades(grades), hasAccount = false }) end)
        if F.ClearJobCache then F.ClearJobCache() end

        return Done(ok and Jobs()[name] ~= nil)
    end

    F.SetJobGrades = function(name, grades, opts)
        name, grades = Key(name), CleanGrades(grades)
        if not name or not grades then return false, 'invalid' end

        local job = Jobs()[name]
        if not job then return false, 'unknown' end

        if Esx then
            MySQL.update.await('DELETE FROM job_grades WHERE job_name = ?', { name })
            if not EsxGrades(name, grades) then return false, 'failed' end
            return true, EsxRefresh()
        end

        if QbFamily then
            local current = Shared('Jobs')[name] or {}
            local data = QbData(current.label or job.label, grades, { type = current.type, defaultDuty = current.defaultDuty, offDutyPay = current.offDutyPay })
            if Qbx then return Done(Export('qbx_core', 'CreateJob', name, data, Keep(opts)) ~= false) end
            if not QbApply('job', name, data) then return false, 'failed' end
            QbSave('job', name, data, opts)
            return true, 'live'
        end

        local queries = { { query = 'DELETE FROM ox_group_grades WHERE `group` = ?', values = { name } } }
        for i, g in ipairs(grades) do
            queries[#queries + 1] = { query = 'INSERT INTO ox_group_grades (`group`, grade, label, accountRole) VALUES (?, ?, ?, NULLIF(?, \'\'))', values = { name, i, g.label, g.isBoss and 'owner' or '' } }
        end
        if not MySQL.transaction.await(queries) then return false, 'failed' end
        ExecuteCommand('reloadgroups')
        if F.ClearJobCache then F.ClearJobCache() end

        return true, 'live'
    end

    F.DeleteJob = function(name, opts)
        name = Key(name)
        if not name or name == 'unemployed' then return false, 'invalid' end
        if not Jobs()[name] then return false, 'unknown' end

        if Esx then
            MySQL.update.await('DELETE FROM job_grades WHERE job_name = ?', { name })
            MySQL.update.await('DELETE FROM jobs WHERE name = ?', { name })
            return true, EsxRefresh()
        end

        if Qbx then
            local _, why = Export('qbx_core', 'RemoveJob', name, Keep(opts))
            return Done(Shared('Jobs')[name] == nil, why)
        end

        if Qb then
            if not QbApply('job', name, nil) then return false, 'failed' end
            QbSave('job', name, nil, opts)
            return true, 'live'
        end

        local ok = pcall(function() exports.ox_core:DeleteGroup(name) end)
        if F.ClearJobCache then F.ClearJobCache() end

        return Done(ok)
    end
end

local function EsxHidden()
    return Esx and FN_DB.HasColumn('users', 'hiddenjob')
end

local function GangView(name, grade, label, gradeName, gradeLabel, boss)
    if type(name) ~= 'string' or name == '' or name == 'none' or name == 'unemployed' then return false end

    return { name = name, label = label or name, grade = tonumber(grade) or 0, grade_name = gradeName or '', grade_label = gradeLabel or gradeName or '', isBoss = boss == true }
end

if Esx then
    F.GetGang = function(playerId)
        if not EsxHidden() then return false end

        local xPlayer = F.RawPlayer(playerId)
        local h = type(xPlayer) == 'table' and xPlayer.hiddenjob or tonumber(playerId) and Player(tonumber(playerId)).state.hiddenjob
        if type(h) ~= 'table' then return false end

        return GangView(h.name, h.grade, h.label, h.grade_name, h.grade_label, h.grade_name == 'boss')
    end
end

if Esx or QbFamily then
    F.GetGangs = function()
        if Esx then return EsxHidden() and Jobs() or {} end

        local out = {}
        for name, gang in pairs(Shared('Gangs')) do
            if name ~= 'none' then
                out[name] = { name = name, label = gang.label or name, grades = {} }
                for key, g in pairs(gang.grades or {}) do
                    local grade = tonumber(key)
                    if grade then out[name].grades[grade] = { name = g.name or tostring(grade), label = g.name or tostring(grade), grade = grade, isBoss = g.isboss == true } end
                end
            end
        end

        return out
    end

    F.GetGangMembers = function(gangName, options)
        if type(gangName) ~= 'string' or gangName == '' then return {} end

        options = type(options) == 'table' and options or {}
        local limit = math.min(math.max(math.floor(tonumber(options.limit) or 500), 1), 500)
        local offset = math.min(math.max(math.floor(tonumber(options.offset) or 0), 0), 100000)
        local gang = F.GetGangs()[gangName] or { grades = {} }
        local rows
        local result = {}

        if Esx then
            if not EsxHidden() then return {} end
            rows = MySQL.query.await(('SELECT identifier, firstname, lastname, hiddenjob_grade AS grade FROM users WHERE hiddenjob = ? ORDER BY identifier LIMIT %d OFFSET %d'):format(limit, offset), { gangName }) or {}
        elseif Qbx and FN_DB.HasTable('player_groups') then
            rows = MySQL.query.await(('SELECT g.citizenid AS identifier, g.grade, p.charinfo FROM player_groups g JOIN players p ON p.citizenid = g.citizenid WHERE g.type = \'gang\' AND g.`group` = ? ORDER BY g.citizenid LIMIT %d OFFSET %d'):format(limit, offset), { gangName }) or {}
        else
            rows = MySQL.query.await(('SELECT citizenid AS identifier, charinfo, JSON_EXTRACT(gang, \'$.grade.level\') AS grade FROM players WHERE JSON_UNQUOTE(JSON_EXTRACT(gang, \'$.name\')) = ? ORDER BY citizenid LIMIT %d OFFSET %d'):format(limit, offset), { gangName }) or {}
        end

        for _, row in ipairs(rows) do
            local info = row.charinfo and FN_DB.Json(row.charinfo) or {}
            local first, last = row.firstname or info.firstname or '', row.lastname or info.lastname or ''
            local grade = tonumber(row.grade) or 0
            result[#result + 1] = { identifier = row.identifier, firstName = first, lastName = last, name = (first .. ' ' .. last):match('^%s*(.-)%s*$'), gang = gangName, grade = grade, gradeLabel = (gang.grades[grade] or {}).label or tostring(grade) }
        end

        return result
    end

    F.SetGang = function(target, gangName, grade)
        grade = math.floor(tonumber(grade) or 0)
        local gang = type(gangName) == 'string' and (F.GetGangs()[gangName] or (gangName == 'none' or gangName == 'unemployed') and {})
        if not gang or (gang.grades and not gang.grades[grade] and gangName ~= 'none' and gangName ~= 'unemployed') then return false end

        if Esx then
            if not EsxHidden() then return false end
            if Online(target) then return select(2, F.Call(F.RawPlayer(target), 'setHiddenJob', gangName, grade)) == true end
            return type(target) == 'string' and (MySQL.update.await('UPDATE users SET hiddenjob = ?, hiddenjob_grade = ? WHERE identifier = ?', { gangName, grade, target }) or 0) > 0
        end

        if Qbx then return Export('qbx_core', 'SetGang', target, gangName, grade) == true end

        if Online(target) then
            local player = F.RawPlayer(target)
            return player ~= nil and player.Functions.SetGang(gangName, grade) ~= false
        end
        if type(target) ~= 'string' then return false end

        local g = gang.grades and gang.grades[grade] or {}
        local data = { name = gangName, label = gang.label or gangName, isboss = g.isBoss == true, grade = { name = g.name or 'none', level = grade, isboss = g.isBoss == true } }

        return (MySQL.update.await('UPDATE players SET gang = ? WHERE citizenid = ?', { json.encode(data), target }) or 0) > 0
    end

    F.RemoveGang = function(target, gangName)
        if Qbx then
            local citizenId = Online(target) and F.GetIdentifier(target) or target
            local current = gangName
            if not current and Online(target) then current = (F.GetGang(target) or {}).name end
            if type(citizenId) ~= 'string' or type(current) ~= 'string' then return false end
            return Export('qbx_core', 'RemovePlayerFromGang', citizenId, current) == true
        end

        return F.SetGang(target, Esx and 'unemployed' or 'none', 0)
    end

    F.CreateGang = function(name, label, grades, opts)
        if Esx then
            if not EsxHidden() then return false, 'unsupported' end
            return F.CreateJob(name, label, grades, opts)
        end

        name, label, grades = Key(name), Text(label, 50), CleanGrades(grades)
        if not name or not label or not grades then return false, 'invalid' end
        if Shared('Gangs')[name] then return false, 'exists' end

        local data = QbData(label, grades, {}, true)
        if Qbx then
            local _, why = Export('qbx_core', 'CreateGangs', { [name] = data }, Keep(opts))
            return Done(Shared('Gangs')[name] ~= nil, why)
        end
        if not QbApply('gang', name, data) then return false, 'failed' end
        QbSave('gang', name, data, opts)

        return true, 'live'
    end

    F.DeleteGang = function(name, opts)
        if Esx then
            if not EsxHidden() then return false, 'unsupported' end
            return F.DeleteJob(name, opts)
        end

        name = Key(name)
        if not name or name == 'none' then return false, 'invalid' end
        if not Shared('Gangs')[name] then return false, 'unknown' end
        if Qbx then
            local _, why = Export('qbx_core', 'RemoveGang', name, Keep(opts))
            return Done(Shared('Gangs')[name] == nil, why)
        end
        if not QbApply('gang', name, nil) then return false, 'failed' end
        QbSave('gang', name, nil, opts)

        return true, 'live'
    end
end

local LastGang = {}

local function GangChanged(playerId)
    playerId = tonumber(playerId)
    if not playerId then return end

    SetTimeout(0, function()
        local now = FN_BRIDGE.FRAMEWORK and FN_BRIDGE.FRAMEWORK.GetGang(playerId) or F.GetGang(playerId)
        local before = LastGang[playerId]
        if (now and now.name) == (before and before.name) and (now and now.grade) == (before and before.grade) then return end

        LastGang[playerId] = now
        TriggerEvent('fn_bridge/server/onGangChange', playerId, now, before or false)
    end)
end

AddEventHandler('QBCore:Server:OnGangUpdate', GangChanged)
AddEventHandler('qbx_core:server:onGroupUpdate', GangChanged)
AddEventHandler('esx:setHiddenJob', GangChanged)
AddEventHandler('playerDropped', function() LastGang[source] = nil end)

local function Multijob()
    local hook = FN_BRIDGE.Setting('multijob')

    return type(hook) == 'table' and hook or nil
end

local function PsMultijob()
    return Qb and GetResourceState('ps-multijob') == 'started'
end

local function Entry(name, grade, active)
    local view = JobView(name, grade)
    view.active = active

    return view
end

F.GetPlayerJobs = function(playerId)
    local hook = Multijob()
    if hook and FN_BRIDGE.Callable(hook.list) then
        local ok, list = pcall(hook.list, playerId)
        if ok and type(list) == 'table' then return list end
    end

    local current = F.GetJob and F.GetJob(playerId)
    local held

    if Qbx then
        local player = F.RawPlayer(playerId)
        held = player and player.PlayerData and player.PlayerData.jobs
    elseif PsMultijob() then
        local citizenId = F.GetIdentifier(playerId)
        held = citizenId and Export('ps-multijob', 'GetJobs', citizenId)
    end

    local out = {}
    for name, grade in pairs(type(held) == 'table' and held or {}) do
        if name ~= 'unemployed' then out[#out + 1] = Entry(name, tonumber(grade) or 0, current and current.name == name or false) end
    end

    if current and current.name ~= 'unemployed' and not (type(held) == 'table' and held[current.name]) then
        current.active = true
        out[#out + 1] = current
    end
    table.sort(out, function(a, b) return a.name < b.name end)

    return out
end

F.SetActiveJob = function(playerId, jobName)
    local hook = Multijob()
    if hook and FN_BRIDGE.Callable(hook.set) then
        local ok, done = pcall(hook.set, playerId, jobName)
        if ok and done ~= nil then return done == true end
    end

    if type(jobName) ~= 'string' then return false end
    if Qbx then
        local citizenId = F.GetIdentifier(playerId)
        return citizenId and Export('qbx_core', 'SetPlayerPrimaryJob', citizenId, jobName) == true or false
    end

    for _, job in ipairs(F.GetPlayerJobs(playerId)) do
        if job.name == jobName then
            if job.active then return true end
            local player = PsMultijob() and F.RawPlayer(playerId)
            return player and player.Functions.SetJob(jobName, job.grade) ~= false or false
        end
    end

    return false
end

F.AddPlayerJob = function(target, jobName, grade)
    local hook = Multijob()
    if hook and FN_BRIDGE.Callable(hook.add) then
        local ok, done = pcall(hook.add, target, jobName, grade)
        if ok and done ~= nil then return done == true end
    end

    grade = math.floor(tonumber(grade) or 0)
    local citizenId = Online(target) and F.GetIdentifier(target) or target

    if Qbx and type(citizenId) == 'string' then return Export('qbx_core', 'AddPlayerToJob', citizenId, jobName, grade) == true end
    if PsMultijob() and type(citizenId) == 'string' and Jobs()[jobName] then
        Export('ps-multijob', 'AddJob', citizenId, jobName, grade)
        return true
    end

    return F.SetJob and F.SetJob(target, jobName, grade) or false
end

if Qb and F.RemoveJob then
    local remove = F.RemoveJob
    F.RemoveJob = function(target, jobName)
        if PsMultijob() then
            local citizenId = Online(target) and F.GetIdentifier(target) or target
            if type(citizenId) == 'string' then Export('ps-multijob', 'RemoveJob', citizenId, jobName) end
        end

        return remove(target, jobName)
    end
end

for _, key in ipairs({ 'GetGangs', 'GetGangMembers', 'SetGang', 'RemoveGang', 'CreateGang', 'DeleteGang' }) do
    FN_BRIDGE.SupportedWhen('FRAMEWORK', key, function() return not Esx or EsxHidden() end)
end

if F.Supports then
    local supports = F.Supports
    F.Supports = function(feature)
        if feature == 'multijob' then return Qbx or PsMultijob() or Multijob() ~= nil end
        if feature == 'gangs' and FN_BRIDGE.Callable(FN_BRIDGE.Setting('gang')) then return true end

        return supports(feature)
    end
end

F.GetInsurance = function(identifier)
    local hook = FN_BRIDGE.Setting('insurance')
    if not FN_BRIDGE.Callable(hook) or type(identifier) ~= 'string' then return false end

    local ok, value = pcall(hook, identifier)

    return ok and type(value) == 'table' and value or false
end

if F.SetName then
    local setName = F.SetName
    F.SetName = function(playerId, firstName, lastName)
        local done = setName(playerId, firstName, lastName)
        if done then TriggerEvent('fn_bridge:nameChanged', F.GetIdentifier(playerId), firstName, lastName, playerId) end

        return done
    end
end
