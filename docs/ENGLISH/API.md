# fn_bridge API

Every function fn_bridge gives your script. New to the bridge? Start with [DEVELOPERS.md](DEVELOPERS.md).

This list is fixed. If a function isn't here, don't build on it, because it can change without notice.

## Basics

- **Nothing throws.** If something isn't found or can't be done, you get `false`. Lists and maps come back as `{}`, never `nil`, so you can loop over them right away.
- The only `nil` you'll see is from client getters (`GetPlayerGroup`, `GetIdentifier`, `GetName`) before the player has loaded.
- **SQL = yes** means the function waits on the database. Fine in events and callbacks, not in a per-frame loop.
- Namespace functions are `PascalCase`. Methods on the player object are `camelCase`.

### Money accounts

Always use these names. The bridge translates them for each framework.

| You use | ESX | QBCore / QBox |
| --- | --- | --- |
| `cash` | `money` | `cash` |
| `bank` | `bank` | `bank` |
| `black_money` | `black_money` | none, always `0` |

QBCore's `crypto` is not mapped to anything.

### Callbacks

Callbacks use `lib.callback` from ox_lib:

```lua
local accounts = lib.callback.await('fn_bridge/server/getAccounts', false)
```

## The player object

Returned by `GetPlayerFromId` and `GetPlayerFromIdentifier`. Every field is always filled, so no nil checks are needed.

```lua
{
    source = 12,
    identifier = 'char1:abc...',
    group = 'user',
    job = {
        name = 'unemployed',
        label = 'Unemployed',
        grade = 0,
        grade_name = 'unemployed',
        grade_label = 'Unemployed',
    },
    char = {
        firstName = 'John',
        lastName = 'Doe',
        sex = 'm',
        badge = '',
    },
}
```

| Method | Args | Returns |
| --- | --- | --- |
| `getName` | `separate` | full name, or `{ firstname, lastname }` when `separate` is true |
| `setJob` | `jobName`, `jobGrade`, `onDuty` | nothing |
| `addAccountMoney` | `accountName`, `amount` | `true`, or `false` if the amount isn't positive |
| `removeAccountMoney` | `accountName`, `amount` | `true`, or `false` if the amount isn't positive |
| `getAccounts` | none | `{ cash, bank, black_money }` |
| `addInventoryItem` | `itemName`, `amount`, `metadata` | nothing |
| `removeInventoryItem` | `itemName`, `amount`, `metadata` | nothing |
| `updateChar` | `key`, `value` | nothing |
| `showNotification` | `message`, `type`, `duration` | nothing |

- `updateChar` takes `firstname` and `lastname` on every framework. Other keys go to the framework unchanged.
- On QBCore and QBox, `grade_name` and `grade_label` hold the same text, because those frameworks have one name per grade.
- `char.badge` is the callsign on QBCore and QBox, and `''` on ESX.

## FN_BRIDGE.FRAMEWORK (server)

| Function | Args | Returns | SQL | ESX | QBCore | QBox |
| --- | --- | --- | --- | --- | --- | --- |
| `GetFrameworkName` | none | `'esx'` / `'qb'` / `'qbx'` / `'ox'` / `'vrp'` / `'standalone'` | no | ✅ | ✅ | ✅ |
| `GetPlayerFromId` | `playerId` | player object, or `false` | no | ✅ | ✅ | ✅ |
| `GetPlayerFromIdentifier` | `identifier` | player object, or `false` | no | ✅ | ✅ | ✅ |
| `GetPlayers` | none | array of server ids | no | ✅ | ✅ | ✅ |
| `GetOfflineCharName` | `identifier`, `separate` | name, `{ firstname, lastname }`, or `false` | yes | ✅ | ✅ | ✅ |
| `SearchCharacters` | `query`, `limit` | array of `{ identifier, charId, firstName, lastName, name, job, grade, lastSeen, dateOfBirth, sex, nationality }` | yes | ✅ | ✅ | ✅ |
| `GetCharId` | `identifier` | character id, or the identifier | yes | ✅ | ✅ | ✅ |
| `GetJobMembers` | `jobName` (string or array), `options` | array of `{ identifier, firstName, lastName, name, job, grade, gradeLabel }` | yes | ✅ | ✅ | ✅ |
| `SetJobOffline` | `identifier`, `jobName`, `jobGrade` | `true` if a row changed | yes | ✅ | ✅ | ✅ |
| `CheckJobDuty` | `playerId` | boolean | no | ✅ | ✅ | ✅ |
| `SetJobDuty` | `playerId`, `dutyStatus` | boolean | no | ✅ | ✅ | ✅ |
| `GetJobs` | none | map of job name to `{ name, label, grades }` | yes | ✅ | ✅ | ✅ |
| `GetCounter` | `'admin'` or a job name | number | no | ✅ | ✅ | ✅ |
| `GetJobPlayers` | `jobName` | array of job entries | no | ✅ | ✅ | ✅ |
| `GetJobPlayerCount` | `jobName` | number | no | ✅ | ✅ | ✅ |
| `GetPlayerJobEntry` | `playerId` | job entry, or `false` | no | ✅ | ✅ | ✅ |
| `CheckPermissions` | `playerId`, `groups` (`{ 'admin' }` or `{ admin = true }`) | boolean | no | ✅ | ✅ | ✅ |
| `RegisterUsableItem` | `itemName`, `callback(player)` | nothing | no | ✅ | ✅ | ✅ |
| `UseItem` | `playerId`, `itemName` | nothing | no | ✅ | ✅ | ✅ |
| `GetItemLabel` | `itemName` | label, or the item name | no | ✅ | ✅ | ✅ |
| `GetVehicleByPlate` | `plate` | `{ owner, plate, vehicle, stored }`, or `false` | yes | ✅ | ✅ | ✅ |
| `GetPlayerVehicles` | `identifier` | array of vehicles | yes | ✅ | ✅ | ✅ |
| `CheckLicense` | `identifier`, `license` | boolean | yes | ✅ | ✅ | ✅ |
| `AddLicense` | `identifier`, `license` | `true` | yes | ✅ | ✅ | ✅ |
| `RemoveLicense` | `identifier`, `license` | `true` | yes | ✅ | ✅ | ✅ |

**Added in 1.1.** These work on every framework fn_bridge supports (ESX, QBCore, QBox, ox_core, vRP, standalone). Where a framework has nothing behind a function, it returns `false`, `0` or `{}`. `Supports(feature)` tells you up front.

| Function | Args | Returns | SQL |
| --- | --- | --- | --- |
| `GetIdentifier` | `playerId` | identifier, or `false` (cheap, no player object) | no |
| `GetMoney` | `playerId`, `account` | number | no |
| `AddMoney` | `playerId`, `account`, `amount`, `reason` | boolean | no |
| `RemoveMoney` | `playerId`, `account`, `amount`, `reason` | boolean, `false` when there isn't enough | no |
| `GetJob` | `playerId` | `{ name, label, grade, grade_name, grade_label, isBoss, onDuty }`, or `false` | no |
| `SetJob` | `playerId` or `identifier`, `jobName`, `grade` | boolean, online or offline, checks the job exists | maybe |
| `RemoveJob` | `playerId` or `identifier`, `jobName` | boolean (fires from that job) | maybe |
| `GetGang` | `playerId` | `{ name, label, grade, grade_name, grade_label, isBoss }`, or `false` | no |
| `GetNeeds` | `playerId` | `{ hunger, thirst, stress }`, each 0-100 or missing | no |
| `GetPlayTime` | `playerId` | seconds, or `false` | no |
| `GetPhoneNumber` | `playerId` | number as text, or `false` | maybe |
| `SetPhoneNumber` | `playerId`, `number` | boolean | yes |
| `IsPhoneNumberTaken` | `number` | boolean | yes |
| `SetName` | `playerId`, `firstName`, `lastName` | boolean | yes |
| `IsNameTaken` | `firstName`, `lastName` | boolean | yes |
| `GetCharacter` | `identifier` | `{ identifier, firstName, lastName, name, dateOfBirth, sex, nationality, licenses }`, or `false` | yes |
| `GetCharacters` | `license` (`license:abc` or `abc`) | array of `{ identifier, name }` | yes |
| `AddCharacterSlots` | `license`, `amount`, `default`, `max` | boolean (esx_multicharacter) | yes |
| `Supports` | `'phoneNumber'`, `'characterSlots'`, `'needs'`, `'playTime'`, `'gangs'`, `'vehicles'` | boolean | maybe |

