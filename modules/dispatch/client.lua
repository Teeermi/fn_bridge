local function Street(coords)
    return GetStreetNameFromHashKey((GetStreetNameAtCoord(coords.x, coords.y, coords.z)))
end

local Send = {
    ['ps-dispatch'] = function(a)
        exports['ps-dispatch']:CustomAlert({ message = a.title, code = a.code, icon = 'fas fa-phone', priority = a.priority, coords = a.coords, description = a.message, radius = 0, sprite = a.sprite, color = a.color, scale = 1.2, length = 3, sound = 'Lose_1st', sound2 = 'GTAO_FM_Events_Soundset', offset = false, flash = a.priority == 1, jobs = a.jobs })
    end,
    ['qs-dispatch'] = function(a)
        TriggerServerEvent('qs-dispatch:server:CreateDispatchCall', { job = a.jobs, callLocation = a.coords, callCode = { code = a.code, snippet = a.title }, message = a.message, flashes = a.priority == 1, blip = { sprite = a.sprite, scale = 1.0, colour = a.color, flashes = false, text = a.title, time = 20000 } })
    end,
    ['tk_dispatch'] = function(a)
        exports.tk_dispatch:addCall({ title = a.title, code = a.code, priority = 'Priority ' .. a.priority, coords = a.coords, showLocation = true, showGender = false, playSound = true, blip = { color = a.color, sprite = a.sprite, scale = 0.8 }, jobs = a.jobs })
    end,
    ['fd_dispatch'] = function(a)
        exports.fd_dispatch:CustomAlert({ title = a.title, description = a.message, groups = a.jobs, location = { coords = a.coords, street = a.street or Street(a.coords) }, code = a.code, priority = a.priority, metadata = {}, blip = { radius = 0, sprite = a.sprite, color = a.color, scale = 1.0 } })
    end,
    ['wasabi_mdt'] = function(a)
        local c = { a.coords.x, a.coords.y, a.coords.z }
        exports.wasabi_mdt:CreateDispatch({ type = a.code, title = a.title, description = a.message, location = c, coords = c })
    end,
    ['origen_police'] = function(a)
        TriggerServerEvent('SendAlert:police', { coords = a.coords, title = a.title, message = a.message, job = a.jobs, metadata = {} })
    end,
    ['bub-mdt'] = function(a)
        exports['bub-mdt']:CustomAlert({ code = a.code, offense = a.title, coords = a.coords, info = { label = a.code, icon = 'fas fa-phone' }, blip = a.sprite, isEmergency = a.priority == 1, blipCoords = a.coords })
    end,
    ['kartik-mdt'] = function(a)
        local jobs = {}
        for _, j in ipairs(a.jobs) do jobs[j] = true end
        exports['kartik-mdt']:CustomAlert({ title = a.title, code = a.code, description = a.message, type = 'Alert', coords = a.coords, blip = { radius = 100.0, sprite = a.sprite, color = a.color, scale = 0.8, length = 2 }, jobs = jobs })
    end,
    ['linden_outlawalert'] = function(a)
        TriggerServerEvent('wf-alerts:svNotify', { dispatchData = { displayCode = a.code, description = a.title, isImportant = a.priority == 1 and 1 or 0, recipientList = a.jobs, length = '10000', infoM = 'fa-phone', info = a.message }, caller = 'Phone', coords = a.coords })
    end,
    ['emergencydispatch'] = function(a)
        TriggerServerEvent('emergencydispatch:emergencycall:new', a.jobs[1], a.message, a.coords, true)
    end,
}

RegisterNetEvent('fn_bridge:dispatch', function(resource, alert)
    local send = Send[resource]
    if send and type(alert) == 'table' and GetResourceState(resource) == 'started' then pcall(send, alert) end
end)
