#!/usr/bin/env bash
# Update SHA256 checksums for all evidence files in this gate
set -euo pipefail
cd "$(dirname "$0")"

test -d EVIDENCE || { echo "ERROR: EVIDENCE/ directory missing"; exit 1; }

# Generate CHECKSUMS.txt at gate root
find EVIDENCE -type f -print0 | xargs -0 sha256sum > CHECKSUMS.txt

echo "CHECKSUMS.txt updated on $(date -Is)"

