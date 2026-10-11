# Protecting your server

A script can protect its own web pages. It can't protect the game port. A flood fills your machine's line before
FXServer reads a single packet, so that part is down to your host and your network. This page covers both, starting
with what fn_bridge does for you.

## Web pages through a Cloudflare Tunnel

Some fivenuts scripts serve pages on your game port: fnPhone Anywhere in fn_phone, and the web store, browser
panel, stream widgets and payment webhooks in fn_itemshop. Put them behind a Cloudflare Tunnel. The tunnel connects
out from your machine, so you open no new port, the address people see belongs to Cloudflare instead of your server,
and Cloudflare absorbs floods aimed at it. You need a free Cloudflare account and a domain added to it.

1. In the Cloudflare dashboard open Networking → Tunnels → Create a tunnel, give it a name and run the install
   command it shows on the machine that runs FXServer. There are commands for Windows, Linux and Docker.
2. In the tunnel's Routes tab choose Add route → Published application. Pick a subdomain such as `phone`, your domain,
   and set the service URL to `http://localhost:30120` (your game port).
3. Add this line to `server.cfg`:

```cfg
set fn_bridge:tunnel "on"
```

4. Use the new address in each script, for example `https://phone.example.com/fn_phone` as `Web.url` in fn_phone.

With `fn_bridge:tunnel` on, every fivenuts script answers web requests only when they come through the tunnel.
Someone who sends them straight to `http://<your ip>:30120/fn_phone/...` gets 403, so going around Cloudflare does
not work. Scripts also read the caller's real address from the proxy instead of seeing the tunnel's own, which means
rate limits and lockouts hit only the person who earned them.

| Value | What it does |
| --- | --- |
| `off` (default) | Scripts answer anyone and ignore forwarded addresses |
| `on` | Scripts answer only requests from this machine, which is where the tunnel connects from |
| `10.0.0.5 10.0.0.6` | The same, plus the listed addresses. Use it when the tunnel or proxy runs on another machine |

Requests from this machine are always allowed, so self tests run from the console keep working. The value is read on
every request, which means `set fn_bridge:tunnel on` typed in the console works without a restart.

Caddy or nginx on the same machine works the same way. Make sure the proxy writes `X-Forwarded-For` itself. Caddy
does it by default; in nginx add `proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;`.

Once the setting is on, anything that used to call your server's IP has to use the tunnel address: payment
webhooks (Tebex, skalp, your own), the Discord shop bot and stream widgets in OBS.

## The game port

Players connect to the game port over UDP and TCP, so it has to stay open, and a Cloudflare Tunnel doesn't carry
that traffic. Cloudflare can proxy arbitrary UDP only with Spectrum on its Enterprise plan.

What works is a proxy in front of the server with filtering made for game traffic. Players connect to the proxy, it
forwards the game traffic to your server, and your server's real address never shows up in the server list. FiveM
documents the setup in its [proxy setup guide](https://docs.fivem.net/docs/server-manual/proxy-setup/). On the
server side it comes down to a few lines in `server.cfg`:

```cfg
set sv_forceIndirectListing true
set sv_listingHostOverride "connect.example.com"
set sv_endpoints "<proxy ip>:30120"
set sv_proxyIPRanges "<proxy ip>/32"
```

Then block the game port on the real server for everyone except the proxy. When you pick a provider, ask for UDP
filtering that knows FiveM. A VPS that is just labelled "DDoS protected" usually filters web traffic and not much
else.

## txAdmin

txAdmin listens on port 40120 and shouldn't be reachable from the internet. Allow only your own IP in the firewall,
or publish it through the same tunnel with a Cloudflare Access policy, so the login page sits behind Cloudflare's own
sign-in.

## Firewall

Open the game port (TCP and UDP) and nothing else to everyone. Keep the database port, txAdmin and SSH closed or
limited to your own address. A per-address limit on UDP packets stops small floods from one machine, but it can't help
once the line itself is full.

## Resource downloads

When many players join at once, resource downloads put a big load on the game machine. `fileserver_add` together with
`adhesive_cdnKey` lets a caching proxy or CDN serve those files instead. The FiveM guide linked above covers it.
