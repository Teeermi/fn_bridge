if not FN_BRIDGE.IsSociety('esx_addonaccount') then return end

FN_SOCIETY = {}

local function WithAccount(accountName, callback)
    local result
    TriggerEvent('esx_addonaccount:getSharedAccount', accountName, function(account)
        result = callback(account)
    end)

    return result
end

local Raw = {
    GetMoney = function(accountName)
        return WithAccount(accountName, function(account)
            return account and account.money or 0
        end) or 0
    end,
    AddMoney = function(accountName, amount)
        if type(amount) ~= 'number' or amount <= 0 then return false end

        return WithAccount(accountName, function(account)
            if not account then return false end

            account.addMoney(amount)

            return true
        end) or false
    end,
    RemoveMoney = function(accountName, amount)
        if type(amount) ~= 'number' or amount <= 0 then return false end

        return WithAccount(accountName, function(account)
            if not account or account.money < amount then return false end

            account.removeMoney(amount)

            return true
        end) or false
    end,
}

FN_SOCIETY.Raw = Raw

FN_SOCIETY.GetMoney = function(societyName)
    return Raw.GetMoney('society_' .. societyName)
end

FN_SOCIETY.AddMoney = function(societyName, amount)
    return Raw.AddMoney('society_' .. societyName, amount)
end

FN_SOCIETY.RemoveMoney = function(societyName, amount)
    return Raw.RemoveMoney('society_' .. societyName, amount)
end

Config.DebugPrint('society adapter loaded: esx_addonaccount (server)')
