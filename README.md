# PS5 Relapse self-host

Package a home-server DNS + HTTPS host for the **PS5 Relapse** exploit chain (firmware **7.00–13.60**), so the console’s **User’s Guide** loads your page instead of Sony’s manual.

This repository **does not** vendor exploit code, payloads, certificates, or keys. It clones an upstream host page at setup time and applies a small compatibility patch.

Upstream projects:

- [ntfargo/Relapse-Exploit](https://github.com/ntfargo/Relapse-Exploit) — exploit chain
- [arg0WAK/WAK1360-Relapse](https://github.com/arg0WAK/WAK1360-Relapse) — UI host page (default clone target)

> **Disclaimer.** Educational / security-research use on devices you own. Jailbreaking can brick hardware, void warranties, and violate terms of service. You assume the risk.

---

## How it works

```
PS5 ──DNS──► dnsmasq on your server
               │
               ├─ manuals.playstation.net  →  SERVER_IP
               ├─ manual.playstation.net   →  SERVER_IP
               ├─ doc.dl.playstation.net   →  SERVER_IP
               └─ update / patch hosts     →  0.0.0.0  (blocked)

PS5 opens User’s Guide (HTTPS)
  → nginx on SERVER_IP:443 serves the host page
  → START runs the exploit → PAYLOADS (OnionHEN, ShadowMount+, FTP, …)
```

1. **dnsmasq** answers authoritative A records for the User’s Guide hostnames and black-holes Sony update domains so the console stays on its current firmware.
2. **nginx** serves the host page on **80 and 443** with a self-signed cert for `manuals.playstation.net`.
3. A tiny patch on `index.html` makes the page survive the PS5 browser’s deep paths and aggressive caching.

---

## Requirements

- Linux host with Docker + Compose v2 (dnsmasq uses `network_mode: host`)
- Free **UDP/TCP 53**, **TCP 80**, **TCP 443** on that host
- Ability to set the PS5’s DNS (and ideally your LAN DHCP DNS) to `SERVER_IP`
- `git`, `python3`, `openssl`

macOS / Docker Desktop can build and validate configs, but host-network DNS will not behave the same; run the stack on a Linux box on your LAN.

---

## Quick start

```bash
git clone https://github.com/ThatRetiredDude/ps5-relapse-selfhost.git
cd ps5-relapse-selfhost

cp .env.example .env
# edit .env → set SERVER_IP to this machine’s LAN IPv4

./scripts/render-config.sh   # dnsmasq.conf + nginx/default.conf
./scripts/generate-cert.sh   # certs/manuals.{crt,key}
./scripts/setup-host.sh      # clone upstream into www/ + patch index.html

docker compose up -d
./scripts/verify.sh
```

### Point DNS at the server

**Option A — PS5 only**

Settings → Network → Set Up Internet Connection → Custom → DNS  
Primary = `SERVER_IP`, Secondary = e.g. `1.1.1.1`

**Option B — whole LAN (recommended)**  
Set your router’s DHCP DNS to `SERVER_IP` so every device (including the PS5) uses dnsmasq. Upstream resolvers in `.env` handle everything that isn’t overridden.

### On the PS5

1. Confirm firmware is in the supported range (7.00–13.60) and stays there (update hosts are blocked).
2. Open **User’s Guide** (the book icon). You should see the Relapse / WAK host page, not Sony’s manual.
3. Press **START**. After a successful run, use **PAYLOADS** (OnionHEN, ShadowMount+, FTP, ProsperoStore, etc., depending on what upstream ships / you add).

---

## The gotchas (why this package exists)

These are the things generic “run `serve.py`” instructions leave out.

### 1. HTTPS on port 443

The User’s Guide loads over **HTTPS**. Serving only port 80 is not enough. This stack terminates TLS with a self-signed cert whose CN/SAN is `manuals.playstation.net`.

### 2. SPA fallback silently kills `firmware.js`

If nginx (or any static host) is configured as a single-page app —

```nginx
location / { try_files $uri $uri/ /index.html; }
```

— then a **missing or mis-pathed** `firmware.js` returns **`index.html` with HTTP 200**. The browser tries to execute HTML as JavaScript, the exploit dies, and logs look fine.

**Fix:** make `.js` / `.css` return a real 404:

```nginx
location ~* \.(js|css)$ { try_files $uri =404; }
```

### 3. Deep User’s Guide paths need a `<base href>`

The Guide opens URLs like `/document/en/ps5/…`. Relative assets (`./src/firmware.js`, `./assets/…`) then resolve under that deep path and 404 (or hit the SPA trap above).

**Fix:** in `index.html` `<head>`:

```html
<base href="/">
```

`scripts/setup-host.sh` inserts this automatically.

### 4. The PS5 browser caches aggressively

A once-broken `firmware.js` can stick around. This package:

- sends `Cache-Control: no-store` from nginx
- adds a `?v=…` cache-buster on the `firmware.js` script tag

Bump `CACHE_BUST` (env) or re-run `setup-host.sh` after you change the page.

### 5. ShadowMount+ only scans when it starts

Titles installed after ShadowMount+ has already run (e.g. from ProsperoStore) **will not appear** on the home screen until you **re-run ShadowMount+** from PAYLOADS.

### 6. Autoload ShadowMount+ and FTP

Otherwise you launch them by hand every boot. Configure autoload in the host page’s `payloads.json` (see upstream docs).

### 7. OnionHEN + homebrew title IDs

Homebrew apps you install yourself may need a correct `param.json` and an entry in OnionHEN’s config (`exact_title_ids` / equivalent) or the console shows a generic “something went wrong” dialog. That is outside this DNS/nginx package but bites people next.

---

## Layout

```
├── docker-compose.yml          # dnsmasq (host net) + nginx :80/:443
├── .env.example                # SERVER_IP, upstream DNS, host repo URL
├── dnsmasq/dnsmasq.conf.template
├── nginx/default.conf.template
├── scripts/
│   ├── render-config.sh        # templates → dnsmasq.conf + default.conf
│   ├── generate-cert.sh        # self-signed certs/manuals.{crt,key}
│   ├── setup-host.sh           # clone upstream → www/ + patch index.html
│   └── verify.sh               # local sanity checks
└── README.md
```

Generated / cloned (gitignored): `.env`, `dnsmasq/dnsmasq.conf`, `nginx/default.conf`, `certs/`, `www/`.

---

## Optional: Unraid / existing reverse proxy

If your NAS already runs nginx on 80/443, you can:

1. Still run the **dns** service from this compose file (or any dnsmasq with the same records).
2. Drop the contents of `nginx/default.conf.template` (after rendering) into your host nginx as a server block, pointing `root` at the cloned `www/` and the cert paths at wherever you keep `manuals.crt` / `manuals.key`.
3. Keep the `.js`/`.css` `=404` rule and `Cache-Control: no-store`.

A small “apply drop-in + nginx -t && reload” script on boot is enough; this repo stays compose-first so it works on plain Docker hosts too.

---

## Updating the host page

```bash
./scripts/setup-host.sh        # git fetch + re-apply patch
docker compose restart web
```

To switch upstreams, set `HOST_REPO` / `HOST_REF` in `.env` before running `setup-host.sh`.

---

## Security notes

- The self-signed cert is only so the PS5 browser can speak TLS to **you**. Do not reuse it elsewhere.
- dnsmasq on this host becomes a DNS oracle for anyone pointed at it — keep it on a trusted LAN.
- Payloads (`*.elf`, `*.bin`) come from upstream clones and stay in `www/` (gitignored). **Never commit them.**
- This repo deliberately contains **no** exploit sources.

---

## Credits

- Relapse exploit chain: Sonic_Iso, Jordy, ntfargo, ufm42, Dr. Yenyen, and others listed in [ntfargo/Relapse-Exploit](https://github.com/ntfargo/Relapse-Exploit)
- WAK1360 host UI: [arg0WAK/WAK1360-Relapse](https://github.com/arg0WAK/WAK1360-Relapse)
- Payload authors (OnionHEN, ShadowMount+, FTP server, etc.) — see their respective projects

---

## License

Packaging and scripts in this repository are provided as-is, without warranty. Upstream exploit and host-page licenses apply to material cloned into `www/`.
