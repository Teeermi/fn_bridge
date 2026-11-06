local CHUNK = 131072
local sending

local function send(token, i)
    if not sending or sending.token ~= token then return end
    local data = sending.data
    local n = math.max(1, math.ceil(#data / CHUNK))
    if i >= n then sending = nil end
    TriggerLatentServerEvent('fn_bridge:shotData', 153600, token, i, n, data:sub((i - 1) * CHUNK + 1, i * CHUNK))
end

RegisterNetEvent('fn_bridge:shotNext', send)

RegisterNetEvent('fn_bridge:shot', function(token, opts)
    opts = type(opts) == 'table' and opts or {}
    local ok = GetResourceState('screenshot-basic') == 'started' and pcall(function()
        exports['screenshot-basic']:requestScreenshot({ encoding = opts.encoding or 'webp', quality = tonumber(opts.quality) or 0.92 }, function(data)
            TriggerEvent('fn_bridge:captured')
            if type(data) ~= 'string' then return TriggerServerEvent('fn_bridge:shotData', token, false) end
            sending = { token = token, data = data }
            send(token, 1)
        end)
    end)
    if not ok then TriggerServerEvent('fn_bridge:shotData', token, false) end
end)
