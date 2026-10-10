local seq = 0

RegisterNetEvent('fn_bridge:phone', function(resource, n)
    if resource ~= 'npwd' or type(n) ~= 'table' or type(n.title) ~= 'string' or GetResourceState('npwd') ~= 'started' then return end
    seq = seq + 1
    pcall(function()
        exports['npwd']:createSystemNotification({ uniqId = ('fn_bridge:%d'):format(seq), secondaryTitle = n.title, content = n.body or '', keepOpen = false, duration = 6000 })
    end)
end)
