if not FN_BRIDGE.IsSociety('qb-management') then return end

FN_SOCIETY = {}

local Banks = {
    { resource = 'qb-banking', get = 'GetAccountBalance', add = 'AddMoney', remove = 'RemoveMoney' },
    { resource = 'Renewed-Banking', get = 'getAccountMoney', add = 'addAccountMoney', remove = 'removeAccountMoney' },
}

local Kind = { GetAccount = 'get', GetGangAccount = 'get', AddMoney = 'add', AddGangMoney = 'add', RemoveMoney = 'remove', RemoveGangMoney = 'remove' }

local function Call(resource, method, ...)
    local args = table.pack(...)

    return pcall(function() return exports[resource][method](exports[resource], table.unpack(args, 1, args.n)) end)
end

local function SafeExport(method, ...)
    local ok, result = Call('qb-management', method, ...)
    if ok then return result end

    for _, bank in ipairs(Banks) do
        if GetResourceState(bank.resource) == 'started' then
            ok, result = Call(bank.resource, bank[Kind[method]], ...)
            return ok and result or nil
        end
    end
end

local function Ops(get, add, remove)
    return {
        GetMoney = function(name)
            return tonumber(SafeExport(get, name)) or 0
        end,
        AddMoney = function(name, amount)
            if type(amount) ~= 'number' or amount <= 0 then return false end

            return SafeExport(add, name, amount) and true or false
        end,
        RemoveMoney = function(name, amount)
            if type(amount) ~= 'number' or amount <= 0 or tonumber(SafeExport(get, name) or 0) < amount then return false end

            return SafeExport(remove, name, amount) and true or false
        end,
    }
end

local Jobs = Ops('GetAccount', 'AddMoney', 'RemoveMoney')

FN_SOCIETY.GetMoney = Jobs.GetMoney
FN_SOCIETY.AddMoney = Jobs.AddMoney
FN_SOCIETY.RemoveMoney = Jobs.RemoveMoney
FN_SOCIETY.Gang = Ops('GetGangAccount', 'AddGangMoney', 'RemoveGangMoney')

Config.DebugPrint('society adapter loaded: qb-management (server)')
