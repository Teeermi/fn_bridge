FN_LOG = {
    MaxString = 256,
    MaxKeys = 20,
    MaxQueue = 500,
    MaxRows = 5000,
    BatchRows = 100,
    FlushMs = 5000,
    QueryMs = 15000,
    PaceMs = 1000,
}

local Channels = { economy = 3066993, jobs = 3447003, casino = 15844367, admin = 10181046, anticheat = 15158332 }
local Warned, Queues, Gone = {}, {}, {}
local TableReady, TableMissing, Flushing, CheckAt, Backoff, Failed = false, false, false, 0, FN_LOG.FlushMs, nil
local Lost = { 'ECONNREFUSED', 'ECONNRESET', 'ETIMEDOUT', 'EPIPE', 'ENOTFOUND', 'EHOSTUNREACH', 'PROTOCOL_CONNECTION_LOST', 'PROTOCOL_SEQUENCE_TIMEOUT', 'closed state', 'Connection lost', 'Too many connections', 'ER_CON_COUNT_ERROR', 'ER_SERVER_SHUTDOWN', 'server has gone away', 'Lost connection' }

FN_LOG.Channels = Channels
FN_LOG.Rows = {}

local function Warn(key, message)
    if Warned[key] then return end
    Warned[key] = true
    print(('^3%s^7'):format(message))
end

local function Reject(resource, reason)
    Warn(resource .. '|' .. reason, ('LOG from %s ignored: %s'):format(resource, reason))
end

local function Url(url, name)
    if type(url) ~= 'string' or url == '' then return nil end
    if url:match('^https?://%S+$') then return url end

    Warn('url|' .. name, ('LOG %s is not an http(s) URL, those logs are not sent to Discord'):format(name))
end

FN_LOG.Webhook = function(channel)
    local name = 'fn_bridge:webhook_' .. tostring(channel)

    return Url(GetConvar(name, ''), name)
end

