FN_COINS = {}

local C = FN_COINS
local Shop = 'fn_itemshop'

FN_KNOWN[Shop] = true

local function Amount(value)
    local n = math.tointeger(tonumber(value))
    return n and n > 0 and n <= 1e9 and n or nil
end

local function Online(playerId)
    playerId = tonumber(playerId)
    return playerId and playerId > 0 and GetPlayerName(playerId) and playerId or nil
end

local function Top()
    local list = FN_BRIDGE.ProvidersOf('coins')
    for i = #list, 1, -1 do
        if type(list[i].value) == 'table' then return list[i] end
    end
end

local function Builtin()
    return GetResourceState(Shop) == 'started'
end

local function Wallet(playerId)
    local ok, wallet = pcall(function() return exports[Shop]:phoneWallet(playerId) end)
    return ok and type(wallet) == 'string' and wallet ~= '' and wallet or nil
end

local function Call(fn, ...)
    if not FN_BRIDGE.Callable(fn) then return nil end
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
end

C.Name = function()
    local top = Top()
    if top then return top.resource end

    return Builtin() and Shop or false
end

C.Provide = function(impl)
    return FN_BRIDGE.Provide('coins', impl)
end

C.Get = function(playerId)
    playerId = Online(playerId)
    if not playerId then return nil end

    local top = Top()
    if top then return tonumber((Call(top.value.Get, playerId))) end
    if not Builtin() then return nil end

    local wallet = Wallet(playerId)
    if not wallet then return nil end
    local ok, balance = pcall(function() return exports[Shop]:getBalance(wallet) end)

    return ok and tonumber(balance) or nil
end

C.Remove = function(playerId, amount, reason)
    playerId, amount = Online(playerId), Amount(amount)
    if not playerId or not amount then return false, 'invalid' end
    reason = type(reason) == 'string' and reason:sub(1, 120) or GetInvokingResource() or 'fn_bridge'

    local top = Top()
    if top then
        if not FN_BRIDGE.Callable(top.value.Remove) then return false, 'none' end
        if Call(top.value.Remove, playerId, amount, reason) == true then return true end
        return false, 'funds'
    end
    if not Builtin() then return false, 'none' end

    local wallet = Wallet(playerId)
    if not wallet then return false, 'funds' end
    local ok, done = pcall(function() return exports[Shop]:removeCoins(wallet, amount, reason) end)
    if ok and done == true then return true end

    return false, 'funds'
end

C.Add = function(playerId, amount, reason)
    playerId, amount = Online(playerId), Amount(amount)
    if not playerId or not amount then return false end
    reason = type(reason) == 'string' and reason:sub(1, 120) or GetInvokingResource() or 'fn_bridge'

    local top = Top()
    if top then return Call(top.value.Add, playerId, amount, reason) == true end
    if not Builtin() then return false end

    local wallet = Wallet(playerId)
    if not wallet then return false end
    local ok, done = pcall(function() return exports[Shop]:addCoins(wallet, amount, reason) end)

    return ok and done == true
end
