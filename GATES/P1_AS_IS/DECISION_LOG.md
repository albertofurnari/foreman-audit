# Gate P1 — Decision Log (Append-Only)

Registro decisionale **append-only** per il Gate P1 (As-Is Disambiguation).
Ogni voce deve essere tracciata con ID univoco, timestamp ISO-8601, autore, stato ed evidenze.

---

## Convezioni ID
- **D-P1-NNNN** — Decisione (policy, esito gate, scelta architetturale)
- **A-P1-NNNN** — Azione/Task (operativo, da eseguire)
- **R-P1-NNNN** — Remediation (correzione su evidenza/fallimento)

**Stati ammessi:** `Proposed | Approved | Rejected | InProgress | Done | Deferred`.

---

## Template (copia/incolla)
```yaml
- id: <D|A|R>-P1-XXXX
  when: 2025-11-12T00:00:00+01:00
  who: itmxvlpforaio01   # esecutore/autore
  title: "<titolo sintetico>"
  desc: |
    <descrizione operativa o decisionale>
  evidence:
    - EVIDENCE/<path>
  status: Proposed
  notes: []
````

---

## Log

### Inizializzazione

```yaml
- id: D-P1-0001
  when: 2025-11-12T00:00:00+01:00
  who: itmxvlpforaio01
  title: "Avvio Gate P1 con dipendenza da P0 (waiver DNS ammesso)"
  desc: |
    Si conferma l’avvio del Gate P1. Il Gate P0 è approvato con waiver P0-DNS-001;
    la raccolta P1 procede, mantenendo il monitor DNS drift attivo.
  evidence:
    - ../P0_DNS_PKI_NET/WAIVER_P0_DNS.md
    - ../P0_DNS_PKI_NET/EVIDENCE/dns_drift.tsv
  status: Approved
  notes: []
```

### Selezione host campione (da valorizzare)

```yaml
- id: A-P1-0001
  when: 2025-11-12T00:00:00+01:00
  who: itmxvlpforaio01
  title: "Selezione host campione per siti MXP e VA (Puppet/REX/Windows)"
  desc: |
    Definire almeno:
    - 1 host Linux MXP e 1 host Linux VA per test Puppet (agent --noop + report in Foreman).
    - 1 host (qualsiasi OS) MXP e 1 host VA per smoke-test REX/Ansible (uptime/ping).
    - 1 host Windows per validare il motore di patching reale (WSUS/SCCM/Chocolatey/winget).
    Aggiornare `SUMMARY.yaml.context.targets.*`.
  evidence:
    - SUMMARY.yaml
  status: Proposed
  notes: []
```

### Verifica Puppet — master/env/reports

```yaml
- id: A-P1-0002
  when: 2025-11-12T00:00:00+01:00
  who: itmxvlpforaio01
  title: "Raccolta evidenze Puppet (master, environmentpath, env, report)"
  desc: |
    Eseguire `collect_p1.sh` (sezione Puppet):
    - master/CA: puppet config print; puppetserver ca summary
    - env: hammer puppet-env list; environmentpath
    - agent --noop su host campione MXP e VA; confermare ricezione report in Foreman
  evidence:
    - EVIDENCE/puppet/puppet_master_info.txt
    - EVIDENCE/puppet/puppet_envs.txt
    - EVIDENCE/puppet/agent_status_SAMPLE.tsv
    - EVIDENCE/puppet/reports_last.tsv
  status: Proposed
  notes: []
```

### Topologia Ansible/REX — smoke multi-site

```yaml
- id: A-P1-0003
  when: 2025-11-12T00:00:00+01:00
  who: itmxvlpforaio01
  title: "Mappatura topologia Ansible/REX e smoke-test MXP/VA"
  desc: |
    Identificare modalità operativa (REX vs control node Ansible esterno vs ibrido).
    Eseguire 2 job “uptime/ping” (MXP e VA) e raccogliere output.
  evidence:
    - EVIDENCE/rex/rex_capsules.txt
    - EVIDENCE/rex/rex_smoketest_MXP.txt
    - EVIDENCE/rex/rex_smoketest_VA.txt
    - EVIDENCE/ansible/ansible_topology.txt
  status: Proposed
  notes: []
```

### Patching Windows — engine reale e prova esecuzione

```yaml
- id: A-P1-0004
  when: 2025-11-12T00:00:00+01:00
  who: itmxvlpforaio01
  title: "Identificazione motore patching Windows e prova esecuzione"
  desc: |
    Documentare il motore effettivo (WSUS/SCCM/Chocolatey/winget) e fornire un artefatto esecutivo
    (playbook/script/Job Template) con output di una run recente sull’host campione.
  evidence:
    - EVIDENCE/winpatch/model.md
    - EVIDENCE/winpatch/job_evidence.txt
    - EVIDENCE/winpatch/wsus_gpo.txt
  status: Proposed
  notes: []
```

### Chiusura Gate P1 (criteri)

```yaml
- id: D-P1-0002
  when: 2025-11-12T00:00:00+01:00
  who: itmxvlpforaio01
  title: "Criteri di PASS P1"
  desc: |
    PASS quando:
    - Puppet: master/environments coerenti + report ricevuti per ≥2 host in ≥2 siti.
    - REX/Ansible: job riuscito in MXP e VA, topologia dichiarata e provata.
    - Windows: engine dichiarato + prova di esecuzione (log/output) caricata.
    Altrimenti: CHANGES_REQUESTED con remediation puntuali.
  evidence: []
  status: Approved
  notes: []
