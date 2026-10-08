local LastJob = {}

FN_JOBS = {}

FN_JOBS.Snapshot = function(job)
    if type(job) ~= 'table' then return nil end

    return {
        name = job.name or 'unemployed',
        label = job.label or 'Unemployed',
        grade = tonumber(job.grade) or 0,
        grade_name = job.grade_name or 'unemployed',
        grade_label = job.grade_label or 'Unemployed',
    }
end

FN_JOBS.Read = function(playerId)
    if not FN_FRAMEWORK then return nil end

    local player = FN_FRAMEWORK.GetPlayerFromId(playerId)
    if not player then return nil end

    return FN_JOBS.Snapshot(player.job)
end

FN_JOBS.Seed = function(playerId)
    playerId = tonumber(playerId)
    if not playerId or playerId <= 0 then return end

    LastJob[playerId] = FN_JOBS.Read(playerId)

    if FN_COUNTER then FN_COUNTER.Sync(playerId) end
end

FN_JOBS.Forget = function(playerId)
    playerId = tonumber(playerId)
    if not playerId then return end

    LastJob[playerId] = nil

    if FN_COUNTER then FN_COUNTER.Remove(playerId) end
end

FN_JOBS.Publish = function(playerId)
    playerId = tonumber(playerId)
    if not playerId or playerId <= 0 then return false end

    if FN_COUNTER then FN_COUNTER.Sync(playerId) end

    local current = FN_JOBS.Read(playerId)
    if not current then return false end

    local previous = LastJob[playerId]
    if previous and previous.name == current.name and previous.grade == current.grade then return false end

    LastJob[playerId] = current
    TriggerEvent('fn_bridge/server/onJobChange', playerId, current, previous)

    return true
end

AddEventHandler('playerDropped', function()
    FN_JOBS.Forget(source)
end)
