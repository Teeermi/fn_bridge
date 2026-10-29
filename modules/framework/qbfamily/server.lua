if not FN_BRIDGE.IsFramework('qb') and not FN_BRIDGE.IsFramework('qbx') then return end

local IsQbx = FN_BRIDGE.IsFramework('qbx')

local function Raw(playerId)
    if not tonumber(playerId) then return nil end

    local player = FN_FRAMEWORK.RawPlayer(tonumber(playerId))

    return type(player) == 'table' and player.PlayerData and player or nil
end

local function TrimName(firstName, lastName)
    return ((firstName or '') .. ' ' .. (lastName or '')):match('^%s*(.-)%s*$')
end

local function PositiveAmount(amount)
    amount = math.floor(tonumber(amount) or 0)

    return amount > 0 and amount or nil
end

local function DirtyMoney()
    local dirty = FN_BRIDGE.Setting('dirtyMoney')
    local configured = type(dirty) == 'table' and dirty[FN_FRAMEWORK.GetFrameworkName()]
    if type(configured) == 'table' then return configured end
    if IsQbx and FN_BRIDGE.IsInventory('ox_inventory') then return { item = 'black_money' } end

    return { item = 'markedbills', worth = 'worth' }
end

local function Account(player, accountName)
    if accountName == 'money' then accountName = 'cash' end

    local money = player.PlayerData.money or {}
    if money[accountName] ~= nil then return accountName end

    return nil
end

local function DirtyBalance(playerId)
    local dirty = DirtyMoney()
    if not dirty.worth then return FN_INVENTORY and FN_INVENTORY.GetItemCount(playerId, dirty.item) or 0 end

    local total = 0
    for _, item in ipairs(FN_INVENTORY and FN_INVENTORY.GetPlayerItems(playerId) or {}) do
        if item.name == dirty.item then total = total + (tonumber(item.metadata and item.metadata[dirty.worth]) or 0) * math.max(1, item.count) end
    end

    return math.floor(total)
end

FN_FRAMEWORK.GetIdentifier = function(playerId)
    local player = Raw(playerId)

    return player and player.PlayerData.citizenid or false
end

FN_FRAMEWORK.GetMoney = function(playerId, accountName)
    accountName = accountName or 'bank'
    if accountName == 'black_money' then return DirtyBalance(playerId) end

    local player = Raw(playerId)
    local account = player and Account(player, accountName)

    return account and math.floor(tonumber(player.PlayerData.money[account]) or 0) or 0
end

FN_FRAMEWORK.AddMoney = function(playerId, accountName, amount, reason)
    amount = PositiveAmount(amount)
    local player = Raw(playerId)
    if not amount or not player then return false end

    if (accountName or 'bank') == 'black_money' then
        local dirty = DirtyMoney()
        if not FN_INVENTORY then return false end
        if dirty.worth then return FN_INVENTORY.AddItem(playerId, dirty.item, 1, { [dirty.worth] = amount }) == true end

        return FN_INVENTORY.AddItem(playerId, dirty.item, amount) == true
    end

    local account = Account(player, accountName or 'bank')
    if not account then return false end

    return player.Functions.AddMoney(account, amount, reason or 'fn_bridge') ~= false
end

FN_FRAMEWORK.RemoveMoney = function(playerId, accountName, amount, reason)
    amount = PositiveAmount(amount)
    local player = Raw(playerId)
    if not amount or not player or FN_FRAMEWORK.GetMoney(playerId, accountName) < amount then return false end

    if accountName == 'black_money' then
        local dirty = DirtyMoney()
        if dirty.worth or not FN_INVENTORY then return false end

        return FN_INVENTORY.RemoveItem(playerId, dirty.item, amount) == true
    end

    local account = Account(player, accountName or 'bank')
    if not account then return false end

    return player.Functions.RemoveMoney(account, amount, reason or 'fn_bridge') == true
end