FN_LOG.Cut = function(text, bytes)
    text = tostring(text):sub(1, bytes + 3)
    local parts, from = {}, 1
    while true do
        local valid, bad = utf8.len(text, from)
        if valid then break end
        parts[#parts + 1] = text:sub(from, bad - 1) .. '?'
        from = bad + 1
    end
    parts[#parts + 1] = text:sub(from)
    text = table.concat(parts)
    if #text > bytes then text = text:sub(1, utf8.offset(text, 0, bytes + 1) - 1) end

    return text
end

FN_LOG.DbEnabled = function()
    local value = GetConvar('fn_bridge:logs_db', 'true'):lower()

    return value ~= 'false' and value ~= '0' and value ~= 'off' and value ~= 'no'
end

local function CleanValue(value)
    local kind = type(value)
    if kind == 'string' then return FN_LOG.Cut(value, FN_LOG.MaxString) end
    if kind == 'boolean' then return value end
    if kind == 'number' and value == value and value ~= math.huge and value ~= -math.huge then return value end

    return nil
end

FN_LOG.Clean = function(resource, channel, event, playerId, data)
    resource = type(resource) == 'string' and resource or 'unknown'
    if type(channel) ~= 'string' or not Channels[channel] then return Reject(resource, 'channel must be economy, jobs, casino, admin or anticheat') end
    if type(event) ~= 'string' or #event > 64 or not event:match('^[%w_%-]+[%w_%.%-]*$') then return Reject(resource, 'event must be a short name like shop.buy') end
    if playerId ~= nil and (type(playerId) ~= 'number' or playerId < 0 or playerId % 1 ~= 0) then return Reject(resource, 'playerId must be a server id or nil') end
    if data ~= nil and type(data) ~= 'table' then return Reject(resource, 'data must be a table or nil') end

    local clean, count = {}, 0
    for key, value in pairs(data or {}) do
        count = count + 1
        if count > FN_LOG.MaxKeys then return Reject(resource, ('data has more than %d keys'):format(FN_LOG.MaxKeys)) end
        if type(key) ~= 'string' or key == '' or #key > 32 then return Reject(resource, 'data keys must be strings up to 32 characters') end

        local cleaned = CleanValue(value)
        if cleaned == nil then return Reject(resource, 'data values must be strings, finite numbers or booleans') end
        clean[key] = cleaned
    end

    return { resource = resource, channel = channel, event = event, playerId = playerId, data = clean, at = GetGameTimer(), time = os.time() }
end

FN_LOG.Identity = function(playerId)
    if not playerId or playerId == 0 or not GetPlayerName(playerId) then return {} end

    local identity = {
        serverId = playerId,
        license = GetPlayerIdentifierByType(tostring(playerId), 'license'),
        charId = FN_CHARID and FN_CHARID.Get and FN_CHARID.Get(playerId),
        name = GetPlayerName(playerId),
    }
    local framework = FN_BRIDGE.FRAMEWORK
    if framework and framework.GetName then
        local ok, name = pcall(framework.GetName, playerId)
        if ok and type(name) == 'string' and name ~= '' then identity.name = name end
    end
    if identity.charId ~= nil then identity.charId = FN_LOG.Cut(identity.charId, 64) end
    identity.name = FN_LOG.Cut(identity.name, 128)
    local ped = GetPlayerPed(playerId)
    if ped and ped ~= 0 then identity.coords = GetEntityCoords(ped) end

    return identity
end

FN_LOG.Remember = function(playerId)
    local now = os.time()
    for id, gone in pairs(Gone) do
        if now - gone.at > 600 then Gone[id] = nil end
    end
    local identity = FN_LOG.Identity(playerId)
    if identity.serverId then Gone[playerId] = { at = now, identity = identity } end
end

FN_LOG.Gone = function(playerId)
    return Gone[playerId] and Gone[playerId].identity
end

local function Field(name, value, budget)
    value = FN_LOG.Cut(value, math.max(1, math.min(1024, budget)))
    if value == '' then value = '-' end
    name = FN_LOG.Cut(name, 256)

    return { name = name, value = value, inline = #value <= 40 }, #name + #value
end

FN_LOG.Embed = function(entry)
    local fields, budget = {}, 5000
    local function Add(name, value)
        if #fields >= 25 or budget <= 0 or value == nil then return end
        local field, size = Field(name, value, budget)
        fields[#fields + 1] = field
        budget = budget - size
    end

    if entry.serverId then Add('Player', ('[%d] %s'):format(entry.serverId, entry.name or '?')) end
    Add('Character', entry.charId)
    Add('License', entry.license)
    if entry.coords then Add('Position', ('%.2f, %.2f, %.2f'):format(entry.coords.x, entry.coords.y, entry.coords.z)) end

    local keys = {}
    for key in pairs(entry.data or {}) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do Add(key, entry.data[key]) end

    return {
        title = entry.event,
        color = Channels[entry.channel],
        fields = fields,
        footer = { text = ('%s | %s'):format(entry.resource, entry.channel) },
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ', entry.time),
    }
end

local function QueueFor(url)
    local queue = Queues[url]
    if not queue then
        queue = { items = {}, dropped = 0, running = false }
        Queues[url] = queue
    end

    return queue
end

FN_LOG.Enqueue = function(url, embed)
    local queue = QueueFor(url)
    queue.items[#queue.items + 1] = embed
    if #queue.items > FN_LOG.MaxQueue then
        table.remove(queue.items, 1)
        queue.dropped = queue.dropped + 1
        if queue.dropped == 1 or queue.dropped % 100 == 0 then
            print(('^3LOG webhook queue is full, %d oldest entries dropped so far^7'):format(queue.dropped))
        end
    end

    return queue
end

FN_LOG.Queue = function(url)
    return QueueFor(url).items
end

FN_LOG.Clear = function(url)
    Queues[url] = nil
end

local function RetryAfter(body, headers)
    local ok, decoded = pcall(json.decode, body or '')
    local seconds = ok and type(decoded) == 'table' and tonumber(decoded.retry_after)
    if not seconds and type(headers) == 'table' then seconds = tonumber(headers['Retry-After'] or headers['retry-after']) end

    return math.min(60000, math.max(250, math.ceil((seconds or 5) * 1000)))
end

FN_LOG.Pump = function(url)
    local queue = QueueFor(url)
    local batch, size = {}, 0
    while #batch < 10 and queue.items[1] do
        local length = #json.encode(queue.items[1])
        if #batch > 0 and size + length > 5500 then break end
        batch[#batch + 1] = table.remove(queue.items, 1)
        size = size + length
    end
    if #batch == 0 then return FN_LOG.PaceMs end

    local reply = promise.new()
    PerformHttpRequest(url, function(status, body, headers)
        reply:resolve({ status = status, body = body, headers = headers })
    end, 'POST', json.encode({ embeds = batch }), { ['Content-Type'] = 'application/json' })
    local result = Citizen.Await(reply)

    if result.status == 429 then
        for index = #batch, 1, -1 do table.insert(queue.items, 1, batch[index]) end
        while #queue.items > FN_LOG.MaxQueue do table.remove(queue.items, 1) end

        return RetryAfter(result.body, result.headers)
    end
    if result.status < 200 or result.status >= 300 then
        Warn('http|' .. url .. '|' .. tostring(result.status), ('LOG webhook answered %s, %d entries dropped. Check the fn_bridge:webhook_* convars.'):format(tostring(result.status), #batch))
    end

    return FN_LOG.PaceMs
end

FN_LOG.Discord = function(url, embed)
    if not Url(url, 'a SendLog webhook') then return false end

    local queue = FN_LOG.Enqueue(url, embed)
    if queue.running then return true end

    queue.running = true
    CreateThread(function()
        while queue.items[1] do
            local ok, waitMs = pcall(FN_LOG.Pump, url)
            Wait(ok and waitMs or FN_LOG.PaceMs)
        end
        queue.running = false
    end)

    return true
end

local function Text(value)
    return value ~= nil and tostring(value) or ''
end

local function Coord(coords, axis)
    return coords and ('%.2f'):format(coords[axis]) or ''
end

FN_LOG.Insert = function(rows, now)
    local groups, params = {}, {}
    for index, row in ipairs(rows) do
        groups[index] = "(NOW(3) - INTERVAL ? MICROSECOND, ?, ?, ?, " .. ("NULLIF(?, '')"):rep(8, ', ') .. ")"
        local base = (index - 1) * 12
        params[base + 1] = math.max(0, math.floor((now - row.at) * 1000))
        params[base + 2] = row.resource
        params[base + 3] = row.channel
        params[base + 4] = row.event
        params[base + 5] = Text(row.serverId)
        params[base + 6] = Text(row.charId)
        params[base + 7] = Text(row.name)
        params[base + 8] = Text(row.license)
        params[base + 9] = Coord(row.coords, 'x')
        params[base + 10] = Coord(row.coords, 'y')
        params[base + 11] = Coord(row.coords, 'z')
        params[base + 12] = row.data and next(row.data) and json.encode(row.data) or ''
    end

    return 'INSERT INTO `fn_logs` (`created_at`, `resource`, `channel`, `event`, `server_id`, `char_id`, `char_name`, `license`, `x`, `y`, `z`, `data`) VALUES ' .. table.concat(groups, ', '), params
end

local function Query(fn, sql, params)
    local reply, done = promise.new(), false
    local function Finish(ok, result)
        if done then return end
        done = true
        reply:resolve({ ok, result })
    end
    CreateThread(function() Finish(pcall(fn, sql, params)) end)
    SetTimeout(FN_LOG.QueryMs, function() Finish(false, 'ETIMEDOUT oxmysql did not answer') end)
    local result = Citizen.Await(reply)

    return result[1], result[2]
end

local function TableOk()
    if TableReady then return true end
    if GetGameTimer() < CheckAt then return false end

    local ok, found = Query(MySQL.scalar.await, "SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'fn_logs'")
    if ok and found then
        if TableMissing then print('^2LOG found fn_logs, database logging is back on^7') end
        TableReady, TableMissing, CheckAt, Backoff, Warned.missing = true, false, 0, FN_LOG.FlushMs, nil

        return true
    end

    CheckAt, Backoff = GetGameTimer() + Backoff, math.min(Backoff * 2, 300000)
    if ok then
        TableMissing = true
        Warn('missing', 'LOG table fn_logs is missing, database logging is paused. Import sql/install.sql from fn_bridge into your database, fn_bridge checks again on its own.')
    end

    return false
end

FN_LOG.TableExists = function()
    return TableReady or FN_DB.HasTable('fn_logs')
end

local function Kind(message)
    if message:find('ER_NO_SUCH_TABLE', 1, true) or message:find("doesn't exist", 1, true) then return 'table' end
    for _, code in ipairs(Lost) do
        if message:find(code, 1, true) then return 'lost' end
    end

    return 'other'
end

local function Requeue(chunk)
    local rows = table.move(FN_LOG.Rows, 1, #FN_LOG.Rows, #chunk + 1, chunk)
    if #rows > FN_LOG.MaxRows then
        rows = table.move(rows, #rows - FN_LOG.MaxRows + 1, #rows, 1, {})
        Warn('rows', 'LOG buffer is full, the oldest database rows are being dropped')
    end
    FN_LOG.Rows = rows
end

FN_LOG.Flush = function()
    if Flushing or not FN_LOG.Rows[1] or not TableOk() then return end
    Flushing = true

    while FN_LOG.Rows[1] do
        local rows = FN_LOG.Rows
        local count = math.min(#rows, FN_LOG.BatchRows)
        local chunk = table.move(rows, 1, count, 1, {})
        FN_LOG.Rows = table.move(rows, count + 1, #rows, 1, {})

        local sql, params = FN_LOG.Insert(chunk, GetGameTimer())
        local ok, err = Query(MySQL.query.await, sql, params)
        if ok then
            Failed, Warned.lost = nil, nil
        else
            local message = tostring(err):match('([^\n]*)$')
            local kind = Kind(message)
            if kind == 'other' and Failed and Failed.row == chunk[1] and Failed.message == message then
                Failed = nil
                print(('^1LOG dropped %d rows that fn_logs refused twice: %s^7'):format(#chunk, message))
            else
                Requeue(chunk)
                if kind == 'table' then
                    TableReady, CheckAt = false, 0
                elseif kind == 'lost' then
                    Warn('lost', ('LOG lost the database connection, rows stay in memory and fn_bridge keeps retrying: %s'):format(message))
                else
                    Failed = { row = chunk[1], message = message }
                    Warn('db|' .. message, ('LOG could not write %d rows to fn_logs, trying once more: %s'):format(#chunk, message))
                end
                break
            end
        end
    end

    Flushing = false
end

local function Buffer(entry)
    if not FN_LOG.DbEnabled() then return end

    local rows = FN_LOG.Rows
    rows[#rows + 1] = {
        at = entry.at, resource = FN_LOG.Cut(entry.resource, 64), channel = entry.channel, event = entry.event,
        serverId = entry.serverId, charId = entry.charId, name = entry.name, license = entry.license, coords = entry.coords, data = entry.data,
    }
    if #rows > FN_LOG.MaxRows then
        table.remove(rows, 1)
        Warn('rows', 'LOG buffer is full, the oldest database rows are being dropped')
    end
    if #rows >= FN_LOG.BatchRows then CreateThread(FN_LOG.Flush) end
end

FN_LOG.Write = function(resource, channel, event, playerId, data, identity)
    local entry = FN_LOG.Clean(resource, channel, event, playerId, data)
    if not entry then return false end

    for key, value in pairs(identity or FN_LOG.Identity(playerId)) do entry[key] = value end

    local url = FN_LOG.Webhook(channel)
    if url then FN_LOG.Discord(url, FN_LOG.Embed(entry)) end
    Buffer(entry)

    return true
end

FN_LOG.Send = function(channel, event, playerId, data)
    return FN_LOG.Write(GetInvokingResource() or GetCurrentResourceName(), channel, event, playerId, data)
end

CreateThread(function()
    while true do
        Wait(FN_LOG.FlushMs)
        FN_LOG.Flush()
    end
end)

AddEventHandler('playerDropped', function()
    FN_LOG.Remember(tonumber(source))
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() or TableMissing then return end

    local rows, now = FN_LOG.Rows, GetGameTimer()
    FN_LOG.Rows = {}
    for first = 1, #rows, FN_LOG.BatchRows do
        MySQL.query(FN_LOG.Insert(table.move(rows, first, math.min(#rows, first + FN_LOG.BatchRows - 1), 1, {}), now))
    end
end)

exports('Log', FN_LOG.Send)
