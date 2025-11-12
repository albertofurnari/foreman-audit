# Risks — Gate P0 (DNS / PKI / Connectivity)

## Open Risks
*(none logged yet — add using the template below)*

## Risk Entry Template
```yaml
- id: R-P0-XXX
  title: <short name>
  desc: <what could go wrong / assumption to validate>
  cause: <underlying condition>
  impact: <operational effect if realized>
  likelihood: Low|Medium|High
  severity: Low|Medium|High|Critical
  mitigation: <specific steps / commands / owners>
  owner: <role or person>
  status: Open|Mitigated|Closed|Accepted
  evidence: [ "EVIDENCE/<file1>", "EVIDENCE/<file2>" ]
```
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


## Notes
- Un rischio per voce; mantieni i riferimenti puntuali ai file in EVIDENCE/.
- Chiudi il rischio solo con evidenza aggiornata (commit + checksum).
