if not FN_FRAMEWORK then return end

local CharIdTables = {
    esx = { table = 'users', key = 'identifier' },
    qb = { table = 'players', key = 'citizenid' },
    qbx = { table = 'players', key = 'citizenid' },
}

local charIdSource

FN_CHARID = {}

local function Reject(setting, reason)
    print(('^3setr fn_bridge:charid is^7 %s ^3but %s^7 - character ids fall back to the identifier.'):format(setting, reason))

    return false
end

local function ResolveSource()
    local framework = FN_FRAMEWORK.GetFrameworkName()
    local target = CharIdTables[framework]
    local setting = Config.FrameworkUniqueId
    if not target or setting == nil then return false end
    if type(setting) ~= 'string' then return Reject(tostring(setting), 'it is not a string') end

    local column, path = setting:match('^([%w_]+)%.([%w_%.]+)$')
    if not column then column = setting:match('^[%w_]+$') end
    if not column or (path and (path:find('%.%.') or path:find('^%.') or path:find('%.$'))) then
        return Reject(setting, 'it is neither a column nor column.jsonKey')
    end
    if column == target.key and not path then return false end

    local ok, found = pcall(MySQL.single.await, ('SHOW COLUMNS FROM %s LIKE ?'):format(target.table), { column })
    if not ok or not found then return Reject(setting, ('%s has no %s column'):format(target.table, column)) end

    local value = path
        and ("NULLIF(NULLIF(CAST(JSON_UNQUOTE(JSON_EXTRACT(`%s`, '$.%s')) AS CHAR), ''), 'null')"):format(column, path)
        or ("NULLIF(CAST(`%s` AS CHAR), '')"):format(column)

    local counted, counts = pcall(MySQL.single.await, ('SELECT COUNT(%s) AS total, COUNT(DISTINCT %s) AS uniq FROM %s'):format(value, value, target.table))
    if not counted or not counts then return Reject(setting, ('%s could not be read as a character id'):format(setting)) end

    local shared = (tonumber(counts.total) or 0) - (tonumber(counts.uniq) or 0)
    if shared ~= 0 then return Reject(setting, ('%d rows in %s repeat a value, so it is not unique'):format(shared, target.table)) end

    return { table = target.table, key = target.key, value = value }
end

FN_CHARID.Source = function()
    if charIdSource == nil then charIdSource = ResolveSource() end

    return charIdSource
end

FN_FRAMEWORK.GetCharId = function(identifier)
    if type(identifier) ~= 'string' or identifier == '' then return identifier end

    local source = FN_CHARID.Source()
    if not source then return identifier end

    local ok, row = pcall(MySQL.single.await, ('SELECT %s AS charId FROM %s WHERE %s = ?'):format(source.value, source.table, source.key), { identifier })

    return ok and row and row.charId or identifier
end

local function PublishCharId(playerId)
    local player = FN_FRAMEWORK.GetPlayerFromId(playerId)
    if not player or not player.identifier then return end

    Player(playerId).state:set('fn_charId', FN_FRAMEWORK.GetCharId(player.identifier), true)
end

AddEventHandler('fn_bridge/server/playerLoaded', PublishCharId)

MySQL.ready(function()
    FN_CHARID.Source()

    for _, playerId in ipairs(FN_FRAMEWORK.GetPlayers() or {}) do
        PublishCharId(playerId)
    end
end)