- `account` is `cash`, `bank` or `black_money`. On QBCore, QBox, ox_core and vRP `black_money` is an item (`Config.Bridge.dirtyMoney` of the calling script): `markedbills` with a `worth` on QBCore, `black_money` on QBox with ox_inventory and on ox_core, `dinheirosujo` on vRP. Any other account the player has (QBCore `crypto`) works by its own name.
- `reason` ends up in the framework's money log where it has one.
- `RegisterUsableItem` callbacks get a second argument, `{ name, slot, metadata }`, when the framework passes them. On ox_core point the item at `export = 'fn_bridge.useItem'` in ox_inventory's items.
- `GetJobs` grades carry `isBoss`.

**Duty.** On ESX this uses `job.onDuty`. On an ESX version without it, `CheckJobDuty` returns `true` so nobody gets locked out, and `SetJobDuty` returns `false`.

**Job entries.** fn_bridge keeps one live list of who's online in which job. `GetCounter`, `GetJobPlayers`, `GetJobPlayerCount` and `GetPlayerJobEntry` read it, so they're cheap. Each entry:

| Field | Type | Notes |
| --- | --- | --- |
| `source` | number | server id |
| `identifier` | string | ESX identifier, or citizen id |
| `charId` | string | the character id, or the identifier (see the `fn_bridge:charid` convar) |
| `job` | string | job name |
| `grade` | number | `0` when unknown |
| `grade_name` | string | `'unemployed'` when unknown |
| `grade_label` | string | `'Unemployed'` when unknown |
| `group` | string | `'user'` when none |
| `onDuty` | boolean | |

You get copies, so changing them changes nothing. `GetJobPlayers` lists everyone with the job, on duty or not. `GetCounter('admin')` counts online staff (`admin`, `superadmin`), not a job.

**Vehicles.** `stored` is always `true` / `false`. On QBCore and QBox, `vehicle` holds the vehicle's properties.

**Licences.** `AddLicense` never creates duplicates.

**GetJobMembers** lists everyone with that saved job, online or not. Page it with `options`: `{ limit = 25, offset = 0, search = 'name', identifiers = { ... }, exclude = { ... } }`. `limit` is 1 to 500. There's no total, so ask for `limit + 1` to know if there's another page. It reads the saved job, so combine it with `GetJobPlayers` for players online right now.

**SearchCharacters** finds characters online or offline, by exact identifier, exact character id, or first/last name prefix. Queries under 2 characters return `{}`, and `limit` caps at 10, so call it with a debounce. On ESX, `lastSeen` and `nationality` are always `nil`, and `dateOfBirth` is whatever format your identity resource saves.

On big servers, name searches get faster with this index (ESX):

```sql
ALTER TABLE users ADD INDEX idx_users_name (firstname, lastname);
```

## FN_BRIDGE.VEHICLES (server)

Owned vehicles in the garage table of the running framework: `owned_vehicles` (ESX), `player_vehicles` (QBCore, QBox), `vehicles` (ox_core), `vrp_user_vehicles` (vRP, read only), `fn_vehicles` (standalone, created on first use). jg-advancedgarages and cd_garage columns (`in_garage`, `garage_id`, `impound`) are picked up by themselves.

`owner` is an identifier or an array of them. On QBCore and QBox an entry starting with `license:` matches the `license` column instead of `citizenid`.

| Function | Args | Returns |
| --- | --- | --- |
| `Available` | none | boolean, and a reason or warning |
| `Get` | `plate` | vehicle, or `false` |
| `List` | `owner` | array of vehicles |
| `IsPlateTaken` | `plate` | boolean |
| `IsStored` | `owner`, `plate` | boolean |
| `GetProps` | `owner`, `plate` | props table, `{}` when not found |
| `Add` | `owner`, `model`, `plate`, `props`, `{ garage, license, vin }` | boolean, error |
| `Remove` | `owner`, `plate`, `{ force }` | boolean, error, vehicle (with `row`) |
| `SetOwner` | `owner`, `plate`, `newOwner`, `{ onlyStored }` | boolean, error |
| `TransferAll` | `fromOwner`, `toOwner` | number of vehicles moved |
| `SetPlate` | `owner`, `plate`, `newPlate`, `{ onlyStored }` | boolean, error (also renames qb trunk and glovebox stashes) |
| `SetProps` | `owner`, `plate`, `props`, `{ onlyStored }` | boolean, error (merges keys into the saved props) |
| `SetState` | `owner`, `plate`, `'out'` or `'garage'`, `{ garage }` | boolean, error (`'garage'` also clears impound and depot fees) |
| `GarageColumn` | none | the column a garage name goes into, or `false` |

A vehicle:

```lua
{
    owner = 'ABC12345', plate = 'FN 123', model = 1234567890, modelName = 'adder',
    props = {}, vehicle = {}, state = 'garage', stored = true, garage = 'pillboxgarage',
    kind = 'car', fuel = 80, engine = 100, body = 100,
}
```

`state` is `'garage'`, `'out'` or `'impound'`. `fuel`, `engine` and `body` are 0-100, or `nil` when unknown. `Remove` refuses a car that is out unless `force` is set. Errors: `'table_missing'`, `'schema'`, `'not_owned'`, `'not_stored'`, `'plate_taken'`, `'unsupported'`, `'failed'`.

`Config.Bridge.garage` of the calling script sets which column means parked, the parked value, the garage column, and extra columns to fill when a vehicle is added.

## FN_BRIDGE.CHARACTERS (server)

Character select and lifecycle, for multicharacter scripts. ESX (with esx_multicharacter's `Config.Multichar`), QBCore, QBox and ox_core. On vRP and standalone `Supported()` is `false` and every call returns `false`, `nil` or `{}`. `key` is the framework's character id (`char1:abc` on ESX, citizenid on QBCore and QBox, charId as a string on ox_core).

| Function | Arguments | Returns |
| --- | --- | --- |
| `Supported` | none | boolean |
| `Owner` | `playerId` | what characters are listed by: ESX identifier, license on QBCore and QBox, `nil` on ox_core |
| `List` | `playerId`, `owner` (optional, ox_core userId) | array of `{ key, num, firstname, lastname, dob, sex, height, nationality, phone, cid, job, jobName, grade, cash, bank, dirty, position, seen, jail, down, inside, property, skin }` (`down` = downed or dead when the player logged out; fields the framework lacks are `nil`) |
| `DeferredLogin` | none | `true` on ox_core: log in only after the spawn, ox acts on login at once |
| `TakeOver` | none | hands character select over to your script (ox_core `ox:characterSelect 0`) |
| `HandsOver` | none | `false` when the framework still runs its own select (ESX `Config.Multichar` off, QBox `useExternalCharacters` off) |
| `Slots` | none | ox_core `ox:characterSlots`, else `nil` |
| `Login` | `playerId`, `key` | boolean, waits until the framework has the player loaded |
| `Create` | `playerId`, `num`, `{ firstname, lastname, dob, dobText, sex, height, nationality }` | new `key`, or `nil` |
| `Delete` | `playerId`, `key` | boolean |
| `Logout` | `playerId` | boolean |
| `IsLoaded` | `playerId` | boolean |
| `StarterItems` | `playerId` | array of `{ item, amount, meta }` from the framework's starter list |
| `Money` | `key` | cash + bank of an offline character, or `nil` |
| `Dossier` | `key` | `{ veh, lic, rec, jail }`: vehicles, licences, fines, jail time |

## FN_BRIDGE.CHARACTERS (client)

| Function | Arguments | Returns |
| --- | --- | --- |
| `IsLoggedIn` | none | boolean |
| `Prepare` | none | turns off auto spawn and weather sync before your select screen |
| `LoadingOff` | none | closes the loading screen |
| `Spawn` | `coords`, `{ isNew, sex, kind, creator, ready, appearance, login }` | `false` when `login` failed. Places the player the framework's way and fires its loaded events. `ready()` is called right before the screen fades in, `appearance(sex)` opens your creator for a new character (return `false` to use the framework's), `login()` runs the deferred login on ox_core |
| `Loaded` | none | fires the framework's player loaded events, for your own spawn |
| `Done` | none | turns weather sync back on |

## FN_BRIDGE.FRAMEWORK (client)

