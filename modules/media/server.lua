FN_MEDIA = {}

local Encodings = { webp = true, jpg = true, png = true }
local Kinds = { video = true, image = true, audio = true }

local function Started(resource)
    return GetResourceState(resource) == 'started'
end

local function Opts(opts)
    return type(opts) == 'table' and opts or {}
end

local HOST = 'https://api.fivedock.dev'

local function Token(opts)
    local token = Opts(opts).token
    if type(token) ~= 'string' or token == '' then token = GetConvar('fn_bridge:upload_token', '') end

    return token ~= '' and token or nil
end

local function Await(start, ms)
    local p, done = promise.new(), false
    local function Finish(value)
        if done then return end
        done = true
        p:resolve(value)
    end

    if not pcall(start, Finish) then Finish(false) end
    SetTimeout(ms, function() Finish(false) end)

    return Citizen.Await(p)
end

local function Name(opts, mime)
    local prefix = tostring(Opts(opts).name or 'fn'):gsub('[^%w_%-]', ''):sub(1, 24)

    return ('%s_%d_%d.%s'):format(prefix ~= '' and prefix or 'op', os.time(), math.random(1e6), mime)
end

FN_MEDIA.IsUrl = function(url)
    return type(url) == 'string' and #url <= 512 and url:match('^https://[%w%.%-]+/[^%s"\'()<>\\]*$') ~= nil
end

FN_MEDIA.Capturer = function()
    if Started('screencapture') then return 'screencapture' end
    if Started('screenshot-basic') then return 'screenshot-basic' end

    return false
end

FN_MEDIA.Provider = function(opts)
    if Token(opts) then return 'fivedock' end
    if Started('fivedock') then return 'fivedock-agent' end

    return false
end

