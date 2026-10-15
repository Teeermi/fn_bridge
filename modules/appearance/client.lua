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

local function EsxSkin()
    local esx = GetResourceState('esx_skin') == 'started' and FN_FRAMEWORK and FN_FRAMEWORK.obj
    if type(esx) ~= 'table' or not esx.TriggerServerCallback then return nil end

    local p = promise.new()
    esx.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin) p:resolve(type(skin) == 'table' and skin or false) end)
    SetTimeout(5000, function() p:resolve(false) end)

    return Citizen.Await(p) or nil
end

local function Freemode(skin)
    local model = joaat(skin.sex == 1 and 'mp_f_freemode_01' or 'mp_m_freemode_01')
    if GetEntityModel(PlayerPedId()) == model then return end

    lib.requestModel(model)
    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)
    SetPedDefaultComponentVariation(PlayerPedId())
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
        if type(skin) ~= 'table' then skin = EsxSkin() end
        if type(skin) ~= 'table' then return false end
        Freemode(skin)
        TriggerEvent('skinchanger:loadSkin', skin)
    elseif name == 'fivem-appearance' then
        local saved = EsxSkin()
        if not saved then
            local ok, s = pcall(function() return lib.callback.await('fivem-appearance:server:getAppearance', false) end)
            saved = ok and s
        end
        if type(saved) ~= 'table' then return false end
        if not saved.model then Freemode(saved) end
        exports['fivem-appearance']:setPlayerAppearance(saved)
    else
        return false
    end

    return true
end

local MALE, FEMALE = joaat('mp_m_freemode_01'), joaat('mp_f_freemode_01')

local FEATURES = { 'nose_1', 'nose_2', 'nose_3', 'nose_4', 'nose_5', 'nose_6', 'eyebrows_5', 'eyebrows_6', 'cheeks_1', 'cheeks_2',
    'cheeks_3', 'eye_squint', 'lip_thickness', 'jaw_1', 'jaw_2', 'chin_1', 'chin_2', 'chin_3', 'chin_4', 'neck_thickness' }
local OVERLAYS = { { 'blemishes_1', 'blemishes_2' }, { 'beard_1', 'beard_2' }, { 'eyebrows_1', 'eyebrows_2' }, { 'age_1', 'age_2' },
    { 'makeup_1', 'makeup_2' }, { 'blush_1', 'blush_2' }, { 'complexion_1', 'complexion_2' }, { 'sun_1', 'sun_2' },
    { 'lipstick_1', 'lipstick_2' }, { 'moles_1', 'moles_2' }, { 'chest_1', 'chest_2' }, { 'bodyb_1', 'bodyb_2' } }
local COLORS = { [1] = { 'beard_3', 'beard_4', 1 }, [2] = { 'eyebrows_3', 'eyebrows_4', 1 }, [4] = { 'makeup_3', 'makeup_4', 2 },
    [5] = { 'blush_3', 'blush_4', 2 }, [8] = { 'lipstick_3', 'lipstick_4', 2 }, [10] = { 'chest_3', 'chest_4', 1 } }
local COMPONENTS = { { 'mask_1', 'mask_2', 1 }, { 'arms', 'arms_2', 3 }, { 'pants_1', 'pants_2', 4 }, { 'bags_1', 'bags_2', 5 },
    { 'shoes_1', 'shoes_2', 6 }, { 'chain_1', 'chain_2', 7 }, { 'tshirt_1', 'tshirt_2', 8 }, { 'bproof_1', 'bproof_2', 9 },
    { 'decals_1', 'decals_2', 10 }, { 'torso_1', 'torso_2', 11 } }
local PROPS = { { 'helmet_1', 'helmet_2', 0 }, { 'glasses_1', 'glasses_2', 1 }, { 'ears_1', 'ears_2', 2 },
    { 'watches_1', 'watches_2', 6 }, { 'bracelets_1', 'bracelets_2', 7 } }

local function n(v, d)
    return math.tointeger(tonumber(v)) or d
end

local function f(v)
    return (tonumber(v) or 0) + 0.0
end

local function Kind(d)
    if type(d) ~= 'table' then return nil end
    if d.components or d.headBlend or d.props then return 'illenium' end
    if type(d.face) == 'table' or type(d.pants) == 'table' or type(d.torso2) == 'table' then return 'qb' end
    if d.sex ~= nil or d.torso_1 ~= nil or d.mom ~= nil then return 'skinchanger' end
    return nil
end

