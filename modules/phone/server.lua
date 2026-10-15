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

local OwnNumbers = { 'gksphone', 'qs-smartphone', 'qs-smartphone-pro', 'yseries', 'okokPhone', 'roadphone', 'high_phone', 'high-phone', '17mov_Phone', 'jpr-phonesystem' }


local function Reason(why)
    why = type(why) == 'string' and why:gsub('^phone_', '') or 'failed'
    return why ~= '' and why or 'failed'
end

local FrameworkNumbers = {
    name = 'framework',
    ready = function() return FN_BRIDGE.FRAMEWORK.Supports('phoneNumber') == true end,
    get = function(playerId) return FN_BRIDGE.FRAMEWORK.GetPhoneNumber(playerId) end,
    taken = function(number) return FN_BRIDGE.FRAMEWORK.IsPhoneNumberTaken(number) == true end,
    set = function(playerId, number) return FN_BRIDGE.FRAMEWORK.SetPhoneNumber(playerId, number) == true end,
}

local Numbering = {
    ['fn_phone'] = {
        ready = function() return exports['fn_phone']:simNumbers() == true end,
        get = function(playerId) return exports['fn_phone']:getNumber(playerId) end,
        taken = function(number) return exports['fn_phone']:numberTaken(number) == true end,
        set = function(playerId, number) return exports['fn_phone']:giveSim(playerId, number) end,
    },
    ['lb-phone'] = {
        relog = true,
        ready = function() return not FN_BRIDGE.IsFramework('standalone') and FN_DB.HasTable('phone_phones') end,
        get = function(playerId) return exports['lb-phone']:GetEquippedPhoneNumber(playerId) end,
        taken = function(number) return (MySQL.scalar.await('SELECT COUNT(*) FROM phone_phones WHERE phone_number = ?', { number }) or 0) > 0 end,
        check = function(playerId, current)
            if not current then return false, 'nophone' end
            local owner = MySQL.scalar.await('SELECT id FROM phone_phones WHERE phone_number = ?', { current })
            local id = FN_BRIDGE.FRAMEWORK.GetIdentifier(playerId)
            if owner == nil or id == nil or tostring(owner) ~= tostring(id) then return false, 'unsupported' end
            return true
        end,
        set = function(_, number, old)
            local columns = MySQL.query.await([[SELECT TABLE_NAME AS t, COLUMN_NAME AS c FROM INFORMATION_SCHEMA.COLUMNS
                WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME LIKE 'phone\_%' AND DATA_TYPE IN ('varchar', 'char') AND CHARACTER_MAXIMUM_LENGTH BETWEEN ? AND 32]], { math.max(#old, #number) }) or {}
            local queries = {}
            for _, col in ipairs(columns) do
                queries[#queries + 1] = { query = ('UPDATE `%s` SET `%s` = ? WHERE `%s` = ?'):format(col.t, col.c, col.c), values = { number, old } }
            end
            if #queries == 0 then return false, 'failed' end
            return MySQL.transaction.await(queries) == true
        end,
    },
    ['npwd'] = {
        relog = function() return not FN_BRIDGE.IsFramework('qb') and not FN_BRIDGE.IsFramework('qbx') end,
        ready = FrameworkNumbers.ready,
        get = FrameworkNumbers.get,
        taken = FrameworkNumbers.taken,
        set = function(playerId, number)
            if not FrameworkNumbers.set(playerId, number) then return false end
            local player = (FN_BRIDGE.IsFramework('qb') or FN_BRIDGE.IsFramework('qbx')) and FN_FRAMEWORK.RawPlayer(playerId)
            local data = type(player) == 'table' and player.PlayerData
            if type(data) == 'table' and type(data.charinfo) == 'table' then
                local ok, why = pcall(function()
                    exports['npwd']:unloadPlayer(playerId)
                    exports['npwd']:newPlayer({ source = playerId, identifier = data.citizenid, phoneNumber = number, firstname = data.charinfo.firstname, lastname = data.charinfo.lastname })
                end)
                if not ok then print(('^3[fn_bridge] npwd takes the new number on the next join: %s^0'):format(tostring(why))) end
            end
            return true
        end,
    },
}

local function Numbers()
    local hook = FN_BRIDGE.Setting('phoneNumber')
    if type(hook) == 'table' and FN_BRIDGE.Callable(hook.set) then
        return {
            name = 'hook', relog = hook.relog == true,
            ready = function() return true end,
            get = FN_BRIDGE.Callable(hook.get) and hook.get or FN_PHONE.Number,
            taken = FN_BRIDGE.Callable(hook.taken) and hook.taken or FrameworkNumbers.taken,
            check = FN_BRIDGE.Callable(hook.check) and hook.check or nil,
            set = hook.set,
        }
    end

    local resource = FN_PHONE.Name()
    if resource and Numbering[resource] then
        local n = Numbering[resource]
        n.name = resource
        return n
    end
    if Config.Phone ~= 'none' then
        for _, own in ipairs(OwnNumbers) do
            if Started(own) then return nil, own end
        end
    end

    return FrameworkNumbers
end

FN_PHONE.Numbers = function()
    local n, unsupported = Numbers()
    if not n then return false, 'unsupported', unsupported end

    local ok, ready = pcall(n.ready)
    if not ok or not ready then return false, 'none', n.name end

    local relog = n.relog
    if FN_BRIDGE.Callable(relog) then relog = relog() end

    return { name = n.name, relog = relog == true }
end

FN_PHONE.NumberTaken = function(number)
    local n = Numbers()
    number = (type(number) == 'string' or type(number) == 'number') and tostring(number) or nil
    if not n or not number or number == '' then return true end

    local ok, taken = pcall(n.taken, number)

    return not ok or taken ~= false
end

FN_PHONE.CanSetNumber = function(playerId)
    playerId = Online(playerId)
    if not playerId then return false, 'offline' end

    local ready, why = FN_PHONE.Numbers()
    if not ready then return false, why end

    local n = Numbers()
    if not n.check then return true end

    local okGet, current = pcall(n.get, playerId)
    local ok, done, reason = pcall(n.check, playerId, okGet and current or nil)
    if not ok then return false, 'failed' end

    return done == true, done ~= true and Reason(reason) or nil
end

FN_PHONE.SetNumber = function(playerId, number)
    playerId = Online(playerId)
    number = (type(number) == 'string' or type(number) == 'number') and tostring(number):gsub('[^%d]', '') or ''
    if not playerId then return false, 'offline' end
    if number == '' or #number > 20 then return false, 'invalid' end

    local can, why = FN_PHONE.CanSetNumber(playerId)
    if not can then return false, why end
    if FN_PHONE.NumberTaken(number) then return false, 'taken' end

    local n = Numbers()
    local okGet, old = pcall(n.get, playerId)
    old = okGet and old ~= nil and tostring(old) or ''
    local ok, done, reason = pcall(n.set, playerId, number, old)
    if not ok then
        print(('^1[fn_bridge] phone number %s -> %s (%s): %s^0'):format(old, number, n.name, tostring(done)))
        return false, 'failed'
    end
    if done ~= true then return false, Reason(reason) end

    return true, old
end