FN_MEDIA.Missing = function(opts)
    local out = {}
    if not FN_MEDIA.Capturer() then out[#out + 1] = 'capture' end
    if not FN_MEDIA.Provider(opts) then out[#out + 1] = 'token' end

    return out
end

FN_MEDIA.Ready = function(opts)
    return #FN_MEDIA.Missing(opts) == 0
end

local shots, shotSeq = {}, 0

RegisterNetEvent('fn_bridge:shotData', function(token, data)
    local shot = shots[token]
    if not shot or shot.player ~= source then return end
    shot.done(type(data) == 'string' and #data <= 16777216 and data or false)
end)

FN_MEDIA.Capture = function(playerId, opts)
    playerId = tonumber(playerId)
    local capturer = FN_MEDIA.Capturer()
    if not playerId or not capturer or not GetPlayerName(playerId) then return false end

    opts = Opts(opts)
    local encoding = Encodings[opts.encoding] and opts.encoding or 'webp'
    local quality = tonumber(opts.quality) or 0.92
    local data = Await(function(done)
        if capturer == 'screencapture' then
            exports.screencapture:serverCapture(playerId, { encoding = encoding, quality = quality }, function(d) done(d) end, 'base64')
        else
            shotSeq = shotSeq + 1
            local token = shotSeq
            shots[token] = { player = playerId, done = function(d) shots[token] = nil done(d) end }
            SetTimeout(30000, function() shots[token] = nil end)
            TriggerClientEvent('fn_bridge:shot', playerId, token, { encoding = encoding, quality = quality })
        end
    end, tonumber(opts.timeout) or 12000)

    if type(data) ~= 'string' or data == '' then return false end
    if not data:find('^data:image/') then data = ('data:image/%s;base64,%s'):format(encoding == 'jpg' and 'jpeg' or encoding, data) end

    return data
end

local function Agent(mime, b64, opts)
    local resource, name = FN_BRIDGE.resourceName, Name(opts, mime)
    local ok, path = pcall(function() return exports[resource]:spool(name, b64) end)
    if not ok or type(path) ~= 'string' then return nil end

    local folder = tostring(Opts(opts).folder or 'fn'):gsub('[^%w_%-]', ''):sub(1, 32)
    local url = Await(function(done)
        exports.fivedock:upload({ path = path, name = name, folder = folder }, function(err, r)
            done(not err and type(r) == 'table' and FN_MEDIA.IsUrl(r.url) and r.url)
        end)
    end, 30000)
    pcall(function() exports[resource]:unspool(name) end)

    return url or nil
end

local function Http(mime, b64, opts)
    local r = Await(function(done)
        PerformHttpRequest(HOST .. '/api/v3/file/base64', function(code, body)
            local ok, j = pcall(json.decode, body or '')
            local d = ok and type(j) == 'table' and type(j.data) == 'table' and j.data
            done(code >= 200 and code < 300 and d and FN_MEDIA.IsUrl(d.url) and { url = d.url, id = type(d.id) == 'string' and d.id:sub(1, 64) or nil })
        end, 'POST', json.encode({ base64 = b64, filename = Name(opts, mime), path = Opts(opts).folder }), { ['Content-Type'] = 'application/json', Authorization = Token(opts) })
    end, tonumber(Opts(opts).uploadTimeout) or 20000)

    if r then return r.url, r.id end
end

FN_MEDIA.Upload = function(data, opts)
    local kind, mime, b64 = (type(data) == 'string' and data or ''):match('^data:(%a+)/(%w+)[^,]-;base64,(.+)$')
    if not b64 or not Kinds[kind] then return false end

    local provider = FN_MEDIA.Provider(opts)
    if provider == 'fivedock-agent' then return Agent(mime, b64, opts) or false end
    if not provider then return false end

    local url, file = Http(mime, b64, opts)
    if not url then return false end

    return url, file
end

FN_MEDIA.Shot = function(playerId, opts)
    local data = FN_MEDIA.Capture(playerId, opts)
    if not data then return false, 'capture' end

    local url, file = FN_MEDIA.Upload(data, opts)
    if not url then return false, 'upload' end

    return url, file
end

FN_MEDIA.Delete = function(files, opts)
    local token = Token(opts)
    if not token then return 0 end

    local n = 0
    for _, id in ipairs(type(files) == 'table' and files or { files }) do
        if type(id) == 'string' and #id <= 64 and id:match('^[%w%-_]+$') then
            PerformHttpRequest(HOST .. '/api/v3/file/' .. id, function() end, 'DELETE', '', { Authorization = token })
            n = n + 1
        end
    end

    return n
end

FN_MEDIA.Ticket = function(opts)
    opts = Opts(opts)
    local token = Token(opts)
    if not token then return false, 'token' end

    local kind = Kinds[opts.kind] and opts.kind or 'video'
    local ttl = math.min(math.max(math.floor(tonumber(opts.ttl) or 900), 30), 3600)
    local query = { 'fileType=' .. kind, 'expiresAt=' .. (os.time() + ttl) }
    if opts.single ~= false then query[#query + 1] = 'singleUse=true' end

    local maxSize = math.floor(tonumber(opts.maxSize) or 0)
    if maxSize > 0 then query[#query + 1] = 'maxSize=' .. maxSize end

    local contentType = type(opts.contentType) == 'string' and opts.contentType:match('^[%w%-%.]+/[%w%-%.%+]+$')
    if contentType then query[#query + 1] = 'contentType=' .. contentType end

    local folder = type(opts.folder) == 'string' and opts.folder:gsub('[^%w_%-/]', ''):sub(1, 64)
    if folder and folder ~= '' then query[#query + 1] = 'path=' .. folder end

    local data = Await(function(done)
        PerformHttpRequest(HOST .. '/api/v3/file/presigned-url?' .. table.concat(query, '&'), function(code, body)
            local ok, j = pcall(json.decode, body or '')
            done(code >= 200 and code < 300 and ok and type(j) == 'table' and type(j.data) == 'table' and j.data)
        end, 'GET', '', { Authorization = token })
    end, tonumber(opts.timeout) or 10000)

    local url = data and data.presignedUrl
    if type(url) ~= 'string' or #url > 4096 or not url:match('^https://[%w%.%-]+/[%w%-_%./~%%]+$') then return false, 'host' end

    return { url = url, expires = os.time() + ttl, maxSize = tonumber(data.maxSize) or maxSize, field = 'file' }
end
