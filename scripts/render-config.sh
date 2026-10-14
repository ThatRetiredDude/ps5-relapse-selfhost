#!/usr/bin/env bash
# Render dnsmasq and nginx configs from templates using values in .env
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ ! -f .env ]]; then
  echo "error: .env not found. Copy .env.example to .env and set SERVER_IP." >&2
  exit 1
fi

# shellcheck disable=SC1091
set -a
# shellcheck source=/dev/null
source .env
set +a

: "${SERVER_IP:?SERVER_IP must be set in .env}"
: "${UPSTREAM_DNS_1:=1.1.1.1}"
: "${UPSTREAM_DNS_2:=8.8.8.8}"

if [[ ! "$SERVER_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: SERVER_IP must be an IPv4 address (got: $SERVER_IP)" >&2
  exit 1
fi

export SERVER_IP UPSTREAM_DNS_1 UPSTREAM_DNS_2

render() {
  local src="$1" dst="$2"
  # Portable envsubst of the three variables we care about.
  # Avoids requiring gettext on every host.
  python3 - "$src" "$dst" <<'PY'
import os, sys
src, dst = sys.argv[1], sys.argv[2]
text = open(src, encoding="utf-8").read()
for key in ("SERVER_IP", "UPSTREAM_DNS_1", "UPSTREAM_DNS_2"):
    text = text.replace("${%s}" % key, os.environ[key])
open(dst, "w", encoding="utf-8").write(text)
print(f"wrote {dst}")
PY
}

render dnsmasq/dnsmasq.conf.template dnsmasq/dnsmasq.conf
render nginx/default.conf.template nginx/default.conf

echo "configs rendered for SERVER_IP=$SERVER_IP"
