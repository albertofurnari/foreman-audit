# WAIVER P0-DNS-001 — DNS autoritativo non allineato (deroga temporanea)

- id: WAIVER_P0_DNS-001
- gate: P0 (DNS/PKI/Connettività)
- deviation: Uso di NSS `/etc/hosts` sulla console Foreman in luogo di record A/PTR autoritativi.
- scope: Solo host di console `itmxvlpforaio01.it.cobra.group`. Nessuna modifica su Smart Proxy/host gestiti.
- rationale: Complessità multi-DC e dipendenza da due team esterni. CR DNS già aperta; tempi stimati in settimane.
- evidence:
  - `EVIDENCE/hosts_override.txt`
  - `EVIDENCE/dns_proxies_nss.txt`, `REPORT_dns_nss_summary.txt`
  - `DNS/dns_records.csv`, `DNS/DNS_CHANGE_REQUEST.md` (CR formalizzata)
- mitigations:
  - Monitor “drift” tra NSS e DNS autoritativo (`monitor_dns_drift.sh` + `EVIDENCE/dns_drift.tsv`)
  - Smoke-test periodici: `hammer ping`, `curl https://<proxy>:9090/features`
  - PKI handshake verificato su FQDN attuali; rigenerazione cert prevista post-CR se necessario
- expiry: 2025-12-31 23:59:59 Europe/Rome  (o alla chiusura CR, il primo evento utile)
- owner: Infra / Alberto
- closure_criteria:
  - A+PTR corretti per tutti i proxy/console (forward+reverse AA)
  - `collect_p0.sh` (strict) PASS senza override
  - rimozione blocco `/etc/hosts` e chiusura `R-P0-DNS-OVERRIDE`
- risk_rating: Medium (operational), Low (security) — contesto LAN e certificati pin-based su nomi coerenti
- approvals_required: GPT-5 (Reviewer A), Gemini (Reviewer B)

