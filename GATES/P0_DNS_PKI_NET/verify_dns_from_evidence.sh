#!/usr/bin/env bash
# Verifica forward (A) + reverse (PTR) per ogni proxy usando *solo* EVIDENCE/dns_proxies.txt
# Output:
#  - REPORT_dns_a_ptr.csv     (host,header_ip,forward_ip,ptr_fqdn,status,notes)
#  - REPORT_dns_summary.txt   (riepilogo PASS/FAIL)
#
# Uso: eseguire da GATES/P0_DNS_PKI_NET
set -euo pipefail

EVD="EVIDENCE"
SRC="$EVD/dns_proxies.txt"
OUT_CSV="REPORT_dns_a_ptr.csv"
OUT_SUM="REPORT_dns_summary.txt"

[ -f "$SRC" ] || { echo "ERROR: missing $SRC"; exit 1; }

# Parser di blocchi:
# --- <host> / <ip|N/A> ---
# <linee successive con IP (A) e/o FQDN. (PTR)>
awk -v OFS=',' '
  function flush() {
    if (host != "") {
      status="PASS"; notes="";
      # forward mancante
      if (fwd_ip == "" || fwd_ip == "N/A") { status="FAIL"; notes=notes"no-forward "; }
      # header_ip vs forward
      if (hdr_ip != "" && hdr_ip != "N/A" && fwd_ip != "" && fwd_ip != "N/A" && hdr_ip != fwd_ip) {
        status="FAIL"; notes=notes"hdr!=fwd ";
      }
      # ptr check
      gsub(/\.$/,"",ptr);
      if (ptr == "") { status=(status=="PASS"?"FAIL":status); notes=notes"no-ptr "; }
      else if (host != "" && ptr != host) { status="FAIL"; notes=notes"ptr!=host "; }
      print host, hdr_ip, fwd_ip, ptr, status, (notes==""?"-":notes);
    }
  }

  BEGIN {
    print "host","header_ip","forward_ip","ptr_fqdn","status","notes" > "'"$OUT_CSV"'";
    re_hdr = /^---[[:space:]]+([^[:space:]]+)[[:space:]]*\/[[:space:]]*([^[:space:]]+)[[:space:]]*---$/;
    re_ipv4 = /^[0-9]{1,3}(\.[0-9]{1,3}){3}$/;
    re_ipv6 = /:/;
  }

  # nuova intestazione blocco
  $0 ~ re_hdr {
    flush();
    host=$0; gsub(/^---[[:space:]]+/,"",host); gsub(/[[:space:]]+---$/,"",host);
    hdr_ip=host; sub(/.*\//,"",hdr_ip); gsub(/[[:space:]]+/,"",hdr_ip);
    sub(/[[:space:]]*\/[[:space:]]*.*$/,"",host);
    fwd_ip=""; ptr="";
    next
  }

  # linee dati: se è IP -> forward, se contiene un dot alfabetico -> ptr
  {
    line=$0; gsub(/^[[:space:]]+|[[:space:]]+$/,"",line);
    if (line == "" || line ~ /^===/ || line ~ /^WARN:/) next;

    # A record (v4 o v6)
    if (line ~ re_ipv4 || line ~ re_ipv6) {
      # prendi solo il primo IP utile
      if (fwd_ip == "") fwd_ip=line;
      next
    }

    # Probabile PTR (FQDN con almeno un punto)
    if (index(line,".")>0) {
      if (ptr == "") ptr=line;
      next
    }
  }

  END { flush(); }
' "$SRC" >> "$OUT_CSV"

# Riepilogo
tot=$(($(wc -l < "$OUT_CSV")-1))
pass=$(grep -c ",PASS," "$OUT_CSV" || true)
fail=$(grep -c ",FAIL," "$OUT_CSV" || true)

{
  echo "DNS A/PTR consistency report"
  echo "File: $SRC"
  echo "Total: $tot | PASS: $pass | FAIL: $fail"
  echo
  if [ "$fail" -gt 0 ]; then
    echo "Failures:"
    awk -F, 'NR>1 && $5=="FAIL"{printf "- %s (hdr:%s fwd:%s ptr:%s) [%s]\n",$1,$2,$3,$4,$6}' "$OUT_CSV"
  fi
} > "$OUT_SUM"

echo "Generated: $OUT_CSV and $OUT_SUM"
exit 0

