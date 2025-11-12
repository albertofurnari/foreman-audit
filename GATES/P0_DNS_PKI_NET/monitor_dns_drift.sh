#!/usr/bin/env bash
set -euo pipefail
BASE="$(cd "$(dirname "$0")" && pwd)"
EVD="$BASE/EVIDENCE"
OUT="$EVD/dns_drift.tsv"
mkdir -p "$EVD"

ns_for_zone() { dig +short NS "$1" | head -1; }

zone_from_fqdn() { echo "$1" | cut -d'.' -f2-; }

rev_zone_from_ip() {
  IFS=. read -r a b c d <<<"$1"
  echo "$c.$b.$a.in-addr.arpa"
}

printf "host\tnss_ip\tauth_ns\tdig_a_ip\tdig_ptr_fqdn\tstatus\n" > "$OUT"

mapfile -t HOSTS < "$EVD/proxies_list.txt"
HOSTS=("$HOSTS[@]" "itmxvlpforaio01.it.cobra.group")

for H in "${HOSTS[@]}"; do
  H="${H%%[$'\r\n']}"
  [ -z "$H" ] && continue

  NSS_IP="$(getent hosts "$H" | awk '{print $1}' | head -1)"
  ZONE="$(zone_from_fqdn "$H")"
  NS="$(ns_for_zone "$ZONE")"

  DIG_A=""
  DIG_PTR=""
  STATUS="OK"

  if [ -n "$NS" ]; then
    DIG_A="$(dig +short "@$NS" "$H")"
    if [ -n "$NSS_IP" ]; then
      RZ="$(rev_zone_from_ip "$NSS_IP")"
      DIG_PTR="$(dig +short "@$NS" -x "$NSS_IP")"
    fi
  else
    STATUS="NOAUTHNS"
  fi

  # Valutazione
  if [ -z "$DIG_A" ] || [ -z "$DIG_PTR" ]; then
    STATUS="MISMATCH"
  fi
  if [ -n "$DIG_A" ] && [ -n "$NSS_IP" ] && [ "$DIG_A" != "$NSS_IP" ]; then
    STATUS="MISMATCH"
  fi
  if [ -n "$DIG_PTR" ] && [[ "${DIG_PTR%.}" != "$H" ]]; then
    STATUS="MISMATCH"
  fi

  printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$H" "${NSS_IP:-}" "${NS:-}" "${DIG_A:-}" "${DIG_PTR:-}" "$STATUS" >> "$OUT"
done

echo "Wrote $OUT"