AddEventHandler('QBCore:Server:OnMoneyChange', function(playerId, accountName, amount, operation, reason)
    amount = tonumber(amount)
    if not tonumber(playerId) or not amount or amount == 0 then return end
    if operation ~= 'add' and operation ~= 'remove' then return end

    TriggerEvent('fn_bridge/server/onMoneyChange', tonumber(playerId), accountName, operation == 'add' and amount or -amount, type(reason) == 'string' and reason or '')
end)

local function Group(group)
    if type(group) ~= 'table' or not group.name or group.name == 'none' then return false end

    local grade = type(group.grade) == 'table' and group.grade or {}

    return {
        name = group.name,
        label = group.label or group.name,
        grade = tonumber(grade.level) or 0,
        grade_name = grade.name or '',
        grade_label = grade.name or '',
        isBoss = group.isboss == true or grade.isboss == true,
        onDuty = group.onduty ~= false,
    }
end

FN_FRAMEWORK.GetJob = function(playerId)
    local player = Raw(playerId)

    return player and Group(player.PlayerData.job) or false
end

FN_FRAMEWORK.GetGang = function(playerId)
    local player = Raw(playerId)
    local gang = player and Group(player.PlayerData.gang)
    if gang then gang.onDuty = nil end

    return gang
end

local function JobExists(jobName, grade)
    local job = FN_FRAMEWORK.GetJobs()[jobName]

    return job ~= nil and job.grades[grade] ~= nil
end

FN_FRAMEWORK.SetJob = function(target, jobName, grade)
    grade = math.floor(tonumber(grade) or 0)
    if type(jobName) ~= 'string' or not JobExists(jobName, grade) then return false end

    if IsQbx then
        local ok, result = pcall(function() return exports.qbx_core:SetJob(target, jobName, grade) end)
        if ok and result ~= false then return true end
        if type(target) == 'number' then return false end
    elseif type(target) == 'number' then
        local player = Raw(target)

        return player ~= nil and player.Functions.SetJob(jobName, grade) ~= false
    end

    return type(target) == 'string' and FN_FRAMEWORK.SetJobOffline(target, jobName, grade) or false
end

FN_FRAMEWORK.RemoveJob = function(target, jobName)
    if IsQbx then
        local citizenId = type(target) == 'number' and FN_FRAMEWORK.GetIdentifier(target) or target
        local ok, result = pcall(function() return exports.qbx_core:RemovePlayerFromJob(citizenId, jobName) end)

        return ok and result ~= false
    end

    if type(target) == 'number' then
        local job = FN_FRAMEWORK.GetJob(target)
        if not job or job.name ~= jobName then return false end
    elseif not MySQL.scalar.await([[SELECT 1 FROM players WHERE citizenid = ? AND JSON_UNQUOTE(JSON_EXTRACT(job, '$.name')) = ?]], { target, jobName }) then
        return false
    end

    return FN_FRAMEWORK.SetJob(target, 'unemployed', 0)
end

local function Percent(value)
    value = tonumber(value)

    return value and math.max(0, math.min(100, math.floor(value + 0.5))) or nil
end

FN_FRAMEWORK.GetNeeds = function(playerId)
    local player = Raw(playerId)
    local metadata = player and player.PlayerData.metadata or {}

    return {
        hunger = Percent(metadata.hunger),
        thirst = Percent(metadata.thirst),
        stress = Percent(metadata.stress),
    }
end

FN_FRAMEWORK.AddNeeds = function(playerId, needs)
    local player = Raw(playerId)
    if not player or type(needs) ~= 'table' then return false end

    local metadata = player.PlayerData.metadata or {}
    for name, value in pairs(needs) do
        value = tonumber(value)
        if value and value ~= 0 and (name == 'hunger' or name == 'thirst' or name == 'stress') and metadata[name] ~= nil then
            player.Functions.SetMetaData(name, math.max(0, math.min(100, (tonumber(metadata[name]) or 0) + value)))
        end
    end

    metadata = player.PlayerData.metadata or {}
    if needs.hunger or needs.thirst then TriggerClientEvent('hud:client:UpdateNeeds', playerId, metadata.hunger, metadata.thirst) end
    if needs.stress then TriggerClientEvent('hud:client:UpdateStress', playerId, metadata.stress) end

    return true
