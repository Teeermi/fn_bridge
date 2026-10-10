# fn_bridge

Free bridge between FIVENUTS FiveM scripts and your framework, inventory, garage, target, notifications and job
money. The same script runs on ESX, QBCore, QBox, ox_core, vRP or with no framework, and a fix for a framework
update ships here once.

Download: https://github.com/Teeermi/fn_bridge/releases/latest. Needs `ox_lib` and `oxmysql`.

## Install

Put the folder in `resources` as `fn_bridge` (scripts look it up by that name) and start it after your framework,
inventory and target, before any FIVENUTS script:

```cfg
ensure oxmysql
ensure ox_lib

ensure qbx_core           # or es_extended, qb-core, ox_core, vrp
ensure ox_inventory       # your inventory
ensure ox_target          # your target

ensure fn_bridge

ensure fn_phone           # FIVENUTS scripts go after the bridge
ensure fn_itemshop
ensure fn_multichar
```

On start it prints what it found. A line that doesn't match your server is the first thing to fix; F8 shows the same
block plus the target resource.

```
FIVENUTS.DEV  fn_bridge 1.0.0
----------------------------------------
  framework   qbx
  inventory   ox_inventory
  notify      framework
  help text   framework
  society     Renewed-Banking
  vehicles    ok
```

With no framework it runs standalone: players are known by license, cars go to its own `fn_vehicles` table.

## Update

There is no config file inside fn_bridge. Delete the folder, put the new release in, restart the whole server.
Scripts hold the old copy until they restart, and `ensure fn_bridge` on a live server counts as a restart. Every
script checks the version it needs on start and prints the download link if yours is older.

## Used by

| Script | Uses |
| --- | --- |
| fn_phone | players, money, jobs, items, vehicles and keys, society money, target, characters |
| fn_itemshop (CoinStore) | players, money, items, vehicles and garages, test drive keys, characters |
| fn_multichar | character list, create, login, delete, logout, spawn, starter items |
| fn_profiles | character id, money, vehicle count |

## Settings

Most servers set nothing. Server-wide choices go in `server.cfg`, per-script ones in that script's config.

### `server.cfg`

Only when the banner picked the wrong resource. Use `setr` so clients get the value.

```cfg
setr fn_bridge:inventory "ox_inventory"
setr fn_bridge:notify "ox"
```

| Convar | Default | Values |
| --- | --- | --- |
| `fn_bridge:framework` | `auto` | `esx`, `qb`, `qbx`, `ox`, `vrp`, `standalone` |
| `fn_bridge:inventory` | `auto` | an inventory resource, or `none` for the framework's own |
| `fn_bridge:target` | `auto` | `ox_target`, `qb-target` |
| `fn_bridge:society` | `auto` | the resource that holds job money |
| `fn_bridge:notify` | `auto` | a notify resource; `ox` (ox_lib) is never picked automatically |
| `fn_bridge:helptext` | `auto` | a text UI resource; `ox` (ox_lib) is never picked automatically |
| `fn_bridge:charid` | identifier | short character id: a players column or `column.jsonKey`, e.g. `charinfo.stateid` |
| `fn_bridge:setup` | `setup` | name of the staff coordinate command, `off` removes it |
| `fn_bridge:dispatch` | `auto` | the resource that gets emergency alerts, `none` for no alerts |
| `fn_bridge:phone` | `auto` | the phone that gets notifications, mail and texts from scripts, `none` for none |
| `fn_bridge:debug` | `false` | `true` prints every detection step and draws target zones |

### `fn_bridge_custom`

Your own resources (notify, ambulance, dispatch, housing, renamed garage columns) plug in once for every FIVENUTS script.
Copy the `fn_bridge_custom` folder out of `fn_bridge`, `ensure` it after fn_bridge and add the hooks you need to its `server.lua` and `client.lua`:

```lua
exports.fn_bridge:Provide('revive', function(playerId)
    TriggerClientEvent('my_ambulance:revive', playerId)
end)
```

Hooks: `notify`, `showHelp`, `hideHelp`, `seatbelt` (client), `revive`, `name`, `job`, `phone`, `dispatch`, `housing`,
`chat`, `garage`, `dirtyMoney` (server), and any API function by its full name (`FRAMEWORK.AddMoney`), which replaces it. fn_bridge updates never touch that resource. `fnb_doctor` in the console prints
the blocks your server is missing.

### `Config.Bridge`

Lives in each script's own config, so script updates keep it and two scripts can differ. Same keys as the hooks above;
a value here wins over `fn_bridge_custom` for that script only. Leave out what you don't change.

```lua
Config.Bridge = {
    language = 'pl',
    garage = {
        esx = { parkedColumn = 'stored', stored = 1, garageColumn = 'parking' },
        qb = { parkedColumn = 'state', state = 1, garageColumn = 'garage', garage = 'pillboxgarage' },
    },
    dirtyMoney = {
        qb = { item = 'markedbills', worth = 'worth' },
        ox = { item = 'black_money' },
        vrp = { item = 'dinheirosujo' },
    },
    banWebhook = '',
    notify = function(message, messageType, time) exports['my_notify']:Send(message, messageType, time) end,
    showHelp = function(message, position, options) exports['my_textui']:Show(message) end,
    hideHelp = function() exports['my_textui']:Hide() end,
}
```

