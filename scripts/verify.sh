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
check "firmware.js cache-buster present" grep -qE 'firmware\.js\?v=' www/index.html
check "js/css 404 rule present" grep -q 'try_files \$uri =404' nginx/default.conf
check "HTTPS server block present" grep -q 'listen 443 ssl' nginx/default.conf

if command -v docker >/dev/null 2>&1; then
  if docker compose version >/dev/null 2>&1; then
    check "docker compose config" docker compose config -q
  else
    echo "skip docker compose config (plugin missing)"
  fi
else
  echo "skip docker compose config (docker not installed)"
fi

# Refuse to ship local identifiers. Build tokens at runtime so this file
# does not contain the full literal strings for a naive tree grep.
forbid_hits=0
scan_paths=(.env.example .gitignore README.md docker-compose.yml dnsmasq nginx scripts)
tokens=(
  '10.35.'
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
