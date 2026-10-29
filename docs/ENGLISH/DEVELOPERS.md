# Writing a script with fn_bridge

For developers building their own resource on fn_bridge. Installing it on a server? See [_INSTALL.md](_INSTALL.md).

The one rule: **your script never checks which framework is running.** If you're about to write `if framework == 'esx'`, use a bridge function instead.

## 1. Import it

At the top of your manifest:

```lua
shared_scripts {
    '@fn_bridge/import.lua',
    '@ox_lib/init.lua',
    '@fn_bridge/callback.lua',
    'config.lua',
}
```

That gives you one global, `FN_BRIDGE`. The bridge can take up to 20 seconds to be ready on a slow server, so start **both** your client and server files with:

```lua
while not FN_BRIDGE do Wait(1000) end
```

If the bridge never shows up, the console says why and `FN_BRIDGE` stays `nil`.

Add `dependency 'fn_bridge'` so the server starts it first, and say which version you need:

```lua
dependencies { 'ox_lib', 'oxmysql', 'fn_bridge' }
fn_bridge_version '1.2.0'
```

From fn_bridge 1.3.1 an older fn_bridge doesn't start your script at all and says which version it needs. Older bridges only print that line, and your script keeps running. FXServer won't let a resource stop itself, so make the rest of your code quiet when the check fails.

`@fn_bridge/callback.lua` goes right after `@ox_lib/init.lua`. You keep writing `lib.callback`, `lib.callback.await` and
`lib.callback.register` as usual, but calls from your client to your own server are sent together, one event per frame.
Many servers run a modified ox_lib that drops a player's callbacks above a few per second without an answer, and a UI
that loads ten things at once then hangs until the timeout. With this file it doesn't. Callbacks of other resources
still go through ox_lib. Server to client callbacks are unchanged. Your server answers at most 120 calls per player
per second.

## Settings for your script

