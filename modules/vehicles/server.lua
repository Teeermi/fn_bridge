FN_VEHICLES = {}

local Schemas = {
    esx = {
        table = 'owned_vehicles',
        owner = 'owner',
        props = 'vehicle',
        parked = 'stored',
        garage = 'parking',
        pound = 'pound',
        kind = 'type',
        defaults = { { 'type', 'car' }, { 'stored', 1 } },
    },
    qb = {
        table = 'player_vehicles',
        owner = 'citizenid',
        license = 'license',
        props = 'mods',
        modelName = 'vehicle',
        hash = 'hash',
        parked = 'state',
        impoundValue = 2,
        garage = 'garage',
        depot = 'depotprice',
        fuel = 'fuel',
        engine = 'engine',
        body = 'body',
        required = { 'license', 'citizenid', 'vehicle', 'hash', 'mods', 'plate' },
        defaults = {
            { 'garage', 'pillboxgarage' },
            { 'state', 1 },
            { 'fuel', 100 },
            { 'engine', 1000.0 },
            { 'body', 1000.0 },
            { 'depotprice', 0 },
            { 'balance', 0 },
            { 'paymentamount', 0 },
            { 'paymentsleft', 0 },
            { 'financetime', 0 },
            { 'drivingdistance', 0 },
        },
        plateKeyed = {
            { 'trunkitems', 'plate', '' },
            { 'gloveboxitems', 'plate', '' },
            { 'inventories', 'identifier', 'trunk-' },
            { 'inventories', 'identifier', 'glovebox-' },
        },
    },
    ox = {
        table = 'vehicles',
        owner = 'owner',
        numericOwner = true,
        modelName = 'model',
        data = 'data',
        parked = 'stored',
    },
    standalone = {
        table = 'fn_vehicles',
        owner = 'owner',
        modelName = 'model',
        props = 'props',
    },
}

Schemas.qbx = Schemas.qb

local Warned = {}

for _, resource in ipairs({ 'qb-garages', 'qbx_garages', 'esx_garage', 'jg-advancedgarages', 'cd_garage' }) do FN_KNOWN[resource] = true end

local function WarnOnce(key, message, ...)
    if Warned[key] then return end

    Warned[key] = true
    print(('^3[fn_bridge] '..message..'^7'):format(...))
end

local function Framework()
    return FN_FRAMEWORK and FN_FRAMEWORK.GetFrameworkName() or 'standalone'
end

local function Schema()
    return Schemas[Framework()]
end

local function GarageConfig()
    local garage = FN_BRIDGE.Setting('garage')
    if type(garage) ~= 'table' then garage = {} end
    local framework = Framework()

    return type(garage[framework]) == 'table' and garage[framework]
        or framework == 'qbx' and type(garage.qb) == 'table' and garage.qb
        or {}
end

local Reserved = { parkedColumn = true, garageColumn = true, parkedOut = true }

local function Trim(plate)
    return type(plate) == 'string' and plate:match('^%s*(.-)%s*$') or ''
end

local function Percent(value, max)
    value = tonumber(value)
    if not value then return nil end

    return math.floor(math.max(0, math.min(1, value / max)) * 100 + 0.5)
end

local function Columns(schema)
    return FN_DB.Columns(schema.table)
end

local function Parked(schema, columns)
    local configured = FN_DB.Identifier(GarageConfig().parkedColumn)
    if configured then return columns[configured] and configured or nil end
    if columns.in_garage then return 'in_garage' end

    return schema.parked and columns[schema.parked] and schema.parked or nil
end

local function StoredValue(column)
    local configured = GarageConfig()[column]
    if configured ~= nil then return configured end

    return 1
end

local function IsStoredValue(column, value)
    local want = StoredValue(column)
    if want == 1 then return FN_DB.Bool(value) end

    return tostring(value) == tostring(want)
end

