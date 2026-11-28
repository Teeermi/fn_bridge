FN_LEVELING = {}

local L = FN_LEVELING
local Script = 'fn_leveling'

FN_KNOWN[Script] = 'leveling'

local function Hook(resource, name)
    local hook = FN_BRIDGE.Setting('leveling', resource)
    if FN_BRIDGE.Callable(hook) then return name == 'Award' and hook or nil end
    hook = type(hook) == 'table' and hook[name] or nil

    return FN_BRIDGE.Callable(hook) and hook or nil
end

L.Name = function()
    if GetResourceState(Script) == 'started' then return Script end

    return FN_BRIDGE.Provider('leveling') or false
end

L.Award = function(playerId, tier, reason)
    local resource = GetInvokingResource() or FN_BRIDGE.resourceName
    if GetResourceState(Script) == 'started' then
        local ok, granted, code = pcall(function() return exports[Script]:AwardProgress(playerId, tier, reason, resource) end)
        if ok then return granted, code end

        return 0
    end

    local hook = Hook(resource, 'Award')
    if not hook then return 0 end
    local ok, granted, code = pcall(hook, playerId, tier, reason, resource)

    return ok and granted or 0, ok and code or nil
end

L.Get = function(playerId)
    if GetResourceState(Script) == 'started' then
        local ok, progress = pcall(function() return exports[Script]:GetProgress(playerId) end)

        return ok and type(progress) == 'table' and progress or nil
    end

    local hook = Hook(GetInvokingResource(), 'Get')
    if not hook then return nil end
    local ok, progress = pcall(hook, playerId)

    return ok and type(progress) == 'table' and progress or nil
end

FN_BRIDGE.LEVELING = FN_BRIDGE.Overridable('LEVELING', L)
