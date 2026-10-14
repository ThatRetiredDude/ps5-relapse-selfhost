#!/usr/bin/env bash
# Generate a self-signed TLS certificate for manuals.playstation.net
# The PS5 User's Guide loads over HTTPS; a matching CN/SAN is enough.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CERT_DIR="${CERT_DIR:-certs}"
DAYS="${CERT_DAYS:-3650}"
CN="manuals.playstation.net"

mkdir -p "$CERT_DIR"

if [[ -f "$CERT_DIR/manuals.crt" && -f "$CERT_DIR/manuals.key" ]]; then
  echo "certs already exist in $CERT_DIR/ (remove them to regenerate)"
  openssl x509 -in "$CERT_DIR/manuals.crt" -noout -subject -dates -ext subjectAltName 2>/dev/null || true
  exit 0
fi

openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "$CERT_DIR/manuals.key" \
  -out "$CERT_DIR/manuals.crt" \
  -days "$DAYS" \
  -subj "/CN=${CN}" \
  -addext "subjectAltName=DNS:${CN},DNS:manual.playstation.net,DNS:doc.dl.playstation.net"

chmod 600 "$CERT_DIR/manuals.key"
chmod 644 "$CERT_DIR/manuals.crt"

echo "wrote $CERT_DIR/manuals.crt and $CERT_DIR/manuals.key"
openssl x509 -in "$CERT_DIR/manuals.crt" -noout -subject -dates -ext subjectAltName
