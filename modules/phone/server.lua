FN_PHONE = {}

local Order = { 'fn_phone', 'lb-phone', 'npwd', 'qb-phone' }

for _, resource in ipairs(Order) do FN_KNOWN[resource] = true end

local function Started(resource)
    return GetResourceState(resource) == 'started'
end

local function Text(value, max)
    if type(value) ~= 'string' then return nil end
    value = value:gsub('[%c]', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if value == '' then return nil end
    local length = utf8.len(value)
    if length and length > max then return value:sub(1, utf8.offset(value, max + 1) - 1) end
    if not length and #value > max then return value:sub(1, max) end

    return value
end

local function Online(playerId)
    playerId = tonumber(playerId)

    return playerId and playerId > 0 and GetPlayerName(playerId) ~= nil and playerId or nil
end

local function Call(fn, ...)
    local ok, a, b = pcall(fn, ...)
    if not ok then return nil end

    return a, b
end

local Number = {
    ['fn_phone'] = function(playerId) return exports['fn_phone']:getNumber(playerId) end,
    ['lb-phone'] = function(playerId) return exports['lb-phone']:GetEquippedPhoneNumber(playerId) end,
    ['npwd'] = function(playerId)
        local data = exports['npwd']:getPlayerData({ source = playerId })

        return type(data) == 'table' and data.phoneNumber or nil
    end,
}

local Notify = {
    ['fn_phone'] = function(playerId, n)
        return (tonumber(exports['fn_phone']:notify(playerId, { app = n.app, title = n.title, body = n.body })) or 0) > 0
    end,
    ['lb-phone'] = function(playerId, n)
        exports['lb-phone']:SendNotification(playerId, { app = n.app, title = n.title, content = n.body })

        return true
    end,
    ['npwd'] = function(playerId, n)
        TriggerClientEvent('fn_bridge:phone', playerId, 'npwd', n)

        return true
    end,
    ['qb-phone'] = function(playerId, n)
        TriggerClientEvent('qb-phone:client:CustomNotification', playerId, n.title, n.body or '', n.icon or 'fas fa-bell', n.color or '#2a9bdd', 6000)

        return true
    end,
}

local Mail = {
    ['fn_phone'] = function(target, m)
        return exports['fn_phone']:sendMail(target, { sender = m.sender, subject = m.subject, message = m.message }) and true or false
    end,
    ['lb-phone'] = function(target, m)
        local number = exports['lb-phone']:GetEquippedPhoneNumber(target)
        if not number then return false end

        return exports['lb-phone']:SendMail({ to = number, sender = m.sender, subject = m.subject, message = m.message }) == true
    end,
    ['qb-phone'] = function(target, m)
        local citizenid = type(target) == 'number' and FN_BRIDGE.FRAMEWORK.GetIdentifier(target) or target
        if type(citizenid) ~= 'string' or citizenid == '' then return false end
        exports['qb-phone']:sendNewMailToOffline(citizenid, { sender = m.sender, subject = m.subject, message = m.message })

        return true
    end,
}

local Message = {
    ['fn_phone'] = function(from, to, text)
        return exports['fn_phone']:sendMessage(from, to, text) and true or false
    end,
    ['lb-phone'] = function(from, to, text)
        exports['lb-phone']:SendMessage(from, to, text)

        return true
    end,
    ['npwd'] = function(from, to, text)
        exports['npwd']:emitMessage({ senderNumber = from, targetNumber = to, message = text })

        return true
    end,
}

FN_PHONE.Name = function()
    local forced = Config.Phone
    if forced == 'none' then return false end
    if forced ~= 'auto' then return Started(forced) and forced or false end

    for _, resource in ipairs(Order) do
        if Started(resource) then return resource end
    end

    return false
end

FN_PHONE.Supports = function(what)
    local resource = FN_PHONE.Name()
    if not resource then return false end
    if what == 'notify' then return Notify[resource] ~= nil end
    if what == 'mail' then return Mail[resource] ~= nil end
    if what == 'message' then return Message[resource] ~= nil end
    if what == 'number' then return true end

    return false
end

FN_PHONE.Number = function(playerId)
    playerId = Online(playerId)
    if not playerId then return false end

    local resource = FN_PHONE.Name()
    local read = resource and Number[resource]
    local number = read and Call(read, playerId) or nil
    if number == nil or number == false or number == '' then number = FN_BRIDGE.FRAMEWORK.GetPhoneNumber(playerId) end

    return (type(number) == 'string' or type(number) == 'number') and tostring(number) ~= '' and tostring(number) or false
end

FN_PHONE.Notify = function(playerId, notification)
    playerId = Online(playerId)
    local resource = FN_PHONE.Name()
    local send = resource and Notify[resource]
    if not playerId or not send or type(notification) ~= 'table' then return false end

    local n = {
        title = Text(notification.title, 60),
        body = Text(notification.body or notification.message, 200),
        app = Text(notification.app, 24),
        icon = Text(notification.icon, 48),
        color = type(notification.color) == 'string' and notification.color:match('^#%x%x%x%x%x%x$') or nil,
    }
    if not n.title then return false end

    return Call(send, playerId, n) == true and resource or false
end

FN_PHONE.Mail = function(target, mail)
    local resource = FN_PHONE.Name()
    local send = resource and Mail[resource]
    if not send or type(mail) ~= 'table' then return false end
    if type(target) == 'number' or tonumber(target) and #tostring(target) <= 5 then
        target = Online(target)
    elseif type(target) ~= 'string' or target == '' or #target > 64 then
        target = nil
    end
    if not target then return false end

    local m = {
        sender = Text(mail.sender, 64) or 'System',
        subject = Text(mail.subject, 120),
        message = type(mail.message) == 'string' and mail.message:sub(1, 4000) or nil,
    }
    if not m.subject or not m.message or m.message == '' then return false end

    return Call(send, target, m) == true and resource or false
end

FN_PHONE.Message = function(from, to, text)
    local resource = FN_PHONE.Name()
    local send = resource and Message[resource]
    text = Text(text, 1000)
    from = (type(from) == 'string' or type(from) == 'number') and tostring(from):gsub('[^%d]', '') or ''
    if not send or not text or from == '' then return false end
    if type(to) == 'number' then to = FN_PHONE.Number(to) end
    to = (type(to) == 'string' or type(to) == 'number') and tostring(to):gsub('[^%d]', '') or ''
    if to == '' or to == from then return false end

    return Call(send, from, to, text) == true and resource or false
end
