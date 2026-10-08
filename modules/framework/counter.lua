if not FN_FRAMEWORK then return end

local JobsPlayers = {}
local PlayerJob = {}
local Counts = {}

local dirty = false
local published = false

FN_COUNTER = {}

local function CounterConfig()
    if type(Config.Counter) ~= 'table' then return {} end

    return Config.Counter
end

local function DutyAware()
    return CounterConfig().dutyAware and true or false
end

local function ReadDuty(playerId)
    local ok, onDuty = pcall(FN_FRAMEWORK.CheckJobDuty, playerId)

    return (ok and onDuty) and true or false
end

local function BuildEntry(playerId, player, previous)
    local job = player?.job or {}
    local identifier = player.identifier or ''
    local carried = previous and previous.identifier == identifier and previous.charId

    return {
        source = playerId,
        identifier = identifier,
        charId = carried or FN_FRAMEWORK.GetCharId(identifier),
        job = job.name or 'unemployed',
        grade = tonumber(job.grade) or 0,
        grade_name = job.grade_name or 'unemployed',
        grade_label = job.grade_label or 'Unemployed',
        group = player.group or 'user',
        onDuty = ReadDuty(playerId),
    }
end

local function CopyEntry(entry)
    local copy = {}
    for key, value in pairs(entry) do copy[key] = value end

    return copy
end

local function CountBucket(bucket, dutyAware)
    local total = 0

    for _, entry in pairs(bucket or {}) do
        if not dutyAware or entry.onDuty then total = total + 1 end
    end

    return total
end

local function CountAdmins()
    local groups = {}
    for _, group in ipairs(Config.AdminGroups or {}) do groups[group] = true end

    local total = 0
    for _, bucket in pairs(JobsPlayers) do
        for _, entry in pairs(bucket) do
            if groups[entry.group] then total = total + 1 end
        end
    end

    return total
end

local function BuildCounts()
    local dutyAware = DutyAware()
    local counts = {}

    for _, jobName in ipairs(CounterConfig().jobs or {}) do
        if type(jobName) == 'string' then counts[jobName] = 0 end
    end

    for jobName in pairs(Counts) do counts[jobName] = 0 end

    for jobName, bucket in pairs(JobsPlayers) do
        counts[jobName] = CountBucket(bucket, dutyAware)
    end

    counts.admin = CountAdmins()

    return counts
end

FN_COUNTER.Flush = function()
    dirty = false

    local counts = BuildCounts()
    local changed = {}

    for jobName, total in pairs(counts) do
        local previous = Counts[jobName] or 0
        if previous ~= total then
            changed[#changed + 1] = { jobName, total, previous }
        end
    end

    if published and #changed == 0 then return false end

    Counts = counts
    published = true
    GlobalState.fn_jobCounter = counts

    for _, change in ipairs(changed) do
        TriggerEvent('fn_bridge/server/jobCountChanged', change[1], change[2], change[3])
    end

    return true
end

local function MarkDirty()
    if dirty then return end

    dirty = true

    CreateThread(function()
        Wait(0)
        if not dirty then return end

        FN_COUNTER.Flush()
    end)
end

FN_COUNTER.Sync = function(playerId)
    playerId = tonumber(playerId)
    if not playerId or playerId <= 0 then return false end

    local player = FN_FRAMEWORK.GetPlayerFromId(playerId)
    if not player then return false end

    local jobName = player?.job?.name or 'unemployed'
    local lastJobName = PlayerJob[playerId]
    local previous = lastJobName and JobsPlayers[lastJobName] and JobsPlayers[lastJobName][playerId] or nil

    if lastJobName and lastJobName ~= jobName and JobsPlayers[lastJobName] then
        JobsPlayers[lastJobName][playerId] = nil
    end

    local entry = BuildEntry(playerId, player, previous)

    JobsPlayers[jobName] = JobsPlayers[jobName] or {}
    JobsPlayers[jobName][playerId] = entry
    PlayerJob[playerId] = jobName

    if not previous or lastJobName ~= jobName or previous.onDuty ~= entry.onDuty or previous.group ~= entry.group then
        MarkDirty()
    end

    return true
end

FN_COUNTER.Remove = function(playerId)
    playerId = tonumber(playerId)
    if not playerId then return false end

    local jobName = PlayerJob[playerId]
    PlayerJob[playerId] = nil
    if not jobName then return false end

    if JobsPlayers[jobName] then JobsPlayers[jobName][playerId] = nil end

    MarkDirty()

    return true
end

FN_FRAMEWORK.jobsPlayers = JobsPlayers
FN_FRAMEWORK.playerJob = PlayerJob

FN_FRAMEWORK.GetJobPlayers = function(jobName)
    local players = {}
    if type(jobName) ~= 'string' then return players end

    for _, entry in pairs(JobsPlayers[jobName] or {}) do
        players[#players + 1] = CopyEntry(entry)
    end

    return players
end

FN_FRAMEWORK.GetJobPlayerCount = function(jobName)
    if type(jobName) ~= 'string' then return 0 end

    return CountBucket(JobsPlayers[jobName], DutyAware())
end

FN_FRAMEWORK.GetPlayerJobEntry = function(playerId)
    playerId = tonumber(playerId)
    if not playerId then return false end

    local jobName = PlayerJob[playerId]
    local entry = jobName and JobsPlayers[jobName] and JobsPlayers[jobName][playerId]
    if not entry then return false end

    return CopyEntry(entry)
end

FN_FRAMEWORK.GetCounter = function(counter)
    if type(counter) ~= 'string' then return 0 end
    if counter == 'admin' then return CountAdmins() end

    return FN_FRAMEWORK.GetJobPlayerCount(counter)
end

local function WarnOnAdminJob()
    local ok, jobs = pcall(FN_FRAMEWORK.GetJobs)
    if not ok or type(jobs) ~= 'table' or not jobs.admin then return end

    print('^3this server has a job named^7 admin^3, which collides with the staff count^7 - GlobalState.fn_jobCounter.admin reports staff, not that job.')
end

CreateThread(function()
    local deadline = GetGameTimer() + 30000

    while not FN_FRAMEWORK.obj do
        if GetGameTimer() > deadline then return end
        Wait(100)
    end

    WarnOnAdminJob()

    local players = FN_FRAMEWORK.GetPlayers()
    for _, playerId in ipairs(players) do
        if FN_JOBS then
            FN_JOBS.Seed(playerId)
        else
            FN_COUNTER.Sync(playerId)
        end
    end

    FN_COUNTER.Flush()

    Config.DebugPrint('job registry rebuilt: '..#players..' players')
end)
