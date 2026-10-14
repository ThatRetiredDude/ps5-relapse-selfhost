#!/usr/bin/env bash
# Clone the upstream Relapse host page into ./www and apply the
# PS5 User's Guide compatibility patches. Does not vendor exploit code
# into this repository — the clone stays local (see .gitignore).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  set -a
  # shellcheck source=/dev/null
  source .env
  set +a
fi

HOST_REPO="${HOST_REPO:-https://github.com/arg0WAK/WAK1360-Relapse.git}"
HOST_REF="${HOST_REF:-main}"
WWW="${WWW_DIR:-www}"
CACHE_BUST="${CACHE_BUST:-selfhost}"

if [[ -d "$WWW/.git" ]]; then
  echo "updating existing clone in $WWW ..."
  git -C "$WWW" fetch --depth 1 origin "$HOST_REF"
  git -C "$WWW" checkout -q FETCH_HEAD
else
  if [[ -e "$WWW" ]]; then
    echo "error: $WWW exists but is not a git clone; move it aside and re-run." >&2
    exit 1
  fi
  echo "cloning $HOST_REPO ($HOST_REF) into $WWW ..."
  git clone --depth 1 --branch "$HOST_REF" "$HOST_REPO" "$WWW"
fi

HTML="$WWW/index.html"
if [[ ! -f "$HTML" ]]; then
  echo "error: $HTML not found after clone" >&2
  exit 1
fi

# Backup once per run
cp "$HTML" "$HTML.bak-selfhost-$(date +%Y%m%d-%H%M%S)"

# 1. <base href="/"> so deep User's Guide paths like /document/en/ps5/
#    still resolve ./src/firmware.js and ./assets/* from the site root.
if ! grep -q '<base href="/">' "$HTML"; then
  # Insert immediately after <head> or before the first stylesheet link.
  if grep -q '<link rel="stylesheet"' "$HTML"; then
    # Use a portable python edit (BSD/GNU sed differ on -i).
    python3 - "$HTML" <<'PY'
import sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
needle = '<link rel="stylesheet"'
if '<base href="/">' not in text and needle in text:
    text = text.replace(needle, '<base href="/">\n  ' + needle, 1)
    open(path, "w", encoding="utf-8").write(text)
    print("added <base href=\"/\">")
else:
    print("base href already present or stylesheet link missing")
PY
  else
    echo "warning: no stylesheet link found; insert <base href=\"/\"> into <head> by hand" >&2
  fi
else
  echo "base href already present"
fi

# 2. Cache-bust firmware.js so the PS5 browser does not keep a broken copy.
python3 - "$HTML" "$CACHE_BUST" <<'PY'
import re, sys
path, bust = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8").read()
# Match firmware.js with or without an existing ?v= query
new, n = re.subn(
    r'(src=["\']\.?/src/firmware\.js)(?:\?[^"\']*)?(["\'])',
    rf'\1?v={bust}\2',
    text,
    count=1,
)
if n:
    open(path, "w", encoding="utf-8").write(new)
    print(f"set firmware.js cache-buster to ?v={bust}")
else:
    print("warning: firmware.js script tag not found; skip cache-bust", file=sys.stderr)
PY

echo "--- patch check ---"
grep -n 'base href' "$HTML" || true
grep -n 'firmware.js' "$HTML" || true
echo "host page ready in $WWW/"
echo "note: payloads (*.elf) come from upstream and stay local; this repo never vendors them."
