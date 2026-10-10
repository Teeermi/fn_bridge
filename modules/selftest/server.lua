local Probe = {
    license = 'license:fnbprobe0000000000000000000000000000',
    plate = 'OPB0001',
    plate2 = 'OPB0002',
    phone = '5550199',
    firstName = 'Fnbprobe',
    lastName = 'Selftest',
}

local Tally

local function Report(status, name, detail)
    Tally[status] = Tally[status] + 1
    local colour = status == 'pass' and '^2' or status == 'fail' and '^1' or '^3'
    print(('%s%s^7 %s%s'):format(colour, status:upper(), name, detail and (': ' .. tostring(detail)) or ''))
end

local function Check(name, fn)
    local ok, result, detail = pcall(fn)
    if not ok then return Report('fail', name, result) end
    if result == 'skip' then return Report('skip', name, detail) end

    Report(result and 'pass' or 'fail', name, not result and detail or nil)
end

local Characters = {
    esx = function(index)
        local identifier = ('char%d:%s'):format(index, Probe.license:match(':(.+)$'))
        FN_DB.InsertRow('users', { identifier = identifier, firstname = Probe.firstName, lastname = Probe.lastName .. index, phone_number = index == 1 and Probe.phone or nil, job = 'unemployed', job_grade = 0 })

        return identifier, function() MySQL.query.await('DELETE FROM users WHERE identifier = ?', { identifier }) end
    end,
    qb = function(index)
        local citizenId = ('OPBPROBE%d'):format(index)
        FN_DB.InsertRow('players', {
            citizenid = citizenId,
            license = Probe.license,
            name = 'fnbprobe',
            money = '{}',
            job = json.encode({ name = 'unemployed', grade = { level = 0, name = 'Freelancer' } }),
            gang = '{}',
            position = '{}',
            metadata = '{}',
            charinfo = json.encode({ firstname = Probe.firstName, lastname = Probe.lastName .. index, phone = index == 1 and Probe.phone or nil, birthdate = '2000-01-01', gender = 0 }),
        })

        return citizenId, function() MySQL.query.await('DELETE FROM players WHERE citizenid = ?', { citizenId }) end
    end,
    ox = function(index)
        FN_DB.InsertRow('users', { username = 'fnbprobe', license2 = Probe.license:gsub('^license:', 'license2:') })
        local userId = MySQL.scalar.await('SELECT userId FROM users WHERE username = ? LIMIT 1', { 'fnbprobe' })
        FN_DB.InsertRow('characters', { userId = userId, stateId = ('OPB%04d'):format(index), firstName = Probe.firstName, lastName = Probe.lastName .. index, gender = 'male', dateOfBirth = '2000-01-01', phoneNumber = index == 1 and Probe.phone or nil })
        local charId = MySQL.scalar.await('SELECT charId FROM characters WHERE stateId = ?', { ('OPB%04d'):format(index) })

        return tostring(charId), function()
            MySQL.query.await('DELETE FROM characters WHERE charId = ?', { charId })
            MySQL.query.await('DELETE FROM users WHERE username = ? AND NOT EXISTS (SELECT 1 FROM characters c WHERE c.userId = users.userId)', { 'fnbprobe' })
        end
    end,
    vrp = function(index)
        local userId = 990000 + index
        FN_DB.InsertRow('vrp_users', { id = userId })
        FN_DB.InsertRow('vrp_user_identities', { user_id = userId, registration = index == 1 and Probe.plate or ('OPBV%04d'):format(index), phone = index == 1 and Probe.phone or ('5559%03d'):format(index), firstname = Probe.firstName, name = Probe.lastName .. index, age = 30 })

        return tostring(userId), function()
            MySQL.query.await('DELETE FROM vrp_user_identities WHERE user_id = ?', { userId })
            MySQL.query.await('DELETE FROM vrp_users WHERE id = ?', { userId })
        end
    end,
}

Characters.qbx = Characters.qb

