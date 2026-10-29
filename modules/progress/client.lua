FN_PROGRESS = {}

local running

local function Own(resource)
    local own = FN_BRIDGE.Setting('progress', resource)
    if FN_BRIDGE.Callable(own) then return { Bar = own } end
    if type(own) == 'table' and FN_BRIDGE.Callable(own.Bar) then return own end
end

local function Options(opts)
    local out = {}
    for k, v in pairs(type(opts) == 'table' and opts or {}) do out[k] = v end
    out.duration = math.max(0, math.floor(tonumber(out.duration) or 0))
    out.label = tostring(out.label or '')
    if out.canCancel == nil then out.canCancel = true end
    if out.useWhileDead == nil then out.useWhileDead = false end
    return out
end

FN_PROGRESS.Name = function(resource)
    if Own(resource or GetInvokingResource()) then return FN_BRIDGE.Provider('progress') or 'hook' end
    return lib and lib.progressBar and 'ox_lib' or false
end

FN_PROGRESS.Bar = function(opts)
    local resource = GetInvokingResource()
    if running then return false end
    opts = Options(opts)
    local own = Own(resource)
    running = own or true
    local ok, done = pcall(function()
        if own then return own.Bar(opts) end
        if lib and lib.progressBar then
            if opts.circle then return lib.progressCircle(opts) end
            return lib.progressBar(opts)
        end
        Wait(opts.duration)
        return true
    end)
    running = nil
    if not ok then
        print(('^3the progress bar from %s failed^7 - %s'):format(own and (FN_BRIDGE.Provider('progress') or 'Config.Bridge.progress') or 'ox_lib', tostring(done)))
        return false
    end
    return done == true
end

FN_PROGRESS.Cancel = function()
    if type(running) == 'table' then
        if FN_BRIDGE.Callable(running.Cancel) then pcall(running.Cancel) end
        return true
    end
    if running and lib and lib.cancelProgress then
        lib.cancelProgress()
        return true
    end
    return false
end

FN_PROGRESS.IsActive = function()
    if type(running) == 'table' and FN_BRIDGE.Callable(running.IsActive) then
        local ok, on = pcall(running.IsActive)
        if ok then return on == true end
    end
    return running ~= nil
end
