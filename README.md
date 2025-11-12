# Foreman Audit — Gated Workflow

Repository SSOT per audit e riconfigurazione di Foreman/Katello/Smart Proxies a **gate** (P0, P1, …).

## Struttura
```

GATES/
└─ P0_DNS_PKI_NET/
├─ SUMMARY.yaml
├─ GATE_STATE.json
├─ DECISION_LOG.md
├─ RISKS.md
├─ CHECKSUMS.txt
└─ EVIDENCE/

```

## Ciclo operativo (per ogni gate)
1. **Raccogli evidenze** in `EVIDENCE/`.
2. Aggiorna `SUMMARY.yaml` (assertions + proxies esaminati).
3. Aggiorna `CHECKSUMS.txt` (sha256).
4. Commit & push.
5. Apri una **Gate Submission** Issue e avvia la doppia review (GPT-5, Gemini).
6. Quando entrambe **APPROVE**, chiudi con **Gate Merge Decision**.

## Comandi utili
```bash
# Aggiorna checksum (da GATES/<gate>/)
find EVIDENCE -type f -print0 | xargs -0 sha256sum > CHECKSUMS.txt
```

## Convenzioni

* Un solo gate “aperto” alla volta.
* Stato nel `GATE_STATE.json`: `DRAFT` → `SUBMITTED` → `APPROVED` → `EXECUTED` (o `REWORK`).
* Niente segreti in repo: sanitizza le evidenze prima del push.