local function Tier19(framework, one)
    local FRAMEWORK, B = FN_BRIDGE.FRAMEWORK, FN_BRIDGE
    local managed = B.IsSupported('FRAMEWORK', 'CreateJob')

    Check('GetJobGrades sorted with salary', function()
        if framework == 'standalone' then return 'skip', 'standalone has no jobs' end

        for name in pairs(FRAMEWORK.GetJobs()) do
            local grades = FRAMEWORK.GetJobGrades(name)
            if #grades > 1 then
                for i = 2, #grades do
                    if grades[i].grade <= grades[i - 1].grade or type(grades[i].salary) ~= 'number' then return false, name end
                end
                return true
            end
        end

        return 'skip', 'no job with two grades'
    end)

    Check('GetJobOffline reads the probe', function()
        if not one or not B.IsSupported('FRAMEWORK', 'GetJobOffline') then return 'skip', 'not supported here' end
        if framework == 'vrp' then return 'skip', 'vRP keeps groups in user data' end

        local job = FRAMEWORK.GetJobOffline(one)

        return type(job) == 'table' and type(job.name) == 'string' and FRAMEWORK.GetJobOffline('fnb_nobody') == false, json.encode(job)
    end)

    Check('SetCharacter round trip', function()
        if not one or not B.IsSupported('FRAMEWORK', 'SetCharacter') then return 'skip', 'not supported here' end

        local before = FRAMEWORK.GetCharacter(one)
        if not before then return 'skip', 'no probe character' end

        local set = FRAMEWORK.SetCharacter(one, { dateOfBirth = '1999-09-09', sex = 'f', nationality = 'Probe' })
        local after = FRAMEWORK.GetCharacter(one) or {}
        local restored = FRAMEWORK.SetCharacter(one, { dateOfBirth = before.dateOfBirth or '2000-01-01', sex = before.sex or 'm', nationality = before.nationality or '' })
        local rejected = FRAMEWORK.SetCharacter(one, { sex = 'x' }) == false and FRAMEWORK.SetCharacter('fnb_nobody', { sex = 'm' }) == false

        return set and restored and rejected and after.dateOfBirth == '1999-09-09' and after.sex == 'f', ('set %s restored %s rejected %s dob %s sex %s'):format(tostring(set), tostring(restored), tostring(rejected), tostring(after.dateOfBirth), tostring(after.sex))
    end)

    Check('CreateJob, SetJobGrades, DeleteJob', function()
        if not managed then return 'skip', 'jobs cannot be created on ' .. framework end

        local name = 'fnbprobejob'
        FRAMEWORK.DeleteJob(name, { persist = false })
        local grades = { { grade = 0, name = 'rookie', label = 'Rookie', salary = 10 }, { grade = 1, name = 'chief', label = 'Chief', salary = 30, isBoss = true } }
        local created, how = FRAMEWORK.CreateJob(name, 'Fnb Probe', grades, { persist = false })
        if not created then return false, 'create ' .. tostring(how) end
        if how ~= 'live' then
            FRAMEWORK.DeleteJob(name, { persist = false })
            return 'skip', 'saved, the framework sees it after a restart'
        end

        local again = FRAMEWORK.CreateJob(name, 'Fnb Probe', grades, { persist = false })
        grades[3] = { grade = 2, name = 'boss2', label = 'Boss', salary = 50 }
        local set = FRAMEWORK.SetJobGrades(name, grades, { persist = false })
        local count = #FRAMEWORK.GetJobGrades(name)
        local deleted = FRAMEWORK.DeleteJob(name, { persist = false })

        return again == false and set and count == 3 and deleted and not FRAMEWORK.GetJobs()[name], ('again %s set %s count %d deleted %s'):format(tostring(again), tostring(set), count, tostring(deleted))
    end)

    Check('IsSupported follows the picked adapter', function()
        local jail = B.JAIL.Name()
        local release = jail == 'hook' or B.IsSupported('JAIL', 'Release') == (jail ~= false and jail ~= 'pickle_prisons')
        local noGangs = FRAMEWORK.Supports('gangs') or not B.IsSupported('FRAMEWORK', 'SetGang')

        return release and noGangs, ('jail %s release %s gangs %s'):format(tostring(jail), tostring(B.IsSupported('JAIL', 'Release')), tostring(B.IsSupported('FRAMEWORK', 'SetGang')))
    end)

    Check('gangs round trip', function()
        if not FRAMEWORK.Supports('gangs') or not B.IsSupported('FRAMEWORK', 'CreateGang') then return 'skip', 'no gangs on this setup' end
        if not one then return 'skip', 'no probe character' end

        local name = 'fnbprobegang'
        FRAMEWORK.DeleteGang(name, { persist = false })
        local created, how = FRAMEWORK.CreateGang(name, 'Fnb Gang', { { grade = 0, name = 'kid', label = 'Kid' }, { grade = 1, name = 'boss', label = 'Boss', isBoss = true } }, { persist = false })
        if not created then return false, 'create ' .. tostring(how) end
        if how ~= 'live' then
            FRAMEWORK.DeleteGang(name, { persist = false })
            return 'skip', 'saved, the framework sees it after a restart'
        end

        local set = FRAMEWORK.SetGang(one, name, 1)
        local listed = false
        for _, member in ipairs(FRAMEWORK.GetGangMembers(name)) do
            if member.identifier == one and member.grade == 1 then listed = true end
        end
        local removed = FRAMEWORK.RemoveGang(one, name)
        local deleted = FRAMEWORK.DeleteGang(name, { persist = false })

        return set and listed and removed and deleted, ('set %s listed %s removed %s deleted %s'):format(tostring(set), tostring(listed), tostring(removed), tostring(deleted))
    end)

    Check('multijob and insurance without a player', function()
        local multijob = FRAMEWORK.Supports('multijob')

        return #FRAMEWORK.GetPlayerJobs(65000) == 0 and FRAMEWORK.SetActiveJob(65000, 'police') == false and FRAMEWORK.GetInsurance('fnb_nobody') == false
            and multijob == (framework == 'qbx' or GetResourceState('ps-multijob') == 'started'), 'multijob ' .. tostring(multijob)
    end)

    Check('characterDeleted event', function()
        local got
        local handler = AddEventHandler('fn_bridge:characterDeleted', function(identifier) got = identifier end)
        FN_CHARACTERS.Deleted('fnbprobe_ck', nil)
        RemoveEventHandler(handler)

        return got == 'fnbprobe_ck'
    end)

    Check('SOCIETY 1.9 guards', function()
        local S = B.SOCIETY
        local account = S.GangAccount('fnbgang')

        return S.Transfer('fnbnone_a', 'fnbnone_a', 5) == false and S.Transfer('fnbnone_a', 'fnbnone_b', -1) == false
            and type(account) == 'string' and type(S.GetGangMoney('fnbgang')) == 'number' and S.AddGangMoney('fnbgang', 0) == false
            and S.Watch('fnbnone_a', false) == (B.societyName ~= nil), tostring(account)
    end)

    Check('SOCIETY money round trip with event', function()
        local S = B.SOCIETY
        if not B.societyName then return 'skip', 'no society resource' end

        local job
        for _, name in ipairs({ 'police', 'ambulance', 'mechanic' }) do
            if FRAMEWORK.GetJobs()[name] then job = name break end
        end
        if not job then return 'skip', 'no police, ambulance or mechanic job' end

        local before, seen = S.GetMoney(job), nil
        local handler = AddEventHandler('fn_bridge/server/onSocietyChange', function(name, delta) if name == job then seen = delta end end)
        local added = S.AddMoney(job, 1, 'fnb probe')
        local after = S.GetMoney(job)
        local removed = added and S.RemoveMoney(job, 1, 'fnb probe')
        RemoveEventHandler(handler)
        if not added then return 'skip', 'no account for ' .. job end

        return after == before + 1 and removed and seen == -1 and S.GetMoney(job) == before, ('%s before %d after %d removed %s seen %s'):format(job, before, after, tostring(removed), tostring(seen))
    end)

    Check('BILLING without a player', function()
        local BL = B.BILLING
        local name = BL.Name()
        local bad = BL.Send(nil, { to = 'x', amount = 0 }) == false and BL.Pay(1, 'nope') == false and #BL.List('fnb_nobody') == 0
        if not bad then return false, 'guards' end
        if name ~= 'esx_billing' or not one then return true end

        local id = BL.Send(nil, { to = one, from = 'police', amount = 15, label = 'Fnb probe' })
        local listed = false
        for _, bill in ipairs(BL.List(one)) do
            if bill.id == id and bill.amount == 15 and bill.from == 'police' then listed = true end
        end
        MySQL.query.await('DELETE FROM billing WHERE identifier = ?', { one })

        return listed, tostring(id)
    end)

    Check('JAIL, VOICE, STAFF, MEDIA.Ticket without a player', function()
        local J, V, M = B.JAIL, B.VOICE, B.MEDIA
        local jail = J.Name()
        local sent, why = J.Send(65000, 5)
        local ticket, reason = M.Ticket({ token = '' })
        local tokenless = GetConvar('fn_bridge:upload_token', '') ~= '' or (ticket == false and reason == 'token')

        return (jail == false or type(jail) == 'string') and sent == false and why == 'offline' and J.Get(65000) == false
            and J.CommunityService(65000, 3) == false and V.GetRadio(65000) == false and V.SetRadio(65000, 1) == false
            and B.STAFF.Host('fnb_nojob') == nil and B.STAFF.Call('fnb_nojob', 'GetStaffView', 1) == nil and tokenless, tostring(jail)
    end)

    Check('stash round trip', function()
        local I = B.INVENTORY
        if not B.IsSupported('INVENTORY', 'RegisterStash') then return 'skip', 'no server stashes on this inventory' end

        local item
        for _, name in ipairs({ 'water', 'bread', 'phone', 'sandwich', 'burger', 'lockpick' }) do
            if I.ItemExists(name) then item = name break end
        end
        if not item then return 'skip', 'no common test item exists' end

        local id = 'fnbprobe_stash'
        local registered = I.RegisterStash(id, { label = 'Fnb', slots = 5, weight = 50000 })
        local added = I.AddStashItem(id, item, 2)
        local count = 0
        for _, entry in ipairs(I.GetStashItems(id)) do
            if entry.name == item then count = count + entry.count end
        end
        local removed = I.RemoveStashItem(id, item, 1)
        local cleared = I.ClearStash(id)
        local left = #I.GetStashItems(id)
        if FN_DB.HasTable('ox_inventory') then MySQL.query.await('DELETE FROM ox_inventory WHERE name = ?', { id }) end
        if FN_DB.HasTable('inventories') then MySQL.query.await('DELETE FROM inventories WHERE identifier = ?', { id }) end

        return registered and added and count == 2 and removed and cleared and left == 0, ('reg %s add %s count %d rem %s clear %s left %d'):format(tostring(registered), tostring(added), count, tostring(removed), tostring(cleared), left)
    end)

    Check('RegisterUsable, OnStash, OnShopBuy', function()
        local I = B.INVENTORY
        local usable = I.RegisterUsable('fnbprobe_item', function() return false end, function() end)
        local hooked = not B.IsInventory('ox_inventory') or (I.OnStash('fnbprobe_', function() end) and I.OnShopBuy(function() end))
        if FN_STASH then FN_STASH.Release(B.resourceName) end

        local handler = I.RegisterUsable('fnbprobe_item', 'fnbprobe', function() return false end)

        return usable == true and handler == true and I.RegisterUsable('fnbprobe_item', 1, 2) == false and hooked, ('usable %s hooked %s'):format(tostring(usable), tostring(hooked))
    end)

    Check('DOORS, APPEARANCE, INTERACT without a player', function()
        local D, A, X = B.DOORS, B.APPEARANCE, B.INTERACT
        local doors = D.Name()

        return (doors == false or type(doors) == 'string') and type(D.List()) == 'table' and D.IsLocked('fnb_none') == false and D.SetLocked('fnb_none', 'x') == false
            and A.Get(65000) == false and A.Set(65000, {}) == false and A.FromCode('fnb_none') == false
            and X.Do(65000, 65001, 'cuff') == false and X.Is(65000, 'cuff') == false and X.Has('dance') == false, ('doors %s clothing %s cuff %s'):format(tostring(doors), tostring(A.Name()), tostring(X.Has('cuff')))
    end)
