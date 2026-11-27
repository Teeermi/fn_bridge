if not FN_FRAMEWORK then return end

local Name = FN_BRIDGE.frameworkName
local Qb = Name == 'qb' or Name == 'qbx'
local Keys = { 'hunger', 'thirst', 'stress' }
local Needs = {}
local Sent = {}
local Pending = false

local function Percent(value)
    value = tonumber(value)
    if not value or value ~= value then return nil end

    return math.max(0, math.min(100, math.floor(value + 0.5)))
end

local function Copy()
    return { hunger = Needs.hunger, thirst = Needs.thirst, stress = Needs.stress }
end

local function Emit()
    Pending = false
    local ok, values = pcall(FN_FRAMEWORK.GetNeeds)
    if not ok or type(values) ~= 'table' then return end

    local payload, changed = {}, false
    for _, key in ipairs(Keys) do
        payload[key] = Percent(values[key])
        if payload[key] ~= Sent[key] then changed = true end
    end
    if not changed then return end

    Sent = payload
    TriggerEvent('fn_bridge/client/onNeedsChange', { hunger = payload.hunger, thirst = payload.thirst, stress = payload.stress })
end

local function Queue()
    if Pending then return end

    Pending = true
    SetTimeout(0, Emit)
end

AddEventHandler('fn_bridge/client/refreshNeeds', Queue)

local function SetNeeds(values)
    local changed = false
    for _, key in ipairs(Keys) do
        local value = Percent(values[key])
        if value and value ~= Needs[key] then
            Needs[key] = value
            changed = true
        end
    end

    if changed then Queue() end
end

local function ReadMetadata(data)
    local metadata = type(data) == 'table' and data.metadata
    if type(metadata) == 'table' then SetNeeds(metadata) end
end

if Qb then
    AddEventHandler('fn_bridge/client/updatePlayerData', ReadMetadata)
    RegisterNetEvent('hud:client:UpdateNeeds', function(hunger, thirst) SetNeeds({ hunger = hunger, thirst = thirst }) end)
    RegisterNetEvent('hud:client:UpdateStress', function(stress) SetNeeds({ stress = stress }) end)
elseif Name == 'esx' then
    AddEventHandler('esx_status:onTick', function(list)
        if type(list) ~= 'table' then return end

        local values = {}
        for _, status in ipairs(list) do
            if type(status) == 'table' and (status.name == 'hunger' or status.name == 'thirst' or status.name == 'stress') then
                values[status.name] = tonumber(status.percent) or (tonumber(status.val) and tonumber(status.val) / 10000)
            end
        end
        SetNeeds(values)
    end)
elseif Name == 'ox' then
    AddEventHandler('ox:statusTick', function(statuses)
        if type(statuses) ~= 'table' then return end

        local hunger, thirst = tonumber(statuses.hunger), tonumber(statuses.thirst)
        SetNeeds({ hunger = hunger and 100 - hunger, thirst = thirst and 100 - thirst, stress = statuses.stress })
    end)
end

FN_FRAMEWORK.GetNeeds = function()
    if Qb and not (Needs.hunger and Needs.thirst and Needs.stress) then
        local data = FN_FRAMEWORK.GetPlayerData()
        local metadata = type(data) == 'table' and data.metadata
        if type(metadata) == 'table' then
            for _, key in ipairs(Keys) do
                if Needs[key] == nil then Needs[key] = Percent(metadata[key]) end
            end
        end
    end

    return Copy()
end

local function GangView(name, grade, label, gradeName, gradeLabel, boss)
    if type(name) ~= 'string' or name == '' or name == 'none' or name == 'unemployed' then return false end

    return { name = name, label = label or name, grade = tonumber(grade) or 0, grade_name = gradeName or '', grade_label = gradeLabel or gradeName or '', isBoss = boss == true }
end

FN_FRAMEWORK.GetGang = function()
    if not Qb and Name ~= 'esx' then return false end

    local data = FN_FRAMEWORK.GetPlayerData()
    if type(data) ~= 'table' then return false end

    if Name == 'esx' then
        if GlobalState['fn_bridge:esxGangs'] ~= true then return false end

        local h = data.hiddenjob
        if type(h) ~= 'table' then return false end

        return GangView(h.name, h.grade, h.label, h.grade_name, h.grade_label, h.grade_name == 'boss')
    end

    local gang = data.gang
    if type(gang) ~= 'table' then return false end

    local grade = type(gang.grade) == 'table' and gang.grade or {}
    return GangView(gang.name, grade.level, gang.label, grade.name, grade.name, gang.isboss)
end
