local SchemaCache = {}

FN_DB = {}

FN_DB.Schema = function(tableName)
    if SchemaCache[tableName] then return SchemaCache[tableName] end

    local ok, rows = pcall(MySQL.query.await, [[
        SELECT COLUMN_NAME AS name, IS_NULLABLE AS nullable, COLUMN_DEFAULT AS dflt, EXTRA AS extra, DATA_TYPE AS dtype
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?
    ]], { tableName })

    local schema = {}
    for _, row in ipairs(ok and rows or {}) do
        schema[row.name] = {
            nullable = row.nullable == 'YES',
            hasDefault = row.dflt ~= nil,
            generated = type(row.extra) == 'string' and row.extra ~= '',
            numeric = type(row.dtype) == 'string' and (row.dtype:find('int') or row.dtype == 'decimal' or row.dtype == 'float' or row.dtype == 'double') ~= nil,
            date = type(row.dtype) == 'string' and (row.dtype:find('date') or row.dtype:find('time')) ~= nil,
        }
    end

    if next(schema) then SchemaCache[tableName] = schema end

    return schema
end

FN_DB.Columns = function(tableName)
    local columns = {}
    for name in pairs(FN_DB.Schema(tableName)) do
        columns[name] = true
    end

    return columns
end

FN_DB.HasTable = function(tableName)
    return next(FN_DB.Schema(tableName)) ~= nil
end

FN_DB.HasColumn = function(tableName, column)
    return FN_DB.Schema(tableName)[column] ~= nil
end

FN_DB.ClearCache = function()
    SchemaCache = {}
end

FN_DB.Bool = function(value)
    return value == true or value == 1 or value == '1'
end

FN_DB.Json = function(value)
    if type(value) == 'table' then return value end
    if type(value) ~= 'string' or value == '' then return {} end

    local ok, decoded = pcall(json.decode, value)

    return ok and type(decoded) == 'table' and decoded or {}
end

FN_DB.Placeholders = function(count)
    return string.rep('?', count, ', ')
end

FN_DB.Identifier = function(name)
    return type(name) == 'string' and name:match('^[%a_][%w_]*$') and name or nil
end

FN_DB.InsertRow = function(tableName, values)
    local names, params = {}, {}

    for name, value in pairs(values) do
        if FN_DB.HasColumn(tableName, name) then
            names[#names + 1] = name
            params[#params + 1] = value
        end
    end

    for name, info in pairs(FN_DB.Schema(tableName)) do
        if values[name] == nil and not info.nullable and not info.hasDefault and not info.generated and name ~= 'id' then
            names[#names + 1] = name
            params[#params + 1] = info.numeric and 0 or info.date and '2000-01-01' or '{}'
        end
    end

    return pcall(MySQL.insert.await, ('INSERT IGNORE INTO %s (%s) VALUES (%s)'):format(tableName, table.concat(names, ', '), FN_DB.Placeholders(#names)), params)
end