| Function | Args | Returns | ESX | QBCore | QBox |
| --- | --- | --- | --- | --- | --- |
| `GetFrameworkName` | none | `'esx'` / `'qb'` / `'qbx'` / `'ox'` / `'vrp'` / `'standalone'` | ✅ | ✅ | ✅ |
| `IsPlayerLoaded` | none | boolean | ✅ | ✅ | ✅ |
| `GetPlayerData` | none | raw framework player data | ✅ | ✅ | ✅ |
| `GetPlayerGroup` | none | group, or `nil` before load | ✅ | ✅ | ✅ |
| `GetIdentifier` | none | identifier, or `nil` before load | ✅ | ✅ | ✅ |
| `GetCharId` | none | character id published by the server, or the identifier | ✅ | ✅ | ✅ |
| `GetName` | none | full name, or `nil` before load | ✅ | ✅ | ✅ |
| `GetJob` | none | `{ name, label, grade, grade_label }` | ✅ | ✅ | ✅ |
| `GetAccounts` | none | `{ cash, bank, black_money }` | ✅ | ✅ | ✅ |
| `GetMoney` | `accountName` | number | ✅ | ✅ | ✅ |
| `Notify` | `message`, `messageType`, `time` | nothing | ✅ | ✅ | ✅ |
| `ShowHelpText` | `message`, `position`, `options` | nothing | ✅ | ✅ | ✅ |
| `HideHelpText` | none | nothing | ✅ | ✅ | ✅ |

`Notify` and the help text functions here always use the framework's own UI. Use `FN_BRIDGE.NOTIFY` instead, it follows the server owner's choice. `GetPlayerData` differs per framework, so prefer the named getters.

## FN_BRIDGE.HELPER

**Server**

| Function | Args | Returns |
| --- | --- | --- |
| `print` | `...` | nothing, prints with a timestamp |
| `GetLanguage` | none | language code |
| `NumWithCommas` | `num` | `'1,250'` |
| `SafeCall` | `func`, `...` | the result, or `nil` if it errored |
| `SendLog` | `webhookUrl`, `playerIdOrTitle`, `content`, `scriptName` | nothing |
| `SetPlayerBucket` | `playerId`, `bucket` | nothing |
| `GetIdentifiers` | `playerId` | map of identifier type to value |
| `GetPlayer` | `playerId` | `{ id, name, identifiers }`, or `nil` |
| `BanPlayer` | `playerId`, `reason` | nothing |
| `IsAdmin` | `playerId` | `true` for the console, players in `fn_bridge:admins` (or `Config.Bridge.admins` of the calling script) and players with the `fn_bridge.admin` ACE |
| `RegisterCommand` | `command`, `groups`, `callback`, `allowConsole`, `suggestions`, `deniedMessage` | nothing |
| `GetNetIdFromEntity` | `entity`, `timeout` | net id, or `false` |
| `GetEntityFromNetId` | `netId`, `timeout` | entity, or `false` |

**Client**

| Function | Args | Returns |
| --- | --- | --- |
| `print` | `...` | nothing, prints with a timestamp |
| `GetLanguage` | none | language code |
| `GetTimeInFormat` | `sec` | `HH:MM`, or `HH:MM:SS` |
| `Seatbelt` | none | `true` buckled, `false` not, `nil` when no seatbelt script is known |
| `Postal` | `coords` | nearest postal code as a string, or `nil` without a postal resource |
| `NumWithCommas` | `num` | `'1,250'` |
| `SafeCall` | `func`, `...` | the result, or `nil` if it errored |
| `RegisterNetEvent` | `eventName`, `cb`, `safeEvent` | handler, removed when your resource stops |
| `RegisterKey` | `key`, `command`, `description`, `cb` | nothing |
| `GetNetIdFromEntity` | `entity`, `timeout` | net id, or `false` |
| `GetEntityFromNetId` | `netId`, `timeout` | entity, or `false` |

**Seatbelt** asks your script's `Config.Bridge.seatbelt` hook first (a function returning a boolean), then qbx_seatbelt, qb-smallresources, esx_cruisecontrol and finally a `seatbelt` state bag on the player. Using another seatbelt script? Point the hook at it:

```lua
Config.Bridge = {
    seatbelt = function() return exports['my_seatbelt']:IsOn() end,
}
```

**Postal** reads the postal file of the resource named by `setr fn_bridge:postal` (default `nearest-postal`, file from its `postal_file` metadata).

**RegisterCommand** checks permissions before your code runs.

- `groups`: `{ 'admin' }` or `{ admin = true }`, or `nil` for everyone.
- `callback(playerId, args, rawCommand)` only runs for allowed players.
- `allowConsole = true` lets the server console run it (`playerId` is `0`).
- `suggestions`: `{ help = '...', params = { ... } }` for chat autocomplete.
- `deniedMessage`: your own refusal text, for example `FN_BRIDGE.T('no_access')`.

```lua
FN_BRIDGE.HELPER.RegisterCommand('givecrate', { 'admin' }, function(playerId, args)
    local target = tonumber(args[1])
    if not target then return end

    FN_BRIDGE.INVENTORY.AddItem(target, 'crate', 1)
end, false, { help = 'Give a crate to a player', params = { { name = 'id', help = 'server id' } } })
```

**RegisterNetEvent** with `safeEvent = true` rejects the event if another resource triggered it. Use it for events only the server should send.

**GetNetIdFromEntity / GetEntityFromNetId** retry until the entity is networked (`timeout` in ms, default `1000`). They wait, so call them inside a thread. On the client, `GetNetIdFromEntity` will network a local entity.

**BanPlayer** logs to `Config.Bridge.banWebhook` of the calling script, and warns in the console if it's empty.

## FN_BRIDGE.NOTIFY

| Function | Side | Args | Returns |
| --- | --- | --- | --- |
| `Notify` | server | `playerId`, `message`, `type`, `time` | nothing (prints to console when `playerId` is `0`) |
| `Notify` | client | `message`, `type`, `time` | nothing |
| `ShowHelpText` | client | `message`, `position`, `options` | nothing |
| `HideHelpText` | client | none | nothing |
| `Chat` | server | `playerId`, `author`, `message`, `color` | nothing |

- `type`: `'info'` (default), `'success'` or `'error'`. `time` in ms, default `5000`. Some resources ignore one or both.
- `options` on `ShowHelpText` (like `icon`) only work on some resources. The message always shows.
- `Chat` with `playerId` `-1` or `nil` sends to everyone. `color` is `{ r, g, b }`.

## FN_BRIDGE.TARGET (client)

| Function | Args | Returns |
| --- | --- | --- |
| `AddGlobalPed` | `options` | nothing (every ped, players excluded on ox_target) |
| `RemoveGlobalPed` | `options` or option names | nothing |
| `AddGlobalPlayer` | `options` | nothing |
| `RemoveGlobalPlayer` | none | nothing |
| `AddGlobalVehicle` | `options` | nothing |
| `RemoveGlobalVehicle` | `options` | nothing |
| `AddLocalEntity` | `entities`, `options` | nothing |
| `RemoveLocalEntity` | `entity`, `options` or names (optional) | nothing |
| `AddModel` | `models`, `options` | nothing |
| `RemoveModel` | `model`, `options` or names (optional) | nothing |
| `AddBoxZone` | `name`, `coords`, `size`, `heading`, `options` | zone id (nothing on qb-target) |
| `AddSphereZone` | `name`, `coords`, `radius`, `options` | zone id (nothing on qb-target) |
| `RemoveZone` | `name` | nothing |
| `DisableTargeting` | `bool` | nothing |

Options use the ox_target format on both resources:

```lua
{
    name = 'open_stash',
    label = 'Open stash',
    icon = 'fas fa-box',
    groups = { police = 0 },
    distance = 2.0,
    onSelect = function(entity) end,
}
```

- `onSelect` always receives the entity.
- Remove zones by **name**, since qb-target returns no id.
- `size` on `AddBoxZone` is a `vector3`, with `z` as the height.
- qb-target uses one distance per zone, so the largest option wins (default `1.5`).
- Zones are removed automatically when your resource stops.

## FN_BRIDGE.PICKER (client)

Lets the player aim at a spot in the world and confirm it.

| Function | Args | Returns |
| --- | --- | --- |
| `Start` | `options`, `cb` | `true` if started |
| `Await` | `options` | result, or `false` if cancelled |
| `Stop` | none | `true` if one was running |
| `IsActive` | none | boolean |

