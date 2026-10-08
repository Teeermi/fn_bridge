if not FN_BRIDGE.IsFramework('qb') then return end

local function GetCoreObject()
    local ok, coreObject = pcall(function()
        return exports['qb-core']:GetCoreObject()
    end)

    if not ok or type(coreObject) ~= 'table' then
        ok, coreObject = pcall(function()
            return exports['qb-core']:getSharedObject()
        end)
    end

    if not ok or type(coreObject) ~= 'table' then return nil end

    return coreObject
end

FN_FRAMEWORK = {}
FN_FRAMEWORK.obj = GetCoreObject()

if not FN_FRAMEWORK.obj then
    CreateThread(function()
        local deadline = GetGameTimer() + 30000
        repeat
            Wait(100)
            FN_FRAMEWORK.obj = GetCoreObject()
        until FN_FRAMEWORK.obj or GetGameTimer() > deadline

        if not FN_FRAMEWORK.obj then
            print('^1qb-core never returned a core object^7 - start fn_bridge after qb-core.')
        end
    end)
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    if not FN_FRAMEWORK?.obj then return print('QBCore framework object not found.') end
    TriggerEvent('fn_bridge/client/updatePlayerData', FN_FRAMEWORK.obj.PlayerData)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    if not FN_FRAMEWORK?.obj then return end
    TriggerEvent('fn_bridge/client/updatePlayerData', FN_FRAMEWORK.obj.PlayerData or {})
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(playerData)
    TriggerEvent('fn_bridge/client/updatePlayerData', playerData)
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function()
    if not FN_FRAMEWORK?.obj then return end
    TriggerEvent('fn_bridge/client/updatePlayerData', FN_FRAMEWORK.obj.PlayerData)
end)

FN_FRAMEWORK.GetFrameworkName = function()
    return 'qb'
end

FN_FRAMEWORK.IsPlayerLoaded = function()
    return LocalPlayer.state.isLoggedIn and true or false
end

FN_FRAMEWORK.GetPlayerData = function()
    return FN_FRAMEWORK.obj?.PlayerData or {}
end

FN_FRAMEWORK.GetPlayerGroup = function()
    return LocalPlayer.state.fnGroup
end

FN_FRAMEWORK.GetIdentifier = function()
    local identifier = FN_FRAMEWORK.obj?.PlayerData?.citizenid
    if not identifier then return nil end

    return identifier
end

FN_FRAMEWORK.GetCharId = function()
    return LocalPlayer.state.fn_charId or FN_FRAMEWORK.GetIdentifier()
end

FN_FRAMEWORK.GetName = function()
    local charInfo = FN_FRAMEWORK.obj?.PlayerData?.charinfo
    if not charInfo then return nil end

    return ((charInfo.firstname or '') .. ' ' .. (charInfo.lastname or '')):match('^%s*(.-)%s*$')
end

FN_FRAMEWORK.GetJob = function()
    local job = FN_FRAMEWORK.obj?.PlayerData?.job
    if not job then return { name = 'unemployed', label = 'Unemployed', grade = 0, grade_label = 'Unemployed' } end

    return {
        name = job.name,
        label = job.label,
        grade = job?.grade?.level or 0,
        grade_label = job?.grade?.name or 'Unemployed',
    }
end

FN_FRAMEWORK.GetAccounts = function()
    local money = FN_FRAMEWORK.obj?.PlayerData?.money or {}

    return {
        cash = money.cash or 0,
        bank = money.bank or 0,
        black_money = 0,
    }
end

FN_FRAMEWORK.GetMoney = function(accountName)
    return FN_FRAMEWORK.GetAccounts()[accountName] or 0
end

FN_FRAMEWORK.notifyTypes = {
    info = 'primary',
    success = 'success',
    error = 'error',
}

FN_FRAMEWORK.Notify = function(message, messageType, time)
    FN_FRAMEWORK.obj.Functions.Notify(message, FN_FRAMEWORK.notifyTypes[messageType] or 'primary', time)
end

FN_FRAMEWORK.ShowHelpText = function(message, position)
    exports['qb-core']:DrawText(message, position or 'left')
end

FN_FRAMEWORK.HideHelpText = function()
    exports['qb-core']:HideText()
end

Config.DebugPrint('framework adapter loaded: qb (client)')
