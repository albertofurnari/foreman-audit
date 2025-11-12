#!/usr/bin/env bash
set -euo pipefail
BASE="$(cd "$(dirname "$0")" && pwd)"
EVD="$BASE/EVIDENCE"
mkdir -p "$EVD"

need(){ command -v "$1" >/dev/null 2>&1 || { echo "Missing $1" >&2; exit 1; }; }
need hammer; need openssl

CONSOLE_FQDN="itmxvlpforaio01.it.cobra.group"
CONSOLE_IP="192.168.8.130"

# DNS (NSS) — console
{
  echo "=== CONSOLE FQDN -> A (NSS) ==="
  echo "$CONSOLE_FQDN"
  getent hosts "$CONSOLE_FQDN" || true
  echo
  echo "=== CONSOLE IP -> PTR (NSS) ==="
  echo "$CONSOLE_IP"
  getent hosts "$CONSOLE_IP" || true
} > "$EVD/dns_console_nss.txt"

# PKI — console
openssl s_client -connect "$CONSOLE_FQDN":443 -servername "$CONSOLE_FQDN" </dev/null 2>/dev/null \
  | openssl x509 -noout -issuer -subject -dates > "$EVD/pki_console.txt" || true

# Proxies
mapfile -t PROXIES < <(hammer --csv proxy list | awk -F, 'NR>1{print $2}')
printf "%s\n" "${PROXIES[@]}" > "$EVD/proxies_list.txt"

# DNS (NSS) — proxies
{
  echo "=== PROXIES NSS ==="
  for P in "${PROXIES[@]}"; do
    echo "--- $P ---"
    getent hosts "$P" || echo "NSS-NO-FWD $P"
    # IP dall'override (se presente)
    IP="$(getent hosts "$P" | awk "{print \$1}" | head -1)"
    if [ -n "${IP:-}" ]; then
      getent hosts "$IP" || echo "NSS-NO-PTR $IP"
    fi
  done
} > "$EVD/dns_proxies_nss.txt"

# PKI — proxies 9090
{
  echo "=== PROXIES PKI (9090) ==="
  for P in "${PROXIES[@]}"; do
    echo "--- $P ---"
    openssl s_client -connect "$P":9090 -servername "$P" </dev/null 2>/dev/null \
      | openssl x509 -noout -issuer -subject -dates \
      || echo "ERR: openssl handshake failed for $P"
  done
} > "$EVD/pki_proxies.txt"

# Reachability
PORTS=(9090 8140 443)
{
  echo "=== REACHABILITY Foreman->Proxies (core) ==="
  for P in "${PROXIES[@]}"; do
    echo "--- $P ---"
    for port in "${PORTS[@]}"; do
      (nc -vz -w2 "$P" "$port" >/dev/null 2>&1 && echo "OPEN $port") || echo "CLOSED $port"
    done
  done
} > "$EVD/reach_f2p.txt"

# Checksums
cd "$BASE"
find EVIDENCE -type f -print0 | xargs -0 sha256sum > CHECKSUMS.txt
echo "P0 NSS evidence collected into $EVD"
