FN_APPEARANCE = {}

local A = FN_APPEARANCE
local Resources = { 'illenium-appearance', 'fivem-appearance', 'qb-clothing', 'skinchanger' }
local Props = { 0, 1, 2, 6, 7 }

local function Hook(name)
    local hook = FN_BRIDGE.Setting('appearance')
    local fn = type(hook) == 'table' and hook[name]

    return FN_BRIDGE.Callable(fn) and fn or nil
end

A.Name = function()
    for _, resource in ipairs(Resources) do
        if GetResourceState(resource) == 'started' then return resource end
    end

    return false
end

A.Get = function()
    local ped = PlayerPedId()
    local outfit = { model = GetEntityModel(ped), components = {}, props = {} }

    for id = 0, 11 do
        outfit.components[#outfit.components + 1] = { id = id, drawable = GetPedDrawableVariation(ped, id), texture = GetPedTextureVariation(ped, id) }
    end
    for _, id in ipairs(Props) do
        outfit.props[#outfit.props + 1] = { id = id, drawable = GetPedPropIndex(ped, id), texture = GetPedPropTextureIndex(ped, id) }
    end

    return outfit
end

A.Set = function(outfit)
    if type(outfit) ~= 'table' then return false end

    local hook = Hook('set')
    if hook then
        local ok, done = pcall(hook, outfit)
        if ok and done ~= nil then return done == true end
    end

    local ped = PlayerPedId()
    if tonumber(outfit.model) and tonumber(outfit.model) ~= GetEntityModel(ped) then return false end

    for _, c in ipairs(type(outfit.components) == 'table' and outfit.components or {}) do
        local id, drawable, texture = tonumber(c.id), tonumber(c.drawable), tonumber(c.texture) or 0
        if id and drawable and id >= 0 and id <= 11 and id ~= 0 then SetPedComponentVariation(ped, id, drawable, texture, 0) end
    end
    for _, p in ipairs(type(outfit.props) == 'table' and outfit.props or {}) do
        local id, drawable, texture = tonumber(p.id), tonumber(p.drawable), tonumber(p.texture) or 0
        if id and drawable then
            if drawable < 0 then ClearPedProp(ped, id) else SetPedPropIndex(ped, id, drawable, texture, true) end
        end
    end

    return true
end

A.Restore = function()
    local hook = Hook('restore')
    if hook then
        local ok, done = pcall(hook)
        if ok and done ~= nil then return done == true end
    end

    local name = A.Name()
    if name == 'illenium-appearance' then
        TriggerEvent('illenium-appearance:client:reloadSkin', true)
    elseif name == 'qb-clothing' then
        TriggerServerEvent('qb-clothes:loadPlayerSkin')
    elseif name == 'skinchanger' then
        local skin
        TriggerEvent('esx_skin:getLastSkin', function(s) skin = s end)
        if type(skin) ~= 'table' then return false end
        TriggerEvent('skinchanger:loadSkin', skin)
    elseif name == 'fivem-appearance' then
        local ok, saved = pcall(function() return lib.callback.await('fivem-appearance:server:getAppearance', false) end)
        if not ok or type(saved) ~= 'table' then return false end
        exports['fivem-appearance']:setPlayerAppearance(saved)
    else
        return false
    end

    return true
end

lib.callback.register('fn_bridge:appearance:get', function()
    return A.Get()
end)

RegisterNetEvent('fn_bridge:appearance', function(kind, outfit)
    if kind == 'set' then A.Set(outfit) elseif kind == 'restore' then A.Restore() end
end)