| Key | Default | What it sets |
| --- | --- | --- |
| `language` | `ox:locale`, else `en` | language of the script's texts that go through fn_bridge |
| `garage` | stock garages | parked column and value (`parkedOut` = value when out), garage column, extra columns filled on insert; `qb` covers QBox |
| `dirtyMoney` | see above | black money item where the framework has no black money account |
| `banWebhook` | empty | Discord webhook for the script's ban logs |
| `notify`, `showHelp`, `hideHelp` | not set | your own notify and text UI; client side, so the config must load on the client |
| `chat` | not set | `chat(playerId, author, message, color)` on the server, for a chat without `chat:addMessage` |

jg-advancedgarages and cd_garage columns (`in_garage`, `garage_id`, `impound`) need no setting. Inventories fn_bridge
doesn't cover go through the script's own hook, e.g. `Config.Inventory = 'custom'` in fn_itemshop.

## Supports

| | |
| --- | --- |
| Framework | ESX Legacy 1.9+, QBCore, QBox, ox_core, vRP, standalone |
| Inventory | ox_inventory, qb-inventory, ps-inventory, qs-inventory, codem-inventory, tgiann-inventory, ak47_inventory, core_inventory, origen_inventory, framework's own |
| Target | ox_target, qb-target |
| Notifications | okokNotify, mythic_notify, pNotify, t-notify, vms_notifyv2, brutal_notify, g-notifications, r_notify, wasabi_notify, wasabi_uikit, lation_ui, is_ui, ox_lib, framework's own, your function |
| Text UI | jg-textui, okokTextUI, cd_drawtextui, lab-HintUI, ox_lib, framework's own, your function |
| Society money | esx_addonaccount, qb-management, qb-banking, Renewed-Banking |
| Garages | owned_vehicles, player_vehicles, ox_core vehicles, vRP, jg-advancedgarages and cd_garage columns |
| Character select | ESX (esx_multicharacter mode), QBCore, QBox, ox_core |
| Jail | xt-prison, qb-prison, pickle_prisons, esx_jail, esx-qalle-jail, esx_communityservice, your function |
| Invoices | esx_billing, fn_business, your function |
| Door locks | ox_doorlock, qb-doorlock, your function |
| Clothing | illenium-appearance, fivem-appearance, qb-clothing, esx_skin, your function |
| Radio | pma-voice, SaltyChat |
| Phone | fn_phone, lb-phone, npwd, qb-phone |
| Cuffs and escort | qb-policejob, qbx_police, esx_policejob, your function |
| Multijob | Qbox, ps-multijob, your function |

If two resources of one kind run, the first in the list wins. QBox is checked before QBCore because QBox servers
often keep a qb-core compatibility resource.

## For developers

```lua
dependencies { 'ox_lib', 'oxmysql', 'fn_bridge' }
fn_bridge_version '1.0.0'

shared_scripts {
    '@fn_bridge/import.lua',
    '@ox_lib/init.lua',
    'config.lua',
}
```

This gives one global, `FN_BRIDGE`: `FRAMEWORK`, `INVENTORY`, `VEHICLES`, `KEYS`, `SOCIETY`, `CHARACTERS`, `NOTIFY`,
`TARGET`, `PICKER`, `HELPER`. Never branch on the framework in your script; use a bridge function. `Config.Bridge` in
your config is picked up automatically, `FN_BRIDGE.Configure(Config.Bridge)` changes it at runtime. Signatures never
change between versions; new versions only add functions.

[DEVELOPERS.md](docs/ENGLISH/DEVELOPERS.md) covers import, translations and a worked example,
[API.md](docs/ENGLISH/API.md) every function and which framework supports it,
[_INSTALL.md](docs/ENGLISH/_INSTALL.md) the long install guide. Console: `fnb_doctor` (what was picked and what is missing), `fnb_selftest` (no player needed) or
`fnb_selftest <playerId>`.

## Troubleshooting

| You see | Fix |
| --- | --- |
| `framework standalone` on a server with a framework | move `ensure fn_bridge` below the framework |
| `the ... adapter never finished loading` | the framework didn't answer in 30 s, check its own errors |
| `gave up waiting for the bridge` | that script started first, move `ensure fn_bridge` above it |
| `needs fn_bridge 1.0.0 or newer` | download the latest release, replace the folder |
| `Couldn't start resource ...: dependency fn_bridge` | fn_bridge is missing or not started |
| `setr fn_bridge:notify is "x" which nothing here implements` | typo in `server.cfg`, the message lists valid values |
| `TARGET.AddBoxZone is not available` | no target resource runs, or `fn_bridge:target` names one that isn't started |

Support: https://fivenuts.dev
