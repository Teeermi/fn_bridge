local S = FN_SOCIETY
if not S then return end

local Base = { GetMoney = S.GetMoney, AddMoney = S.AddMoney, RemoveMoney = S.RemoveMoney }
local Raw = S.Raw or Base
local Watched = {}

local function Name(value)
    return type(value) == 'string' and value ~= '' and #value <= 64 and value or nil
end

local function Amount(value)
    value = tonumber(value)

    return value and value > 0 and value < 2 ^ 53 and math.floor(value) or nil
end

local function Changed(name, delta, balance, reason, kind)
    if Watched[name] then Watched[name] = balance end
    TriggerEvent('fn_bridge/server/onSocietyChange', name, delta, balance, type(reason) == 'string' and reason:sub(1, 120) or '', GetInvokingResource(), kind)
end

S.GangAccount = function(gang)
    if not Name(gang) then return nil, false end

    local hook = FN_BRIDGE.Setting('gangAccount')
    if FN_BRIDGE.Callable(hook) then
        local ok, account, dirty = pcall(hook, gang)
        if ok and Name(account) then return account, dirty == true end
    end

    return FN_BRIDGE.IsSociety('esx_addonaccount') and 'society_' .. gang or gang, false
end

local function GangOps(gang)
    local hook = FN_BRIDGE.Setting('gangAccount')
    local account = S.GangAccount(gang)
    if not account then return nil end
    if FN_BRIDGE.Callable(hook) then return Raw, account end
    if S.Gang then return S.Gang, gang end

    return Raw, account
end

local function JobOps(name)
    local hook = FN_BRIDGE.Setting('societyAccount')
    if FN_BRIDGE.Callable(hook) then
        local ok, account = pcall(hook, name)
        if ok and Name(account) then return Raw, account end
    end
    if S.Raw and name:find('^society_') then return Raw, name end

    return Base, name
end

local function Balance(name)
    local ops, account = JobOps(name)

    return tonumber(ops.GetMoney(account)) or 0
end

S.GetMoney = function(name)
    if not Name(name) then return 0 end

    return Balance(name)
end

S.AddMoney = function(name, amount, reason)
    amount = Amount(amount)
    if not Name(name) or not amount then return false end

    local ops, account = JobOps(name)
    if not ops.AddMoney(account, amount) then return false end

    Changed(name, amount, Balance(name), reason, 'job')

    return true
end

S.RemoveMoney = function(name, amount, reason)
    amount = Amount(amount)
    if not Name(name) or not amount then return false end

    local ops, account = JobOps(name)
    if not ops.RemoveMoney(account, amount) then return false end

    Changed(name, -amount, Balance(name), reason, 'job')

    return true
end

S.Transfer = function(from, to, amount, reason)
    amount = Amount(amount)
    if not Name(from) or not Name(to) or from == to or not amount then return false end

    local fromOps, fromAccount = JobOps(from)
    local toOps, toAccount = JobOps(to)
    if not fromOps.RemoveMoney(fromAccount, amount) then return false end
    if not toOps.AddMoney(toAccount, amount) then
        fromOps.AddMoney(fromAccount, amount)
        return false
    end

    Changed(from, -amount, Balance(from), reason, 'job')
    Changed(to, amount, Balance(to), reason, 'job')

    return true
end

S.GetGangMoney = function(gang)
    local ops, account = GangOps(gang)

    return ops and tonumber(ops.GetMoney(account)) or 0
end

S.AddGangMoney = function(gang, amount, reason)
    local ops, account = GangOps(gang)
    amount = Amount(amount)
    if not ops or not amount or not ops.AddMoney(account, amount) then return false end

    Changed(gang, amount, ops.GetMoney(account), reason, 'gang')

    return true
end

S.RemoveGangMoney = function(gang, amount, reason)
    local ops, account = GangOps(gang)
    amount = Amount(amount)
    if not ops or not amount or ops.GetMoney(account) < amount or not ops.RemoveMoney(account, amount) then return false end

    Changed(gang, -amount, ops.GetMoney(account), reason, 'gang')

    return true
end

S.Watch = function(name, on)
    if not Name(name) or not FN_BRIDGE.societyName then return false end

    Watched[name] = on ~= false and (Watched[name] or Balance(name)) or nil

    return true
end

CreateThread(function()
    while true do
        Wait(10000)
        for name, last in pairs(Watched) do
            local now = Balance(name)
            if now ~= last then
                Watched[name] = now
                TriggerEvent('fn_bridge/server/onSocietyChange', name, now - last, now, 'external', nil, 'job')
            end
        end
    end
end)
