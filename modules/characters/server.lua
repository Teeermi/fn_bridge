if not FN_FRAMEWORK then return end

FN_CHARACTERS = {}

local MAX = 10

local function decode(v)
    if type(v) == 'table' then return v end
    if type(v) ~= 'string' or v == '' then return nil end
    local ok, r = pcall(json.decode, v)
    return ok and r or nil
end

local function Iso(s)
    if type(s) ~= 'string' then return nil end
    local a, b, c = s:match('^(%d+)[%-/%.](%d+)[%-/%.](%d+)')
    if not a then return nil end
    local y, m, d
    if #a == 4 then y, m, d = a, b, c else d, m, y = a, b, c end
    y, m, d = tonumber(y), tonumber(m), tonumber(d)
    if not (y and m and d) or m < 1 or m > 12 or d < 1 or d > 31 then return nil end
    return ('%04d-%02d-%02d'):format(y, m, d)
end

local function vec(p)
    p = decode(p)
    if type(p) ~= 'table' then return nil end
    local x, y, z = tonumber(p.x), tonumber(p.y), tonumber(p.z)
    if not (x and y and z) or (x == 0 and y == 0) then return nil end
    return { x = x, y = y, z = z, w = tonumber(p.w or p.heading or p.a or p.h) or 0.0 }
end

local function marks(n)
    return ('?, '):rep(n):sub(1, -3)
end

local function waitFor(fn, ms)
    local stop = GetGameTimer() + ms
    while not fn() do
        if GetGameTimer() > stop then return false end
        Wait(50)
    end
    return true
end

local function sexOf(v)
    if v == 1 or v == '1' or v == 'f' or v == 'F' or v == 'female' then return 'f' end
    return 'm'
end

local function esx()
    return FN_FRAMEWORK.obj
end

local function qb()
    return FN_FRAMEWORK.obj
end

local loaded = {}
AddEventHandler('QBCore:Server:PlayerLoaded', function(p)
    local s = p and p.PlayerData and p.PlayerData.source
    if s then loaded[s] = true end
end)
AddEventHandler('QBCore:Server:OnPlayerUnload', function(s) loaded[s] = nil end)
AddEventHandler('playerDropped', function() loaded[source] = nil end)

local hasColumn = {}
local function column(t, c)
    local k = t .. '.' .. c
    if hasColumn[k] == nil then
        hasColumn[k] = MySQL.scalar.await('SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?', { t, c }) ~= nil
    end
    return hasColumn[k]
end

local esxColumns
local function esxTables()
    esxColumns = esxColumns or MySQL.query.await([[SELECT TABLE_NAME AS t, COLUMN_NAME AS c FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND COLUMN_NAME IN ('identifier', 'owner')
        AND DATA_TYPE IN ('varchar', 'char', 'text', 'tinytext', 'mediumtext', 'longtext')]]) or {}
    return esxColumns
end

local function qbChar(r)
    local ci = decode(r.charinfo) or {}
    local job = decode(r.job) or {}
    local money = decode(r.money) or {}
    local grade = type(job.grade) == 'table' and job.grade or {}
    return {
        key = r.citizenid,
        num = tonumber(ci.cid) or tonumber(r.cid),
        firstname = ci.firstname,
        lastname = ci.lastname,
        dob = Iso(ci.birthdate),
        sex = sexOf(ci.gender),
        height = tonumber(ci.height),
        nationality = ci.nationality,
        phone = ci.phone and tostring(ci.phone) or nil,
        cid = r.citizenid,
        job = job.label,
        jobName = job.name,
        grade = grade.name,
        cash = tonumber(money.cash) or 0,
        bank = tonumber(money.bank) or 0,
        position = vec(r.position),
        seen = tonumber(r.seen),
        jail = (tonumber(r.injail) or 0) > 0,
        down = r.dead == true or r.dead == 'true' or r.ls == true or r.ls == 'true' or nil,
        inside = decode(r.inside),
        property = tonumber(r.prop),
    }
end

