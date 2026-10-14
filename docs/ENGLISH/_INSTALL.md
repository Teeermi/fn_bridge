# Installing fn_bridge

Takes about five minutes. Most servers don't need to change a single setting.

## 1. Requirements

- `oxmysql`
- `ox_lib`
- One framework: **ESX Legacy 1.9+** (`es_extended`), **QBCore** (`qb-core`), **QBox** (`qbx_core`), **ox_core** or **vRP** (`vrp`). With none of them running, fn_bridge runs in standalone mode: players are known by their license and money features are off.

Older ESX versions won't work.

## 2. Add it to your server

Download the newest release from https://github.com/Teeermi/fn_bridge/releases/latest and put the `fn_bridge` folder in your resources. Don't rename it, our scripts look for it by name.

fn_bridge has no config file. To update, replace the whole folder: nothing you set lives in it.

## 3. Start order

fn_bridge looks at what's already running when it starts, so it has to come **after** your framework, inventory and target, and **before** any FIVENUTS script:

```cfg
ensure oxmysql
ensure ox_lib

ensure es_extended        # or qb-core, or qbx_core
ensure ox_inventory       # your inventory
ensure ox_target          # your target

ensure fn_bridge

ensure fn_phone          # FIVENUTS scripts go after the bridge
```

## 4. Check it worked

When it's ready, fn_bridge prints what it found:

```
FIVENUTS.DEV  fn_bridge 1.0.0
----------------------------------------
  framework   esx
  inventory   ox_inventory
  notify      okok
  help text   framework
```

If something there isn't what you expected, that's usually the cause of any problem. The F8 console shows the same block, plus your target resource.

Need more detail? Type `fnb_doctor` in the server console. It shows what fn_bridge picked for each part and why, the hooks you added, your framework's player object and table columns, running resources it has no adapter for, and an anticheat include your resources have but ours don't. It ends with the `fn_bridge_custom` blocks for whatever is missing, ready to paste.

`setr fn_bridge:debug true` in `server.cfg` logs each choice as it's made. Remove it afterwards, it's noisy.

## 5. Settings

fn_bridge detects everything on its own. Settings live in two places, and neither is inside fn_bridge, so updates never touch them.

### Server-wide: `server.cfg`

Only add a line if the banner picked the wrong resource. Use `setr`, the client needs the value too.

```cfg
setr fn_bridge:framework "qbx"
setr fn_bridge:inventory "ox_inventory"
```

