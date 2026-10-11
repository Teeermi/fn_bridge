if type(lib) ~= 'table' then return end

local ox = lib.callback
local EVENT = 'fn_bridge:cb:' .. GetCurrentResourceName()
local MISS = '__fn_bridge_miss'

if IsDuplicityVersion() then
    local handlers, spent = {}, {}

    AddEventHandler('playerDropped', function() spent[source] = nil end)

    RegisterNetEvent(EVENT, function(batch)
        local src = source
        if type(batch) ~= 'table' then return end
        local now = GetGameTimer() // 1000
        local s = spent[src]
        if not s or s.t ~= now then
            s = { t = now, n = 0 }
            spent[src] = s
        end
        s.n = s.n + #batch
        if s.n > 120 then return end
        for i = 1, math.min(#batch, 40) do
            local r = batch[i]
            if type(r) == 'table' and math.type(r[1]) == 'integer' and type(r[2]) == 'string' then
                local fn, args = handlers[r[2]], type(r[3]) == 'table' and r[3] or {}
                if not fn then
                    TriggerClientEvent(EVENT, src, r[1], MISS)
                else
                    Citizen.CreateThreadNow(function()
                        local res = table.pack(xpcall(fn, debug.traceback, src, table.unpack(args, 1, math.min(math.tointeger(args.n) or #args, 32))))
                        if not res[1] then
                            print(('^1SCRIPT ERROR: %s^0'):format(res[2]))
                            return TriggerClientEvent(EVENT, src, r[1])
                        end
                        TriggerClientEvent(EVENT, src, r[1], table.unpack(res, 2, res.n))
                    end)
                end
            end
        end
    end)

    lib.callback = setmetatable({
        await = ox.await,
        register = function(name, fn)
            handlers[name] = fn
            return ox.register(name, fn)
        end,
    }, getmetatable(ox))
    return
end

local TIMEOUT = GetConvarInt('ox:callbackTimeout', 300000)
local seq, waiting, queue, timers, foreign = 0, {}, nil, {}, {}

local function flush()
    local q = queue
    queue = nil
    if q then TriggerServerEvent(EVENT, q) end
end

local function due(name, delay)
    if type(delay) ~= 'number' or delay <= 0 then return true end
    local now = GetGameTimer()
    if (timers[name] or 0) > now then return false end
    timers[name] = now + delay
    return true
end

local function send(name, cb, late, ...)
    seq = seq + 1
    local id = seq
    waiting[id] = { name = name, cb = cb, late = late, args = table.pack(...) }
    if not queue then
        queue = {}
        SetTimeout(0, flush)
    end
    queue[#queue + 1] = { id, name, waiting[id].args }
    if #queue >= 32 then flush() end
    SetTimeout(TIMEOUT, function()
        local w = waiting[id]
        waiting[id] = nil
        if w and w.late then w.late() end
    end)
end

RegisterNetEvent(EVENT, function(id, ...)
    if source == '' then return end
    local w = waiting[id]
    if not w then return end
    waiting[id] = nil
    if ... == MISS then
        foreign[w.name] = true
        return ox(w.name, false, w.cb, table.unpack(w.args, 1, w.args.n))
    end
    w.cb(...)
end)

local function await(name, delay, ...)
    if not due(name, delay) then return end
    if foreign[name] then return ox.await(name, false, ...) end
    local p = promise.new()
    send(name, function(...) p:resolve(table.pack(...)) end, function()
        p:reject(("callback event '%s' timed out"):format(name))
    end, ...)
    local r = Citizen.Await(p)
    return table.unpack(r, 1, r.n)
end

lib.callback = setmetatable({ await = await, register = ox.register }, {
    __call = function(_, name, delay, cb, ...)
        if not cb then return await(name, delay, ...) end
        if not due(name, delay) then return end
        if foreign[name] then return ox(name, false, cb, ...) end
        send(name, cb, nil, ...)
    end,
})
