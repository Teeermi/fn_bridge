FN_BILLING = {}

local B = FN_BILLING
local Paying = {}

FN_KNOWN['esx_billing'] = true

local function Text(value, max)
    return type(value) == 'string' and value ~= '' and value:sub(1, max) or nil
end

local function Esx()
    return GetResourceState('esx_billing') == 'started' and FN_DB.HasTable('billing')
end

local function Providers()
    local out = {}
    for _, entry in ipairs(FN_BRIDGE.ProvidersOf('billing')) do
        if type(entry.value) == 'table' then out[#out + 1] = entry end
    end

    return out
end

local function Clean(bill)
    if type(bill) ~= 'table' then return nil end

    local amount = math.floor(tonumber(bill.amount) or 0)
    local to = Text(bill.to, 64)
    if not to or amount < 1 or amount > 1e9 then return nil end

    local items = {}
    for i, item in ipairs(type(bill.items) == 'table' and bill.items or {}) do
        if i > 50 or type(item) ~= 'table' then break end
        items[#items + 1] = { label = Text(item.label, 80) or '', amount = math.floor(tonumber(item.amount) or 0), count = math.max(1, math.floor(tonumber(item.count) or 1)) }
    end

    return { to = to, from = Text(bill.from, 64), amount = amount, label = Text(bill.label, 120) or 'Invoice', items = items, due = tonumber(bill.due) }
end

B.Name = function()
    local list = Providers()
    if #list > 0 then return list[#list].resource end

    return Esx() and 'esx_billing' or false
end

B.Provide = function(impl)
    return FN_BRIDGE.Provide('billing', impl)
end

B.Send = function(playerId, bill)
    bill = Clean(bill)
    if not bill then return false, 'invalid' end

    local list = Providers()
    local top = list[#list]
    if top and FN_BRIDGE.Callable(top.value.Send) then
        local ok, id, why = pcall(top.value.Send, tonumber(playerId), bill)
        if ok and id then return top.resource .. ':' .. tostring(id) end

        return false, ok and why or 'failed'
    end

    if not Esx() then return false, 'none' end

    local sender = tonumber(playerId) and FN_FRAMEWORK.GetIdentifier(tonumber(playerId)) or 'server'
    local society = bill.from and FN_FRAMEWORK.GetJobs()[bill.from] and 'society_' .. bill.from
    local id = MySQL.insert.await('INSERT INTO billing (identifier, sender, target_type, target, label, amount) VALUES (?, ?, ?, ?, ?, ?)', { bill.to, sender, society and 'society' or 'player', society or sender, bill.label, bill.amount })

    return id and 'esx_billing:' .. id or false, not id and 'failed' or nil
end

B.List = function(identifier)
    if type(identifier) ~= 'string' or identifier == '' then return {} end

    local out = {}
    for _, entry in ipairs(Providers()) do
        if FN_BRIDGE.Callable(entry.value.List) then
            local ok, rows = pcall(entry.value.List, identifier)
            for _, row in ipairs(ok and type(rows) == 'table' and rows or {}) do
                if type(row) == 'table' and row.id ~= nil then
                    out[#out + 1] = { id = entry.resource .. ':' .. tostring(row.id), from = row.from, label = row.label, amount = tonumber(row.amount) or 0, due = row.due, status = row.status or 'unpaid', source = entry.resource }
                end
            end
        end
    end

    if Esx() then
        for _, row in ipairs(MySQL.query.await('SELECT id, label, amount, target_type, target FROM billing WHERE identifier = ? ORDER BY id DESC LIMIT 100', { identifier }) or {}) do
            out[#out + 1] = { id = 'esx_billing:' .. row.id, from = row.target_type == 'society' and tostring(row.target):gsub('^society_', '') or row.target, label = row.label, amount = tonumber(row.amount) or 0, status = 'unpaid', source = 'esx_billing' }
        end
    end

    return out
end

local function PayEsx(playerId, id)
    if not id then return false, 'unknown' end

    local identifier = FN_FRAMEWORK.GetIdentifier(playerId)
    local row = identifier and MySQL.single.await('SELECT sender, target_type, target, amount, label FROM billing WHERE id = ? AND identifier = ?', { id, identifier })
    local amount = row and math.floor(tonumber(row.amount) or 0)
    if not amount or amount < 1 then return false, 'unknown' end

    local account = FN_FRAMEWORK.GetMoney(playerId, 'cash') >= amount and 'cash' or FN_FRAMEWORK.GetMoney(playerId, 'bank') >= amount and 'bank'
    if not account then return false, 'funds' end
    if (MySQL.update.await('DELETE FROM billing WHERE id = ? AND identifier = ?', { id, identifier }) or 0) ~= 1 then return false, 'unknown' end

    if not FN_FRAMEWORK.RemoveMoney(playerId, account, amount, 'Bill Paid') then
        MySQL.insert.await('INSERT INTO billing (id, identifier, sender, target_type, target, label, amount) VALUES (?, ?, ?, ?, ?, ?, ?)', { id, identifier, row.sender, row.target_type, row.target, row.label, amount })
        return false, 'funds'
    end

    if row.target_type == 'society' then
        local raw = FN_SOCIETY and FN_SOCIETY.Raw
        if raw then raw.AddMoney(row.target, amount) elseif FN_SOCIETY then FN_SOCIETY.AddMoney(tostring(row.target):gsub('^society_', ''), amount, 'bill') end
    else
        local sender = FN_FRAMEWORK.GetPlayerFromIdentifier(row.sender)
        if sender then FN_FRAMEWORK.AddMoney(sender.source, account, amount, 'Paid bill') end
    end
    TriggerEvent('esx_billing:paidBill', playerId, id)

    return true
end

B.Pay = function(playerId, id)
    playerId = tonumber(playerId)
    local source, raw
    if type(id) == 'string' then source, raw = id:match('^([^:]+):(.+)$') end
    if not playerId or not source or Paying[id] then return false, 'invalid' end

    Paying[id] = true
    local ok, done, why = false, false, 'unknown'

    if source == 'esx_billing' then
        ok, done, why = pcall(PayEsx, playerId, tonumber(raw))
    else
        for _, entry in ipairs(Providers()) do
            if entry.resource == source and FN_BRIDGE.Callable(entry.value.Pay) then
                ok, done, why = pcall(entry.value.Pay, playerId, tonumber(raw) or raw)
                break
            end
        end
    end
    Paying[id] = nil

    if ok and done then return true end

    return false, ok and why or 'failed'
end