Only one picker runs at a time. `Start` calls `cb(result)` or `cb(false)`. `Await` waits and returns the same.

| `mode` | Shows | Adds to result |
| --- | --- | --- |
| `point` (default) | a marker | nothing |
| `box` | a wireframe box | `size` |
| `model` | a see-through preview of `model` | nothing |
| `entity` | an outline on the entity under the crosshair | `entity`, `model` |

| Option | Type | What it does |
| --- | --- | --- |
| `mode` | string | see above |
| `heading` | boolean | allow rotating, returns `w` |
| `zOffset` | boolean | allow raising/lowering, returns `zOffset` |
| `startHeading` | number | starting heading |
| `size` | `{ x, y, z }` | box size, default `2.0` each |
| `resize` | boolean | allow resizing the box |
| `model` | string or hash | preview model |
| `entityType` | `'ped'` or `'object'` | preview type, default object |
| `entityTypes` | number array | which entities `entity` mode accepts |
| `outline` | boolean | `false` hides the outline |
| `flags` | number | raycast flags, default `511` |
| `distance` | number | raycast distance |
| `precision` | number | decimal places |
| `colour` | `{ r, g, b }` | marker colour |
| `hint` / `hintPosition` | string | help text and where it shows |
| `keys` | table | override controls for this call |
| `headingStep` / `headingStepFast` / `zSpeed` / `zSpeedFast` / `sizeStep` | number | override step sizes |
| `disableControls` | number array | extra controls to block |
| `onTick` | function | runs every frame with `{ mode, coords, heading, zOffset, size, entity, axis }` |
| `onInvalid` | function | `entity` mode, called when confirming with nothing aimed at |

Result:

```lua
{
    x = 215.44, y = -810.02, z = 30.79,
    coords = vector3(215.44, -810.02, 30.79),
    w = 90.0,
    zOffset = 0.5,
    size = { x = 2.0, y = 2.0, z = 2.5 },
    entity = 123456,
    model = -1234567890,
}
```

Optional fields only appear when the mode or options ask for them. `coords` is a `vector3`, so send `{ x, y, z }` to NUI instead.

Default controls (pass `keys` in the options to change them for one call): `E` confirm, Backspace cancel, scroll rotate, arrow up/down height, `R` reset height, arrow left/right resize, `G` switch axis, Shift for bigger steps. The picker stops when your resource stops.

## FN_BRIDGE.INVENTORY

Works with ox_inventory, qb-inventory, ps-inventory, qs-inventory, codem-inventory, tgiann-inventory, ak47_inventory, or the framework's own inventory.

Every item comes back like this:

```lua
{
    name = 'water',
    label = 'Water',
    count = 3,
    metadata = {},
    slot = 5,       -- false when the inventory has no slots
}
```

**Server**

| Function | Args | Returns |
| --- | --- | --- |
| `GetPlayerItems` | `playerId` | array of items |
| `AddItem` | `playerId`, `itemName`, `count`, `metadata`, `slot` | boolean |
| `RemoveItem` | `playerId`, `itemName`, `count`, `metadata`, `slot` | boolean |
| `GetItemCount` | `playerId`, `itemName`, `metadata` | number |
| `HasItem` | `playerId`, `itemName`, `metadata` | boolean |
| `GetItemSlot` | `playerId`, `slot` | item, or `false` |
| `SetMetadata` | `playerId`, `slot`, `metadata` | boolean |
| `CanCarry` | `playerId`, `itemName`, `count`, `metadata` | boolean, `true` when the inventory cannot tell |
| `ItemExists` | `itemName` | boolean, `true` when the inventory cannot tell |
| `DefineItems` | array of `{ name, label, weight, unique, use, description, image }` | `{ kind, missing, added, restart }` (registers on QBCore and ESX, lists what ox_inventory and others still need). `image` is the file name QBCore shows, `<name>.png` when left out |
| `GetMaxWeight` | `playerId` | grams, or `false` (ox_inventory) |
| `SetMaxWeight` | `playerId`, `grams` | boolean (ox_inventory) |
| `GetLoadout` | `playerId` | array of `{ name, label, ammo }`: weapons ESX keeps outside the inventory, `{}` everywhere else |
| `RemoveLoadout` | `playerId`, `weaponName` | boolean, `false` when the weapon is not in the ESX loadout |

**Client**

| Function | Args | Returns |
| --- | --- | --- |
| `OpenInventory` | `'stash'` / `'shop'` / `'player'`, `data` | nothing |
| `GetItemCount` | `itemName`, `metadata` | number |
| `HasItem` | `itemName`, `metadata` | boolean |
| `GetItemData` | `itemName` | `{ name, label, description, image }`, or `false` |

**About the AddItem / RemoveItem result.** Only ox_inventory and qb-inventory report whether the item really moved. On the others, `true` means the call went through. Check `GetItemCount` if it matters.

**About metadata filters.** ox_inventory and ak47_inventory filter properly. The others match simple top-level values only (no nested tables). qb-inventory and codem-inventory remove by slot, so `RemoveItem` returns `false` if nothing matches. qs-inventory ignores the filter on the client. Test before relying on it.

### Support

✅ works, ⚠️ works with limits, ❌ not available (logs and returns `false`).

| Function | ox | qb | ps | qs | codem | tgiann | ak47 | framework |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `GetPlayerItems` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| `AddItem` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| `RemoveItem` | ✅ | ⚠️ | ✅ | ✅ | ⚠️ | ✅ | ✅ | ⚠️ |
| `GetItemCount` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| `HasItem` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| `GetItemSlot` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| `SetMetadata` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ⚠️ QBCore only |
| `OpenInventory` | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ | ✅ | ⚠️ |
| `GetItemData` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| `GetItemCount` (client) | ✅ | ✅ | ✅ | ⚠️ | ✅ | ⚠️ | ✅ | ⚠️ |
| `HasItem` (client) | ✅ | ✅ | ✅ | ⚠️ | ✅ | ⚠️ | ✅ | ⚠️ |

- `RemoveItem` on qb-inventory and codem-inventory works by slot only.
- `OpenInventory` does nothing on tgiann-inventory.
- Client `GetItemCount` / `HasItem` on qs-inventory and tgiann-inventory ignore metadata.

### Without an inventory resource

- **ESX:** uses ESX's own inventory. No slots, so `slot` is `false`. Weapons live in the loadout, not in `GetPlayerItems`: read them with `GetLoadout` and take one with `RemoveLoadout`. With an inventory resource weapons are items and `GetLoadout` returns `{}`.
- **QBCore:** uses the player's items, with slots.
- **QBox:** not supported (QBox expects ox_inventory). Calls log a message and return `false`.

`OpenInventory` does nothing in this mode, and `GetItemData` has no image.

## FN_BRIDGE.SOCIETY (server)

| Function | Args | Returns |
| --- | --- | --- |
| `GetMoney` | `societyName` | number |
| `AddMoney` | `societyName`, `amount` | boolean |
| `RemoveMoney` | `societyName`, `amount` | boolean |

Works with esx_addonaccount, qb-management, qb-banking and Renewed-Banking, detected automatically. Pass the account name as your server uses it (esx_addonaccount adds `society_` itself). `amount` must be positive. `RemoveMoney` returns `false` when there isn't enough. With none of them running, calls return `false` (or `0` for `GetMoney`).

## FN_BRIDGE.DISPATCH (server)

| Function | Args | Returns |
| --- | --- | --- |
| `Name` | none | the dispatch resource alerts go to, or `false` |
| `Send` | `playerId`, `alert` | the resource that took the alert, or `false` |

