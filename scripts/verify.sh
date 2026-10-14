#!/usr/bin/env bash
# Lightweight sanity checks after setup (does not require a PS5).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail=0

check() {
  local desc="$1"; shift
  if "$@"; then
    echo "ok  $desc"
  else
    echo "FAIL $desc" >&2
    fail=1
  fi
}

check "dnsmasq.conf exists" test -f dnsmasq/dnsmasq.conf
check "nginx default.conf exists" test -f nginx/default.conf
check "TLS cert exists" test -f certs/manuals.crt
check "TLS key exists" test -f certs/manuals.key
check "www/index.html exists" test -f www/index.html
check "base href present" grep -q '<base href="/">' www/index.html
check "firmware.js ?v=4" grep -qE 'firmware\.js\?v=4' www/index.html
check "force-ready script tag" grep -q 'force-ready.js?v=4' www/index.html
check "force-ready.js file" test -f www/src/force-ready.js
check "firmware detectFirmware helper" grep -q 'detectFirmware' www/src/firmware.js
check "js/css 404 rule present" grep -q 'try_files \$uri =404' nginx/default.conf
check "HTTPS server block present" grep -q 'listen 443 ssl' nginx/default.conf
check "HOST_REF pin in .env.example" grep -q 'b2398fd5bea116f990595e0a187ae94d8c6db43d' .env.example
check "overlay payloads.json present" test -f overlay/payloads.json
check "unraid drop-in template present" test -f unraid/relapse-nginx.conf.template

if [[ -f www/payloads/ftpsrv-ps5.elf ]]; then
  check "ftpsrv registered in payloads.json" grep -q 'ftpsrv-ps5.elf' www/payloads/payloads.json
fi

if command -v docker >/dev/null 2>&1; then
  if docker compose version >/dev/null 2>&1; then
    check "docker compose config" docker compose config -q
  else
    echo "skip docker compose config (plugin missing)"
  fi
else
  echo "skip docker compose config (docker not installed)"
fi

forbid_hits=0
scan_paths=(.env.example .gitignore README.md docker-compose.yml dnsmasq nginx scripts overlay unraid)
tokens=(
  "$(printf '%s%s' '10.' '35.')"
  "$(printf '%s%s' Tow er)"
  "$(printf '%s%s' tai 'l-')"
  "$(printf '%s%s' max well)"
)
for term in "${tokens[@]}"; do
  if grep -RIn --exclude-dir=.git --exclude='verify.sh' -e "$term" "${scan_paths[@]}" 2>/dev/null; then
    echo "FAIL forbidden token matched" >&2
    forbid_hits=1
  fi
done

if [[ "$forbid_hits" -eq 0 ]]; then
  echo "ok  no forbidden local identifiers"
else
  fail=1
fi

exit "$fail"
