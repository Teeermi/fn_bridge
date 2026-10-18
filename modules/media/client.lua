RegisterNetEvent('fn_bridge:shot', function(token, opts)
    opts = type(opts) == 'table' and opts or {}
    local ok = GetResourceState('screenshot-basic') == 'started' and pcall(function()
        exports['screenshot-basic']:requestScreenshot({ encoding = opts.encoding or 'webp', quality = tonumber(opts.quality) or 0.92 }, function(data)
            TriggerEvent('fn_bridge:captured')
            TriggerLatentServerEvent('fn_bridge:shotData', 1048576, token, data)
        end)
    end)
    if not ok then TriggerServerEvent('fn_bridge:shotData', token, false) end
end)
