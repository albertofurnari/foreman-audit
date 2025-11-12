# Contributing — Foreman Audit (Gated)

Questo repository è la Single Source of Truth (SSOT) per gli audit a gate (P0, P1, …).

## Regole di base
- **Un solo gate “aperto”** alla volta.
- **No segreti**: sanitizza output ed evidenze prima del commit.
- **Console-only push**: i commit/push avvengono dalla console Foreman.

## Workflow per gate
1. Raccogli evidenze in `GATES/<GATE>/EVIDENCE/`.
2. Aggiorna `SUMMARY.yaml` (assertions + `proxies_examined`).
3. Genera `CHECKSUMS.txt`.
4. Aggiorna `GATE_STATE.json`:
   - `DRAFT` → `SUBMITTED` (dopo push della submission)
   - `APPROVED` (dopo doppia review)
   - `EXECUTED` (dopo remediation/applicazione)
   - `REWORK` (se servono correzioni)
5. Apri/chiudi le Issue tramite i template in `.github/ISSUE_TEMPLATE/`.

## Commit, branch, tag
- **Branch principale**: `main`.
- **Commit message**:  
  - `chore(<gate>): ...` (scaffold/manutenzione)  
  - `feat(<gate>): ...` (nuove evidenze/script)  
  - `fix(<gate>): ...` (correzioni evidenze/summary)
- **Tag consigliati**:
  - `gate-P0-submitted`
  - `gate-P0-approved`
  - `gate-P0-executed`

## Verifiche automatiche
- GitHub Actions:
  - `.github/workflows/validate-gate.yml` (presenza file chiave)
  - `.github/workflows/validate-summary-schema.yml` (schema SUMMARY)

## Struttura minima per gate
```

GATES/<GATE>/
├─ SUMMARY.yaml
├─ GATE_STATE.json
├─ DECISION_LOG.md
├─ RISKS.md
├─ CHECKSUMS.txt
└─ EVIDENCE/

```

## Contatti / Ruoli
- **Director/Orchestrator**: coordina gate, approva merge decision.
- **Reviewers (AI)**: GPT-5, Gemini (rispondono nel formato REVIEW vincolato).

