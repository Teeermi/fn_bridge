if FN_BRIDGE.societyName then return end

FN_SOCIETY = {}

local function Warn(key)
    print(('SOCIETY.%s is not supported by this resource: no society resource detected - install esx_addonaccount, qb-management or Renewed-Banking, or set Config.Society by hand'):format(key))
end

FN_SOCIETY.GetMoney = function()
    Warn('GetMoney')

    return 0
end

FN_SOCIETY.AddMoney = function()
    Warn('AddMoney')

    return false
end

FN_SOCIETY.RemoveMoney = function()
    Warn('RemoveMoney')

    return false
end

Config.DebugPrint('society adapter loaded: _default (server)')
