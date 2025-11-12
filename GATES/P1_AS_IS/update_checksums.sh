#!/usr/bin/env bash
# Gate P1 — Genera CHECKSUMS.txt (sha256) per integrità evidenze
set -euo pipefail

BASE="$(cd "$(dirname "$0")" && pwd)"
OUT="$BASE/CHECKSUMS.txt"

sha_cmd() {
  if command -v sha256sum >/dev/null 2>&1; then
    echo "sha256sum"
  elif command -v shasum >/dev/null 2>&1; then
    echo "shasum -a 256"
  else
    echo "ERROR: no sha256 tool found" >&2
    exit 1
  fi
}

cd "$BASE"

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

# Elenca tutti i file sotto P1, escludendo CHECKSUMS.txt e .git
# Mantiene percorsi relativi per stabilità cross-host
find . \
  -type f \
  -not -path "*/.git/*" \
  -not -path "./CHECKSUMS.txt" \
  -print0 | sort -z | while IFS= read -r -d '' f; do
    # normalizza prefisso "./"
    rel="${f#./}"
    $(sha_cmd) "$rel" >> "$TMP"
  done

mv "$TMP" "$OUT"
echo "Wrote $OUT"