end

local function TierA()
    local framework = FN_BRIDGE.frameworkName
    local FRAMEWORK, VEHICLES = FN_BRIDGE.FRAMEWORK, FN_BRIDGE.VEHICLES
    local cleanups = {}
    local one, two

    Check('framework detected', function() return framework ~= nil, 'none' end)

    Check('framework contract', function()
        local missing = {}
        for _, key in ipairs(FN_BRIDGE.FrameworkContract) do
            if not FN_BRIDGE.IsSupported('FRAMEWORK', key) then missing[#missing + 1] = key end
        end

        return #missing == 0 or framework == 'standalone', table.concat(missing, ', ')
    end)

    Check('GetJobs lists jobs with grades', function()
        if framework == 'standalone' then return 'skip', 'standalone has no jobs' end

        local count, graded = 0, 0
        for _, job in pairs(FRAMEWORK.GetJobs()) do
            count = count + 1
            if next(job.grades) ~= nil then graded = graded + 1 end
        end

        return count > 0 and graded == count, ('%d jobs, %d with grades'):format(count, graded)
    end)

    local create = Characters[framework]
    if create then
        local cleanupOne, cleanupTwo
        one, cleanupOne = create(1)
        two, cleanupTwo = create(2)
        cleanups[#cleanups + 1] = cleanupOne
        cleanups[#cleanups + 1] = cleanupTwo
        FN_DB.ClearCache()
    else
        one, two = Probe.license, Probe.license:gsub('0000$', '0001')
    end

    if create then
        Check('GetCharacter reads the probe', function()
            local character = FRAMEWORK.GetCharacter(one)

            return type(character) == 'table' and character.firstName == Probe.firstName and character.lastName == Probe.lastName .. '1', json.encode(character)
        end)

        Check('GetOfflineCharName', function()
            local name = FRAMEWORK.GetOfflineCharName(one)

            return name == Probe.firstName .. ' ' .. Probe.lastName .. '1', name
        end)

        Check('GetCharacters by license', function()
            if framework == 'vrp' then return 'skip', 'vRP keeps licenses in vrp_user_ids, the probe has none' end

            for _, character in ipairs(FRAMEWORK.GetCharacters(Probe.license)) do
                if character.identifier == one then return true end
            end

            return false, json.encode(FRAMEWORK.GetCharacters(Probe.license))
        end)

        Check('SearchCharacters by name', function()
            for _, character in ipairs(FRAMEWORK.SearchCharacters(Probe.firstName, 10)) do
                if character.identifier == one then return true end
            end

            return false, 'probe not found'
        end)

        Check('IsNameTaken', function()
            if framework == 'standalone' then return 'skip' end

            return FRAMEWORK.IsNameTaken(Probe.firstName, Probe.lastName .. '1') and not FRAMEWORK.IsNameTaken(Probe.firstName, 'Nobody'), 'wrong answer'
        end)

        Check('IsPhoneNumberTaken', function()
            if not FRAMEWORK.Supports('phoneNumber') then return 'skip', 'no phone numbers on this setup' end

            return FRAMEWORK.IsPhoneNumberTaken(Probe.phone) and not FRAMEWORK.IsPhoneNumberTaken('5550000'), 'wrong answer'
        end)

        Check('SetJobOffline and GetJobMembers', function()
            if framework == 'vrp' then return 'skip', 'vRP jobs are groups set through the proxy for online users' end

            local jobName, grade
            for name, job in pairs(FRAMEWORK.GetJobs()) do
                if name ~= 'unemployed' and job.grades[1] then jobName, grade = name, 1 break end
            end
            if not jobName then return 'skip', 'no job with grade 1' end
            if not FRAMEWORK.SetJobOffline(one, jobName, grade) then return false, 'SetJobOffline returned false' end

            for _, member in ipairs(FRAMEWORK.GetJobMembers(jobName, { identifiers = { one } })) do
                if member.identifier == one then return member.grade == grade, ('grade %s'):format(member.grade) end
            end

            return false, 'probe not listed'
        end)

        if framework == 'ox' then cleanups[#cleanups + 1] = function() MySQL.query.await('DELETE FROM character_groups WHERE charId IN (?, ?)', { tonumber(one), tonumber(two) }) end end

        Check('licenses round trip', function()
            if framework == 'esx' and not FN_DB.HasTable('user_licenses') then return 'skip', 'no user_licenses table' end

            local license = framework == 'vrp' and 'driver' or 'fnbprobe'
            FRAMEWORK.AddLicense(one, license)
            local granted = FRAMEWORK.CheckLicense(one, license)
            FRAMEWORK.RemoveLicense(one, license)

            return granted and not FRAMEWORK.CheckLicense(one, license), ('granted=%s'):format(tostring(granted))
        end)
    end

    Check('vehicles available', function()
        local available, reason = VEHICLES.Available()

        return available, reason
    end)

    if VEHICLES.Available() and framework ~= 'vrp' then
        for _, plate in ipairs({ Probe.plate, Probe.plate2 }) do
            local schema = { esx = 'owned_vehicles', qb = 'player_vehicles', qbx = 'player_vehicles', ox = 'vehicles', standalone = 'fn_vehicles' }
            MySQL.query.await(('DELETE FROM %s WHERE plate = ?'):format(schema[framework]), { plate })
        end

        Check('VEHICLES.Add', function() return VEHICLES.Add(one, 'adder', Probe.plate, { fuelLevel = 80.0 }, { license = Probe.license }) end)
        Check('VEHICLES.Get', function()
            local vehicle = VEHICLES.Get(Probe.plate)

            return vehicle and vehicle.owner == one and vehicle.model == joaat('adder') and vehicle.stored, json.encode(vehicle)
        end)
        Check('VEHICLES.IsPlateTaken', function() return VEHICLES.IsPlateTaken(Probe.plate) and not VEHICLES.IsPlateTaken('OPBNONE') end)
        Check('VEHICLES.List', function()
            for _, vehicle in ipairs(VEHICLES.List(one)) do
                if vehicle.plate == Probe.plate then return true end
            end

            return false
        end)
        Check('VEHICLES.SetProps + GetProps', function()
            if framework == 'ox' then return 'skip', 'ox_core keeps properties in its own vehicle object' end
            if not VEHICLES.SetProps(one, Probe.plate, { fuelLevel = 42 }) then return false, 'SetProps returned false' end

            return tonumber(VEHICLES.GetProps(one, Probe.plate).fuelLevel) == 42, json.encode(VEHICLES.GetProps(one, Probe.plate))
        end)
        Check('VEHICLES.SetState out and back', function()
            if framework == 'standalone' then return 'skip', 'standalone vehicles have no garage state' end
            if not VEHICLES.SetState(one, Probe.plate, 'out') then return false, 'out failed' end

            local out = VEHICLES.Get(Probe.plate).state
            VEHICLES.SetState(one, Probe.plate, 'garage')

            return out == 'out' and VEHICLES.Get(Probe.plate).state == 'garage', out
        end)
        Check('VEHICLES.Impound and back', function()
            if framework == 'standalone' then return 'skip', 'standalone vehicles have no garage state' end
            local done, why = VEHICLES.Impound(Probe.plate, { fee = 250, reason = 'fnb' })
            if not done then return false, why end

            local vehicle = VEHICLES.Get(Probe.plate)
            local impounded = vehicle.state == 'impound' or (framework == 'ox' and vehicle.garage == 'impound')
            VEHICLES.SetState(one, Probe.plate, 'garage')

            return impounded and VEHICLES.Get(Probe.plate).state == 'garage', json.encode(vehicle)
        end)
        Check('VEHICLES.SetPlate', function()
            if not VEHICLES.SetPlate(one, Probe.plate, Probe.plate2, { onlyStored = true }) then return false, 'SetPlate returned false' end

            return VEHICLES.Get(Probe.plate2) and not VEHICLES.Get(Probe.plate)
        end)
        Check('VEHICLES.SetOwner', function()
            if not VEHICLES.SetOwner(one, Probe.plate2, two) then return false, 'SetOwner returned false' end

            return VEHICLES.Get(Probe.plate2).owner == two, VEHICLES.Get(Probe.plate2).owner
        end)
        Check('VEHICLES.Remove', function()
            local removed, why = VEHICLES.Remove(two, Probe.plate2)

            return removed and not VEHICLES.Get(Probe.plate2), why
        end)
    end

    Check('SOCIETY.GetMoney', function()
        if not FN_BRIDGE.societyName then return 'skip', 'no society resource' end

        return type(FN_BRIDGE.SOCIETY.GetMoney('police')) == 'number'
    end)

    Check('DISPATCH.Name and Send without a player', function()
        local name = FN_BRIDGE.DISPATCH.Name()

        return (name == false or type(name) == 'string') and FN_BRIDGE.DISPATCH.Send(65000, {}) == false, tostring(name)
    end)

    Check('PHONE without a player', function()
        local P = FN_BRIDGE.PHONE
        local name = P.Name()

        return (name == false or type(name) == 'string') and P.Notify(65000, { title = 'x' }) == false and P.Mail(65000, { subject = 'x', message = 'x' }) == false
            and P.Message('5550100', 65000, 'x') == false and P.Number(65000) == false and P.Notify(1, {}) == false and P.Mail('fnb_nobody', {}) == false, tostring(name)
    end)

    Check('PHONE.Mail to an offline character', function()
        local P = FN_BRIDGE.PHONE
        if P.Name() ~= 'qb-phone' then return 'skip', 'only checked live with qb-phone' end
        local cid = 'FNBPHONE1'
        local sent = P.Mail(cid, { sender = 'fn_bridge', subject = 'fnb selftest', message = 'probe' })
        Wait(300)
        local n = MySQL.scalar.await('SELECT COUNT(*) FROM player_mails WHERE citizenid = ? AND subject = ?', { cid, 'fnb selftest' }) or 0
        MySQL.query.await('DELETE FROM player_mails WHERE citizenid = ?', { cid })

        return sent == 'qb-phone' and n == 1, ('%s, %d row'):format(tostring(sent), n)
    end)

    Check('DEATH without a player', function()
        local D = FN_BRIDGE.DEATH
        local reviver = D.Reviver()

        return D.GetState(65000) == 'alive' and not D.IsDown(65000) and D.Revive(65000) == false and D.SetFlag(65000, true) == false
            and (reviver == false or type(reviver) == 'string'), tostring(reviver)
    end)

    Check('HOUSING lists without a player', function()
        local H = FN_BRIDGE.HOUSING
        local running, none = H.Running(), H.List(nil, 'fnb_nobody')
        return type(running) == 'table' and type(none) == 'table' and #none == 0 and #H.List(nil, nil) == 0, table.concat(running, ', ')
    end)

    Check('MEDIA guards and spool', function()
        local M = FN_BRIDGE.MEDIA
        local urls = M.IsUrl('https://r2.fivemanage.com/a/b.webp') and not M.IsUrl('http://x.y/a.webp') and not M.IsUrl('https://x.y/a b')
            and not M.IsUrl('https://x.y/a")') and not M.IsUrl('data:image/webp;base64,AA') and not M.IsUrl('javascript:alert(1)')
        local missing = M.Missing({ provider = 'fivemanage', token = '' })
        local guards = M.Upload('not an image', {}) == false and M.Capture(65000, {}) == false and M.Delete({ '../x' }, { token = 'x' }) == 0
        local resource = FN_BRIDGE.resourceName
        local path = exports[resource]:spool('fnbprobe.txt', 'Zm5fYnJpZGdl')
        local spooled = path == 'cache/fnbprobe.txt' and LoadResourceFile(resource, path) == 'fn_bridge' and exports[resource]:spool('../x.txt', 'eA==') == nil
        exports[resource]:unspool('fnbprobe.txt')

        return urls and guards and spooled and (GetConvar('fn_bridge:upload_token', '') ~= '' or missing[#missing] == 'token'), ('urls %s guards %s spool %s capture %s provider %s'):format(urls, guards, spooled, tostring(M.Capturer()), tostring(M.Provider()))
    end)

    Check('Provide hooks (tools/fnb_hooktest)', function()
        if GetResourceState('fnb_hooktest') ~= 'started' then return 'skip', 'fnb_hooktest is not running' end

        local hooked = FRAMEWORK.GetName(-7) == 'Hook Probe' and FN_BRIDGE.IsSupported('FRAMEWORK', 'GetName')
            and (FRAMEWORK.GetGang(-7) or {}).name == 'fnbprobe' and FN_BRIDGE.IsSupported('FRAMEWORK', 'GetGang')
            and FN_BRIDGE.DISPATCH.Name() == 'hook' and FN_BRIDGE.DISPATCH.Send(1, { coords = vector3(0.0, 0.0, 0.0) }) == 'fnb_hooktest'
            and FN_BRIDGE.Provider('garage') == 'fnb_hooktest' and ((FN_BRIDGE.Setting('garage', 'fnb_hooktest') or {}).esx or {}).parkedOut ~= 0
        local B = FN_BRIDGE
        local account, dirty = B.SOCIETY.GangAccount('fnbgang')
        local bills = B.BILLING.List('fnb_billed')
        local hooked19 = B.STAFF.Host('fnbprobejob') == 'fnb_hooktest' and B.STAFF.Host('police') == nil
            and (FRAMEWORK.GetInsurance('fnb_insured') or {}).plan == 'gold' and B.BILLING.Name() == 'fnb_hooktest'
            and B.BILLING.Send(nil, { to = 'x', amount = 5 }) == 'fnb_hooktest:7' and (bills[1] or {}).id == 'fnb_hooktest:7'
            and B.BILLING.Pay(1, 'fnb_hooktest:7') == true and B.JAIL.Name() == 'hook' and account == 'fnb_gang_account' and dirty == true
            and B.DOORS.Name() == 'hook' and B.DOORS.IsLocked('fnbdoor') and #B.DOORS.List() == 1 and B.INTERACT.Has('cuff') == 'hook'
        StopResource('fnb_hooktest')
        Wait(500)

        local released = FRAMEWORK.GetName(-7) ~= 'Hook Probe' and (FRAMEWORK.GetGang(-7) or {}).name ~= 'fnbprobe'
            and FN_BRIDGE.STAFF.Host('fnbprobejob') == nil and FN_BRIDGE.BILLING.Name() ~= 'fnb_hooktest'
        for _, key in ipairs({ 'name', 'dispatch', 'garage', 'FRAMEWORK.GetGang', 'staff', 'billing', 'jail', 'doors', 'interact' }) do
            released = released and FN_BRIDGE.Provider(key) ~= 'fnb_hooktest'
        end

        return hooked and hooked19 and released, ('hooked %s 1.9 %s released %s'):format(hooked, hooked19, released)
    end)

    Tier19(framework, create and one or nil)

    for _, cleanup in ipairs(cleanups) do pcall(cleanup) end
end

local function TierB(playerId)
    local FRAMEWORK, INVENTORY = FN_BRIDGE.FRAMEWORK, FN_BRIDGE.INVENTORY

    Check('GetIdentifier matches the player object', function()
        local player = FRAMEWORK.GetPlayerFromId(playerId)

        return player and FRAMEWORK.GetIdentifier(playerId) == player.identifier, tostring(FRAMEWORK.GetIdentifier(playerId))
    end)

    Check('GetJob', function() return type(FRAMEWORK.GetJob(playerId)) == 'table' or FN_BRIDGE.IsFramework('standalone') end)

    for _, account in ipairs({ 'bank', 'cash' }) do
        Check('money round trip: ' .. account, function()
            if FN_BRIDGE.IsFramework('standalone') then return 'skip' end

            local before = FRAMEWORK.GetMoney(playerId, account)
            if not FRAMEWORK.AddMoney(playerId, account, 7, 'fnb_selftest') then return false, 'AddMoney' end

            local added = FRAMEWORK.GetMoney(playerId, account)
            if not FRAMEWORK.RemoveMoney(playerId, account, 7, 'fnb_selftest') then return false, 'RemoveMoney' end

            return added == before + 7 and FRAMEWORK.GetMoney(playerId, account) == before and not FRAMEWORK.RemoveMoney(playerId, account, before + 1000000), ('%d -> %d'):format(before, added)
        end)
    end

    Check('GetNeeds', function() return type(FRAMEWORK.GetNeeds(playerId)) == 'table' end)

    local item
    for _, name in ipairs({ 'water', 'water_bottle', 'bread', 'sandwich', 'phone' }) do
        if INVENTORY.ItemExists(name) then item = name break end
    end

    Check('item round trip', function()
        if not item then return 'skip', 'no common test item exists' end

        local before = INVENTORY.GetItemCount(playerId, item)
        if not INVENTORY.CanCarry(playerId, item, 1) then return 'skip', 'inventory full' end
        INVENTORY.AddItem(playerId, item, 1)
        local added = INVENTORY.GetItemCount(playerId, item)
        INVENTORY.RemoveItem(playerId, item, 1)

        return added == before + 1 and INVENTORY.GetItemCount(playerId, item) == before, ('%d -> %d'):format(before, added)
    end)

    Check('SetMetadata round trip', function()
        if not item or not FN_BRIDGE.IsSupported('INVENTORY', 'SetMetadata') then return 'skip', 'not supported here' end

        INVENTORY.AddItem(playerId, item, 1, { fnb = 'a' })
        local slot
        for _, entry in ipairs(INVENTORY.GetPlayerItems(playerId)) do
            if entry.name == item and entry.metadata.fnb == 'a' then slot = entry.slot end
        end
        if not slot then return false, 'probe item not found' end

        INVENTORY.SetMetadata(playerId, slot, { fnb = 'b' })
        local tagged = INVENTORY.GetItemSlot(playerId, slot)
        INVENTORY.RemoveItem(playerId, item, 1, nil, slot)

        return tagged and tagged.metadata.fnb == 'b', json.encode(tagged)
    end)
end

RegisterCommand('fnb_selftest', function(source, args)
    if source ~= 0 then return end
    if not FN_BRIDGE.IsReady() then return print('fn_bridge is not ready yet') end

    Tally = { pass = 0, fail = 0, skip = 0 }
    local playerId = tonumber(args[1])

    CreateThread(function()
        if playerId then TierB(playerId) else TierA() end
        print(('fnb_selftest %s: %d passed, %d failed, %d skipped'):format(FN_BRIDGE.frameworkName, Tally.pass, Tally.fail, Tally.skip))
    end)
end, true)
