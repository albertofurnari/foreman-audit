#!/usr/bin/env bash
set -euo pipefail

SRC="GATES/P0_DNS_PKI_NET/EVIDENCE/dns_proxies_nss.txt"
OUT="GATES/P0_DNS_PKI_NET/REPORT_dns_nss_summary.txt"
EXC="GATES/P0_DNS_PKI_NET/EXCLUDED_HOSTS.txt"

[ -f "$SRC" ] || { echo "Missing $SRC"; exit 1; }

awk -v excfile="$EXC" '
  BEGIN{
    fail=0; total=0; excluded=0
    if (excfile != "" && (getline line < excfile) > 0) {
      do {
        gsub(/\r$/,"",line)
        if (line ~ /^[[:space:]]*$/ || line ~ /^#/) continue
        excl[tolower(line)]=1
      } while ((getline line < excfile) > 0)
      close(excfile)
    }
    print "NSS forward/reverse check report"
  }

  # Nuovo blocco host
  /^--- /{
    host=$2
    host_l=tolower(host)
    fwd=0; ptr=0
    if (host_l in excl) { skip=1; excluded++ } else { skip=0; total++ }
    next
  }

  # Nessun forward
  /NSS-NO-FWD/ {
    if (!skip) { fail++; print "FAIL: no forward for " $2 }
    next
  }

  # getent hosts <fqdn> -> IP
  /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+[[:space:]]/ {
    fwd=1; ip=$1; next
  }

  # getent hosts <ip> -> fqdn (reverse)
  /^[^ ]+\.[^ ]+\.[^ ]+\.[^ ]+\./ && !/^NSS-NO-PTR/ {
    # line starts with FQDN (reverse output); consider it a PTR hit
    ptr=1; next
  }

  END{
    if (fail==0) {
      print "Summary: PASS (NSS) on", total, "hosts", (excluded>0? "(excluded: "excluded")":"")
    } else {
      print "Summary: FAIL=" fail, "on", total, "hosts", (excluded>0? "(excluded: "excluded")":"")
    }
  }
' "$SRC" | tee "$OUT"

