# fn_bridge changelog

## 1.4.8 (2026-10-24)

Fixed
- Callbacks sent while a script is still loading now wait for it. A script started by a loader, such as a license or escrow loader, registers its callbacks a few seconds after it starts. Players who called in those seconds were moved to plain ox_lib callbacks for the rest of their session, and servers that limit ox_lib callbacks dropped those calls, so apps hung on a spinner.
- A callback name that belongs to another resource is checked again after 30 seconds, so one miss no longer lasts the whole session.

## 1.4.7 (2026-10-24)

Added
- CHARACTERS.AwaitCreator waits until a clothing creator opened by another script is closed, for example the one a starter apartment opens. It returns true when a creator opened.

Fixed
- CHARACTERS.Spawn now waits for a new character to save their look on QBCore, Qbox and ox_core as well. It returns once qb-clothing or illenium-appearance closes, the same way it already waited for esx_skin. Before, it returned while the creator was still open, so whatever a script did after the spawn started too early.

## 1.4.6 (2026-10-24)

Added
- VEHICLES.Add and VEHICLES.Remove work on vRP. A car goes into vrp_user_vehicles, and Remove takes { model } to pick which car to take, because every car of a vRP character has the same plate.
- VEHICLES.Traits tells a script how the garage behaves: platePerVehicle is false and onePerModel is true on vRP.
- FRAMEWORK.Supports('salary') says whether the framework keeps a salary per job grade. That's true on ESX, QBCore and Qbox, and false on ox_core and vRP.

Fixed
- HOUSING.IsLocked returns false for an unlocked door. It returned nil, so scripts treated an unlocked home as a home without a lock and fn_phone hid the lock button.
- ox_core and vRP know the unemployed job. Players without a job were reported as unemployed, but GetJobs didn't list it, so scripts refused to set it. Setting it clears the active group on ox_core and the job group on vRP.
- VEHICLES.Available on vRP no longer returns the table name as a second value, which scripts read as a warning about the garage table.
- Callbacks over the limit of 120 a second get an empty answer at once, and the script shows its error. The server used to drop them without a reply, so the screen waiting for them hung for five minutes.

## 1.4.5 (2026-10-18)

Fixed
- MEDIA.Capture works with screenshot-basic. The bridge now takes the picture with its client export and sends it to the server as a latent event. requestClientScreenshot uploaded over plain http, which the https NUI blocks as Mixed Content, so photos were never saved.
- Cars whose impounded column is set count as impounded, so scripts can't take them out of the garage. impoundColumn in the garage settings names another column.

## 1.4.4 (2026-10-18)

Added
- COINS gives scripts one way to charge premium coins. It uses CoinStore (fn_itemshop) when it runs, and any other coin shop can plug in from fn_bridge_custom with FN_BRIDGE.Provide('coins', { Get, Remove, Add }). fnb_doctor shows which one is used.

Fixed
- Callbacks with more than 4 KB of arguments go to the server as latent events, and answers over 64 KB come back the same way. Before, a script that sent a lot through callbacks, like screen sharing in fn_phone, could get the player kicked with Reliable network event size overflow. This needs sv_enableNetEventReassembly, which is on by default.

## 1.4.3 (2026-10-18)

Changed
- INTERACT.IsCuffed and INTERACT.Is with cuff also read the IsHandcuffed, isCuffed and IsCuffed state bags, next to isHandcuffed, handcuffed and cuffed. Police scripts name this flag differently, and the bridge used to miss the capitalised ones.

## 1.4.2 (2026-10-17)

Fixed
- Muting a phone call on pma-voice uses the pma-voice mute. The bridge asked pma-voice for isPlayerMuted, which pma-voice does not have, so it forced the player's volume to zero every frame instead.
- Unmuting no longer turns the call down. It used to set the pma-voice call volume to a hundredth of what it was.
- A muted caller standing next to you sounds like a normal voice, without the phone filter.

## 1.4.1 (2026-10-16)

Before you update
- set fn_bridge:upload "fivemanage" does nothing now. Use a fivedock.dev token in fn_bridge:upload_token or run the fivedock agent.

Added
- KEYS.SetLocked locks or unlocks a car on the server and on the client that owns it, so a lock script running on that client no longer undoes it. A key script that keeps its own lock state replaces KEYS.SetLocked in fn_bridge_custom.

Changed
- MEDIA uploads, deletes and tickets go only to fivedock.dev. The fivemanage provider and the fn_bridge:upload convar are removed.

