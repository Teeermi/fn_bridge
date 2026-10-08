local resourceName = GetCurrentResourceName()
local Download = 'https://github.com/Teeermi/fn_bridge/releases/latest'
local InitAttempts = 40
local InitDelayMs = 500

local function SafeExport()
    local status, result = pcall(function()
        return exports['fn_bridge']:GetBridge()
    end)

    if not status then return nil, result end
    if not result then return nil, 'fn_bridge is not ready yet' end

    return result
end

local function InitBridge()
    local bridge, lastError = SafeExport()
    if bridge then return bridge end

    for _ = 1, InitAttempts do
        Citizen.Wait(InitDelayMs)
        bridge, lastError = SafeExport()
        if bridge then return bridge end
    end

    print('[fn_bridge] '..resourceName..' gave up waiting for the bridge after '..math.floor((InitAttempts * InitDelayMs) / 1000)..'s: '..tostring(lastError))
    print('[fn_bridge] '..resourceName..' will not work. Check the fn_bridge console output, it prints why it never became ready. Download: '..Download)

    return nil
end

local function OwnSettings()
    return type(Config) == 'table' and type(Config.Bridge) == 'table' and Config.Bridge or nil
end

local function LoadLocales(bridge)
    local own = OwnSettings()
    local language = tostring(own and own.language or (bridge.HELPER and bridge.HELPER.GetLanguage()) or 'en'):lower()
    bridge.LOCALES = {}

    for _, code in ipairs(language == 'en' and { 'en' } or { language, 'en' }) do
        local raw = LoadResourceFile(resourceName, 'locales/'..code..'.json')
        if raw then
            local ok, value = pcall(json.decode, raw)
            if ok and type(value) == 'table' then
                bridge.LOCALES = value
                return
            end

            print('['..resourceName..'] locales/'..code..'.json is not valid JSON: '..tostring(value))
        end
    end
end

local function Older(have, want)
    local a, b = {}, {}
    for n in tostring(have):gmatch('%d+') do a[#a + 1] = tonumber(n) end
    for n in tostring(want):gmatch('%d+') do b[#b + 1] = tonumber(n) end

    for i = 1, math.max(#a, #b) do
        if (a[i] or 0) ~= (b[i] or 0) then return (a[i] or 0) < (b[i] or 0) end
    end

    return false
end

local bridge = FN_BRIDGE or InitBridge()
if not bridge then return end

local wanted = GetResourceMetadata(resourceName, 'fn_bridge_version', 0)
if wanted and Older(bridge.version, wanted) then
    print(('^1[fn_bridge] %s needs fn_bridge %s or newer, this server runs %s. Download the newest fn_bridge: %s^7'):format(resourceName, wanted, tostring(bridge.version), Download))
end

bridge.T = function(key, vars)
    if not bridge.LOCALES then LoadLocales(bridge) end

    local locales = bridge.LOCALES
    local str = locales[key] or key
    if vars then
        for k, v in pairs(vars) do
            str = str:gsub('{' .. k .. '}', tostring(v))
        end
    end

    return str
end

FN_BRIDGE = bridge

CreateThread(function()
    local own = OwnSettings()
    if own then bridge.Configure(own) end
end)

FN_BRIDGE.HELPER.print('Loaded successfully in ' .. resourceName)
