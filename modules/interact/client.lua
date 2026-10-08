FN_INTERACT = {}

FN_INTERACT.IsCuffed = function()
    local hook = FN_BRIDGE.Setting('interact')
    if type(hook) == 'table' and FN_BRIDGE.Callable(hook.isCuffed) then
        local ok, value = pcall(hook.isCuffed)
        if ok and value ~= nil then return value == true end
    end

    local data = FN_FRAMEWORK and FN_FRAMEWORK.GetPlayerData and FN_FRAMEWORK.GetPlayerData()
    if type(data) == 'table' and type(data.metadata) == 'table' and data.metadata.ishandcuffed == true then return true end

    local state = LocalPlayer.state
    if state.isHandcuffed == true or state.handcuffed == true or state.cuffed == true then return true end

    return IsPedCuffed(PlayerPedId())
end