Fixed
- Phone calls on pma-voice are heard again. VOICE.SetCall called addPlayerToCall on the server, which pma-voice only has on the client, so nobody was put in the call channel. It uses setPlayerCall now, and speakerphone and mute work again with it.

## 1.4.0 (2026-10-15)

Added
- HOUSING.Give hands a home to a character, either a house you already created or a new starter apartment. It works with bcs_housing and nolag_properties, and HOUSING.Giver says up front which of these the running script can do. Any other housing script plugs in with a giveHome function in Config.Bridge. CoinStore 1.0.3 sells properties this way.
- MEDIA.Upload takes videos and voice recordings (data:video/ and data:audio/) as well as images.
- VOICE runs phone calls. The server side has SetCall, GetCall, MuteCall, CallMuted and RadioCount, the client side RadioEnabled and RadioTalk. It works with pma-voice, SaltyChat, YACA and mumble-voip. Another voice script plugs in with the voice hook, and setr fn_bridge:voice picks one when several run.
- HOUSING.List returns the other key holders of each home, and with { keys = true } also the homes a character only holds a key to. New functions IsLocked, SetLocked, ForSale, Starters, Resume and Prepare cover locks, homes for sale, starter apartments and spawning back inside, and the housing hook can be a table with all of them.
- PHONE.SetNumber changes a character's phone number in fn_phone, lb-phone, npwd or the framework field. Numbers, NumberTaken and CanSetNumber check before anything is charged. A phone that keeps numbers its own way plugs in with the phoneNumber hook.
- JAIL.GetOffline says whether a character who is not loaded is in jail. The jail hook takes an offline function for it.
- DOORS.Get finds a door by id or name, DEATH.Ambulances lists the ambulance scripts running, and HELPER.GetFuel reads a car's fuel on the client, with a fuel hook for other fuel scripts.
- The client event fn_bridge:characterSelect fires when the framework sends a player back to character select. The server event fn_bridge:characterLogout fires when a player leaves their character without leaving the server.
- APPEARANCE.Apply dresses any ped from saved illenium-appearance, fivem-appearance, qb-clothing or skinchanger data, and APPEARANCE.Creator opens the creator from the appearance hook. The appearance hook takes apply, creator and, on the server, skin for skins kept in another table. fn_multichar 1.3.1 uses them instead of its own Config.Appearance.
- CHARACTERS.Spawns returns extra spawn points from the new spawns hook, for a motel script for example.
- fnb_doctor shows the voice, phone number and fuel hooks and prints a block to paste for each. fnb_selftest checks HOUSING.Give guards, that dispatch skips the sender, call groups and mute, house locks, the sale list, phone number guards, offline jail and the new hooks.

Changed
- Notifications accept inform as well as info, and ox_lib gets inform. CoinStore 1.0.3 and fn_phone 1.1.10 send their notifications and [E] prompts through NOTIFY now.
- An inventory fn_bridge has no adapter for plugs in with INVENTORY hooks in fn_bridge_custom. CoinStore 1.0.3 drops its own Config.Inventory = 'custom'.
- DISPATCH.Send never hands an alert back to the script that sent it, and DISPATCH.Name takes a resource to leave out. fn_phone 1.1.10 sends 911 calls, SOS and crash alerts through the bridge, so they reach fn_mdt and the dispatch hook.
- APPEARANCE.Restore with esx_skin and skinchanger asks the server for the saved skin when esx_skin has none cached, and puts the freemode model back before loading it. A player who wore another ped model gets the character back.
- APPEARANCE.Restore with fivem-appearance on ESX reads the skin from esx_skin. Before, it waited on a callback that ESX servers don't register.

Fixed
- HOUSING reads qs-housing homes from its own tables. Before, it called an export qs-housing doesn't have, so the list was always empty. qs-housing also has no export for handing out a house, so HOUSING.Give no longer offers it.
- HOUSING lists bcs_housing homes by the character identifier. Before, the arguments were swapped and the list was empty.
- HOUSING.Give with nolag_properties transfers the house to the player. Before, it sent the wrong owner type and the transfer failed.
- INVENTORY.CanCarry asks codem-inventory, tgiann-inventory, origen_inventory and core_inventory. Before, it always said yes there.
- DISPATCH sends cd_dispatch alerts the way Codesign documents for the server side.
- HELPER.GetFuel reads ti_fuel and x-fuel, which name the export getFuel.
- Notifications through lation_ui use its info type.

