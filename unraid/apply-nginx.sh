#!/usr/bin/env bash
# Optional: merge the Relapse server block into an existing host nginx config
# (Unraid-style /etc/nginx/conf.d/servers.conf). Safe to re-run.
#
# Usage:
#   export SERVER_IP=192.168.1.50
#   export WAK_ROOT=/path/to/www
#   export CERT_DIR=/path/to/certs
#   export NGINX_SERVERS_CONF=/etc/nginx/conf.d/servers.conf
#   ./unraid/apply-nginx.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE="$ROOT/unraid/relapse-nginx.conf.template"
DROP_IN="${DROP_IN:-/boot/config/custom/relapse-nginx.conf}"
CONF="${NGINX_SERVERS_CONF:-/etc/nginx/conf.d/servers.conf}"
MARKER_BEGIN="# Relapse PS5 host"
MARKER_END="# Relapse PS5 host END"

: "${SERVER_IP:?set SERVER_IP}"
: "${WAK_ROOT:?set WAK_ROOT to the host-page directory (www)}"
: "${CERT_DIR:?set CERT_DIR to the directory with manuals.crt/key}"

if [[ ! -f "$TEMPLATE" ]]; then
  echo "error: missing $TEMPLATE" >&2
  exit 1
fi

rendered="$(mktemp)"
trap 'rm -f "$rendered"' EXIT

python3 - "$TEMPLATE" "$rendered" <<'PY'
import os, sys
src, dst = sys.argv[1], sys.argv[2]
text = open(src, encoding="utf-8").read()
for key in ("SERVER_IP", "WAK_ROOT", "CERT_DIR"):
    text = text.replace("${%s}" % key, os.environ[key])
open(dst, "w", encoding="utf-8").write(text)
PY

mkdir -p "$(dirname "$DROP_IN")"
cp "$rendered" "$DROP_IN"
echo "wrote $DROP_IN"

if [[ ! -f "$CONF" ]]; then
  echo "warning: $CONF not found; drop-in saved but not merged" >&2
  exit 0
fi

# Strip previous block, then append.
if grep -q "$MARKER_BEGIN" "$CONF" 2>/dev/null; then
  # portable: rewrite without the old block
  python3 - "$CONF" "$MARKER_BEGIN" "$MARKER_END" <<'PY'
import sys
path, begin, end = sys.argv[1], sys.argv[2], sys.argv[3]
lines = open(path, encoding="utf-8").read().splitlines(True)
out, skip = [], False
for line in lines:
    if begin in line:
        skip = True
        continue
    if skip and end in line:
        skip = False
        continue
    if not skip:
        out.append(line)
open(path, "w", encoding="utf-8").write("".join(out))
PY
fi

{
  echo "$MARKER_BEGIN"
  cat "$DROP_IN"
  echo "$MARKER_END"
} >> "$CONF"

if command -v nginx >/dev/null 2>&1; then
  nginx -t && nginx -s reload
  echo "nginx reloaded"
else
  echo "drop-in merged into $CONF (nginx binary not in PATH; reload yourself)"
fi