fn_bridge has no config file. What a server owner might change about how fn_bridge works for **your** script goes into your own config as `Config.Bridge` (keys in [_INSTALL.md](_INSTALL.md#per-script-configbridge)). `import.lua` hands it to fn_bridge a tick after your resource loads, so you write nothing for it. To pass it earlier, or to change it at runtime:

```lua
FN_BRIDGE.Configure(Config.Bridge)
```

fn_bridge keeps one copy per resource and drops it when the resource stops.

## 2. Text and translations

Put your text in `locales/en.json` inside your own resource:

```json
{
    "welcome": "Welcome back, {name}",
    "not_owned": "You do not have that job"
}
```

Add it to your manifest:

```lua
files {
    'locales/en.json',
}
```

Then:

```lua
FN_BRIDGE.T('welcome', { name = 'John' })   --> Welcome back, John
FN_BRIDGE.T('missing_key')                  --> missing_key
```

- The language is `Config.Bridge.language` of your script, else the `ox:locale` convar, else `en`. If it's `'pl'`, your resource needs `locales/pl.json`.
- A missing language file falls back to `en.json`, so always ship English.
- A missing key shows the key itself, so you'll spot it on screen.

## 3. What's in FN_BRIDGE

```lua
FN_BRIDGE.FRAMEWORK    -- players, jobs, money, licences, vehicles
FN_BRIDGE.INVENTORY    -- items
FN_BRIDGE.NOTIFY       -- notifications, help text, chat
FN_BRIDGE.TARGET       -- target zones (client)
FN_BRIDGE.PICKER       -- pick a spot in the world (client)
FN_BRIDGE.PROGRESS     -- progress bar (client)
FN_BRIDGE.HELPER       -- commands, logs, small utilities
FN_BRIDGE.SOCIETY      -- job money (server)
```

All eight exist on both sides. If one has nothing behind it (like `TARGET` on the server), calling it logs a message and returns `false` instead of erroring.

Every function is listed in [API.md](API.md). If it isn't there, don't rely on it.

### The player identifier

`player.identifier` is what you save player data under. It's the ESX identifier on ESX, and the `citizenid` on QBCore and QBox. Always read it from the player object and never try to parse it.

```lua
local player = FN_BRIDGE.FRAMEWORK.GetPlayerFromId(playerId)
local identifier = player and player.identifier
```

## 4. Player state

fn_bridge already tracks the local player, so don't poll natives in a loop. Read these instead:

```lua
GlobalState.fn_playerPed        -- ped handle
GlobalState.fn_playerId         -- local player id
GlobalState.fn_serverId         -- server id
GlobalState.fn_isDead           -- true or false
GlobalState.fn_playerCoords     -- vector3, updated 4 times a second
GlobalState.fn_playerWeapon     -- current weapon hash
GlobalState.fn_vehicle          -- vehicle handle, or false
GlobalState.fn_vehicleDriver    -- true when driving
```

## 5. Events

```lua
-- client
AddEventHandler('fn_bridge/client/updatePlayerData', function(playerData) end)
AddEventHandler('fn_bridge/client/isDead', function(isDead) end)
AddEventHandler('fn_bridge/client/onVehicleEnter', function(vehicle, isDriver) end)
AddEventHandler('fn_bridge/client/onVehicleLeave', function(vehicle, wasDriver) end)

-- server
AddEventHandler('fn_bridge/server/playerLoaded', function(playerId, player) end)
AddEventHandler('fn_bridge/server/onJobChange', function(playerId, job, lastJob) end)
```

Name your own events the same way, with the side in the middle: `my_resource/server/doSomething`.

## 6. A full example

A paycheck desk: police can collect their pay with a target zone or a key.

`fxmanifest.lua`

```lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

shared_scripts {
    '@fn_bridge/import.lua',
    '@ox_lib/init.lua',
    '@fn_bridge/callback.lua',
}

client_script 'client/main.lua'
server_script 'server/main.lua'

files {
    'locales/en.json',
}
```

`locales/en.json`

```json
{
    "paid": "You were paid {amount}",
    "wrong_job": "You do not work here",
    "collect": "Collect your pay"
}
```

`client/main.lua`

```lua
while not FN_BRIDGE do Wait(1000) end

OP = {
    zoneName = 'paycheck_desk',
}

OP.Collect = function()
    if FN_BRIDGE.FRAMEWORK.GetJob().name ~= 'police' then
        return FN_BRIDGE.NOTIFY.Notify(FN_BRIDGE.T('wrong_job'), 'error')
    end

    TriggerServerEvent('paycheck/server/collect')
end

CreateThread(function()
    FN_BRIDGE.TARGET.AddBoxZone(OP.zoneName, vector3(441.0, -982.0, 30.7), vector3(1.0, 1.0, 2.0), 0.0, {
        {
            name = OP.zoneName,
            label = FN_BRIDGE.T('collect'),
            icon = 'fas fa-money-bill',
            onSelect = OP.Collect,
        },
    })
end)

FN_BRIDGE.HELPER.RegisterKey('F5', 'paycheck', FN_BRIDGE.T('collect'), OP.Collect)
```

`server/main.lua`

```lua
while not FN_BRIDGE do Wait(1000) end

local OP = {
    amount = 500,
}

RegisterNetEvent('paycheck/server/collect', function()
    local playerId = source
    local player = FN_BRIDGE.FRAMEWORK.GetPlayerFromId(playerId)
    if not player or player.job.name ~= 'police' then return end

    player.addAccountMoney('bank', OP.amount)

    FN_BRIDGE.NOTIFY.Notify(playerId, FN_BRIDGE.T('paid', {
        amount = FN_BRIDGE.HELPER.NumWithCommas(OP.amount),
    }), 'success')
end)
```

This runs on ESX, QBCore and QBox as is. Notice the server takes the player from `source` and checks the job again, instead of trusting the client.

## 7. Items

```lua
-- server
FN_BRIDGE.INVENTORY.AddItem(playerId, 'water', 1)
FN_BRIDGE.INVENTORY.RemoveItem(playerId, 'water', 1)
FN_BRIDGE.INVENTORY.GetItemCount(playerId, 'water')
FN_BRIDGE.INVENTORY.HasItem(playerId, 'water')

-- client
FN_BRIDGE.INVENTORY.OpenInventory('stash', { id = 'garage', owner = 'char1:abc' })
```

Items always come back in the same shape, whatever inventory the server runs:

```lua
{ name = 'water', label = 'Water', count = 3, metadata = {}, slot = 5 }
```

- On most inventories, `AddItem` / `RemoveItem` returning `true` only means the call went through. If you need to be sure, check `GetItemCount` afterwards.
- Matching items by `metadata` works differently per inventory. Test it on the inventory you're targeting.

## 8. Target zones

```lua
FN_BRIDGE.TARGET.AddBoxZone(name, coords, size, heading, options)
FN_BRIDGE.TARGET.AddSphereZone(name, coords, radius, options)
FN_BRIDGE.TARGET.RemoveZone(name)
```

Options use the ox_target format on both ox_target and qb-target, and `onSelect` always gets the entity. Remove zones by **name**. Zones are cleaned up automatically when your resource stops.

## 9. Do and don't

| Don't | Do |
| --- | --- |
| Check the framework name | Use a bridge function |
| Use `FN_BRIDGE.FRAMEWORK.obj` | Use the named getters |
| Poll `PlayerPedId()` in a loop | Read `GlobalState.fn_playerPed` |
| Write text straight into code | Use `FN_BRIDGE.T('key')` |
| Trust a player id from the client | Use `source` on the server |

`fn_bridge/snippets.lua` has every state key and event ready to copy.
