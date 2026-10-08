if not FN_FRAMEWORK then return end

FN_CHARACTERS = {}

local function fw()
    return FN_BRIDGE.frameworkName
end

local function esx()
    return FN_FRAMEWORK.obj
end

local esxLoaded
RegisterNetEvent('esx:playerLoaded', function(data, isNew, skin)
    esxLoaded = { data = data, isNew = isNew, skin = skin }
end)

local function wake()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)
    SetEntityCollision(ped, true, true)
    SetEntityInvincible(ped, false)
    SetPlayerControl(PlayerId(), true, 0)
end

local function teleport(c)
    local ped = PlayerPedId()
    RequestCollisionAtCoord(c.x, c.y, c.z)
    SetEntityCoordsNoOffset(ped, c.x, c.y, c.z, false, false, false)
    SetEntityHeading(ped, c.w or 0.0)
    local stop = GetGameTimer() + 5000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < stop do Wait(0) end
end

local function creatorEsx(sex)
    local done = false
    local function open()
        TriggerEvent('esx_skin:openSaveableMenu', function() done = true end, function() done = true end)
    end
    if GetResourceState('skinchanger') == 'started' then
        TriggerEvent('skinchanger:loadDefaultModel', sex ~= 'f', open)
    else
        open()
    end
    local stop = GetGameTimer() + 1800000
    while not done and GetGameTimer() < stop do Wait(250) end
end

local function esxEvents()
    wake()
    TriggerServerEvent('esx:onPlayerSpawn')
    TriggerEvent('esx:onPlayerSpawn')
    TriggerEvent('esx:restoreLoadout')
end

local function qbEvents(qbx)
    TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
    if qbx then TriggerEvent('QBCore:Client:OnPlayerLoaded') end
end

local function spawnEsx(c, o, ready, appearance)
    local stop = GetGameTimer() + 15000
    while not esxLoaded and GetGameTimer() < stop do Wait(50) end
    local skin = esxLoaded and esxLoaded.skin
    if o.isNew or type(skin) ~= 'table' or next(skin) == nil then
        teleport(c)
        wake()
        ready()
        DoScreenFadeIn(600)
        if not appearance(o.sex) then creatorEsx(o.sex) end
        esxEvents()
        return
    end
    local p = promise.new()
    esx().SpawnPlayer(skin, { x = c.x, y = c.y, z = c.z, heading = c.w or 0.0 }, function() p:resolve(true) end)
    Citizen.Await(p)
    esxEvents()
end

local function spawnQb(c, o, ready, appearance, qbx)
    if GetResourceState('spawnmanager') == 'started' then
        local p = promise.new()
        exports.spawnmanager:spawnPlayer({ x = c.x, y = c.y, z = c.z, heading = c.w or 0.0, skipFade = true }, function() p:resolve(true) end)
        Citizen.Await(p)
    else
        teleport(c)
    end
    wake()
    qbEvents(qbx)
    if o.kind ~= 'last' then
        TriggerServerEvent('qb-houses:server:SetInsideMeta', 0, false)
        TriggerServerEvent('qb-apartments:server:SetInsideMeta', 0, 0, false)
    end
    Wait(500)
    if o.isNew and o.creator ~= false then
        ready()
        DoScreenFadeIn(600)
        if not appearance(o.sex) then TriggerEvent('qb-clothes:client:CreateFirstCharacter') end
    end
end

FN_CHARACTERS.IsLoggedIn = function()
    local f = fw()
    if f == 'esx' then
        local ok, v = pcall(function() return esx().IsPlayerLoaded() end)
        return ok and v == true
    end
    if f == 'ox' then
        local p = exports.ox_core:GetPlayer()
        return not p or not p.userId or p.charId ~= nil
    end
    return (f == 'qb' or f == 'qbx') and LocalPlayer.state.isLoggedIn == true
end

FN_CHARACTERS.Prepare = function()
    pcall(function() exports.spawnmanager:setAutoSpawn(false) end)
    if GetResourceState('qb-weathersync') == 'started' then TriggerEvent('qb-weathersync:client:DisableSync') end
    if fw() == 'esx' then TriggerEvent('esx_skin:resetFirstSpawn') end
    esxLoaded = nil
    return true
end

FN_CHARACTERS.LoadingOff = function()
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    if fw() == 'esx' then TriggerEvent('esx:loadingScreenOff') end
    return true
end

FN_CHARACTERS.Spawn = function(c, o)
    o = type(o) == 'table' and o or {}
    local ready = function() if FN_BRIDGE.Callable(o.ready) then o.ready() end end
    local appearance = function(sex) return FN_BRIDGE.Callable(o.appearance) and o.appearance(sex) == true end
    local f = fw()
    if f == 'ox' then
        teleport(c)
        if not (FN_BRIDGE.Callable(o.login) and o.login() == true) then return false end
        wake()
        if o.isNew then
            ready()
            DoScreenFadeIn(600)
            appearance(o.sex)
        end
    elseif f == 'esx' then
        spawnEsx(c, o, ready, appearance)
    else
        spawnQb(c, o, ready, appearance, f == 'qbx')
    end
    return true
end

FN_CHARACTERS.Loaded = function()
    local f = fw()
    if f == 'esx' then esxEvents() elseif f == 'qb' or f == 'qbx' then qbEvents(f == 'qbx') end
    return true
end

FN_CHARACTERS.Done = function()
    if GetResourceState('qb-weathersync') == 'started' then TriggerEvent('qb-weathersync:client:EnableSync') end
    return true
end
