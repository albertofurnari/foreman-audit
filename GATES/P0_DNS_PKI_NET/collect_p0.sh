#!/usr/bin/env bash
# P0 evidence collector — run on the CONSOLE (itmxvlpforaio01)
set -euo pipefail

BASE="$(cd "$(dirname "$0")" && pwd)"
EVD="$BASE/EVIDENCE"
mkdir -p "$EVD"

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; exit 1; }; }
need hammer
need openssl

# DNS tool: prefer dig, fallback to host
DIG="dig"; command -v dig >/dev/null 2>&1 || DIG="host"

# Ensure nc for TCP reachability (best effort install if missing)
if ! command -v nc >/dev/null 2>&1; then
  if command -v dnf >/dev/null 2>&1; then dnf -y install nmap-ncat || true
  elif command -v yum >/dev/null 2>&1; then yum -y install nmap-ncat || true
  elif command -v apt-get >/dev/null 2>&1; then apt-get update -y && apt-get install -y netcat || true
  fi
fi

CONSOLE_FQDN="itmxvlpforaio01.it.cobra.group"
CONSOLE_IP="192.168.8.130"

# DNS — console
{
  echo "=== CONSOLE FQDN -> A ==="
  echo "$CONSOLE_FQDN"
  if [ "$DIG" = "dig" ]; then dig +short "$CONSOLE_FQDN" || true; else host "$CONSOLE_FQDN" || true; fi
  echo
  echo "=== CONSOLE IP -> PTR ==="
  echo "$CONSOLE_IP"
  if [ "$DIG" = "dig" ]; then dig -x "$CONSOLE_IP" +short || true; else host "$CONSOLE_IP" || true; fi
} > "$EVD/dns_console.txt"

# PKI — console 443
openssl s_client -connect "$CONSOLE_FQDN":443 -servername "$CONSOLE_FQDN" </dev/null 2>/dev/null \
  | openssl x509 -noout -issuer -subject -dates > "$EVD/pki_console.txt" || echo "ERR: openssl console" > "$EVD/pki_console.txt"

# Proxies list
mapfile -t PROXIES < <(hammer --csv proxy list | awk -F, 'NR>1{print $2}')
printf "%s\n" "${PROXIES[@]}" > "$EVD/proxies_list.txt"

# DNS — proxies (tollerante agli errori)
{
  echo "=== PROXIES DNS ==="
  for P in "${PROXIES[@]}"; do
    # proteggi il pipeline con subshell e || true
    IP="$({ getent hosts "$P" 2>/dev/null | awk '{print $1}'; } || true)"
    echo "--- $P / ${IP:-N/A} ---"
    if [ "$DIG" = "dig" ]; then (dig +short "$P" || true); else (host "$P" || true); fi
    if [ -n "${IP:-}" ]; then
      if [ "$DIG" = "dig" ]; then (dig -x "$IP" +short || true); else (host "$IP" || true); fi
    else
      echo "WARN: forward DNS unresolved for $P" || true
    fi
  done
} > "$EVD/dns_proxies.txt"

# PKI — proxies 9090 (sempre produce file)
{
  echo "=== PROXIES PKI (9090) ==="
  for P in "${PROXIES[@]}"; do
    echo "--- $P ---"
    openssl s_client -connect "$P":9090 -servername "$P" </dev/null 2>/dev/null \
      | openssl x509 -noout -issuer -subject -dates \
      || echo "ERR: openssl handshake failed for $P"
  done
} > "$EVD/pki_proxies.txt"

# Reachability — console -> proxies
PORTS=(9090 5647 443 8443 8140)
{
  echo "=== REACHABILITY Foreman->Proxies ==="
  for P in "${PROXIES[@]}"; do
    echo "--- $P ---"
    for port in "${PORTS[@]}"; do
      if command -v nc >/dev/null 2>&1; then
        (nc -vz -w2 "$P" "$port" >/dev/null 2>&1 && echo "OPEN $port") || echo "CLOSED $port"
      else
        timeout 2 bash -c "exec 3<>/dev/tcp/$P/$port" >/dev/null 2>&1 && echo "OPEN $port" || echo "CLOSED $port"
      fi
    done
  done
} > "$EVD/reach_f2p.txt"

# Git version evidence (locale)
{
  echo "=== GIT VERSION ==="
  date -Is
  git --version || true
} > "$EVD/git_versions.txt"

# Checksums
cd "$BASE"
find EVIDENCE -type f -print0 | xargs -0 sha256sum > CHECKSUMS.txt

echo "P0 evidence collected in: $EVD"

