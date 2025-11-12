# Decision Log — Gate P0 (DNS/PKI/CONNECTIVITY)

## Proposals
<!-- Una riga per proposta -->
#- ID: A-P0-01
#  - Desc: <descrizione azione>
#  - Commands: <riferimento a script/comandi>
#  - Evidence: <file in EVIDENCE/* richiesti>
#  - Status: Proposed | Approved | Rejected
#  - Reviewer Notes (GPT-5): <...>
#  - Reviewer Notes (Gemini): <...>
- ID: A-P0-EXCLUDE-BROWN
  Desc: Escludere itva01vlpfpxbrwn01.vfabrown.local dal conteggio P0 e pianificare decommission
  Status: Approved
  Reviewer Notes (GPT-5): OK
  Reviewer Notes (Gemini): OK

- ID: A-P0-WAIVER-DNS
  When: <oggi, ISO-8601>
  What: Introduzione WAIVER P0-DNS-001 per consentire prosecuzione audit
  Reason: CR DNS con tempi lunghi; override locale è stabile e confinato
  Mitigations: monitor_dns_drift, smoke-test ricorrenti
  Status: Proposed → (da marcare Approved dopo doppia review)


## Final Decision
- Director: <APPROVED | REWORK>
- Rationale: <motivazione sintetica>
- Date: <YYYY-MM-DDTHH:MMZ>

## Change Log
- <YYYY-MM-DDTHH:MMZ> init

