FN_STAFF = {}

local Priority = { fn_mdt = 1 }

FN_STAFF.Host = function(jobName)
    if type(jobName) ~= 'string' or jobName == '' then return nil end

    local best, rank
    for _, entry in ipairs(FN_BRIDGE.ProvidersOf('staff')) do
        if FN_BRIDGE.Callable(entry.value) and GetResourceState(entry.resource) == 'started' then
            local ok, hosts = pcall(entry.value, jobName)
            local mine = Priority[entry.resource] or 2
            if ok and hosts == true and (not rank or mine < rank) then best, rank = entry.resource, mine end
        end
    end

    return best
end

FN_STAFF.Call = function(jobName, exportName, ...)
    local host = FN_STAFF.Host(jobName)
    if not host or type(exportName) ~= 'string' then return nil end

    local args = table.pack(...)
    local ok, result, extra = pcall(function() return exports[host][exportName](exports[host], table.unpack(args, 1, args.n)) end)
    if not ok then return nil end

    return result, extra
end
