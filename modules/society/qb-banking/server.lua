if not FN_BRIDGE.IsSociety('qb-banking') then return end

FN_SOCIETY = {}

local function SafeExport(method, ...)
    local ok, result = pcall(function(...)
        return exports['qb-banking'][method](exports['qb-banking'], ...)
    end, ...)

    if not ok then return nil end

    return result
end

FN_SOCIETY.GetMoney = function(societyName)
    return tonumber(SafeExport('GetAccountBalance', societyName)) or 0
end

FN_SOCIETY.AddMoney = function(societyName, amount)
    if type(amount) ~= 'number' or amount <= 0 then return false end

    local result = SafeExport('AddMoney', societyName, amount, 'fn_bridge')

    return result ~= nil and result ~= false and result ~= 0
end

FN_SOCIETY.RemoveMoney = function(societyName, amount)
    if type(amount) ~= 'number' or amount <= 0 or FN_SOCIETY.GetMoney(societyName) < amount then return false end

    return SafeExport('RemoveMoney', societyName, amount, 'fn_bridge') == true
end

Config.DebugPrint('society adapter loaded: qb-banking (server)')