local function skinchanger(ped, d)
    if d.mom ~= nil or d.dad ~= nil then
        SetPedHeadBlendData(ped, n(d.mom, 21), n(d.dad, 0), n(d.grandparents, 0), n(d.mom, 21), n(d.dad, 0), n(d.grandparents, 0),
            f(d.face_md_weight) / 100.0, f(d.skin_md_weight) / 100.0, f(d.face_g_weight) / 100.0, false)
    else
        SetPedHeadBlendData(ped, n(d.face, 0), n(d.face, 0), n(d.face, 0), n(d.skin, 0), n(d.skin, 0), n(d.skin, 0), 1.0, 1.0, 1.0, true)
    end
    for i, key in ipairs(FEATURES) do
        SetPedFaceFeature(ped, i - 1, f(d[key]) / 10.0)
    end
    SetPedEyeColor(ped, n(d.eye_color, 0))
    for i, o in ipairs(OVERLAYS) do
        local v = n(d[o[1]], 255)
        SetPedHeadOverlay(ped, i - 1, v < 0 and 255 or v, f(d[o[2]]) / 10.0)
    end
    for i, c in pairs(COLORS) do
        SetPedHeadOverlayColor(ped, i, c[3], n(d[c[1]], 0), n(d[c[2]], 0))
    end
    SetPedComponentVariation(ped, 2, n(d.hair_1, 0), n(d.hair_2, 0), 0)
    SetPedHairColor(ped, n(d.hair_color_1, 0), n(d.hair_color_2, 0))
    for _, c in ipairs(COMPONENTS) do
        SetPedComponentVariation(ped, c[3], n(d[c[1]], 0), n(d[c[2]], 0), 0)
    end
    for _, p in ipairs(PROPS) do
        local v = n(d[p[1]], -1)
        if v < 0 then
            ClearPedProp(ped, p[3])
        else
            SetPedPropIndex(ped, p[3], v, n(d[p[2]], 0), true)
        end
    end
end

local ILL_FACE = { 'noseWidth', 'nosePeakHigh', 'nosePeakSize', 'noseBoneHigh', 'nosePeakLowering', 'noseBoneTwist', 'eyeBrownHigh',
    'eyeBrownForward', 'cheeksBoneHigh', 'cheeksBoneWidth', 'cheeksWidth', 'eyesOpening', 'lipsThickness', 'jawBoneWidth', 'jawBoneBackSize',
    'chinBoneLowering', 'chinBoneLenght', 'chinBoneSize', 'chinHole', 'neckThickness' }
local ILL_OVERLAYS = { 'blemishes', 'beard', 'eyebrows', 'ageing', 'makeUp', 'blush', 'complexion', 'sunDamage', 'lipstick',
    'moleAndFreckles', 'chestHair', 'bodyBlemishes' }
local ILL_TINT2 = { makeUp = true, blush = true, lipstick = true }

local function illenium(ped, d)
    local free = IsPedModel(ped, MALE) or IsPedModel(ped, FEMALE)
    local hb = d.headBlend
    if free and type(hb) == 'table' then
        SetPedHeadBlendData(ped, n(hb.shapeFirst, 0), n(hb.shapeSecond, 0), n(hb.shapeThird, 0), n(hb.skinFirst, 0), n(hb.skinSecond, 0),
            n(hb.skinThird, 0), f(hb.shapeMix), f(hb.skinMix), f(hb.thirdMix), false)
    end
    if type(d.faceFeatures) == 'table' then
        for i, k in ipairs(ILL_FACE) do SetPedFaceFeature(ped, i - 1, f(d.faceFeatures[k])) end
    end
    if type(d.headOverlays) == 'table' then
        for i, k in ipairs(ILL_OVERLAYS) do
            local o = d.headOverlays[k]
            if type(o) == 'table' then
                SetPedHeadOverlay(ped, i - 1, n(o.style, 255), f(o.opacity))
                if o.color then SetPedHeadOverlayColor(ped, i - 1, ILL_TINT2[k] and 2 or 1, n(o.color, 0), n(o.secondColor, 0)) end
            end
        end
    end
    for _, c in pairs(type(d.components) == 'table' and d.components or {}) do
        local id = n(c.component_id, -1)
        if id >= 0 and not (free and (id == 0 or id == 2)) then SetPedComponentVariation(ped, id, n(c.drawable, 0), n(c.texture, 0), 0) end
    end
    for _, p in pairs(type(d.props) == 'table' and d.props or {}) do
        local id, v = n(p.prop_id, -1), n(p.drawable, -1)
        if id >= 0 then
            if v < 0 then ClearPedProp(ped, id) else SetPedPropIndex(ped, id, v, n(p.texture, 0), true) end
        end
    end
    if type(d.hair) == 'table' then
        SetPedComponentVariation(ped, 2, n(d.hair.style, 0), n(d.hair.texture, 0), 0)
        SetPedHairColor(ped, n(d.hair.color, 0), n(d.hair.highlight, 0))
    end
    if d.eyeColor then SetPedEyeColor(ped, n(d.eyeColor, 0)) end
    if free and type(d.tattoos) == 'table' then
        local male = IsPedModel(ped, MALE)
        ClearPedDecorations(ped)
        for _, zone in pairs(d.tattoos) do
            for _, t in ipairs(type(zone) == 'table' and zone or {}) do
                local hash = male and t.hashMale or t.hashFemale
                if t.collection and hash and hash ~= '' then
                    for _ = 1, math.max(1, math.floor((tonumber(t.opacity) or 0.1) * 10 + 0.5)) do
                        AddPedDecorationFromHashes(ped, joaat(t.collection), joaat(hash))
                    end
                end
            end
        end
    end
