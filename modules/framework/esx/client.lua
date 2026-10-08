if not FN_BRIDGE.IsFramework('esx') then return end

local function GetSharedObject()
    local ok, sharedObject = pcall(function()
        return exports['es_extended']:getSharedObject()
    end)

    if not ok or type(sharedObject) ~= 'table' then return nil end

    return sharedObject
end

FN_FRAMEWORK = {}
FN_FRAMEWORK.obj = GetSharedObject()

if not FN_FRAMEWORK.obj then
    CreateThread(function()
        local deadline = GetGameTimer() + 30000
        repeat
            Wait(100)
            FN_FRAMEWORK.obj = GetSharedObject()
        until FN_FRAMEWORK.obj or GetGameTimer() > deadline

        if not FN_FRAMEWORK.obj then
            print('^1es_extended never returned a shared object^7 - start fn_bridge after es_extended.')
        end
    end)
end

RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    if not FN_FRAMEWORK?.obj then return print('ESX framework object not found.') end
    FN_FRAMEWORK.obj.PlayerData = xPlayer
    TriggerEvent('fn_bridge/client/updatePlayerData', FN_FRAMEWORK.obj.PlayerData)
end)

RegisterNetEvent('esx:onPlayerLogout', function()
    if not FN_FRAMEWORK?.obj then return end
    FN_FRAMEWORK.obj.PlayerData = {}
    TriggerEvent('fn_bridge/client/updatePlayerData', FN_FRAMEWORK.obj.PlayerData)
end)

RegisterNetEvent('esx:setJob', function(job)
    if not FN_FRAMEWORK?.obj?.PlayerData then return end
    FN_FRAMEWORK.obj.PlayerData.job = job
    TriggerEvent('fn_bridge/client/updatePlayerData', FN_FRAMEWORK.obj.PlayerData)
end)

FN_FRAMEWORK.GetFrameworkName = function()
    return 'esx'
end

FN_FRAMEWORK.IsPlayerLoaded = function()
    return FN_FRAMEWORK.obj.IsPlayerLoaded()
end

FN_FRAMEWORK.GetPlayerData = function()
    return FN_FRAMEWORK.obj.GetPlayerData()
end

FN_FRAMEWORK.GetPlayerGroup = function()
    local playerGroup = FN_FRAMEWORK.obj?.PlayerData?.group
    if not playerGroup then return nil end

    return playerGroup
end

FN_FRAMEWORK.GetIdentifier = function()
    local identifier = FN_FRAMEWORK.obj?.PlayerData?.identifier
    if not identifier then return nil end

    return identifier
end

FN_FRAMEWORK.GetCharId = function()
    return LocalPlayer.state.fn_charId or FN_FRAMEWORK.GetIdentifier()
end

FN_FRAMEWORK.GetName = function()
    local playerData = FN_FRAMEWORK.GetPlayerData()
    if not playerData then return nil end

    return playerData.firstName..' '..playerData.lastName
end

FN_FRAMEWORK.GetJob = function()
    local playerData = FN_FRAMEWORK.obj.PlayerData
    if not playerData?.job then return { name = 'unemployed', label = 'Unemployed', grade = 0, grade_label = 'Unemployed' } end

    return {
        name = playerData.job.name,
        label = playerData.job.label,
        grade = playerData.job.grade,
        grade_label = playerData.job.grade_label,
    }
end

FN_FRAMEWORK.accountNames = {
    money = 'cash',
    bank = 'bank',
    black_money = 'black_money',
}

FN_FRAMEWORK.GetAccounts = function()
    local accounts = { cash = 0, bank = 0, black_money = 0 }
    local playerData = FN_FRAMEWORK.GetPlayerData()

    for _, account in ipairs(playerData?.accounts or {}) do
        local accountName = FN_FRAMEWORK.accountNames[account.name]
        if accountName then accounts[accountName] = account.money or 0 end
    end

    return accounts
end

FN_FRAMEWORK.GetMoney = function(accountName)
    return FN_FRAMEWORK.GetAccounts()[accountName] or 0
end

FN_FRAMEWORK.Notify = function(message, messageType, time)
    FN_FRAMEWORK.obj.ShowNotification(message, messageType, time)
end

FN_FRAMEWORK.ShowHelpText = function(message)
    FN_FRAMEWORK.obj.ShowHelpNotification(message)
end

FN_FRAMEWORK.HideHelpText = function()
    return true
end

Config.DebugPrint('framework adapter loaded: esx (client)')