end

FN_FRAMEWORK.GetPlayTime = function()
    return false
end

local function SetCharInfo(player, values)
    local charInfo = player.PlayerData.charinfo
    if type(charInfo) ~= 'table' then return false end

    for key, value in pairs(values) do
        charInfo[key] = value
    end

    local functions = player.Functions or {}
    if functions.SetCharInfo then
        for key, value in pairs(values) do
            functions.SetCharInfo(key, value)
        end
    elseif functions.SetPlayerData then
        functions.SetPlayerData('charinfo', charInfo)
    else
        return false
    end

    if functions.Save then pcall(functions.Save) end

    return true
end

FN_FRAMEWORK.GetPhoneNumber = function(playerId)
    local player = Raw(playerId)
    local charInfo = player and player.PlayerData.charinfo
    local number = type(charInfo) == 'table' and charInfo.phone

    return number and tostring(number) or false
end

FN_FRAMEWORK.SetPhoneNumber = function(playerId, number)
    local player = Raw(playerId)
    if not player or not SetCharInfo(player, { phone = number }) then return false end

    if FN_DB.HasColumn('players', 'phone_number') then
        pcall(MySQL.update.await, 'UPDATE players SET phone_number = ? WHERE citizenid = ?', { number, player.PlayerData.citizenid })
    end

    return true
end

