# fn_bridge changelog

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
