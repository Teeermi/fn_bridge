if not FN_BRIDGE.IsFramework('standalone') then return end

FN_FRAMEWORK = {}
FN_FRAMEWORK.obj = {}

FN_FRAMEWORK.GetFrameworkName = function()
    return 'standalone'
end

FN_FRAMEWORK.accountNames = {}

FN_FRAMEWORK.ResolveAccount = function()
    return nil
end

local function License(playerId)
    playerId = tonumber(playerId)
    if not playerId or playerId <= 0 or not GetPlayerName(playerId) then return nil end

    return GetPlayerIdentifierByType(playerId, 'license') or GetPlayerIdentifierByType(playerId, 'license2')
end

local function Group(playerId)
    return IsPlayerAceAllowed(tostring(playerId), 'command') and 'admin' or 'user'
end

local Unemployed = { name = 'unemployed', label = 'Unemployed', grade = 0, grade_name = 'unemployed', grade_label = 'Unemployed' }

local function BuildPlayerData(playerId, license)
    local name = GetPlayerName(playerId) or ''

    return {
        source = playerId,
        identifier = license,
        group = Group(playerId),
        job = Unemployed,
        char = {
            firstName = name,
            lastName = '',
            sex = 'm',
            badge = '',
        },
        showNotification = function(message, _type, duration)
            TriggerClientEvent('fn_bridge/client/notify', playerId, message, _type, duration)
        end,
        getName = function(separate)
            if separate then return { firstname = name, lastname = '' } end

            return name
        end,
        setJob = function() end,
        addAccountMoney = function() return false end,
        removeAccountMoney = function() return false end,
        getAccounts = function() return { cash = 0, bank = 0, black_money = 0 } end,
        addInventoryItem = function(itemName, amount, metadata)
            if FN_INVENTORY then FN_INVENTORY.AddItem(playerId, itemName, amount, metadata) end
        end,
        removeInventoryItem = function(itemName, amount, metadata)
            if FN_INVENTORY then FN_INVENTORY.RemoveItem(playerId, itemName, amount, metadata) end
        end,
        updateChar = function() end,
    }
end

FN_FRAMEWORK.RawPlayer = License

FN_FRAMEWORK.GetIdentifier = function(playerId)
    return License(playerId) or false
end

FN_FRAMEWORK.GetPlayerFromId = function(playerId)
    local license = License(playerId)
    if not license then return false end

    return BuildPlayerData(tonumber(playerId), license)
end

FN_FRAMEWORK.GetPlayerFromIdentifier = function(identifier)
    for _, playerId in ipairs(GetPlayers()) do
        if License(playerId) == identifier then return FN_FRAMEWORK.GetPlayerFromId(playerId) end
    end

    return false
end

FN_FRAMEWORK.GetPlayers = function()
    local players = {}
    for _, playerId in ipairs(GetPlayers()) do
        players[#players + 1] = tonumber(playerId)
    end

    return players
end

FN_FRAMEWORK.GetMoney = function() return 0 end
FN_FRAMEWORK.AddMoney = function() return false end
FN_FRAMEWORK.RemoveMoney = function() return false end
FN_FRAMEWORK.GetJob = function() return false end
FN_FRAMEWORK.SetJob = function() return false end
FN_FRAMEWORK.SetJobOffline = function() return false end
FN_FRAMEWORK.RemoveJob = function() return false end
FN_FRAMEWORK.CheckJobDuty = function() return false end
FN_FRAMEWORK.SetJobDuty = function() return false end
FN_FRAMEWORK.GetJobs = function() return {} end
FN_FRAMEWORK.GetJobMembers = function() return {} end
FN_FRAMEWORK.GetGang = function() return false end
FN_FRAMEWORK.GetNeeds = function() return {} end
FN_FRAMEWORK.GetPlayTime = function() return false end
FN_FRAMEWORK.GetPhoneNumber = function() return false end
FN_FRAMEWORK.SetPhoneNumber = function() return false end
FN_FRAMEWORK.IsPhoneNumberTaken = function() return false end
FN_FRAMEWORK.SetName = function() return false end
FN_FRAMEWORK.IsNameTaken = function() return false end
FN_FRAMEWORK.SearchCharacters = function() return {} end
FN_FRAMEWORK.GetCharacter = function() return false end
FN_FRAMEWORK.AddCharacterSlots = function() return false end
FN_FRAMEWORK.CheckLicense = function() return false end
FN_FRAMEWORK.AddLicense = function() return false end
FN_FRAMEWORK.RemoveLicense = function() return false end

FN_FRAMEWORK.GetOfflineCharName = function(identifier, separate)
    local player = FN_FRAMEWORK.GetPlayerFromIdentifier(identifier)
    if player then return player.getName(separate) end

    return false
end

FN_FRAMEWORK.GetCharactersByIds = function()
    return {}
end

FN_FRAMEWORK.GetCharacters = function(license)
    local hash = type(license) == 'string' and (license:match('^license2?:(%w+)$') or license:match('^%w+$'))
    if not hash then return {} end

    return { { identifier = 'license:' .. hash, name = 'license:' .. hash } }
end

FN_FRAMEWORK.CheckPermissions = function(playerId, groups)
    groups = FN_HELPER.NormalizeGroups(groups)
    if not groups then return false end

    for groupName, wanted in pairs(groups) do
        if wanted and IsPlayerAceAllowed(tostring(playerId), 'group.' .. groupName) then return true end
    end

    return groups[Group(playerId)] or false
end

local Usable = {}

FN_FRAMEWORK.RegisterUsableItem = function(itemName, callback)
    Usable[itemName] = callback
end

FN_FRAMEWORK.UseItem = function(playerId, itemName)
    local callback = Usable[itemName]
    local player = callback and FN_FRAMEWORK.GetPlayerFromId(playerId)
    if player then callback(player, { name = itemName }) end
end

FN_FRAMEWORK.GetItemLabel = function(itemName)
    return itemName
end

FN_FRAMEWORK.GetVehicleByPlate = function(plate)
    return FN_VEHICLES.Get(plate)
end

FN_FRAMEWORK.GetPlayerVehicles = function(identifier)
    return FN_VEHICLES.List(identifier)
end

FN_FRAMEWORK.GetName = function(playerId)
    return License(playerId) and GetPlayerName(playerId) or false
end

FN_FRAMEWORK.GetVehicleCatalog = function()
    return {}
end

FN_FRAMEWORK.Supports = function(feature)
    return feature == 'vehicles'
end

local Loaded = {}

local function OnPlayerLoaded(playerId)
    playerId = tonumber(playerId)
    if not playerId or Loaded[playerId] or not License(playerId) then return end

    Loaded[playerId] = true
    Player(playerId).state:set('fnGroup', Group(playerId), true)
    FN_JOBS.Seed(playerId)
    TriggerEvent('fn_bridge/server/playerLoaded', playerId, FN_FRAMEWORK.GetPlayerFromId(playerId))
end

RegisterNetEvent('fn_bridge/server/standaloneLoaded', function()
    OnPlayerLoaded(source)
end)

AddEventHandler('playerDropped', function()
    Loaded[source] = nil
    FN_JOBS.Forget(source)
end)

CreateThread(function()
    for _, playerId in ipairs(GetPlayers()) do
        OnPlayerLoaded(playerId)
    end
end)

lib.callback.register('fn_bridge/server/checkPermissions', FN_FRAMEWORK.CheckPermissions)

lib.callback.register('fn_bridge/server/getAccounts', function()
    return { cash = 0, bank = 0, black_money = 0 }
end)

Config.DebugPrint('framework adapter loaded: standalone (server)')
