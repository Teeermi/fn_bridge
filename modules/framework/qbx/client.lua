if not FN_BRIDGE.IsFramework('qbx') then return end

FN_FRAMEWORK = {}
FN_FRAMEWORK.obj = exports['qbx_core']

local function CallCore(exportName, ...)
    local args = table.pack(...)

    return pcall(function()
        return exports['qbx_core'][exportName](exports['qbx_core'], table.unpack(args, 1, args.n))
    end)
end

local function CoreValue(exportName, ...)
    local ok, result = CallCore(exportName, ...)
    if not ok then return nil end

    return result
end

local function GetPlayerData()
    local playerData = CoreValue('GetPlayerData')
    if type(playerData) ~= 'table' then return {} end

    return playerData
end

local function PublishPlayerData(playerData)
    TriggerEvent('fn_bridge/client/updatePlayerData', playerData or GetPlayerData())
end

RegisterNetEvent('qbx_core:client:playerLoaded', function()
    PublishPlayerData()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PublishPlayerData()
end)

RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
    PublishPlayerData({})
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    PublishPlayerData({})
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(playerData)
    PublishPlayerData(playerData)
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function()
    PublishPlayerData()
end)

FN_FRAMEWORK.GetFrameworkName = function()
    return 'qbx'
end

FN_FRAMEWORK.IsPlayerLoaded = function()
    return LocalPlayer.state.isLoggedIn and true or false
end

FN_FRAMEWORK.GetPlayerData = function()
    return GetPlayerData()
end

FN_FRAMEWORK.GetPlayerGroup = function()
    return LocalPlayer.state.fnGroup
end

FN_FRAMEWORK.GetIdentifier = function()
    local identifier = GetPlayerData().citizenid
    if not identifier then return nil end

    return identifier
end

FN_FRAMEWORK.GetCharId = function()
    return LocalPlayer.state.fn_charId or FN_FRAMEWORK.GetIdentifier()
end

FN_FRAMEWORK.GetName = function()
    local charInfo = GetPlayerData().charinfo
    if not charInfo then return nil end

    return ((charInfo.firstname or '') .. ' ' .. (charInfo.lastname or '')):match('^%s*(.-)%s*$')
end

FN_FRAMEWORK.GetJob = function()
    local job = GetPlayerData().job
    if not job then return { name = 'unemployed', label = 'Unemployed', grade = 0, grade_label = 'Unemployed' } end

    return {
        name = job.name,
        label = job.label,
        grade = job?.grade?.level or 0,
        grade_label = job?.grade?.name or 'Unemployed',
    }
end

FN_FRAMEWORK.GetAccounts = function()
    local money = GetPlayerData().money or {}

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
    info = 'inform',
    success = 'success',
    error = 'error',
}

FN_FRAMEWORK.Notify = function(message, messageType, duration)
    CallCore('Notify', message, FN_FRAMEWORK.notifyTypes[messageType] or 'inform', duration)
end

local HelpTextPositions = {
    left = 'left-center',
    right = 'right-center',
    top = 'top-center',
    bottom = 'bottom',
}

FN_FRAMEWORK.ShowHelpText = function(message, position, options)
    lib.showTextUI(message, FN_NOTIFY.HelpTextOptions(HelpTextPositions[position] or position, options))
end

FN_FRAMEWORK.HideHelpText = function()
    lib.hideTextUI()
end

Config.DebugPrint('framework adapter loaded: qbx (client)')