local function OwnerList(owner)
    local list = type(owner) == 'table' and owner or { owner }
    local out = {}
    for _, value in ipairs(list) do
        if value ~= nil and value ~= '' then out[#out + 1] = tostring(value) end
    end

    return out
end

local function OwnerClause(schema, owner, params)
    local owners, licenses = {}, {}

    for _, value in ipairs(OwnerList(owner)) do
        if schema.license and value:find('^license2?:') then
            licenses[#licenses + 1] = value
        elseif schema.numericOwner then
            if tonumber(value) then owners[#owners + 1] = tonumber(value) end
        else
            owners[#owners + 1] = value
        end
    end

    local parts = {}
    if #owners > 0 then
        parts[#parts + 1] = ('%s IN (%s)'):format(schema.owner, FN_DB.Placeholders(#owners))
        for _, value in ipairs(owners) do params[#params + 1] = value end
    end
    if #licenses > 0 then
        parts[#parts + 1] = ('%s IN (%s)'):format(schema.license, FN_DB.Placeholders(#licenses))
        for _, value in ipairs(licenses) do params[#params + 1] = value end
    end

    if #parts == 0 then return nil end

    return '(' .. table.concat(parts, ' OR ') .. ')'
end

local function ReadProps(schema, row)
    if schema.data then return FN_DB.Json(FN_DB.Json(row[schema.data]).properties) end
    if schema.props then return FN_DB.Json(row[schema.props]) end

    return {}
end

local function ReadState(schema, columns, row)
    if columns.in_garage then
        if FN_DB.Bool(row.impound) or (tonumber(row.impound) or 0) > 0 then return 'impound', row.garage_id end

        return FN_DB.Bool(row.in_garage) and 'garage' or 'out', row.garage_id
    end

    if schema.data then return row[schema.parked] == nil and 'out' or 'garage', row[schema.parked] end

    local parked = Parked(schema, columns)
    if schema.pound and type(row[schema.pound]) == 'string' and row[schema.pound] ~= '' then return 'impound', row[schema.pound] end
    if not parked then return 'garage' end
    if schema.impoundValue and tonumber(row[parked]) == schema.impoundValue then return 'impound' end

    return IsStoredValue(parked, row[parked]) and 'garage' or 'out'
end

local function BuildVehicle(schema, columns, row)
    local props = ReadProps(schema, row)
    local modelName = schema.modelName and type(row[schema.modelName]) == 'string' and row[schema.modelName]:lower() or nil
    local model = tonumber(schema.hash and row[schema.hash]) or tonumber(props.model) or (modelName and joaat(modelName)) or nil
    local state, garage = ReadState(schema, columns, row)

    return {
        owner = row[schema.owner] ~= nil and tostring(row[schema.owner]) or nil,
        plate = Trim(row.plate),
        model = model,
        modelName = modelName,
        props = props,
        vehicle = props,
        state = state,
        stored = state == 'garage',
        garage = type(garage) == 'string' and garage or (schema.garage and row[schema.garage]) or '',
        kind = schema.kind and row[schema.kind] or nil,
        fuel = Percent(schema.fuel and row[schema.fuel] or props.fuelLevel, 100),
        engine = Percent(schema.engine and row[schema.engine] or props.engineHealth, 1000),
        body = Percent(schema.body and row[schema.body] or props.bodyHealth, 1000),
    }
end

local function EnsureStandalone()
    if Framework() ~= 'standalone' or FN_DB.HasTable('fn_vehicles') then return end

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS fn_vehicles (
            id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            owner      VARCHAR(64) NOT NULL,
            model      VARCHAR(64) NOT NULL,
            plate      VARCHAR(12) NOT NULL UNIQUE,
            props      LONGTEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_op_vehicles_owner (owner)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    if FN_DB.HasTable('cs_vehicles') then
        pcall(MySQL.query.await, 'INSERT IGNORE INTO fn_vehicles (owner, model, plate, props, created_at) SELECT owner, model, plate, props, created_at FROM cs_vehicles')
    end

    FN_DB.ClearCache()
end

local function Ready()
    local schema = Schema()
    if not schema then return nil, nil, 'unsupported' end

    EnsureStandalone()
    if not FN_DB.HasTable(schema.table) then return nil, nil, 'table_missing' end

    return schema, Columns(schema)
end

local function OnlyStored(sql, params, schema, columns)
    local parked = Parked(schema, columns)
    if not parked then return sql end
    if schema.data then return sql .. (' AND %s IS NOT NULL'):format(parked) end

    params[#params + 1] = StoredValue(parked)

    return sql .. (' AND %s = ?'):format(parked)
end

FN_VEHICLES.Available = function()
    if Framework() == 'vrp' then return FN_DB.HasTable('vrp_user_vehicles'), 'vrp_user_vehicles' end

    local schema, columns, reason = Ready()
    if not schema then return false, reason end

    local missing = {}
    for _, name in ipairs(schema.required or { schema.owner, 'plate' }) do
        if not columns[name] then missing[#missing + 1] = name end
    end
    if #missing > 0 then return false, 'missing columns: ' .. table.concat(missing, ', ') end

    local filled = {}
    for _, name in ipairs(schema.required or {}) do filled[name] = true end
    for _, entry in ipairs(schema.defaults or {}) do filled[entry[1]] = true end

    local required = {}
    if schema.required then
        for name, info in pairs(FN_DB.Schema(schema.table)) do
            if not filled[name] and not info.nullable and not info.hasDefault and not info.generated and name ~= 'id' then
                required[#required + 1] = name
            end
        end
    end
    table.sort(required)
    if #required > 0 then return true, 'NOT NULL columns without a default: ' .. table.concat(required, ', ') end

    return true
end

FN_VEHICLES.GarageColumn = function()
    local schema, columns = Ready()
    if not schema or not schema.garage then return false end

    local column = FN_DB.Identifier(GarageConfig().garageColumn) or schema.garage

    return columns[column] and column or false
end

local function VrpRows(where, value)
    local ok, rows = pcall(MySQL.query.await, ([[
        SELECT v.user_id, v.vehicle, v.detido, v.fuel, v.engine, v.body, i.registration
        FROM vrp_user_vehicles v LEFT JOIN vrp_user_identities i ON i.user_id = v.user_id
        WHERE %s = ? LIMIT 100]]):format(where), { value })

    local out = {}
    for _, row in ipairs(ok and rows or {}) do
        local modelName = type(row.vehicle) == 'string' and row.vehicle:lower() or nil
        out[#out + 1] = {
            owner = tostring(row.user_id),
            plate = Trim(row.registration),
            model = modelName and joaat(modelName) or nil,
            modelName = modelName,
            props = {},
            vehicle = {},
            state = tonumber(row.detido) == 1 and 'impound' or 'garage',
            stored = tonumber(row.detido) ~= 1,
            garage = '',
            fuel = Percent(row.fuel, 100),
            engine = Percent(row.engine, 1000),
            body = Percent(row.body, 1000),
        }
    end

    return out
end

FN_VEHICLES.Get = function(plate)
    plate = Trim(plate)
    if plate == '' then return false end
    if Framework() == 'vrp' then return VrpRows('i.registration', plate)[1] or false end

    local schema, columns = Ready()
    if not schema then return false end

    local ok, row = pcall(MySQL.single.await, ('SELECT * FROM %s WHERE plate = ? OR TRIM(plate) = ? LIMIT 1'):format(schema.table), { plate, plate })
    if not ok or not row then return false end

    return BuildVehicle(schema, columns, row)
end

FN_VEHICLES.List = function(owner)
    if Framework() == 'vrp' then return VrpRows('v.user_id', tonumber(OwnerList(owner)[1])) end

    local schema, columns = Ready()
    if not schema then return {} end

    local params = {}
    local clause = OwnerClause(schema, owner, params)
    if not clause then return {} end

    local ok, rows = pcall(MySQL.query.await, ('SELECT * FROM %s WHERE %s LIMIT 200'):format(schema.table, clause), params)

    local out = {}
    for _, row in ipairs(ok and rows or {}) do
        out[#out + 1] = BuildVehicle(schema, columns, row)
    end

    return out
end

FN_VEHICLES.IsPlateTaken = function(plate)
    plate = Trim(plate)
    if plate == '' then return true end
    if Framework() == 'vrp' then
        local ok, found = pcall(MySQL.scalar.await, 'SELECT 1 FROM vrp_user_identities WHERE registration = ? LIMIT 1', { plate })
        return ok and found ~= nil
    end

    local schema = Ready()
    if not schema then return false end

    local ok, found = pcall(MySQL.scalar.await, ('SELECT 1 FROM %s WHERE plate = ? OR TRIM(plate) = ? LIMIT 1'):format(schema.table), { plate, plate })

    return ok and found ~= nil
end

FN_VEHICLES.IsStored = function(owner, plate)
    for _, vehicle in ipairs(FN_VEHICLES.List(owner)) do
        if vehicle.plate == Trim(plate) then return vehicle.stored end
    end

    return false
end

FN_VEHICLES.GetProps = function(owner, plate)
    for _, vehicle in ipairs(FN_VEHICLES.List(owner)) do
        if vehicle.plate == Trim(plate) then return vehicle.props end
    end

    return {}
end

local function LicenseOf(citizenId)
    local ok, license = pcall(MySQL.scalar.await, 'SELECT license FROM players WHERE citizenid = ?', { citizenId })

    return ok and license or nil
end

local function OxAdd(owner, model, plate, props, options)
    if not tonumber(owner) then return false, 'no_owner' end

    local ok, result = pcall(function()
        return exports.ox_core:CreateVehicle({
            owner = tonumber(owner),
            model = model,
            plate = plate,
            stored = options.garage or 'impound',
            properties = props,
        })
    end)

    if not ok then return false, tostring(result) end

    return true
end

FN_VEHICLES.Add = function(owner, model, plate, props, options)
    options = type(options) == 'table' and options or {}
    plate = Trim(plate)
    if type(model) ~= 'string' or plate == '' then return false, 'invalid' end
    if Framework() == 'ox' then return OxAdd(OwnerList(owner)[1], model, plate, props, options) end

    local schema, columns, reason = Ready()
    if not schema then return false, reason end

    owner = OwnerList(owner)[1]
    if not owner then return false, 'no_owner' end

    local vehicleProps = type(props) == 'table' and json.decode(json.encode(props)) or {}
    vehicleProps.model = vehicleProps.model or joaat(model)
    vehicleProps.plate = plate

    local values = {
        [schema.owner] = owner,
        plate = plate,
    }
    if schema.props then values[schema.props] = json.encode(vehicleProps) end
    if schema.modelName then values[schema.modelName] = model end
    if schema.hash then values[schema.hash] = joaat(model) end
    if schema.license then values[schema.license] = options.license or LicenseOf(owner) end
    if columns.vin then values.vin = options.vin or ('FN%s'):format(plate:gsub('%s', '')):sub(1, 17) end

    for _, name in ipairs(schema.required or {}) do
        if not columns[name] then
            WarnOnce('vehicles:required:' .. name, '%s has no "%s" column. This garage stores vehicles differently, adding vehicles will not work.', schema.table, name)
            return false, 'schema'
        end
        if values[name] == nil then return false, 'no_' .. name end
    end

    local config = GarageConfig()
    local filled = {}
    for name in pairs(values) do filled[name] = true end

    local garageColumn = options.garage and FN_VEHICLES.GarageColumn()
    if garageColumn then
        values[garageColumn] = options.garage
        filled[garageColumn] = true
    end

    for _, entry in ipairs(schema.defaults or {}) do
        local name = entry[1]
        if columns[name] and not filled[name] then
            local value = config[name]
            if value == nil then value = entry[2] end
            values[name] = value
            filled[name] = true
        end
    end

    local extra = {}
    for name in pairs(config) do
        if not Reserved[name] and not filled[name] then extra[#extra + 1] = name end
    end
    table.sort(extra)

    for _, name in ipairs(extra) do
        if columns[name] then
            values[name] = config[name]
            filled[name] = true
        else
            WarnOnce('vehicles:extra:' .. name, 'Config.Bridge.garage sets "%s", but %s has no such column. Ignored.', name, schema.table)
        end
    end

    local names, params = {}, {}
    for name, value in pairs(values) do
        if FN_DB.Identifier(name) then
            names[#names + 1] = name
            params[#params + 1] = value
        end
    end

    local ok, err = pcall(MySQL.insert.await, ('INSERT INTO %s (%s) VALUES (%s)'):format(schema.table, table.concat(names, ', '), FN_DB.Placeholders(#names)), params)
    if not ok then
        print(('^1[fn_bridge] adding vehicle %s (%s) failed:^7 %s'):format(plate, model, tostring(err)))
        return false, tostring(err):find('Duplicate', 1, true) and 'plate_taken' or 'failed'
    end

    return true
end

FN_VEHICLES.Remove = function(owner, plate, options)
    options = type(options) == 'table' and options or {}
    local schema, columns, reason = Ready()
    if not schema then return false, reason end

    local params = { Trim(plate) }
    local clause = OwnerClause(schema, owner, params)
    if not clause then return false, 'not_owned' end

    local ok, row = pcall(MySQL.single.await, ('SELECT * FROM %s WHERE plate = ? AND %s LIMIT 1'):format(schema.table, clause), params)
    if not ok or not row then return false, 'not_owned' end

    local vehicle = BuildVehicle(schema, columns, row)
    if not options.force and not vehicle.stored then return false, 'not_stored' end

    local sql = ('DELETE FROM %s WHERE plate = ? AND %s'):format(schema.table, clause)
    if not options.force then sql = OnlyStored(sql, params, schema, columns) end

    local done, affected = pcall(MySQL.update.await, sql, params)
    if not done then
        print(('^1[fn_bridge] removing vehicle %s failed:^7 %s'):format(tostring(plate), tostring(affected)))
        return false, 'failed'
    end
    if (affected or 0) < 1 then return false, 'not_stored' end

    vehicle.row = row

    return true, nil, vehicle
end

local function Update(owner, plate, setSql, setParams, options)
    options = type(options) == 'table' and options or {}
    local schema, columns, reason = Ready()
    if not schema then return false, reason end

    local params = {}
    for _, value in ipairs(setParams) do params[#params + 1] = value end
    params[#params + 1] = Trim(plate)

    local clause = OwnerClause(schema, owner, params)
    if not clause then return false, 'not_owned' end

    local sql = ('UPDATE %s SET %s WHERE plate = ? AND %s'):format(schema.table, setSql(schema, columns), clause)
    if options.onlyStored then sql = OnlyStored(sql, params, schema, columns) end
    if options.where then sql = sql .. ' AND ' .. options.where end

    local ok, affected = pcall(MySQL.update.await, sql, params)
    if not ok then
        print(('^1[fn_bridge] updating vehicle %s failed:^7 %s'):format(tostring(plate), tostring(affected)))
        return false, tostring(affected):find('Duplicate', 1, true) and 'plate_taken' or 'failed'
    end
    if (affected or 0) < 1 then return false, options.onlyStored and 'not_stored' or 'not_owned' end

    return true
end

FN_VEHICLES.SetOwner = function(owner, plate, newOwner, options)
    local schema = Schema()
    if not schema then return false, 'unsupported' end

    local newLicense = schema.license and LicenseOf(newOwner)
    local setParams = { schema.numericOwner and tonumber(newOwner) or newOwner }
    if newLicense then setParams[2] = newLicense end

    return Update(owner, plate, function()
        return newLicense and ('%s = ?, %s = ?'):format(schema.owner, schema.license) or ('%s = ?'):format(schema.owner)
    end, setParams, options)
end

FN_VEHICLES.TransferAll = function(fromOwner, toOwner)
    local schema = Ready()
    if not schema or fromOwner == toOwner then return 0 end

    local ok, affected = pcall(MySQL.update.await, ('UPDATE %s SET %s = ? WHERE %s = ?'):format(schema.table, schema.owner, schema.owner), { toOwner, fromOwner })

    return ok and affected or 0
end

local function JsonColumn(schema)
    return schema.props or schema.data
end

local function JsonPath(schema, key)
    return schema.data and ('$.properties.%s'):format(key) or ('$.%s'):format(key)
end

FN_VEHICLES.SetPlate = function(owner, plate, newPlate, options)
    newPlate = Trim(newPlate)
    if newPlate == '' then return false, 'invalid' end

    local schema = Schema()
    if not schema then return false, 'unsupported' end

    local column = JsonColumn(schema)
    local done, why = Update(owner, plate, function()
        if not column then return 'plate = ?' end

        return ("plate = ?, %s = IF(JSON_VALID(%s), JSON_SET(%s, '%s', ?), %s)"):format(column, column, column, JsonPath(schema, 'plate'), column)
    end, column and { newPlate, newPlate } or { newPlate }, options)

    if not done then return false, why end

    for _, keyed in ipairs(schema.plateKeyed or {}) do
        if FN_DB.HasColumn(keyed[1], keyed[2]) then
            pcall(MySQL.update.await, ('UPDATE %s SET %s = ? WHERE %s = ?'):format(keyed[1], keyed[2], keyed[2]), { keyed[3] .. newPlate, keyed[3] .. Trim(plate) })
        end
    end

    return true
end

FN_VEHICLES.SetProps = function(owner, plate, props, options)
    local schema = Schema()
    local column = schema and JsonColumn(schema)
    if not column then return false, 'unsupported' end

    local paths, setParams = {}, {}
    for key, value in pairs(type(props) == 'table' and props or {}) do
        if type(key) == 'string' and key:match('^[%w_]+$') then
            local plain = type(value) == 'number' or type(value) == 'string'
            paths[#paths + 1] = ("'%s', %s"):format(JsonPath(schema, key), plain and '?' or "JSON_EXTRACT(?, '$')")
            setParams[#setParams + 1] = plain and value or json.encode(value)
        end
    end
    if #paths == 0 then return false, 'invalid' end

    options = { onlyStored = type(options) == 'table' and options.onlyStored or nil }
    options.where = ("JSON_VALID(%s) AND JSON_TYPE(%s) = 'OBJECT'"):format(column, column)

    return Update(owner, plate, function()
        return ('%s = JSON_SET(%s, %s)'):format(column, column, table.concat(paths, ', '))
    end, setParams, options)
end

FN_VEHICLES.SetState = function(owner, plate, state, options)
    if state ~= 'out' and state ~= 'garage' then return false, 'invalid' end

    local schema, columns, reason = Ready()
    if not schema then return false, reason end

    local garage = type(options) == 'table' and options.garage or nil
    local sets, setParams = {}, {}
    local parked = Parked(schema, columns)

    if columns.in_garage then
        sets[#sets + 1] = 'in_garage = ?'
        setParams[#setParams + 1] = state == 'garage' and 1 or 0
        if state == 'garage' and columns.impound then sets[#sets + 1] = 'impound = 0' end
    end

    if schema.data then
        if state == 'garage' then
            sets[#sets + 1] = ('%s = ?'):format(schema.parked)
            setParams[#setParams + 1] = garage or 'impound'
        else
            sets[#sets + 1] = ('%s = NULL'):format(schema.parked)
        end
    else
        local seen = {}
        for _, column in ipairs({ schema.parked, parked }) do
            if column and column ~= 'in_garage' and columns[column] and not seen[column] then
                seen[column] = true
                sets[#sets + 1] = ('%s = ?'):format(column)
                setParams[#setParams + 1] = state == 'garage' and StoredValue(column) or column == parked and GarageConfig().parkedOut or 0
            end
        end
        if state == 'garage' and schema.pound and columns[schema.pound] then sets[#sets + 1] = ('%s = NULL'):format(schema.pound) end
        if state == 'garage' and schema.depot and columns[schema.depot] then sets[#sets + 1] = ('%s = 0'):format(schema.depot) end
    end

    if #sets == 0 then return false, 'unsupported' end

    return Update(owner, plate, function() return table.concat(sets, ', ') end, setParams)
end

local function Despawn(plate)
    for _, vehicle in ipairs(GetAllVehicles()) do
        if Trim(GetVehicleNumberPlateText(vehicle)) == plate then DeleteEntity(vehicle) end
    end
end

FN_VEHICLES.Impound = function(plate, options)
    plate, options = Trim(plate), type(options) == 'table' and options or {}
    local vehicle = FN_VEHICLES.Get(plate)
    if not vehicle then return false, 'not_owned' end

    local hook = FN_BRIDGE.Setting('impound')
    if FN_BRIDGE.Callable(hook) then
        local ok, done, why = pcall(hook, plate, options, vehicle)
        if not ok or not done then return false, ok and why or 'failed' end
        Despawn(plate)
        return true
    end

    local schema, columns, reason = Ready()
    if not schema then return false, reason end

    local fee = math.max(0, math.floor(tonumber(options.fee) or 0))
    local depot = type(options.depot) == 'string' and options.depot:sub(1, 50) or nil
    local sets, params = {}, {}
    local function Set(column, value)
        sets[#sets + 1] = ('%s = ?'):format(column)
        params[#params + 1] = value
    end

    if columns.in_garage then
        Set('in_garage', 0)
        if columns.impound then Set('impound', 1) end
    end
    if schema.data then
        Set(schema.parked, depot or 'impound')
    elseif schema.impoundValue and columns[schema.parked] then
        Set(schema.parked, schema.impoundValue)
        if columns[schema.depot] then Set(schema.depot, fee) end
        if depot and columns[schema.garage] then Set(schema.garage, depot) end
    elseif schema.pound and columns[schema.pound] then
        Set(schema.parked, 0)
        Set(schema.pound, depot or 'los_santos')
    end
    if #sets == 0 then return false, 'unsupported' end

    params[#params + 1] = vehicle.plate
    local ok, affected = pcall(MySQL.update.await, ('UPDATE %s SET %s WHERE plate = ?'):format(schema.table, table.concat(sets, ', ')), params)
    if not ok or (affected or 0) < 1 then return false, 'failed' end

    Despawn(plate)

    return true
end

FN_VEHICLES.JobColumn = function()
    local schema, columns = Ready()

    return schema and Framework() == 'esx' and columns.job and 'job' or false
end

FN_VEHICLES.ListJob = function(jobName)
    local column = type(jobName) == 'string' and FN_VEHICLES.JobColumn()
    if not column then return {} end

    local schema, columns = Ready()
    local out = {}
    for _, row in ipairs(MySQL.query.await(('SELECT * FROM %s WHERE %s = ? LIMIT 500'):format(schema.table, column), { jobName }) or {}) do
        out[#out + 1] = BuildVehicle(schema, columns, row)
    end

    return out
end

FN_VEHICLES.SetJob = function(plate, jobName)
    local column = FN_VEHICLES.JobColumn()
    if not column or (jobName ~= false and type(jobName) ~= 'string') then return false end

    local schema = Ready()
    local ok, affected = pcall(MySQL.update.await, ('UPDATE %s SET %s = NULLIF(?, \'\') WHERE plate = ?'):format(schema.table, column), { jobName or '', Trim(plate) })

    return ok and (affected or 0) > 0
end

for _, key in ipairs({ 'SetOwner', 'SetPlate', 'SetProps', 'SetState', 'Impound' }) do
    FN_BRIDGE.SupportedWhen('VEHICLES', key, function()
        local schema = Schema()

        return schema ~= nil and (key ~= 'SetProps' or JsonColumn(schema) ~= nil)
    end)
end
