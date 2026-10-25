local function Convar(name, default)
    local value = GetConvar('fn_bridge:' .. name, '')

    return value ~= '' and value or default
end

local setupCommand = Convar('setup', 'setup')

local admins = {}
for name in Convar('admins', 'admin,superadmin,god'):gmatch('[^%s,]+') do admins[#admins + 1] = name end

Config = {
    ResourceName = GetCurrentResourceName(),
    Debug = Convar('debug', 'false') == 'true',
    Framework = Convar('framework', 'auto'),
    InventorySystem = Convar('inventory', 'auto'),
    NotifySystem = Convar('notify', 'auto'),
    ShowHelpSystem = Convar('helptext', 'auto'),
    TargetSystem = Convar('target', 'auto'),
    Society = Convar('society', 'auto'),
    FrameworkUniqueId = Convar('charid', nil),
    Postal = Convar('postal', 'nearest-postal'),
    Dispatch = Convar('dispatch', 'auto'),
    Phone = Convar('phone', 'auto'),
    Voice = Convar('voice', 'auto'),
    Weather = Convar('weather', 'auto'),
    AdminGroups = admins,
    Counter = {
        dutyAware = false,
        jobs = { 'police', 'ambulance' },
    },
    Setup = {
        command = setupCommand ~= 'off' and setupCommand or false,
        distance = 25.0,
        ped = 'a_m_m_business_01',
        prop = 'prop_barrier_work05',
    },
    Picker = {
        distance = 25.0,
        headingStep = 5.0,
        headingStepFast = 22.5,
        zSpeed = 0.5,
        zSpeedFast = 2.0,
        sizeStep = 0.25,
        precision = 3,
        keys = {
            confirm = 38,
            cancel = 177,
            fast = 21,
            rotateLeft = 242,
            rotateRight = 241,
            zUp = 172,
            zDown = 173,
            resetZ = 45,
            sizeShrink = 174,
            sizeGrow = 175,
            axis = 47,
        },
    },
}

Config.DebugPrint = function(...)
    if not Config.Debug then return end
    print('[^2'..Config.ResourceName..'^7] ^3DEBUG^7:', ...)
end
