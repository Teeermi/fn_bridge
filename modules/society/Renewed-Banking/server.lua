if not FN_BRIDGE.IsSociety('Renewed-Banking') then return end

FN_SOCIETY = {}

local function SafeExport(method, ...)
    local ok, result = pcall(function(...)
        return exports['Renewed-Banking'][method](exports['Renewed-Banking'], ...)
    end, ...)

    if not ok then return nil end

    return result
end

FN_SOCIETY.GetMoney = function(societyName)
    return tonumber(SafeExport('getAccountMoney', societyName)) or 0
end

FN_SOCIETY.AddMoney = function(societyName, amount)
    if type(amount) ~= 'number' or amount <= 0 then return false end

    return SafeExport('addAccountMoney', societyName, amount, 'fn_bridge') and true or false
end

FN_SOCIETY.RemoveMoney = function(societyName, amount)
    if type(amount) ~= 'number' or amount <= 0 then return false end

    return SafeExport('removeAccountMoney', societyName, amount, 'fn_bridge') and true or false
end

Config.DebugPrint('society adapter loaded: Renewed-Banking (server)')