`alert` fields, all optional: `code` (`'10-52'`), `title`, `message`, `coords` (the player's position when left out), `jobs` (list or one job name, default `police`), `sprite`, `color`, `priority` (`1` high, `2` normal, `3` low), `street`.

Picks the first one running: fn_phone (its service apps get a report and it forwards to your dispatch), lb-tablet, ps-dispatch, cd_dispatch, qs-dispatch, tk_dispatch, fd_dispatch, wasabi_mdt, origen_police, bub-mdt, kartik-mdt, redutzu-mdt, piotreq_gpt, linden_outlawalert, emergencydispatch. `setr fn_bridge:dispatch` forces one, or `none`. When `Send` returns `false`, nobody got the alert, so your script should tell the job its own way.

```lua
local via = FN_BRIDGE.DISPATCH.Send(source, { code = '10-52', title = 'Person down', jobs = { 'ambulance' }, priority = 1 })
if not via then
    -- notify on-duty medics yourself
end
```

## FN_BRIDGE.PHONE (server)

Added in 1.0.1. Sends things to the player's phone, whatever phone the server runs.

| Function | Args | Returns |
| --- | --- | --- |
| `Name` | none | the phone resource in use, or `false` |
| `Supports` | `'notify'`, `'mail'`, `'message'` or `'number'` | boolean for the phone in use |
| `Number` | `playerId` | the phone number as text (from the phone, else the framework), or `false` |
| `Notify` | `playerId`, `{ title, body, app, icon, color }` | the phone resource that showed it, or `false` |
| `Mail` | `playerId` or a character identifier, `{ sender, subject, message }` | the phone resource that got it, or `false` |
| `Message` | `fromNumber`, `playerId` or a number, `text` | the phone resource that sent it, or `false` |

Picks the first one running: fn_phone, lb-phone, npwd, qb-phone. `setr fn_bridge:phone` forces one, or `none`.
`title` is required for `Notify`, `subject` and `message` for `Mail`. `app` is an app id of that phone (fn_phone,
lb-phone), `icon` a Font Awesome class and `color` a hex colour (qb-phone). A character identifier reaches players
who are offline (the citizenid on QBCore and Qbox, the identifier on ESX).

| | Notify | Mail | Message |
| --- | --- | --- | --- |
| fn_phone | yes | yes, offline too | yes |
| lb-phone | yes | yes, offline too | yes |
| npwd | yes | no | yes |
| qb-phone | yes | yes, offline too | no |

When a function returns `false`, the player did not get it on a phone, so show it your own way:

```lua
if not FN_BRIDGE.PHONE.Notify(source, { title = 'Store', body = 'Your order has arrived' }) then
    FN_BRIDGE.NOTIFY.Notify(source, 'Your order has arrived', 'success')
end
```

## FN_BRIDGE.HOUSING (server)

| Function | Args | Returns |
| --- | --- | --- |
| `Running` | none | housing resources found, in order |
| `List` | `playerId`, `key` (optional) | up to 20 homes: `{ id, label, sub, coords = { x, y, z, w }, enter }` (`z` is `nil` when the resource does not store it) |

`key` is the character identifier (citizenid on QB/Qbox, the ESX identifier); when left out it comes from `playerId`. Reads qb-houses, qb-apartments, qbx_properties, ps-housing, esx_property, qs-housing and bcs_housing. `enter`, when the resource has one, is `{ event, server, args }` that puts the player inside. Homes without coordinates are skipped.

## FN_BRIDGE.VOICE (client)

| Function | Args | Returns |
| --- | --- | --- |
| `Name` | none | the voice resource (`'pma-voice'` or `'saltychat'`), or `false` |
| `Get` | none | `{ name, modes = { { index, distance, name } }, range, distance, custom, cycle, radio, call }` or `nil` |
| `SetRange` | `index` | `true` when the talk range is now that mode |
| `SetVolume` | `'radio'` or `'call'`, `0..100` | `true` when the voice resource took it |

Works with pma-voice and SaltyChat. `custom` is set while a script overrides the range, `SetRange` then returns `false`. `cycle` is `false` when the server turned range cycling off (`voice_enableProximityCycle 0`). SaltyChat modes come from its `config.json` `VoiceRanges` and have no `name`, it has no call volume (`call` is `nil`), and its radio volume above 100% reads as 100.

## FN_BRIDGE.PREFS (client)

Player preferences that every fivenuts script shares, kept on the player's PC. A player who switches the language or streamer mode in one script gets it in the others.

| Function | Args | Returns |
| --- | --- | --- |
| `Keys` | none | `{ 'cb', 'clock', 'lang', 'motion', 'streamer', 'units' }` |
| `Get` | `key` | the value, or `nil` when the player never set it |
| `All` | none | every set value |
| `Set` | `key`, `value` | `true` when stored; `nil` clears it |

Values: `lang` (a language code, `''` follows the server), `clock` (`'24'`, `'12'`), `units` (`'auto'`, `'metric'`, `'imperial'`), `streamer`, `motion` (reduce motion), `cb` (colour blind palette) as booleans. Each script checks the values it reads. A change fires the local client event `fn_bridge:prefs` (`key`, `value`).

## FN_BRIDGE.DEATH

| Function | Side | Args | Returns |
| --- | --- | --- | --- |
| `GetState` | server | `playerId` | `'alive'`, `'down'` (last stand) or `'dead'` |
| `GetState` | client | none | the same for the local player |
| `IsDown` | both | `playerId` on the server | `true` when not `'alive'` |
| `Revive` | server | `playerId` | how the player was revived (`'hook'`, a resource name, `'bridge'`) or `false` |
| `SetFlag` | server | `playerId`, `on` | `true` when the framework flag was written |
| `Reviver` | server | none | the resource `Revive` goes to, or `false` for the built-in revive |
| `Provide` | both | `impl` or `nil` | `true` when registered |

Without a provider, `GetState` reads QBCore and Qbox metadata (`inlaststand`, `isdead`), then state bags (`inlaststand`, `laststand`, `isDown`, `down` mean down; `isDead`, `IsDead`, `isdead`, `dead`, `Dead` mean dead), then the ped's health. That covers esx_ambulancejob, qb-ambulancejob, qbx_medical, ox_core and most paid ambulance scripts without an adapter.

`Revive` asks, in order: the provider, the calling script's `Config.Bridge.revive(playerId)` hook, qbx_medical, qb-ambulancejob, esx_ambulancejob, and last a plain resurrect in place. It then clears the framework flag.

`SetFlag` writes the flag other scripts and character screens read: QBCore and Qbox metadata `isdead` (and clears `inlaststand`), ESX `users.is_dead` when the column exists, and the `isDead` state bag (ox_core saves it to `characters.isDead`).

A death script that owns the whole flow registers itself with `Provide({ GetState = fn, Revive = fn })` on the server (`GetState(playerId)`) and `Provide({ GetState = fn })` on the client. Every `GetState`, `IsDown` and `Revive` call then goes to it. The registration ends when that resource stops.

```lua
-- a script with its own revive, for any ambulance resource fn_bridge does not know
Config.Bridge = {
    revive = function(playerId)
        TriggerClientEvent('my_ambulance:revive', playerId)
    end,
}
```

## FN_BRIDGE.MEDIA (server)

| Function | Args | Returns |
| --- | --- | --- |
| `Ready` | `opts` | `true` when a screenshot resource and an upload host are both there |
| `Missing` | `opts` | list of what is missing: `'capture'` and/or `'token'` |
| `Capturer` | none | `'screencapture'`, `'screenshot-basic'` or `false` |
| `Provider` | `opts` | `'fivedock'` (API token), `'fivedock-agent'` (the fivedock resource, no token), `'fivemanage'` or `false` |
| `Capture` | `playerId`, `opts` | the player's screen as a `data:image/...;base64,` string, or `false` |
| `Upload` | `dataUrl`, `opts` | `url, fileId`, or `false` |
| `Shot` | `playerId`, `opts` | `Capture` then `Upload`: `url, fileId`, or `false, 'capture' or 'upload'` |
| `Delete` | `fileIds`, `opts` | deletes uploaded files (needs a token), returns how many requests went out |
| `IsUrl` | `url` | `true` for a plain `https://` URL that is safe to show in a UI |

Files go to [fivedock.dev](https://fivedock.dev). All fields of `opts` are optional: `token` (falls back to `set fn_bridge:upload_token`; without any token the `fivedock` agent resource uploads, when it runs), `provider` (`'fivedock'` or `'fivemanage'`, falls back to `set fn_bridge:upload`, default `'fivedock'`), `encoding` (`'webp'`, `'jpg'`, `'png'`), `quality` (0 to 1), `name` (file name prefix), `folder`, `timeout` and `uploadTimeout` in ms. The screenshot holds the game picture only, without any NUI, so hide the radar and HUD on the client first. Calls wait for the host, so run them in a thread.

```lua
local opts = { token = Config.Upload.token, name = 'myscript', folder = 'myscript' }
if not FN_BRIDGE.MEDIA.Ready(opts) then return print(table.concat(FN_BRIDGE.MEDIA.Missing(opts), ', ')) end
local url, file = FN_BRIDGE.MEDIA.Shot(source, opts)
if url then
    -- save url, keep file to call Delete later
end
```

## FN_BRIDGE.HTTP (server)

For scripts that answer web requests with `SetHttpHandler`. The server owner turns the gate on with
`set fn_bridge:tunnel` (see [PROTECTION.md](PROTECTION.md)), and every script that asks `Origin` follows it.

| Function | Args | Returns |
| --- | --- | --- |
| `Origin` | `address`, `headers` | the caller's address, or `nil` when `fn_bridge:tunnel` is on and the request did not come through the tunnel or a listed proxy. Behind one it reads the last `X-Forwarded-For` entry, then `CF-Connecting-IP` |
| `Tunnel` | none | `true` when `fn_bridge:tunnel` is on |
| `Header` | `headers`, `name` | a header value, ignoring case |

```lua
SetHttpHandler(function(req, res)
    local ip = FN_BRIDGE.HTTP.Origin(req.address, req.headers)
    if not ip then
        res.writeHead(403)
        return res.send('')
    end
    -- rate limit by ip, answer the request
end)
```

Pass `req.address` and `req.headers`, not `req` itself: the request carries functions, and functions are slow to
send to another resource.

## Added in 1.9

Everything below came with fn_mdt, fn_business and fn_crime. The same rules hold: nothing throws, missing things come back as `false`, `0` or `{}`, and `FN_BRIDGE.IsSupported(namespace, key)` is `false` where a function is only a stub on this server. Each part says what it reads and which hook replaces it. Hooks are registered with `FN_BRIDGE.Provide(key, value)` (also `exports.fn_bridge:Provide`), a script's own `Config.Bridge[key]` wins over them, and they end when the providing resource stops.

### FRAMEWORK (server)

| Function | Args | Returns | SQL |
| --- | --- | --- | --- |
| `GetJobGrades` | `jobName` | array of `{ grade, name, label, salary, isBoss }` sorted by grade, `{}` for an unknown job | yes |
| `GetJobOffline` | `identifier` | `{ name, label, grade, grade_name, grade_label, isBoss }` saved for that character, online or not, or `false` | yes |
| `CreateJob` | `name`, `label`, `grades`, `opts` | `true, 'live'` or `true, 'restart'` (saved, the framework sees it after a restart), or `false, error` | yes |
| `SetJobGrades` | `name`, `grades`, `opts` | `true, 'live' or 'restart'`, or `false, error` (replaces every grade, salaries included) | yes |
| `DeleteJob` | `name`, `opts` | `true, 'live' or 'restart'`, or `false, error` | yes |
| `GetPlayerJobs` | `playerId` | array of `{ name, label, grade, grade_label, isBoss, active }`; one entry (the current job) where the server has no multijob | maybe |
| `SetActiveJob` | `playerId`, `jobName` | boolean, `false` when the player does not hold that job | maybe |
| `AddPlayerJob` | `playerId` or `identifier`, `jobName`, `grade` | boolean. Adds the job next to the others (Qbox, ps-multijob, `multijob` hook). Without multijob it is `SetJob` | maybe |
| `GetGangs` | none | map of gang name to `{ name, label, grades }`, like `GetJobs` | maybe |
| `GetGangMembers` | `gangName`, `options` | like `GetJobMembers` | yes |
| `SetGang` | `playerId` or `identifier`, `gangName`, `grade` | boolean, online or offline, checks the gang exists | maybe |
| `RemoveGang` | `playerId` or `identifier`, `gangName` (optional) | boolean | maybe |
| `CreateGang` | `name`, `label`, `grades`, `opts` | `true, 'live' or 'restart'`, or `false, error` | yes |
| `DeleteGang` | `name`, `opts` | `true, 'live' or 'restart'`, or `false, error` | yes |
| `GetInsurance` | `identifier` | `{ active, plan, expires }` from the `insurance` hook, or `false` | no |
| `SetCharacter` | `identifier`, `{ dateOfBirth, sex, nationality }` | boolean. Online or offline, any field may be left out, `sex` is `'m'` or `'f'`, `dateOfBirth` is stored as given (the format your framework uses). ESX writes `users.dateofbirth`/`sex` and `nationality` when that column exists; QBCore and Qbox write `charinfo.birthdate`/`gender`/`nationality`. ox_core, vRP and standalone: `IsSupported` is `false` | no |

- `grades` is an array of `{ grade, name, label, salary, isBoss }`. `grade` starts at `0`; ox_core numbers its grades from `1` in the order given, and `GetJobGrades` returns them that way. `opts` for `CreateJob`: `{ type, defaultDuty, offDutyPay, whitelisted, persist }`, all optional; the others take `{ persist }`. `persist = false` keeps the change in memory only on QBCore and Qbox (ESX and ox_core always save to the database). Errors: `'exists'`, `'unknown'`, `'invalid'`, `'unsupported'`, `'failed'`, or the framework's own message.
- Where jobs live: ESX tables `jobs` and `job_grades` (live when ESX has `RefreshJobs`, else `'restart'`), Qbox `CreateJob`/`RemoveJob` (saved to its jobs file), QBCore `AddJob`/`UpdateJob`/`RemoveJob` in memory plus fn_bridge's own `fn_bridge_groups` table, replayed at every start, ox_core groups (`CreateGroup`, grades in `ox_group_grades`). vRP and standalone: `IsSupported` is `false` for the create, grade and delete functions.
- **Gangs.** QBCore and Qbox use their gangs. ESX uses the `hiddenjob` pattern when `users.hiddenjob` exists (a second ESX job on `xPlayer.hiddenjob`, set with `setHiddenJob`): gangs are then ESX jobs and `CreateGang` is `CreateJob`. Anything else: the `gang` hook for reading and `FRAMEWORK.SetGang` / `FRAMEWORK.RemoveGang` overrides for writing. `GetGang` now asks the `gang` hook first. `Supports('gangs')` follows all of this.
- **Duty.** `CheckJobDuty` asks the `duty` hook first (`function(playerId) return boolean end`), for servers where a job core counts duty.
- **Multijob.** Qbox natively, ps-multijob when it runs, else the `multijob` hook: `{ list = function(playerId) end, set = function(playerId, job) end, add = function(target, job, grade) end }`. `Supports('multijob')` is `true` only with one of these, so a staff panel knows whether a second job can be added next to the main one. `Supports('gangs')` is also `true` when a `gang` hook is registered.

Events (server, `AddEventHandler`):

| Event | Args |
| --- | --- |
| `fn_bridge/server/onGangChange` | `playerId`, `gang`, `lastGang` (same shape as `GetGang`, `false` for none) |
| `fn_bridge:characterDeleted` | `identifier`, `playerId` (or `nil`), fired after the row is gone: `CHARACTERS.Delete`, esx_multicharacter, qb-multicharacter, Qbox, ox_core |
| `fn_bridge:nameChanged` | `identifier`, `firstName`, `lastName`, `playerId` (after `FRAMEWORK.SetName`) |

### JAIL (server)

| Function | Args | Returns |
| --- | --- | --- |
| `Name` | none | `'hook'`, the jail resource, or `false` |
| `Send` | `playerId`, `minutes`, `opts` | boolean, error |
| `Release` | `playerId`, `opts` | boolean, error |
| `Get` | `playerId` | `{ minutes, reason }` (minutes left, `reason` may be `nil`), or `false` when free |
| `CommunityService` | `playerId`, `actions`, `opts` | boolean, error; `actions = 0` ends it |

`opts`: `{ reason, by }`, `by` is the officer's server id. Reads qb-prison, xt-prison (Qbox), pickle_prisons, esx_jail and esx-qalle-jail, community service from esx_communityservice. pickle_prisons only takes sentences from an officer's client, so it needs `by`. Errors: `'offline'`, `'none'`, `'officer'`, `'unsupported'` (`Release` on pickle_prisons, which has no release API), `'failed'`. `IsSupported('JAIL', 'Release')` is `false` when the picked adapter cannot release. Hooks: `jail` = `{ send = fn(playerId, minutes, opts), release = fn(playerId, opts), get = fn(playerId) }`, `communityService` = `function(playerId, actions, opts)`.

### VEHICLES (server)

| Function | Args | Returns |
| --- | --- | --- |
| `Impound` | `plate`, `{ fee, reason, until, depot, by }` | boolean, error. Marks the car impounded in the garage table (qb-garages and Qbox `state = 2`, `depotprice`; jg/cd `impound` columns; ESX `stored`/`pound`), deletes it from the world when it is out. `until` is a unix time |
| `JobColumn` | none | the column that marks a company car (`owned_vehicles.job` on ESX), or `false` |
| `ListJob` | `jobName` | array of vehicles owned by that job, `{}` without a job column |
| `SetJob` | `plate`, `jobName` or `false` | boolean, `false` without a job column |

Release from the impound with `SetState(owner, plate, 'garage')`. The garage tables keep only the fee (and `depot` as the garage where it has a column), so keep `reason` and `until` in your script; the hook gets them. Hook `impound` = `function(plate, opts, vehicle) return boolean end` for a garage script fn_bridge does not read. On ox_core an impounded car reads as `state = 'garage'` with `garage = 'impound'`.

### SOCIETY (server)

| Function | Args | Returns |
| --- | --- | --- |
| `AddMoney`, `RemoveMoney` | `societyName`, `amount`, `reason` | as before, `reason` is new and optional |
| `Transfer` | `from`, `to`, `amount`, `reason` | boolean, both sides or neither |
| `Watch` | `societyName`, `on` | `true`; while on, changes made by other resources fire `onSocietyChange` with reason `'external'` (checked every 10 s) |
| `GangAccount` | `gangName` | account name, `dirty` (boolean) |
| `GetGangMoney` | `gangName` | number |
| `AddGangMoney`, `RemoveGangMoney` | `gangName`, `amount`, `reason` | boolean |

Event `fn_bridge/server/onSocietyChange` (`societyName`, `delta`, `balance`, `reason`, `resource`, `kind`): every change through fn_bridge, plus watched outside changes. `kind` is `'job'` or `'gang'` (then `societyName` is the gang name). `societyAccount` = `function(job) return accountName end` names a company account that does not follow the default (on esx_addonaccount, an account without the `society_` prefix); a name that already starts with `society_` is used as it is. Gang accounts: qb-management gang accounts, Renewed-Banking and qb-banking accounts named after the gang, esx_addonaccount `society_<gang>`. A qb-management without money exports (newer QBCore keeps the money in qb-banking, Qbox's qbx_management in Renewed-Banking) now falls through to qb-banking or Renewed-Banking, for job and gang accounts alike. Hook `gangAccount` = `function(gang) return accountName, dirty end` (an ESX server that keeps gang money in an addon account named after the gang returns `gang, true`).

### BILLING (server)

One address for invoices from every script.

| Function | Args | Returns |
| --- | --- | --- |
| `Name` | none | where `Send` goes: the providing resource, `'esx_billing'`, or `false` |
| `Send` | `playerId` or `nil` (who issues it), `bill` | bill id as a string, or `false, error` |
| `List` | `identifier` | array of `{ id, from, label, amount, due, status, source }`, every source merged, newest first |
| `Pay` | `playerId`, `id` | boolean, error |
| `Provide` | `impl` | `true`; same as `FN_BRIDGE.Provide('billing', impl)` |

`bill`: `{ to = identifier or job, from = job or resource, amount, label, items = { { label, amount, count } }, due }` (`due` is a unix time). `status` is `'unpaid'`, `'overdue'` or `'paid'`. Ids carry their source (`'esx_billing:12'`), so `Pay` finds the right one. A provider is `{ Send = fn(playerId, bill), List = fn(identifier), Pay = fn(playerId, id) }` with its own ids; fn_business registers itself this way. Without a provider esx_billing is used. Errors: `'none'`, `'invalid'`, `'funds'`, `'unknown'`, `'failed'`.

### STAFF (server)

| Function | Args | Returns |
| --- | --- | --- |
| `Host` | `jobName` | the resource that runs staff (hiring, schedule, payroll) for that job, or `nil` |
| `Call` | `jobName`, `exportName`, `...` | what that export returned, or `nil` without a host |

A product registers with `FN_BRIDGE.Provide('staff', function(jobName) return true end)` for the jobs it runs. When two answer `true`, fn_mdt wins. Without a host, fn_phone keeps its own Work and Service apps.

### MEDIA (server)

| Function | Args | Returns |
| --- | --- | --- |
| `Ticket` | `opts` | `{ url, expires, maxSize, field }` for one upload straight from the player's client, or `false, error` |

The server asks the host for a short lived upload link, so the API token never reaches a player. The client sends a `multipart/form-data` POST with the file in `field` (`'file'`) to `url` and gets `{ data = { id, url } }` back. `opts`: `{ kind = 'video' (or 'image', 'audio'), contentType, maxSize (bytes), folder, ttl (seconds, default 900, max 3600), single (default true), token, provider }`. Needs a token (`opts.token` or `set fn_bridge:upload_token`); the fivedock agent alone cannot issue links. Errors: `'token'`, `'host'`.

### VOICE

| Function | Side | Args | Returns |
| --- | --- | --- | --- |
| `GetRadio` | client | none | radio channel as a number, `0` when off, `false` without a voice resource |
| `SetRadio` | client | `channel` | boolean, `0` leaves the radio |
| `Name` | server | none | `'pma-voice'`, `'saltychat'` or `false` |
| `GetRadio` | server | `playerId` | channel number, `0` or `false` |
| `SetRadio` | server | `playerId`, `channel` | boolean |

pma-voice and SaltyChat (primary channel). A radio item script on top (mm_radio, qb-radio) keeps working, it sees the change from the voice resource.

### INVENTORY (server)

| Function | Args | Returns |
| --- | --- | --- |
| `RegisterStash` | `id`, `{ label, slots, weight, owner, groups }` | boolean |
| `GetStashItems` | `id` | array of items |
| `AddStashItem` | `id`, `itemName`, `count`, `metadata` | boolean |
| `RemoveStashItem` | `id`, `itemName`, `count`, `metadata` | boolean |
| `ClearStash` | `id` | boolean |
| `OpenStash` | `playerId`, `id` | boolean, opens it on the player's screen (check access in your script first) |
| `OnStash` | `prefix` (or `nil` for every stash), `cb` | `true` when hooked. `cb({ playerId, stash, action, item, count, metadata })`, `action` is `'put'` or `'take'` |
| `OnShopBuy` | `cb` | `true` when hooked. `cb({ playerId, shop, item, count, price, currency })` |
| `RegisterUsable` | `itemName`, `predicate`, `onUse` (or `itemName`, `resourceName`, `handler`) | boolean |

- Stashes: ox_inventory and qb-inventory (2.x exports); elsewhere `IsSupported` is `false`. `weight` in grams. The client can still open one with `OpenInventory('stash', id)`: ox_inventory checks `groups` and `owner` itself, and on qb-inventory and ps-inventory fn_bridge now opens only stashes registered with `RegisterStash` and checks `groups` (job or gang with a minimum grade) and `owner` (a character identifier). `OpenInventory('player', serverId)` there needs the target within 3 m.
- `OnStash` and `OnShopBuy` use ox_inventory hooks; elsewhere they return `false`. Hooks end when your resource stops. Return nothing from `cb`, it only watches.
- `RegisterUsable` lets several scripts share one item. fn_bridge registers the item once; on use it asks each script's `predicate(playerId, item)` in the order they registered and runs `onUse(playerId, item)` of the first that says `true`. With the second form, `handler(playerId, item)` does both and returns `true` when it took the use; `false` passes it to the next script. Example: one `tablet` item opens fn_mdt for police, fn_business for a company and fn_crime for a gang. Registering again from the same resource replaces its entry.

### DOORS (server)

| Function | Args | Returns |
| --- | --- | --- |
| `Name` | none | `'hook'`, `'ox_doorlock'`, `'qb-doorlock'` or `false` |
| `List` | none | array of `{ id, name, locked, coords }` |
| `IsLocked` | `id` | boolean |
| `SetLocked` | `id`, `locked`, `playerId` (optional, who acts) | boolean |
| `Allow` | `id`, `{ groups = { police = 0 }, identifiers = { ... } }` | boolean (who may use the door; replaces the lists) |

ox_doorlock does all of it (`id` is its number or the door name). qb-doorlock only `SetLocked`. Hook `doors` = `{ list = fn(), isLocked = fn(id), setLocked = fn(id, locked, playerId), allow = fn(id, access) }`.

### APPEARANCE

An outfit is the same everywhere, so it survives a change of clothing script:

```lua
{
    model = `mp_m_freemode_01`,
    components = { { id = 11, drawable = 55, texture = 0 }, ... },
    props = { { id = 0, drawable = -1, texture = 0 }, ... },
}
```

| Function | Side | Args | Returns |
| --- | --- | --- | --- |
| `Name` | both | none | the clothing resource, or `false` |
| `Get` | client | none | the outfit the player wears |
| `Set` | client | `outfit` | boolean, `false` when the model differs |
| `Restore` | client | none | boolean, back to the saved look of the clothing script |
| `Get` | server | `playerId` | outfit, or `false` |
| `Set` | server | `playerId`, `outfit` | boolean |
| `Restore` | server | `playerId` | boolean |
| `FromCode` | server | `code` | outfit from an illenium-appearance outfit code, or `false` |

`Set` is for uniforms and gang clothes: it dresses the ped with game natives (the head stays) and does not touch the look the clothing script saved. `Restore` asks illenium-appearance, fivem-appearance, qb-clothing or esx_skin for that saved look. `Get` on the server asks the player's client. Hook `appearance` on the client = `{ set = fn(outfit), restore = fn() }`.

### DEATH (server)

Event `fn_bridge/server/playerDied` (`victim`, `{ state, killer, weapon, coords, cause }`): `state` is `'down'` or `'dead'`, `killer` the server id of the player who dealt the last damage within 10 s (from the server's own `weaponDamageEvent`), or `false`, `weapon` a hash or `false`, `cause` the death cause hash the victim's game reported. Fires once per death.

### INTERACT (server)

Cuffs, bags, escorting and the like belong to the police or crime script the server already has. fn_bridge finds it.

| Function | Args | Returns |
| --- | --- | --- |
| `Has` | `kind` | `'hook'`, the resource that does it, or `false` |
| `Do` | `playerId` (who acts), `target`, `kind`, `on` (`true` / `false`, toggles when `nil`) | boolean, `false` when nobody handles it, so your script does its own |
| `Is` | `target`, `kind` | boolean |
| `IsCuffed` (client) | none | `true` when the local player is cuffed: the `interact` hook's `isCuffed`, QBCore and Qbox `ishandcuffed`, the `isHandcuffed`, `handcuffed` or `cuffed` state bag, else `IsPedCuffed` |

`kind`: `'cuff'`, `'ziptie'`, `'bag'`, `'escort'`, `'trunk'`, `'search'`, `'rob'`. Read: qb-policejob, qbx_police, esx_policejob (cuff, escort, search where they have it), search through the inventory resource. Hook `interact` = `{ cuff = fn(playerId, target, on), ..., is = fn(target, kind) }`, any subset; on the client `{ isCuffed = fn() }`.

### DISPATCH

fn_mdt now comes first in the list, before fn_phone: `exports.fn_mdt:alert(alert, playerId)`.

### Hook keys added in 1.9

`gang`, `duty`, `multijob`, `insurance` (`function(identifier) return { active, plan, expires } end`), `jail`, `communityService`, `impound`, `gangAccount`, `societyAccount`, `billing`, `staff`, `doors`, `interact`, `appearance` (client).

## Other bridge values

| Name | What it is |
| --- | --- |
| `FN_BRIDGE.T(key, vars)` | translated text, or the key if missing |
| `FN_BRIDGE.LOCALES` | your resource's loaded translations |
| `FN_BRIDGE.IsReady()` | whether the bridge finished loading |
| `FN_BRIDGE.IsCallable(value)` | whether a value can be called |
| `FN_BRIDGE.frameworkName` | `'esx'`, `'qb'` or `'qbx'` |
| `FN_BRIDGE.inventoryName` | detected inventory, or `nil` for the framework's own |
| `FN_BRIDGE.societyName` | detected society resource, or `nil` |
| `FN_BRIDGE.version` | fn_bridge version |
| `FN_BRIDGE.IsSupported(namespace, key)` | `false` when that function is only a stub on this server, or when the adapter picked here cannot do it (`JAIL.Release` on pickle_prisons, the gang functions on ESX without `users.hiddenjob`, the vehicle write functions without a garage table) |
| `FN_BRIDGE.Provide(key, value)` | registers a server-wide hook for the calling resource (also `exports.fn_bridge:Provide`), `nil` removes it. Keys and shapes: `_INSTALL.md`, fn_bridge_custom. A key like `FRAMEWORK.AddMoney` replaces that function of the namespace |
| `FN_BRIDGE.Providers()` | `{ [key] = resource }` of every provided hook |
| `FN_BRIDGE.ProvidersOf(key)` | every registration of `key`, oldest first: `{ { resource, value } }` |
| `FN_BRIDGE.Provider(key)` | resource that provided `key`, or `nil` |
| `FN_BRIDGE.Setting(key)` | the calling script's `Config.Bridge[key]`, else the provided hook |
| `exports.fn_bridge:RestartSelf()` | server, 1.2.2: restarts the calling resource half a second later from fn_bridge's side and returns `true`. A resource that restarts itself with `ExecuteCommand` takes FXServer down; this is the safe way. Only the caller can be restarted, once at a time |

All namespaces exist on both sides. One with nothing behind it (like `TARGET` on the server) logs and returns `false`, so you never need a nil check. Load the bridge with `@fn_bridge/import.lua`, see [DEVELOPERS.md](DEVELOPERS.md).

## Server callbacks

| Name | Args | Returns |
| --- | --- | --- |
| `fn_bridge/server/checkPermissions` | `groups` (map) | boolean |
| `fn_bridge/server/getAccounts` | none | `{ cash, bank, black_money }` |

## Events

| Event | Side | Args |
| --- | --- | --- |
| `fn_bridge/client/updatePlayerData` | client | `playerData` |
| `fn_bridge/client/isDead` | client | `isDead` |
| `fn_bridge:deathChanged` | client | `state`, `previous` (`'alive'`, `'down'`, `'dead'`) |
| `fn_bridge/client/notified` | client | `message`, `type`, `resource` |
| `fn_bridge/client/onVehicleEnter` | client | `vehicle`, `isDriver` |
| `fn_bridge/client/onVehicleLeave` | client | `vehicle`, `wasDriver` |
| `fn_bridge/server/playerLoaded` | server | `playerId`, player object |
| `fn_bridge/server/onJobChange` | server | `playerId`, `job`, `lastJob` |
| `fn_bridge/server/jobCountChanged` | server | `jobName`, `count`, `previous` |
| `fn_bridge/server/onMoneyChange` | server | `playerId`, `account`, `delta`, `reason` (ESX, QBCore, QBox) |

- `onJobChange` fires on any job or grade change, with the same `job` table shape on every framework. `lastJob` is `nil` on the first change of a session.
- `jobCountChanged` fires when a job's online count changes. A job switch fires it twice: once for the old job, once for the new one.
- `isDead` fires when `GlobalState.fn_isDead` changes.
- `deathChanged` follows `DEATH.GetState()`, checked every 500 ms.
- `notified` fires on the player's client for every `NOTIFY.Notify` (client or server side) and every framework `Notify`, before it is shown. `resource` is the script that sent it, or `nil` when unknown. A notification history can listen here and skip its own resource.

## Shared state

Only fn_bridge writes these. Read them instead of polling natives.

| Key | Type | Updated |
| --- | --- | --- |
| `GlobalState.fn_playerPed` | entity | when it changes (checked every 250 ms) |
| `GlobalState.fn_playerId` | number | at start |
| `GlobalState.fn_serverId` | number | at start |
| `GlobalState.fn_isDead` | boolean | on death and respawn |
| `GlobalState.fn_vehicle` | entity or `false` | on enter and leave |
| `GlobalState.fn_vehicleDriver` | boolean | on enter, leave and seat change |
| `GlobalState.fn_playerCoords` | vector3 | every 250 ms |
| `GlobalState.fn_playerWeapon` | hash | when it changes (checked every 250 ms) |
| `GlobalState.fn_jobCounter` | map | online players per job, on both sides |

```lua
local policeOnline = GlobalState.fn_jobCounter?.police or 0

AddStateBagChangeHandler('fn_jobCounter', 'global', function(bagName, key, value) end)
```

`fn_jobCounter` also holds `admin`, the online staff count. `police` and `ambulance` always appear, even at `0`.
