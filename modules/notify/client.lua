FN_NOTIFY = {}

FN_NOTIFY.informTypes = {
    info = 'inform',
    success = 'success',
    error = 'error',
}

FN_NOTIFY.notifiers = {
    framework = function(message, messageType, time)
        return FN_FRAMEWORK.Notify(message, messageType, time)
    end,
    ox = function(message, messageType)
        return lib.notify({ description = message, type = FN_NOTIFY.informTypes[messageType] or messageType, position = 'top-right' })
    end,
    mythic = function(message, messageType, time)
        return exports['mythic_notify']:SendAlert(FN_NOTIFY.informTypes[messageType] or 'inform', message, time)
    end,
    pNotify = function(message, messageType, time)
        return exports['pNotify']:SendNotification({ text = message, type = messageType, timeout = time, layout = 'centerRight' })
    end,
    okok = function(message, messageType, time)
        return exports['okokNotify']:Alert('Notification', message, time, messageType, false)
    end,
    ['t-notify'] = function(message, messageType, time)
        return exports['t-notify']:Alert({ style = messageType, message = message, duration = time })
    end,
    vms_notifyv2 = function(message, messageType, time)
        return exports['vms_notifyv2']:Notification({ type = messageType, description = message, duration = time })
    end,
    wasabi_uikit = function(message, messageType, time)
        return exports['wasabi_uikit']:Notification({ title = message, type = messageType, time = time })
    end,
    wasabi = function(message, messageType, time)
        return exports['wasabi_notify']:notify(nil, message, time, messageType)
    end,
    lation_ui = function(message, messageType)
        return exports['lation_ui']:notify({ message = message, type = messageType })
    end,
    brutal_notify = function(message, messageType, time)
        return exports['brutal_notify']:SendAlert('Brutal Notify', message, time, messageType)
    end,
    ['g-notifications'] = function(message, messageType)
        return exports['g-notifications']:Notify({ title = 'Notification', description = message, type = messageType })
    end,
    is_ui = function(message, messageType, time)
        return exports['is_ui']:Notify(message, nil, time, messageType)
    end,
    r_notify = function(message, messageType, time)
        return exports['r_notify']:notify({ title = 'Notification', content = message, type = messageType, icon = 'fas fa-check', duration = time, position = 'top-right', sound = false })
    end,
}

FN_NOTIFY.helpTextShow = {
    framework = function(message, position, options)
        return FN_FRAMEWORK.ShowHelpText(message, position, options)
    end,
    ox = function(message, position, options)
        return lib.showTextUI(message, FN_NOTIFY.HelpTextOptions(position, options))
    end,
    jg = function(message)
        return exports['jg-textui']:DrawText(message)
    end,
    okok = function(message, position)
        return exports['okokTextUI']:Open(message, 'darkblue', position or 'left', false)
    end,
    cd = function(message)
        return TriggerEvent('cd_drawtextui:ShowUI', 'show', message)
    end,
    lab = function(message)
        return exports['lab-HintUI']:Show(message, 'Hint Text')
    end,
}

FN_NOTIFY.helpTextHide = {
    framework = function()
        return FN_FRAMEWORK.HideHelpText()
    end,
    ox = function()
        return lib.hideTextUI()
    end,
    jg = function()
        return exports['jg-textui']:HideText()
    end,
    okok = function()
        return exports['okokTextUI']:Close()
    end,
    cd = function()
        return TriggerEvent('cd_drawtextui:ShowUI', 'hide')
    end,
    lab = function()
        return exports['lab-HintUI']:Hide()
    end,
}

local function Own(key, resource)
    local own = FN_BRIDGE.Setting(key, resource)

    return FN_BRIDGE.Callable(own) and own or nil
end

local function Notify(resource, message, messageType, time)
    if messageType == 'inform' then messageType = 'info' end
    TriggerEvent('fn_bridge/client/notified', message, messageType or 'info', resource or GetInvokingResource())
    local notifier = Own('notify', resource) or FN_NOTIFY.notifiers[FN_BRIDGE.notifyName]
    if not notifier then return false end

    return notifier(message, messageType or 'info', time or 5000)
end

FN_NOTIFY.Notify = function(message, messageType, time)
    return Notify(nil, message, messageType, time)
end

FN_NOTIFY.HelpTextOptions = function(position, options)
    local resolved = {}

    if type(options) == 'table' then
        for key, value in pairs(options) do
            resolved[key] = value
        end
    end

    resolved.position = position or resolved.position or 'left-center'

    return resolved
end

FN_NOTIFY.ShowHelpText = function(message, position, options)
    local show = Own('showHelp') or FN_NOTIFY.helpTextShow[FN_BRIDGE.helpTextName]
    if not show then return false end

    return show(message, position, options)
end

FN_NOTIFY.HideHelpText = function()
    local hide = Own('hideHelp') or FN_NOTIFY.helpTextHide[FN_BRIDGE.helpTextName]
    if not hide then return false end

    return hide()
end

FN_NOTIFY.SupportedNames = function(adapters)
    local names = {}
    for name in pairs(adapters) do
        names[#names + 1] = name
    end
    table.sort(names)

    return names
end

RegisterNetEvent('fn_bridge/client/notify', function(message, messageType, time, resource)
    Notify(resource, message, messageType, time)
end)

CreateThread(function()
    if not FN_NOTIFY.notifiers[FN_BRIDGE.notifyName] then
        print('^3setr fn_bridge:notify is "'..tostring(FN_BRIDGE.notifyName)..'"^7 which nothing here implements, so notifications are off. Supported: '..table.concat(FN_NOTIFY.SupportedNames(FN_NOTIFY.notifiers), ', '))
    end

    if not FN_NOTIFY.helpTextShow[FN_BRIDGE.helpTextName] then
        print('^3setr fn_bridge:helptext is "'..tostring(FN_BRIDGE.helpTextName)..'"^7 which nothing here implements, so help text is off. Supported: '..table.concat(FN_NOTIFY.SupportedNames(FN_NOTIFY.helpTextShow), ', '))
    end
end)

Config.DebugPrint('notify adapter loaded: '..tostring(FN_BRIDGE.notifyName)..', help text adapter loaded: '..tostring(FN_BRIDGE.helpTextName)..' (client)')