local function qbSkins(list)
    if #list == 0 then return end
    local keys, by = {}, {}
    for _, c in ipairs(list) do
        keys[#keys + 1] = c.key
        by[c.key] = c
    end
    local rows = MySQL.query.await(('SELECT citizenid, model, skin FROM playerskins WHERE citizenid IN (%s) AND active = 1'):format(marks(#keys)), keys) or {}
    for _, r in ipairs(rows) do
        local c = by[r.citizenid]
        if c then c.skin = { model = r.model, data = decode(r.skin) } end
    end
end

local QB_LIST = [[SELECT citizenid, cid, charinfo, money, job, position, UNIX_TIMESTAMP(last_updated) AS seen,
    JSON_EXTRACT(metadata, '$.injail') AS injail, JSON_EXTRACT(metadata, '$.inside') AS inside,
    JSON_EXTRACT(metadata, '$.isdead') AS dead, JSON_EXTRACT(metadata, '$.inlaststand') AS ls,
    JSON_EXTRACT(metadata, '$.currentPropertyId') AS prop FROM players WHERE license ]]

local function qbList(rows)
    local out = {}
    for _, r in ipairs(rows or {}) do out[#out + 1] = qbChar(r) end
    qbSkins(out)
    return out
end

local function qbCharinfo(num, d)
    return {
        firstname = d.firstname,
        lastname = d.lastname,
        birthdate = d.dob,
        gender = d.sex == 'f' and 1 or 0,
        nationality = d.nationality,
        height = d.height,
        cid = num,
    }
end

local function qbHouses(src)
    if GetResourceState('qb-houses') ~= 'started' then return end
    local houses, garages = {}, {}
    for _, v in ipairs(MySQL.query.await('SELECT name, label, coords, owned, price, tier, garage FROM houselocations') or {}) do
        local garage = decode(v.garage) or {}
        houses[v.name] = { coords = decode(v.coords), owned = tonumber(v.owned) == 1 or v.owned == true, price = v.price, locked = true, adress = v.label, tier = v.tier, garage = garage, decorations = {} }
        garages[v.name] = { label = v.label, takeVehicle = garage }
    end
    TriggerClientEvent('qb-garages:client:houseGarageConfig', src, garages)
    TriggerClientEvent('qb-houses:client:setHouseConfig', src, houses)
end

local function qbLoaded(src)
    waitFor(function() return loaded[src] end, 10000)
    Wait(1000)
    qb().Commands.Refresh(src)
    qbHouses(src)
end

local function qbStarter(src)
    local ok, items = pcall(function() return exports['qb-core']:GetShared('StarterItems') end)
    if not ok or type(items) ~= 'table' then items = qb().Shared and qb().Shared.StarterItems or {} end
    local p = qb().Functions.GetPlayer(src)
    if not p then return {} end
    local ci, out = p.PlayerData.charinfo or {}, {}
    for _, v in pairs(items) do
        local meta = {}
        if v.item == 'id_card' then
            meta = { citizenid = p.PlayerData.citizenid, firstname = ci.firstname, lastname = ci.lastname, birthdate = ci.birthdate, gender = ci.gender, nationality = ci.nationality }
        elseif v.item == 'driver_license' then
            meta = { firstname = ci.firstname, lastname = ci.lastname, birthdate = ci.birthdate, type = 'Class C Driver License' }
        end
        out[#out + 1] = { item = v.item, amount = v.amount or 1, meta = meta }
    end
    return out
end

local function qbxStarter(src)
    local raw = LoadResourceFile('qbx_core', 'config/shared.lua')
    local fn = raw and load(raw, '@qbx_core/config/shared.lua', 't', setmetatable({}, { __index = _G }))
    local ok, cfg = pcall(fn or error)
    local out = {}
    for _, v in ipairs(ok and type(cfg) == 'table' and cfg.starterItems or {}) do
        local meta = v.metadata
        if type(meta) == 'function' then
            local mok, m = pcall(meta, src)
            meta = mok and m or nil
        end
        out[#out + 1] = { item = v.name, amount = v.amount or 1, meta = meta }
    end
    return out
end

local tables
local function has(t)
    if not tables then
        tables = {}
        for _, r in ipairs(MySQL.query.await('SELECT TABLE_NAME AS t FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = DATABASE()') or {}) do
            tables[r.t] = true
        end
    end
    return tables[t] == true
end

local function cars(rows, model, stored)
    local out = {}
    for _, r in ipairs(rows or {}) do
        out[#out + 1] = { model = model(r), plate = r.plate and tostring(r.plate):gsub('^%s+', ''):gsub('%s+$', '') or '', stored = stored(r) }
    end
    return out
end

local function fines(sql, key)
    local r = MySQL.single.await(sql, { key })
    return r and { fines = tonumber(r.n) or 0, unpaid = tonumber(r.s) or 0 } or nil
end

local function qbDossier(key)
    local d = {}
    if has('player_vehicles') then
        d.veh = cars(MySQL.query.await('SELECT vehicle, plate, state FROM player_vehicles WHERE citizenid = ? LIMIT 30', { key }),
            function(r) return r.vehicle end, function(r) return tonumber(r.state) == 1 end)
    end
    local m = MySQL.single.await([[SELECT JSON_EXTRACT(metadata, '$.licences') AS lic, JSON_EXTRACT(metadata, '$.criminalrecord') AS rec,
        JSON_EXTRACT(metadata, '$.injail') AS jail FROM players WHERE citizenid = ?]], { key }) or {}
    local lic = decode(m.lic)
    if type(lic) == 'table' then
        d.lic = {}
        for id, on in pairs(lic) do
            if on == true then d.lic[#d.lic + 1] = { id = id } end
        end
        table.sort(d.lic, function(a, b) return a.id < b.id end)
    end
    if has('phone_invoices') then
        d.rec = fines('SELECT COUNT(*) AS n, COALESCE(SUM(amount), 0) AS s FROM phone_invoices WHERE citizenid = ?', key)
    end
    local rec = decode(m.rec)
    if type(rec) == 'table' then
        d.rec = d.rec or {}
        d.rec.record = rec.hasRecord == true
    end
    d.jail = tonumber(m.jail) or 0
    return d
end

local function qbMoney(key)
    local m = decode(MySQL.scalar.await('SELECT money FROM players WHERE citizenid = ?', { key }))
    return m and (tonumber(m.cash) or 0) + (tonumber(m.bank) or 0) or nil
end

local IMPL = {}

IMPL.esx = {
    license = function(src) return esx().GetIdentifier(src) end,
    list = function(src)
        local id = esx().GetIdentifier(src)
        if not id then return {} end
        local keys = {}
        for n = 1, MAX do keys[n] = ('char%d:%s'):format(n, id) end
        local rows = MySQL.query.await(([[SELECT u.identifier, u.firstname, u.lastname, u.dateofbirth, u.sex, u.height, u.accounts,
            u.position, u.skin, u.job AS job_name, j.label AS job_label, g.label AS grade_label]] .. (column('users', 'is_dead') and ', u.is_dead' or '') .. [[ FROM users u
            LEFT JOIN jobs j ON j.name = u.job LEFT JOIN job_grades g ON g.job_name = u.job AND g.grade = u.job_grade
            WHERE u.identifier IN (%s)]]):format(marks(#keys)), keys) or {}
        local out = {}
        for _, r in ipairs(rows) do
            local acc = decode(r.accounts) or {}
            local skin = decode(r.skin)
            out[#out + 1] = {
                key = r.identifier,
                num = tonumber(r.identifier:match('^char(%d+):')),
                firstname = r.firstname,
                lastname = r.lastname,
                dob = Iso(r.dateofbirth),
                sex = sexOf(r.sex),
                height = tonumber(r.height),
                job = r.job_label,
                jobName = r.job_name,
                grade = r.grade_label,
                cash = tonumber(acc.money) or 0,
                bank = tonumber(acc.bank) or 0,
                dirty = tonumber(acc.black_money),
                down = (tonumber(r.is_dead) or 0) > 0 or r.is_dead == true or nil,
                position = vec(r.position),
                skin = skin and { data = skin } or nil,
            }
        end
        return out
    end,
    login = function(src, key)
        local n = key:match('^char(%d+):')
        if not n then return false end
        TriggerEvent('esx:onPlayerJoined', src, 'char' .. n)
        return waitFor(function() return FN_FRAMEWORK.RawPlayer(src) ~= nil end, 15000)
    end,
    create = function(src, num, d)
        TriggerEvent('esx:onPlayerJoined', src, 'char' .. num, {
            firstname = d.firstname,
            lastname = d.lastname,
            dateofbirth = d.dobText,
            sex = d.sex,
            height = d.height or 180,
        })
        if not waitFor(function() return FN_FRAMEWORK.RawPlayer(src) ~= nil end, 15000) then return nil end
        return ('char%d:%s'):format(num, esx().GetIdentifier(src))
    end,
    delete = function(_, key)
        local q = {}
        for _, r in ipairs(esxTables()) do
            q[#q + 1] = { query = ('DELETE FROM `%s` WHERE `%s` = ?'):format(r.t, r.c), values = { key } }
        end
        return #q > 0 and MySQL.transaction.await(q) == true
    end,
    logout = function(src)
        local p = promise.new()
        TriggerEvent('esx:playerLogout', src, function() p:resolve(true) end)
        SetTimeout(10000, function() p:resolve(false) end)
        return Citizen.Await(p)
    end,
    loaded = function(src) return FN_FRAMEWORK.RawPlayer(src) ~= nil end,
    money = function(key)
        local a = decode(MySQL.scalar.await('SELECT accounts FROM users WHERE identifier = ?', { key }))
        return a and (tonumber(a.money) or 0) + (tonumber(a.bank) or 0) or nil
    end,
    dossier = function(key)
        local d = {}
        if has('owned_vehicles') then
            d.veh = cars(MySQL.query.await('SELECT plate, vehicle, `stored` FROM owned_vehicles WHERE owner = ? LIMIT 30', { key }),
                function(r)
                    local v = decode(r.vehicle)
                    return v and v.model
                end, function(r) return r.stored == true or tonumber(r.stored) == 1 end)
        end
        if has('user_licenses') then
            local join = has('licenses')
            local rows = MySQL.query.await(join and 'SELECT ul.type, l.label FROM user_licenses ul LEFT JOIN licenses l ON l.type = ul.type WHERE ul.owner = ?'
                or 'SELECT type FROM user_licenses WHERE owner = ?', { key }) or {}
            d.lic = {}
            for _, r in ipairs(rows) do d.lic[#d.lic + 1] = { id = r.type, label = r.label } end
        end
        if has('billing') then
            d.rec = fines('SELECT COUNT(*) AS n, COALESCE(SUM(amount), 0) AS s FROM billing WHERE identifier = ?', key)
        end
        return d
    end,
    multichar = function()
        local ok, cfg = pcall(function() return esx().GetConfig() end)
        return ok and type(cfg) == 'table' and cfg.Multichar == true
    end,
}

IMPL.qb = {
    license = function(src) return GetPlayerIdentifierByType(src, 'license') end,
    list = function(src)
        local lic = GetPlayerIdentifierByType(src, 'license')
        if not lic then return {} end
        return qbList(MySQL.query.await(QB_LIST .. '= ?', { lic }))
    end,
    login = function(src, key)
        loaded[src] = nil
        if not qb().Player.Login(src, key) then return false end
        qbLoaded(src)
        return true
    end,
    create = function(src, num, d)
        loaded[src] = nil
        if not qb().Player.Login(src, false, { cid = num, charinfo = qbCharinfo(num, d) }) then return nil end
        qbLoaded(src)
        local p = qb().Functions.GetPlayer(src)
        return p and p.PlayerData.citizenid
    end,
    delete = function(src, key)
        qb().Player.DeleteCharacter(src, key)
        return true
    end,
    logout = function(src)
        qb().Player.Logout(src)
        return true
    end,
    loaded = function(src) return qb().Functions.GetPlayer(src) ~= nil end,
    starter = qbStarter,
    money = qbMoney,
    dossier = qbDossier,
}

IMPL.qbx = {
    license = function(src) return GetPlayerIdentifierByType(src, 'license') end,
    list = function(src)
        local lic = GetPlayerIdentifierByType(src, 'license')
        if not lic then return {} end
        local lic2 = GetPlayerIdentifierByType(src, 'license2') or lic
        return qbList(MySQL.query.await(QB_LIST .. 'IN (?, ?)', { lic2, lic }))
    end,
    login = function(src, key)
        loaded[src] = nil
        if not exports.qbx_core:Login(src, key) then return false end
        waitFor(function() return loaded[src] end, 10000)
        return true
    end,
    create = function(src, num, d)
        loaded[src] = nil
        if not exports.qbx_core:Login(src, nil, { charinfo = qbCharinfo(num, d) }) then return nil end
        waitFor(function() return loaded[src] end, 10000)
        local p = exports.qbx_core:GetPlayer(src)
        return p and p.PlayerData.citizenid
    end,
    delete = function(_, key)
        exports.qbx_core:DeleteCharacter(key)
        return true
    end,
    logout = function(src)
        exports.qbx_core:Logout(src)
        return true
    end,
    loaded = function(src) return exports.qbx_core:GetPlayer(src) ~= nil end,
    starter = qbxStarter,
    money = qbMoney,
    dossier = qbDossier,
    external = function()
        local cfg = LoadResourceFile('qbx_core', 'config/client.lua') or ''
        return cfg:find('useExternalCharacters%s*=%s*true') ~= nil
    end,
}

local OX_LIST = [[SELECT c.charId, c.stateId, c.firstName, c.lastName, c.gender, DATE_FORMAT(c.dateOfBirth, '%Y-%m-%d') AS dob,
    c.phoneNumber, c.x, c.y, c.z, c.heading, UNIX_TIMESTAMP(c.lastPlayed) AS seen, a.balance, i.inventory, g.name AS job_name,
    g.label AS job_label, gg.label AS grade_label FROM characters c
    LEFT JOIN accounts a ON a.owner = c.charId AND a.isDefault = 1
    LEFT JOIN character_inventory i ON i.charId = c.charId
    LEFT JOIN character_groups cg ON cg.charId = c.charId AND cg.isActive = 1
    LEFT JOIN ox_groups g ON g.name = cg.name
    LEFT JOIN ox_group_grades gg ON gg.`group` = cg.name AND gg.grade = cg.grade
    WHERE c.userId = ? AND c.deleted IS NULL ORDER BY c.charId]]

local function oxCash(inv)
    local n = 0
    for _, it in pairs(decode(inv) or {}) do
        if type(it) == 'table' and it.name == 'money' then n = n + (tonumber(it.count) or 0) end
    end
    return n
end

local function oxMoney(key)
    local r = MySQL.single.await([[SELECT a.balance, i.inventory FROM characters c LEFT JOIN accounts a ON a.owner = c.charId AND a.isDefault = 1
        LEFT JOIN character_inventory i ON i.charId = c.charId WHERE c.charId = ?]], { key })
    return r and (tonumber(r.balance) or 0) + oxCash(r.inventory) or nil
end

local function oxDossier(key)
    local d = {}
    d.veh = cars(MySQL.query.await('SELECT model, plate, `stored` FROM vehicles WHERE owner = ? LIMIT 30', { key }),
        function(r) return r.model end, function(r) return r.stored ~= nil and r.stored ~= 'impound' end)
    d.lic = {}
    for _, r in ipairs(MySQL.query.await('SELECT cl.name, l.label FROM character_licenses cl LEFT JOIN ox_licenses l ON l.name = cl.name WHERE cl.charId = ?', { key }) or {}) do
        d.lic[#d.lic + 1] = { id = r.name, label = r.label }
    end
    d.rec = fines([[SELECT COUNT(*) AS n, COALESCE(SUM(i.amount), 0) AS s FROM accounts_invoices i
        JOIN accounts a ON a.id = i.toAccount WHERE a.owner = ? AND a.isDefault = 1 AND i.paidAt IS NULL]], key)
    return d
end

IMPL.ox = {
    list = function(src, owner)
        local uid = owner or Player(src).state.userId
        if not uid then return {} end
        local out = {}
        local q = column('characters', 'isDead') and OX_LIST:gsub('c%.heading,', 'c.heading, c.isDead,', 1) or OX_LIST
        for n, r in ipairs(MySQL.query.await(q, { uid }) or {}) do
            out[n] = {
                key = tostring(r.charId),
                num = n,
                firstname = r.firstName,
                lastname = r.lastName,
                dob = r.dob,
                sex = sexOf(r.gender),
                phone = r.phoneNumber,
                cid = r.stateId,
                job = r.job_label,
                jobName = r.job_name,
                grade = r.grade_label,
                cash = oxCash(r.inventory),
                bank = tonumber(r.balance) or 0,
                position = vec({ x = r.x, y = r.y, z = r.z, w = r.heading }),
                seen = tonumber(r.seen),
                down = r.isDead == true or (tonumber(r.isDead) or 0) > 0 or nil,
            }
        end
        if has('playerskins') then qbSkins(out) end
        return out
    end,
    login = function(src, key)
        return exports.ox_core:CallPlayer(src, 'setActiveCharacter', tonumber(key)) ~= nil
    end,
    create = function(src, _, d)
        local uid = Player(src).state.userId
        local y, m, day = d.dob:match('^(%d+)-(%d+)-(%d+)$')
        local date = os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(day), hour = 12 }) * 1000
        if not uid or exports.ox_core:CallPlayer(src, 'createCharacter', {
            firstName = d.firstname, lastName = d.lastname, gender = d.sex == 'f' and 'female' or 'male', date = date,
        }) == nil then return nil end
        local id = MySQL.scalar.await('SELECT MAX(charId) FROM characters WHERE userId = ? AND deleted IS NULL', { uid })
        return id and tostring(id)
    end,
    delete = function(src, key)
        return exports.ox_core:CallPlayer(src, 'deleteCharacter', tonumber(key)) == true
    end,
    logout = function(src)
        exports.ox_core:CallPlayer(src, 'logout')
        return true
    end,
    loaded = function(src)
        local p = exports.ox_core:GetPlayer(src)
        return p ~= nil and p.charId ~= nil
    end,
    money = oxMoney,
    dossier = oxDossier,
}

local function call(name, ...)
    local i = IMPL[FN_BRIDGE.frameworkName or '']
    if not i or not i[name] then return nil end
    local ok, a = pcall(i[name], ...)
    if not ok then
        print(('^1[fn_bridge] CHARACTERS.%s failed: %s^0'):format(name, tostring(a)))
        return nil
    end
    return a
end

FN_CHARACTERS.Supported = function() return IMPL[FN_BRIDGE.frameworkName or ''] ~= nil end
FN_CHARACTERS.Owner = function(src) return call('license', src) end
FN_CHARACTERS.List = function(src, owner) return call('list', src, owner) or {} end
FN_CHARACTERS.DeferredLogin = function() return FN_BRIDGE.frameworkName == 'ox' end
FN_CHARACTERS.Login = function(src, key) return call('login', src, key) == true end
FN_CHARACTERS.Create = function(src, num, data) return call('create', src, num, data) end
FN_CHARACTERS.Delete = function(src, key)
    local done = call('delete', src, key) == true
    if done then FN_CHARACTERS.Deleted(key, src) end
    return done
end
FN_CHARACTERS.Logout = function(src) return call('logout', src) == true end
FN_CHARACTERS.IsLoaded = function(src) return call('loaded', src) == true end
FN_CHARACTERS.StarterItems = function(src) return call('starter', src) or {} end
FN_CHARACTERS.Money = function(key) return call('money', key) end
FN_CHARACTERS.Dossier = function(key) return call('dossier', key) end

FN_CHARACTERS.TakeOver = function()
    if FN_BRIDGE.frameworkName == 'ox' and GetConvarInt('ox:characterSelect', 1) ~= 0 then SetConvarReplicated('ox:characterSelect', '0') end
    return true
end

FN_CHARACTERS.HandsOver = function()
    local fw = FN_BRIDGE.frameworkName
    if fw == 'esx' then return call('multichar') == true end
    if fw == 'qbx' then return call('external') == true end
    return true
end

FN_CHARACTERS.Slots = function()
    if FN_BRIDGE.frameworkName ~= 'ox' then return nil end
    return GetConvarInt('ox:characterSlots', 1)
end

local Recent = {}

FN_CHARACTERS.Deleted = function(identifier, playerId)
    if type(identifier) ~= 'string' or identifier == '' or Recent[identifier] then return end

    Recent[identifier] = true
    SetTimeout(10000, function() Recent[identifier] = nil end)
    TriggerEvent('fn_bridge:characterDeleted', identifier, tonumber(playerId))
end

local function Gone(identifier, playerId, sql)
    if type(identifier) ~= 'string' or identifier == '' then return end

    SetTimeout(3000, function()
        if not MySQL.scalar.await(sql, { identifier }) then FN_CHARACTERS.Deleted(identifier, playerId) end
    end)
end

RegisterNetEvent('esx_multicharacter:DeleteCharacter', function(slot)
    local license = GetPlayerIdentifierByType(source, 'license')
    slot = math.tointeger(tonumber(slot))
    if license and slot then Gone(('char%d:%s'):format(slot, license:gsub('^license:', '')), source, 'SELECT 1 FROM users WHERE identifier = ?') end
end)

for _, event in ipairs({ 'qb-multicharacter:server:deleteCharacter', 'qbx_core:server:deleteCharacter' }) do
    RegisterNetEvent(event, function(citizenId)
        Gone(citizenId, source, 'SELECT 1 FROM players WHERE citizenid = ?')
    end)
end

AddEventHandler('ox:deletedCharacter', function(playerId, _, charId)
    FN_CHARACTERS.Deleted(tostring(charId), playerId)
end)
