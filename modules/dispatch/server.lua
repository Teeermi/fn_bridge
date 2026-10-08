FN_DISPATCH = {}

local Order = { 'fn_mdt', 'fn_phone', 'lb-tablet', 'ps-dispatch', 'cd_dispatch', 'qs-dispatch', 'tk_dispatch', 'fd_dispatch', 'wasabi_mdt', 'origen_police', 'bub-mdt', 'kartik-mdt', 'redutzu-mdt', 'piotreq_gpt', 'linden_outlawalert', 'emergencydispatch' }

for _, resource in ipairs(Order) do FN_KNOWN[resource] = true end

local Server = {
    ['fn_mdt'] = function(playerId, alert)
        return exports['fn_mdt']:alert(alert, playerId) and 'fn_mdt' or false
    end,
    ['fn_phone'] = function(playerId, alert)
        return exports['fn_phone']:dispatch(playerId, alert) or false
    end,
    ['lb-tablet'] = function(_, alert)
        local priority = alert.priority == 1 and 'high' or alert.priority == 3 and 'low' or 'medium'
        exports['lb-tablet']:AddDispatch({ priority = priority, code = alert.code, title = alert.title, description = alert.message, location = { label = alert.street or '', coords = vector2(alert.coords.x, alert.coords.y) }, time = 600, job = alert.jobs[1] })
    end,
    ['cd_dispatch'] = function(_, alert)
        TriggerEvent('cd_dispatch:AddNotification', { job_table = alert.jobs, coords = alert.coords, title = alert.title, message = alert.message, flash = 0, unique_id = tostring(math.random(1e9)), sound = 1, blip = { sprite = alert.sprite, scale = 1.2, colour = alert.color, flashes = true, text = alert.title, time = 5, radius = 0 } })
    end,
    ['redutzu-mdt'] = function(_, alert)
        TriggerEvent('redutzu-mdt:server:addDispatchToMDT', { code = alert.code, title = alert.message, street = alert.street or '', duration = 600000, coords = alert.coords })
    end,
    ['piotreq_gpt'] = function(playerId, alert)
        exports['piotreq_gpt']:SendAlert(playerId, { title = alert.title, code = alert.code, icon = 'fa-solid fa-phone', info = { { icon = 'fa-solid fa-road', isStreet = true }, { icon = 'fa-solid fa-circle-info', data = alert.message } }, blip = { sprite = alert.sprite, color = alert.color, scale = 1.0, name = alert.title } })
    end,
}

local function Started(resource)
    return GetResourceState(resource) == 'started'
end

local function Text(value, max, default)
    if type(value) ~= 'string' or value == '' then return default end

    return value:sub(1, max)
end

FN_DISPATCH.Name = function()
    if FN_BRIDGE.Callable(FN_BRIDGE.Setting('dispatch')) then return 'hook' end

    local forced = Config.Dispatch
    if forced == 'none' then return false end
    if forced ~= 'auto' then return Started(forced) and forced or false end

    for _, resource in ipairs(Order) do
        if Started(resource) then return resource end
    end

    return false
end

FN_DISPATCH.Send = function(playerId, alert)
    playerId = tonumber(playerId)
    local resource = FN_DISPATCH.Name()
    if not resource or not playerId or type(alert) ~= 'table' then return false end

    local ped = GetPlayerPed(playerId)
    local coords = alert.coords or (ped ~= 0 and GetEntityCoords(ped))
    if not coords then return false end

    local jobs = type(alert.jobs) == 'table' and alert.jobs or { type(alert.jobs) == 'string' and alert.jobs or 'police' }
    local clean = {
        code = Text(alert.code, 12, '10-80'),
        title = Text(alert.title, 60, 'Alert'),
        message = Text(alert.message, 300, ''),
        coords = vector3(coords.x, coords.y, coords.z),
        jobs = jobs,
        sprite = tonumber(alert.sprite) or 161,
        color = tonumber(alert.color) or 1,
        priority = tonumber(alert.priority) or 2,
        street = Text(alert.street, 64, nil),
    }

    local hook = FN_BRIDGE.Setting('dispatch')
    local send = FN_BRIDGE.Callable(hook) and hook or Server[resource]
    if not send then
        TriggerClientEvent('fn_bridge:dispatch', playerId, resource, clean)
        return resource
    end

    local ok, result = pcall(send, playerId, clean)
    if not ok or result == false then return false end

    return type(result) == 'string' and result or resource
end