Scripts that ask for 1.3.2 or older work with this version.

## 1.3.2 (2026-10-14)

Added
- INVENTORY.DefineItems takes an image file name per item. On QBCore a renamed item keeps the icon its script ships, for example an fnBook item called fnbook still shows laptop.png. Without it the image stays <name>.png as before.

No API changes for scripts that don't pass it. Scripts that ask for 1.3.1 or older work with this version.

## 1.3.1 (2026-10-14)

Added
- The console says when a newer fn_bridge is out. fn_bridge asks GitHub once on start, and without internet access it says nothing.
- A script that needs a newer fn_bridge than the one running no longer starts. The console says which script and which version it needs. A script can't stop itself once it has started, so before this it kept running half broken.
- The console lists fn_bridge files you changed, on every start. The release carries checksums.json and the next update replaces those files, so move the change to fn_bridge_custom, a convar or Config.Bridge first. Line endings don't count as a change. fnb_doctor shows the same list under files.

No API changes. Scripts that ask for 1.3.0 or older work with this version.

## 1.3.0 (2026-10-14)

Added
- setr fn_bridge:admins lists your staff groups for every FIVENUTS script at once, for example setr fn_bridge:admins "owner,management,admin". It defaults to admin,superadmin,god. Servers with their own group names (owner, headadmin and so on) no longer need an ACE line per script.
- FN_BRIDGE.HELPER.IsAdmin(playerId) on the server. It is true for the console, for players in one of those groups and for players with the fn_bridge.admin ACE. A script can pass its own list in Config.Bridge.admins.
- The /setup command and the staff counter use the same list.
- fnb_selftest checks IsAdmin.

## 1.2.2 (2026-10-13)

Added
- exports.fn_bridge:RestartSelf() on the server. A script calls it to restart itself: fn_bridge stops and starts the calling resource half a second later. A resource that runs ExecuteCommand('restart ...') on itself takes FXServer down and needs ACE for restart, stop and start. This export needs neither, and it only restarts the resource that called it, one restart at a time.
- fn_phone 1.1.6 uses it for the Restart button in Admin → Server Config.

Scripts that ask for 1.2.0 work with this version.

## 1.2.1 (2026-10-12)

Fixed
- The character dossier on ESX and ox_core no longer fails on MySQL 8, where stored is a reserved word. MariaDB was already fine.
- fn_bridge_groups and the standalone vehicle table use utf8mb4_unicode_ci, the collation oxmysql connects with, so joins with framework tables no longer throw Illegal mix of collations.

No API changes. Scripts that ask for 1.2.0 work with this version.

## 1.2.0 (2026-10-11)

Added
- FN_BRIDGE.HTTP and the fn_bridge:tunnel setting, for scripts that serve web pages on the game port (fnPhone Anywhere, the CoinStore web store and panel). With set fn_bridge:tunnel "on" in server.cfg, fivenuts scripts answer web requests only through a Cloudflare Tunnel or a proxy on the same machine. Requests sent straight to the game port get 403, and scripts see the visitor's real address, so rate limits hit the right person. When the tunnel runs on another machine, put its address instead of on.
- HTTP.Origin, HTTP.Tunnel and HTTP.Header for your own SetHttpHandler code.
- docs/ENGLISH/PROTECTION.md: how to set up the tunnel, and what protects the game port.
- The startup banner shows web direct or web tunnel only, and fnb_selftest checks the new functions.

fn_phone 1.1.6 and CoinStore 1.0.2 need this version.

## 1.1.0 (2026-10-11)

Added
- callback.lua. Add '@fn_bridge/callback.lua' right after '@ox_lib/init.lua' in your shared_scripts and keep using lib.callback as before. Calls from your client to your own server are sent together, one event per frame, so servers with an ox_lib that limits callbacks per player stop dropping them. Details in docs/ENGLISH/DEVELOPERS.md.

No config changes needed.

## 1.0.1 (2026-10-10)

Added
- FN_BRIDGE.PHONE. Scripts can send notifications, mail and texts to whatever phone the server runs (fn_phone, lb-phone, npwd or qb-phone). setr fn_bridge:phone picks one, or turns it off with none. Details in docs/ENGLISH/API.md.

No config changes needed.

## 1.0.0 (2026-10-08)

- First release under the fivenuts name. Runs on ESX, QBCore, Qbox, ox_core, vRP or with no framework at all. Needs ox_lib and oxmysql.