end

local QB_FACE = { 'nose_0', 'nose_1', 'nose_2', 'nose_3', 'nose_4', 'nose_5', 'eyebrown_high', 'eyebrown_forward', 'cheek_1', 'cheek_2',
    'cheek_3', 'eye_opening', 'lips_thickness', 'jaw_bone_width', 'jaw_bone_back_lenght', 'chimp_bone_lowering', 'chimp_bone_lenght',
    'chimp_bone_width', 'chimp_hole', 'neck_thikness' }
local QB_COMPONENTS = { { 'mask', 1 }, { 'arms', 3 }, { 'pants', 4 }, { 'bag', 5 }, { 'shoes', 6 }, { 'accessory', 7 }, { 't-shirt', 8 },
    { 'vest', 9 }, { 'decals', 10 }, { 'torso2', 11 } }
local QB_OVERLAYS = { { 'beard', 1 }, { 'eyebrows', 2 }, { 'ageing', 3 }, { 'makeup', 4 }, { 'blush', 5 }, { 'lipstick', 8 } }
local QB_PROPS = { { 'hat', 0 }, { 'glass', 1 }, { 'ear', 2 }, { 'watch', 6 }, { 'bracelet', 7 } }

local function qb(ped, d)
    local function iv(k)
        local v = d[k]
        if type(v) ~= 'table' then return 0, 0, v end
        return n(v.item, 0), n(v.texture, 0), v
    end
    local f1, s1 = iv('face')
    local f2, s2 = iv('face2')
    local mix = type(d.facemix) == 'table' and d.facemix or {}
    SetPedHeadBlendData(ped, f1, f2, 0, s1, s2, 0, f(mix.shapeMix), f(mix.skinMix), 0.0, false)
    for i, k in ipairs(QB_FACE) do SetPedFaceFeature(ped, i - 1, iv(k) / 10.0) end
    for _, o in ipairs(QB_OVERLAYS) do
        local v, c = iv(o[1])
        SetPedHeadOverlay(ped, o[2], v < 0 and 255 or v, 1.0)
        SetPedHeadOverlayColor(ped, o[2], 1, c, 0)
    end
    local moles, mo = iv('moles')
    if moles > 0 then SetPedHeadOverlay(ped, 9, moles, mo / 10.0) end
    local eye = iv('eye_color')
    if eye > 0 then SetPedEyeColor(ped, eye) end
    local hair, hc = iv('hair')
    SetPedComponentVariation(ped, 2, hair, 0, 0)
    SetPedHairColor(ped, hc, hc)
    for _, c in ipairs(QB_COMPONENTS) do
        local v, t = iv(c[1])
        SetPedComponentVariation(ped, c[2], v, t, 0)
    end
    for _, p in ipairs(QB_PROPS) do
        local v, t = iv(p[1])
        if v > 0 then SetPedPropIndex(ped, p[2], v, t, true) else ClearPedProp(ped, p[2]) end
    end
end

local Appliers = { illenium = illenium, qb = qb, skinchanger = skinchanger }

A.Apply = function(ped, data)
    local hook = Hook('apply')
    if hook and pcall(hook, ped, data) then return true end

    local apply = Appliers[Kind(data)]

    return apply ~= nil and pcall(apply, ped, data) == true
end

A.Creator = function(sex)
    local hook = Hook('creator')
    if not hook then return false end

    local ok, done = pcall(hook, sex)

    return ok and done ~= false
end

lib.callback.register('fn_bridge:appearance:get', function()
    return A.Get()
end)

RegisterNetEvent('fn_bridge:appearance', function(kind, outfit)
    if kind == 'set' then A.Set(outfit) elseif kind == 'restore' then A.Restore() end
end)
