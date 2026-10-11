# fn_bridge

fn_bridge sits between FIVENUTS scripts and your server. Our scripts talk to the bridge, and the bridge talks to your framework, inventory and UI resources. That's why one script runs on ESX, QBCore, QBox, ox_core, vRP and standalone without changes, and why a framework update gets fixed in one place instead of in every script you own.

## What it supports

| | Supported |
| --- | --- |
| Framework | ESX Legacy 1.9+, QBCore, QBox, ox_core, vRP, standalone |
| Inventory | ox_inventory, qb-inventory, ps-inventory, qs-inventory, codem-inventory, tgiann-inventory, ak47_inventory, core_inventory, origen_inventory, or your framework's own |
| Target | ox_target, qb-target |
| Notifications | okokNotify, mythic_notify, pNotify, t-notify, vms_notifyv2, brutal_notify, g-notifications, r_notify, wasabi_notify, wasabi_uikit, lation_ui, is_ui, ox_lib, your framework's own, or your own function |
| Text UI | jg-textui, okokTextUI, cd_drawtextui, lab-HintUI, ox_lib, your framework's own, or your own function |
| Society money | esx_addonaccount, qb-management, qb-banking, Renewed-Banking |
| Garages | owned_vehicles, player_vehicles, ox_core vehicles, vRP, jg-advancedgarages and cd_garage columns |
| Character select | ESX (esx_multicharacter mode), QBCore, QBox, ox_core |
| Jail | xt-prison, qb-prison, pickle_prisons, esx_jail, esx-qalle-jail, esx_communityservice, your function |
| Invoices | esx_billing, fn_business, your function |
| Door locks | ox_doorlock, qb-doorlock, your function |
| Clothing | illenium-appearance, fivem-appearance, qb-clothing, esx_skin, your function |
| Radio | pma-voice, SaltyChat |
| Cuffs and escort | qb-policejob, qbx_police, esx_policejob, your function |
| Multijob | Qbox, ps-multijob, your function |

You don't have to tell it what you run. It checks once when the server starts.

## Requirements

- `ox_lib`
- `oxmysql`
- ESX, QBCore, QBox, ox_core or vRP (or nothing, in standalone mode)

## Next steps

- **Installing:** [_INSTALL.md](_INSTALL.md)
- **Writing your own script:** [DEVELOPERS.md](DEVELOPERS.md)
- **Every function:** [API.md](API.md)
- **Tunnel, proxy and DDoS:** [PROTECTION.md](PROTECTION.md)

## Support

https://fivenuts.dev
