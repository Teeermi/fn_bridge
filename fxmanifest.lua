fx_version 'cerulean'
game 'gta5'
lua54 'yes'

version '1.0.0'
author 'fivenuts.dev | https://fivenuts.dev'
description 'fn_bridge - Bridge for op scripts'

dependencies {
    'ox_lib',
    'oxmysql',
}

shared_scripts {
    '@ox_lib/init.lua',
    'shared/settings.lua',
    'shared/init.lua',
}

client_scripts {
    'modules/framework/esx/client.lua',
    'modules/framework/qbx/client.lua',
    'modules/framework/qb/client.lua',
    'modules/framework/mirror/client.lua',
    'modules/characters/client.lua',
    'modules/helper/client.lua',
    'modules/notify/client.lua',
    'modules/death/client.lua',
    'modules/dispatch/client.lua',
    'modules/setup/client.lua',
    'modules/picker/client.lua',
    'modules/keys/client.lua',
    'modules/voice/client.lua',
    'modules/appearance/client.lua',
    'modules/jail/client.lua',
    'modules/interact/client.lua',
    'modules/prefs/client.lua',
    'modules/target/ox_target/client.lua',
    'modules/target/qb-target/client.lua',
    'modules/inventory/ak47_inventory/client.lua',
    'modules/inventory/tgiann-inventory/client.lua',
    'modules/inventory/codem-inventory/client.lua',
    'modules/inventory/qs-inventory/client.lua',
    'modules/inventory/ps-inventory/client.lua',
    'modules/inventory/qb-inventory/client.lua',
    'modules/inventory/ox_inventory/client.lua',
    'modules/inventory/_default/client.lua',
    'client.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'modules/db/server.lua',
    'modules/framework/jobs.lua',
    'modules/framework/esx/server.lua',
    'modules/framework/qbx/server.lua',
    'modules/framework/qb/server.lua',
    'modules/framework/qbfamily/server.lua',
    'modules/framework/ox/server.lua',
    'modules/framework/vrp/server.lua',
    'modules/framework/standalone/server.lua',
    'modules/framework/groups.lua',
    'modules/framework/mirror/server.lua',
    'modules/vehicles/server.lua',
    'modules/characters/server.lua',
    'modules/keys/server.lua',
    'modules/framework/charid.lua',
    'modules/framework/counter.lua',
    'modules/helper/server.lua',
    'modules/notify/server.lua',
    'modules/dispatch/server.lua',
    'modules/death/server.lua',
    'modules/media/server.lua',
    'modules/housing/server.lua',
    'modules/voice/server.lua',
    'modules/jail/server.lua',
    'modules/billing/server.lua',
    'modules/staff/server.lua',
    'modules/doors/server.lua',
    'modules/appearance/server.lua',
    'modules/interact/server.lua',
    'modules/media/spool.js',
    'modules/setup/server.lua',
    'modules/inventory/ak47_inventory/server.lua',
    'modules/inventory/tgiann-inventory/server.lua',
    'modules/inventory/codem-inventory/server.lua',
    'modules/inventory/qs-inventory/server.lua',
    'modules/inventory/ps-inventory/server.lua',
    'modules/inventory/qb-inventory/server.lua',
    'modules/inventory/ox_inventory/server.lua',
    'modules/inventory/core_inventory/server.lua',
    'modules/inventory/origen_inventory/server.lua',
    'modules/inventory/_default/server.lua',
    'modules/inventory/define.lua',
    'modules/inventory/stash.lua',
    'modules/society/Renewed-Banking/server.lua',
    'modules/society/qb-management/server.lua',
    'modules/society/qb-banking/server.lua',
    'modules/society/esx_addonaccount/server.lua',
    'modules/society/_default/server.lua',
    'modules/society/server.lua',
    'server.lua',
    'modules/selftest/server.lua',
    'modules/doctor/server.lua',
}

files {
    'import.lua',
}
