FN_UPDATE = {}

local Releases = 'https://github.com/Teeermi/fn_bridge/releases/latest'
local Api = 'https://api.github.com/repos/Teeermi/fn_bridge/releases/latest'
local edited

local function Newer(a, b)
    local x, y = {}, {}
    for n in tostring(a):gmatch('%d+') do x[#x + 1] = tonumber(n) end
    for n in tostring(b):gmatch('%d+') do y[#y + 1] = tonumber(n) end

    for i = 1, math.max(#x, #y) do
        if (x[i] or 0) ~= (y[i] or 0) then return (x[i] or 0) > (y[i] or 0) end
    end

    return false
end

FN_UPDATE.Hash = function(text)
    local h = 2166136261
    for i = 1, #text do
        local b = text:byte(i)
        if b ~= 13 then h = ((h ~ b) * 16777619) & 0xffffffff end
    end

    return ('%08x'):format(h)
end

FN_UPDATE.Edited = function()
    if edited then return edited end

    local raw = LoadResourceFile(FN_BRIDGE.resourceName, 'checksums.json')
    local ok, sums = pcall(json.decode, raw or '')
    if not ok or type(sums) ~= 'table' then return nil end

    local paths = {}
    for path in pairs(sums) do paths[#paths + 1] = path end
    table.sort(paths)

    local list = {}
    for _, path in ipairs(paths) do
        local text = LoadResourceFile(FN_BRIDGE.resourceName, path)
        if not text or FN_UPDATE.Hash(text) ~= sums[path] then list[#list + 1] = path end
        Wait(0)
    end

    edited = list

    return list
end

FN_UPDATE.Latest = function(cb)
    PerformHttpRequest(Api, function(status, body)
        if status ~= 200 or type(body) ~= 'string' then return end

        local ok, data = pcall(json.decode, body)
        local tag = ok and type(data) == 'table' and data.tag_name
        if type(tag) == 'string' then cb((tag:gsub('^v', ''))) end
    end, 'GET', '', { ['User-Agent'] = 'fn_bridge', ['Accept'] = 'application/vnd.github+json' })
end

AddEventHandler('onResourceStarting', function(resource)
    local want = GetResourceMetadata(resource, 'fn_bridge_version', 0)
    if not want or not tostring(FN_BRIDGE.version):match('%d') or not Newer(want, FN_BRIDGE.version) then return end

    print(('^1%s needs fn_bridge %s or newer, this server runs %s, so it was not started. Download the newest fn_bridge: %s^7'):format(resource, want, FN_BRIDGE.version, Releases))
    CancelEvent()
end)

CreateThread(function()
    while not FN_BRIDGE.IsReady() do Wait(500) end

    if tostring(FN_BRIDGE.version):match('%d') then
        FN_UPDATE.Latest(function(latest)
            if Newer(latest, FN_BRIDGE.version) then
                print(('^3fn_bridge %s is out, this server runs %s. Replace the fn_bridge folder with the new release and restart the server: %s^7'):format(latest, FN_BRIDGE.version, Releases))
            end
        end)
    end

    local list = FN_UPDATE.Edited()
    if list and #list > 0 then
        print(('^3fn_bridge files changed since the release: %s. The next update replaces them. Move your changes to fn_bridge_custom, a convar in server.cfg or Config.Bridge in your script, see docs/ENGLISH/_INSTALL.md.^7'):format(table.concat(list, ', ')))
    end
end)