FN_FRAMEWORK.IsPhoneNumberTaken = function(number)
    local sql = [[SELECT 1 FROM players WHERE JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.phone')) = ?]]
    local params = { tostring(number) }

    if FN_DB.HasColumn('players', 'phone_number') then
        sql = sql .. ' OR phone_number = ?'
        params[2] = tostring(number)
    end

    return MySQL.scalar.await(sql .. ' LIMIT 1', params) ~= nil
end

FN_FRAMEWORK.SetName = function(playerId, firstName, lastName)
    local player = Raw(playerId)

    return player ~= nil and SetCharInfo(player, { firstname = firstName, lastname = lastName })
end

FN_FRAMEWORK.SetCharacter = function(identifier, fields)
    if type(identifier) ~= 'string' or type(fields) ~= 'table' then return false end

    local values = {
        birthdate = type(fields.dateOfBirth) == 'string' and #fields.dateOfBirth <= 20 and fields.dateOfBirth or nil,
        gender = (fields.sex == 'm' or fields.sex == 'f') and (fields.sex == 'f' and 1 or 0) or nil,
        nationality = type(fields.nationality) == 'string' and #fields.nationality <= 50 and fields.nationality or nil,
    }
    if next(values) == nil then return false end

    local online = FN_FRAMEWORK.GetPlayerFromIdentifier(identifier)
    local player = online and Raw(online.source)
    if player then return SetCharInfo(player, values) end

    local sets, params = {}, {}
    for key, value in pairs(values) do
        sets[#sets + 1] = ("'$.%s', ?"):format(key)
        params[#params + 1] = value
    end
    params[#params + 1] = identifier

    local ok = pcall(MySQL.update.await, ('UPDATE players SET charinfo = JSON_SET(charinfo, %s) WHERE citizenid = ?'):format(table.concat(sets, ', ')), params)

    return ok and MySQL.scalar.await('SELECT 1 FROM players WHERE citizenid = ?', { identifier }) ~= nil
end

FN_FRAMEWORK.IsNameTaken = function(firstName, lastName)
    local first = "CONVERT(JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')) USING utf8mb4) COLLATE utf8mb4_unicode_ci"
    local last = "CONVERT(JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')) USING utf8mb4) COLLATE utf8mb4_unicode_ci"

    return MySQL.scalar.await(('SELECT 1 FROM players WHERE %s = ? AND %s = ? LIMIT 1'):format(first, last), { firstName, lastName }) ~= nil
end

local function Sex(gender)
    if gender == 1 or gender == '1' or gender == 'f' or gender == 'female' then return 'f' end

    return 'm'
end

FN_FRAMEWORK.GetCharacter = function(identifier)
    if type(identifier) ~= 'string' then return false end

    local row = MySQL.single.await('SELECT citizenid, charinfo, metadata FROM players WHERE citizenid = ?', { identifier })
    if not row then return false end

    local charInfo = FN_DB.Json(row.charinfo)
    local metadata = FN_DB.Json(row.metadata)
    local granted = type(metadata.licences) == 'table' and metadata.licences or type(metadata.licenses) == 'table' and metadata.licenses or {}

    local licenses = {}
    for name, value in pairs(granted) do
        if value == true then licenses[#licenses + 1] = name end
    end
    table.sort(licenses)

    return {
        identifier = row.citizenid,
        firstName = charInfo.firstname or '',
        lastName = charInfo.lastname or '',
        name = TrimName(charInfo.firstname, charInfo.lastname),
        dateOfBirth = charInfo.birthdate ~= '' and charInfo.birthdate and tostring(charInfo.birthdate) or nil,
        sex = charInfo.gender ~= nil and Sex(charInfo.gender) or nil,
        nationality = charInfo.nationality ~= '' and charInfo.nationality or nil,
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

FN_FRAMEWORK.GetCharactersByIds = function(identifiers)
    local list = IdList(identifiers)
    if #list == 0 then return {} end

    local result = {}
    for _, row in ipairs(MySQL.query.await(('SELECT citizenid, charinfo FROM players WHERE citizenid IN (%s)'):format(FN_DB.Placeholders(#list)), list) or {}) do
        local charInfo = FN_DB.Json(row.charinfo)
        result[#result + 1] = { identifier = row.citizenid, firstName = charInfo.firstname or '', lastName = charInfo.lastname or '', name = TrimName(charInfo.firstname, charInfo.lastname), dateOfBirth = charInfo.birthdate and tostring(charInfo.birthdate) or nil }
    end

    return result
end

FN_FRAMEWORK.GetCharacters = function(license)
    local hash = type(license) == 'string' and (license:match('^license2?:(%w+)$') or license:match('^%w+$'))
    if not hash then return {} end

    local characters = {}
    for _, row in ipairs(MySQL.query.await('SELECT citizenid, charinfo FROM players WHERE license IN (?, ?)', { 'license:' .. hash, 'license2:' .. hash }) or {}) do
        local charInfo = FN_DB.Json(row.charinfo)
        local name = TrimName(charInfo.firstname, charInfo.lastname)
        characters[#characters + 1] = { identifier = row.citizenid, name = name ~= '' and name or row.citizenid }
    end
    table.sort(characters, function(a, b) return a.identifier < b.identifier end)

    return characters
end

FN_FRAMEWORK.AddCharacterSlots = function()
    return false
end

FN_FRAMEWORK.GetName = function(playerId)
    local player = Raw(playerId)
    local charInfo = player and player.PlayerData.charinfo
    if type(charInfo) ~= 'table' then return false end

    return TrimName(charInfo.firstname, charInfo.lastname)
end

FN_FRAMEWORK.GetVehicleCatalog = function()
    local vehicles
    if IsQbx then
        local ok, result = pcall(function() return exports.qbx_core:GetVehiclesByName() end)
        vehicles = ok and result
    else
        vehicles = FN_FRAMEWORK.obj and FN_FRAMEWORK.obj.Shared and FN_FRAMEWORK.obj.Shared.Vehicles
    end

    local catalog = {}
    for name, vehicle in pairs(type(vehicles) == 'table' and vehicles or {}) do
        local model = (type(vehicle.model) == 'string' and vehicle.model or name):lower()
        catalog[model] = { model = model, label = vehicle.name or model, brand = vehicle.brand, price = math.floor(tonumber(vehicle.price) or 0), category = vehicle.category }
    end

    return catalog
end

local Features = {
    money = function() return true end,
    phoneNumber = function() return true end,
    characterSlots = function() return false end,
    needs = function() return true end,
    playTime = function() return false end,
    gangs = function() return true end,
    vehicles = function() return FN_VEHICLES.Available() end,
}

FN_FRAMEWORK.Supports = function(feature)
    local check = Features[feature]

    return check and check() == true or false
end
