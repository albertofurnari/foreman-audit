# [SUBMIT] Gate P1 — As-Is Disambiguation

## Contesto
- **Console:** itmxvlpforaio01.it.cobra.group (192.168.8.130)
- **Scope P1:** PUPPET · REX/ANSIBLE · WINDOWS PATCHING
- **Dipendenza:** P0 APPROVED_WITH_WAIVER (WAIVER_P0_DNS-001) — CR DNS in corso; attività P1 non impattano il DNS autoritativo.

## Target di campionamento (da SUMMARY.yaml)
- Puppet sample hosts: <!-- es. host-mxp01.it.cobra.group, host-va01.intra.cobra.it -->
- REX sample hosts:
  - MXP: <!-- es. host-mxp01.it.cobra.group -->
  - VA:  <!-- es. host-va01.intra.cobra.it -->
- Windows sample hosts: <!-- es. win-mxp01.it.cobra.group -->

---

## Evidenze caricate (path relativi a `GATES/P1_AS_IS/`)
### Puppet
- `EVIDENCE/puppet/puppet_master_info.txt`
- `EVIDENCE/puppet/puppet_envs.txt`
- `EVIDENCE/puppet/agent_status_SAMPLE.tsv`
- `EVIDENCE/puppet/reports_last.tsv`

### REX / Ansible
- `EVIDENCE/rex/rex_capsules.txt`
- `EVIDENCE/rex/rex_smoketest_MXP.txt`
- `EVIDENCE/rex/rex_smoketest_VA.txt`
- `EVIDENCE/ansible/ansible_topology.txt`

### Patching Windows
- `EVIDENCE/winpatch/model.md`
- `EVIDENCE/winpatch/job_evidence.txt`
- `EVIDENCE/winpatch/wsus_gpo.txt`  <!-- opzionale, se WSUS/GPO -->

### Riepilogo & Stato Gate
- `SUMMARY.yaml`
- `GATE_STATE.json`   <!-- state=SUBMITTED al momento dell’invio -->
- `DECISION_LOG.md`
- `RISKS.md`

---

## Criteri di valutazione (richiesti ai reviewer)
- **Puppet**
  - PASS se: master/CA identificati; `environmentpath` coerente; elenco ambienti consistente con Foreman; almeno 2 host (≥2 siti) con `agent --noop` riuscito e **report ricevuto** in Foreman (timestamp recente).
- **REX/Ansible**
  - PASS se: topologia esplicitata (REX vs Control Node Ansible vs HYBRID) **e** 2 smoke-test riusciti (MXP e VA) con output salvato.
- **Patching Windows**
  - PASS se: motore effettivo dichiarato (WSUS/SCCM/Chocolatey/winget) **e** presente un artefatto esecutivo con output di una run reale recente.

---

## Richiesta di review (formato vincolato)
> I reviewer devono rispondere **esclusivamente** nel formato seguente:

```

=== REVIEW ===
Verdict: APPROVE | CHANGES_REQUESTED
Findings:

* [OK/ISSUE] <punto, citando file e riga>
  Mandatory changes (if any):
* <azione puntuale + file di prova richiesto>
  Optional improvements:
* <suggerimento non bloccante>

=== END ===

```

---

## Note / Vincoli
- **DNS waiver attivo (P0):** le evidenze P1 non richiedono risoluzione autoritativa ai fini funzionali. Ogni riferimento a FQDN segue lo stato corrente (waived) e sarà riallineato post-CR.
- **Sicurezza:** nessun segreto/credenziale è presente nei file di evidenza (policy “secrets scrub” attiva).

---

## Azione al GO (post-APPROVE)
- Impostare `GATE_STATE.json → APPROVED` e taggare `gate-P1-approved`.
- Aprire **P2 — To-Be Design (Tassonomia/CV/LE/Proxy roles)** basata sugli esiti P1.
