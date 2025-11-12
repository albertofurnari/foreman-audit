# Risks — Gate P0 (DNS / PKI / Connectivity)

## Open Risks
*(none logged yet — add using the template below)*

## Risk Entry Template
- id: R-P0-DCOMM-BROWN
  title: Decommission proxy vfabrown
  desc: Proxy itva01vlpfpxbrwn01.vfabrown.local irraggiungibile e da dismettere
  cause: Host spento/legacy; manutenzione non più prevista
  impact: Riferimenti orfani (subnet/DHCP/DNS/TFTP, content source, puppet, REx)
  likelihood: Medium
  severity: Medium
  mitigation: Eseguire checklist di decommission (vedi Gate P5), riassegnare risorse prima del delete
  owner: Infra
  status: Open
  evidence: ["EVIDENCE/reach_f2p.txt","EVIDENCE/dns_proxies.txt"]
- id: R-P0-DNS-OVERRIDE
  title: DNS autoritativo non allineato (override NSS locale)
  desc: Console usa /etc/hosts; dig/host non riflettono lo stato autoritativo.
  status: Accepted (time-boxed)
  waiver_ref: WAIVER_P0_DNS-001
  until: 2025-12-31
  mitigation:
    - monitor_dns_drift.sh giornaliero con alert su mismatch
    - smoke-test periodici (hammer ping; features 9090)
  owner: Infra
  evidence: ["EVIDENCE/hosts_override.txt","REPORT_dns_nss_summary.txt","EVIDENCE/dns_drift.tsv"]


## Notes
- Un rischio per voce; mantieni i riferimenti puntuali ai file in EVIDENCE/.
- Chiudi il rischio solo con evidenza aggiornata (commit + checksum).
