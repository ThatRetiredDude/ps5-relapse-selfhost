#!/usr/bin/env bash
# Clone the upstream WAK1360 host page into ./www, pin a known commit, and
# apply the local overlay (base href, cache-bust, UA fixes, force-ready).
# Does not vendor exploit code into this repository — the clone stays local.
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
# Pin the commit this overlay was built against (override via .env if needed).
HOST_REF="${HOST_REF:-b2398fd5bea116f990595e0a187ae94d8c6db43d}"
WWW="${WWW_DIR:-www}"
OVERLAY="${OVERLAY_DIR:-overlay}"

clone_pinned() {
  local dest="$1"
  if [[ -d "$dest/.git" ]]; then
    echo "updating existing clone in $dest → $HOST_REF ..."
    git -C "$dest" remote set-url origin "$HOST_REPO" 2>/dev/null || true
    git -C "$dest" fetch --depth 1 origin "$HOST_REF"
    git -C "$dest" checkout -q --force FETCH_HEAD
    git -C "$dest" clean -fdq
  else
    if [[ -e "$dest" ]]; then
      echo "error: $dest exists but is not a git clone; move it aside and re-run." >&2
      exit 1
    fi
    echo "cloning $HOST_REPO @$HOST_REF into $dest ..."
    mkdir -p "$dest"
    git -C "$dest" init -q
    git -C "$dest" remote add origin "$HOST_REPO"
    git -C "$dest" fetch --depth 1 origin "$HOST_REF"
    git -C "$dest" checkout -q FETCH_HEAD
  fi
  echo "checked out $(git -C "$dest" rev-parse HEAD)"
}

clone_pinned "$WWW"

if [[ ! -d "$OVERLAY" ]]; then
  echo "error: overlay directory missing: $OVERLAY" >&2
  exit 1
fi

echo "applying overlay from $OVERLAY ..."
# Copy overlay files on top of the pinned upstream tree.
# Use ditto/cp -R semantics without copying directories that would nest.
while IFS= read -r -d '' src; do
  rel="${src#"$OVERLAY"/}"
  # payloads.json is applied by scripts/add-ftpsrv.sh (optional FTP step)
  if [[ "$rel" == "payloads.json" ]]; then
    continue
  fi
  dst="$WWW/$rel"
  mkdir -p "$(dirname "$dst")"
  cp -f "$src" "$dst"
  echo "  + $rel"
done < <(find "$OVERLAY" -type f -print0)

# Sanity: required overlay pieces
for req in index.html src/firmware.js src/helper.js src/force-ready.js; do
  if [[ ! -f "$WWW/$req" ]]; then
    echo "error: missing $WWW/$req after overlay" >&2
    exit 1
  fi
done

echo "--- overlay check ---"
grep -n 'base href' "$WWW/index.html" || true
grep -n 'force-ready.js' "$WWW/index.html" || true
grep -nE 'firmware\.js\?v=4' "$WWW/index.html" || true
grep -c 'detectFirmware' "$WWW/src/firmware.js" || true
test -f "$WWW/src/force-ready.js" && echo "force-ready.js present"

echo "host page ready in $WWW/"
echo "optional: ./scripts/add-ftpsrv.sh   # download FTP payload + update payloads.json"
