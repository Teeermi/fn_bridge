local Mirrored = { ox = true, vrp = true, standalone = true }
if not Mirrored[FN_BRIDGE.frameworkName] then return end

FN_FRAMEWORK = {}
FN_FRAMEWORK.obj = {}

local PlayerData

local function Publish(data)
    PlayerData = type(data) == 'table' and data or nil
    TriggerEvent('fn_bridge/client/updatePlayerData', PlayerData or {})
end

RegisterNetEvent('fn_bridge/client/mirror', Publish)

AddEventHandler('ox:playerLogout', function()
    Publish(nil)
end)

CreateThread(function()
    if FN_BRIDGE.IsFramework('standalone') then TriggerServerEvent('fn_bridge/server/standaloneLoaded') end

    local data = lib.callback.await('fn_bridge/server/mirror', false)
    if data then Publish(data) end
end)

AddEventHandler('playerSpawned', function()
    if FN_BRIDGE.IsFramework('standalone') and not PlayerData then TriggerServerEvent('fn_bridge/server/standaloneLoaded') end
end)

FN_FRAMEWORK.GetFrameworkName = function()
    return FN_BRIDGE.frameworkName
end

FN_FRAMEWORK.IsPlayerLoaded = function()
    return PlayerData ~= nil
end

FN_FRAMEWORK.GetPlayerData = function()
    return PlayerData or {}
end

FN_FRAMEWORK.GetPlayerGroup = function()
    return LocalPlayer.state.fnGroup or (PlayerData and PlayerData.group)
end

FN_FRAMEWORK.GetIdentifier = function()
    return PlayerData and PlayerData.identifier or nil
end

FN_FRAMEWORK.GetCharId = function()
    return LocalPlayer.state.fn_charId or FN_FRAMEWORK.GetIdentifier()
end

FN_FRAMEWORK.GetName = function()
    return PlayerData and PlayerData.name or nil
end

FN_FRAMEWORK.GetJob = function()
    local job = PlayerData and PlayerData.job
    if type(job) ~= 'table' then return { name = 'unemployed', label = 'Unemployed', grade = 0, grade_label = 'Unemployed' } end

    return {
        name = job.name,
        label = job.label,
        grade = job.grade or 0,
        grade_label = job.grade_label or '',
    }
end

FN_FRAMEWORK.GetAccounts = function()
    return lib.callback.await('fn_bridge/server/getAccounts', false) or { cash = 0, bank = 0, black_money = 0 }
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
    lib.notify({ description = message, type = FN_FRAMEWORK.notifyTypes[messageType] or 'inform', duration = duration })
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

Config.DebugPrint('framework adapter loaded: ' .. FN_BRIDGE.frameworkName .. ' (client mirror)')