| Convar | Default | What it does |
| --- | --- | --- |
| `fn_bridge:framework` | `auto` | Force `esx`, `qb`, `qbx`, `ox`, `vrp` or `standalone` |
| `fn_bridge:inventory` | `auto` | Force an inventory, or `none` to use your framework's own |
| `fn_bridge:target` | `auto` | `ox_target` or `qb-target` |
| `fn_bridge:society` | `auto` | Which resource holds job money |
| `fn_bridge:notify` | `auto` | Which resource shows notifications |
| `fn_bridge:helptext` | `auto` | Which resource shows help text |
| `fn_bridge:charid` | identifier | The short character id, see below |
| `fn_bridge:setup` | `setup` | Name of the staff coordinate command, `off` removes it |
| `fn_bridge:postal` | `nearest-postal` | Resource with your postal codes map |
| `fn_bridge:dispatch` | `auto` | Which resource gets emergency alerts, `none` turns them off |
| `fn_bridge:phone` | `auto` | Which phone gets notifications, mail and texts from scripts, `none` turns them off |
| `fn_bridge:admins` | `admin,superadmin,god` | Your staff groups, see [Admins](#admins) |
| `fn_bridge:debug` | `false` | Shows what was detected and draws target zones |
| `fn_bridge:tunnel` | `off` | `on` when web pages of fivenuts scripts go through a Cloudflare Tunnel or a proxy on this machine, see [PROTECTION.md](PROTECTION.md) |

ox_lib is never picked automatically for notifications or text UI, because it's always running and nothing else would ever get chosen. Set it by hand if you want it:

```cfg
setr fn_bridge:notify "ox"
setr fn_bridge:helptext "ox"
```

### Admins

Every FIVENUTS script asks fn_bridge who is an admin. List the groups your staff have in your framework (`xPlayer.group` on ESX, the permission on QBCore and QBox, the group on ox_core and vRP):

```cfg
setr fn_bridge:admins "owner,management,headadmin,admin"
```

A player with the `fn_bridge.admin` ACE is an admin too, which helps when your staff ranks live in an admin menu instead of the framework: `add_ace group.moderator fn_bridge.admin allow`. Each script also keeps its own ACE (for example `fn_phone.admin`) for when you want someone to manage only that one script. Players get admin rights the next time they join. Framework groups only count once the player has a character loaded, so on the character select screen use the ACE.

### Photo uploads

Scripts with photos (fn_multichar, fn_pausemenu) take the screenshot on the server and upload it from there, so no token or webhook ever reaches a player. They need `screenshot-basic` or `screencapture` running, and a place to store the files: [fivedock.dev](https://fivedock.dev). Either run the `fivedock` agent resource, which uploads with your server's own fivedock connection and needs nothing else, or put a fivedock API token in `server.cfg` once and every script uses it:

```cfg
set fn_bridge:upload_token "your-fivedock-token"
```

Use `set`, never `setr`: `setr` sends the value to every player. A token in a script's own server config wins over this one. With a token, deleting a photo in a script also deletes the file on fivedock. Already on Fivemanage? Add `set fn_bridge:upload "fivemanage"` and use your Fivemanage token.

**If you run more than one** supported resource of the same kind, the first one in the [supported list](readme.md) wins. For frameworks, QBox is checked before QBCore, since QBox servers often keep a qb-core compatibility resource around.

### Per script: `Config.Bridge`

Everything else is set per script, in that script's own config, as `Config.Bridge`. Two scripts can differ, and a script update keeps your values like any other setting of that script.

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
}
```

| Key | Default | What it does |
| --- | --- | --- |
| `language` | `ox:locale`, else `en` | Language of the script's `locales/*.json` |
| `garage` | stock garages | Which column means parked (`parkedColumn`, its value when parked, `parkedOut` for its value when out), the garage column, and extra columns to fill when the script adds a car |
| `dirtyMoney` | `markedbills`, `black_money`, `dinheirosujo` | The item used as black money where the framework has no black money account |
| `banWebhook` | empty | Discord webhook for the script's ban logs |
| `admins` | `fn_bridge:admins` | Staff groups for this script only, as a list: `{ 'owner', 'cardev' }` |
| `notify`, `showHelp`, `hideHelp`, `chat`, `revive`, ... | not set | Your own functions for this script only, see `fn_bridge_custom` below |

Leave out what you don't change. fn_bridge reads `Config.Bridge` on its own when the script starts.

### Job counter

fn_bridge counts online players per job, and every FIVENUTS script reads the same number. `police` and `ambulance` always show up, even at `0`. Staff (`admin`, `superadmin`) are counted under `admin`.

### Character id

`setr fn_bridge:charid` picks the short id FIVENUTS scripts show and search by, such as an MDT's citizen ID. Name a column on your players table (`users` on ESX, `players` on QBCore and QBox), or a field inside a JSON column as `column.key`, for example `setr fn_bridge:charid "charinfo.stateid"`.

The value has to be unique per character. fn_bridge checks this once at start. If the column is missing, the setting is malformed, or two characters share a value, it prints a warning and falls back to the player identifier. Player data is always stored under the identifier, so changing this setting never loses anything.

### /setup coordinate tool

A staff command for grabbing coordinates without guessing. Type `/setup` (staff only), aim at a spot and press `E` to copy it.

| Key | Does |
| --- | --- |
| `G` | Switch between point, ped and prop |
| Scroll | Rotate (hold Shift for bigger steps) |
| `E` | Copy to clipboard |
| Backspace | Close |

You get `vector3(...)` for a point, or `vector4(...)` with heading for a ped or prop. Paste it straight into a config. Another resource already uses `/setup`? Rename it with `setr fn_bridge:setup "coords"`, or remove it with `"off"`.

### Using your own resources: `fn_bridge_custom`

Your notifications, ambulance, dispatch or garage aren't on the list? Plug them in once, for every FIVENUTS script, in `fn_bridge_custom`. It's a small resource that belongs to you: fn_bridge updates never touch it.

1. Copy the `fn_bridge_custom` folder out of `fn_bridge` into your resources.
2. Add `ensure fn_bridge_custom` right after `ensure fn_bridge`.
3. Add the hooks you need to its `server.lua` (server side) and `client.lua` (client side), like this:

```lua
-- client.lua
exports.fn_bridge:Provide('notify', function(message, kind, time)
    exports['my_notify']:Send(message, kind, time)
end)

-- server.lua
exports.fn_bridge:Provide('revive', function(playerId)
    TriggerClientEvent('my_ambulance:revive', playerId)
end)
```

| Hook | Side | Takes | Replaces |
| --- | --- | --- | --- |
| `notify` | client | `message, kind, time` | Notifications. `kind` is `"info"`, `"success"` or `"error"` |
| `showHelp`, `hideHelp` | client | `message, position, options` / nothing | Help text in the corner |
| `seatbelt` | client | nothing, returns `true` when buckled | Seatbelt state |
| `revive` | server | `playerId` | Reviving a player |
| `name` | server | `playerId`, returns a string | Character name |
| `job` | server | `playerId`, returns a job table | The player's job |
| `phone` | server | `playerId`, returns a string | Phone number |
| `dispatch` | server | `playerId, alert` | Police and EMS alerts |
| `housing` | server | `identifier, playerId`, returns homes | Homes a character owns |
| `chat` | server | `playerId, author, message, color` | Chat messages from scripts |
| `garage` | server | a table, not a function | Garage columns, see `Config.Bridge` above |
| `dirtyMoney` | server | a table, not a function | Black money item |
| `gang` | server | `playerId`, returns a gang table | The player's gang (organisation) |
| `duty` | server | `playerId`, returns a boolean | On or off duty, for a job core that counts it |
| `multijob` | server | `{ list, set, add }` | Several jobs per character |
| `insurance` | server | `identifier`, returns `{ active, plan, expires }` | Health insurance |
| `jail` | server | `{ send, release, get }` | Your prison script |
| `communityService` | server | `playerId, actions, opts` | Community service |
| `impound` | server | `plate, opts, vehicle` | Impounding a car in your garage script |
| `gangAccount` | server | `gang`, returns the account name and `true` for dirty money | Where gang money is kept |
| `societyAccount` | server | `job`, returns the account name | A company account with a name of its own |
| `doors` | server | `{ list, isLocked, setLocked, allow }` | Your door lock script |
| `interact` | both | server `{ cuff, escort, bag, ..., is }`, client `{ isCuffed }` | Cuffs, escort and the like in your police or crime script |
| `appearance` | client | `{ set, restore }` | Wearing an outfit and taking it off |
| `FRAMEWORK.AddMoney`, `INVENTORY.AddItem`, ... | both | same as in [API.md](API.md) | That one function, completely. Any function of any namespace, by its full name |

A reader (`name`, `job`, `phone`, `gang`, `duty`) that returns `nil` falls back to what fn_bridge finds on its own. A full name like `FRAMEWORK.AddMoney` doesn't fall back, it replaces the function, so a server whose core was rewritten can still run every FIVENUTS script without touching fn_bridge. Stopping `fn_bridge_custom` removes its hooks.

**One script needs something different?** The same keys work in that script's `Config.Bridge`, and they win over `fn_bridge_custom` for that script only. Client functions there only work from a config file the script also loads on the client (`shared_scripts` or `client_scripts`).

For an inventory fn_bridge doesn't support, scripts that need one ship their own `Config.Inventory = 'custom'` hook, see that script's docs.

## 6. Good to know

- **Some data is read straight from your database:** `users`, `jobs`, `job_grades`, `owned_vehicles` and `user_licenses` on ESX, `players`, `player_vehicles` and `player_groups` on QBCore and QBox, `characters`, `character_groups`, `character_licenses` and `vehicles` on ox_core, and `vrp_user_identities` and `vrp_user_vehicles` on vRP. Renamed columns will break those features. Garages that add `in_garage`, `garage_id` and `impound` (jg-advancedgarages, cd_garage) are read without any setting.
- **In standalone mode** fn_bridge keeps cars in its own `fn_vehicles` table, created the first time a script adds one.
- **On ESX, fn_bridge adds one index** (`fn_bridge_job` on `users.job`) the first time it starts, if `job` has none yet. It speeds up job rosters and changes no data. If your database user isn't allowed to create indexes, it prints a warning and works without it.
- **Don't restart fn_bridge on a live server.** The scripts that use it keep pointing at the old copy. Restart the whole server instead. `ensure fn_bridge` on a running server counts as a restart.
- **Don't edit its files.** Updates overwrite them. Everything you're meant to change is a convar in `server.cfg`, a hook in `fn_bridge_custom`, or `Config.Bridge` in a script's config.

## Troubleshooting

| You see | Fix |
| --- | --- |
| Banner says `framework standalone` on a server with a framework | Move `ensure fn_bridge` below your framework |
| `xPlayer.<method> failed on this ESX build` | Your ESX is modified. Run `fnb_doctor` and send us its output |
| `the ... adapter never finished loading` | Your framework didn't respond in 30 seconds. Check its own errors first |
| `gave up waiting for the bridge` | That script started before fn_bridge. Move `ensure fn_bridge` above it |
| `setr fn_bridge:notify is "x" which nothing here implements` | Typo in `server.cfg`. The message lists valid values |
| `TARGET.AddBoxZone is not available` | No target resource is running, or `setr fn_bridge:target` names one that isn't started |
| `needs fn_bridge 1.0.0 or newer` | Download the newest fn_bridge and replace the folder |

Still stuck? https://fivenuts.dev
