# Gate P1 — Risk Register

Registro rischi specifico del Gate **P1 (As-Is Disambiguation)**.  
Formato: YAML-like per leggibilità, uno per blocco. Stati ammessi: `Open | Mitigating | Accepted | Closed`.

---

- id: R-P1-PUPPET-STATE
  title: Stato Puppet ambiguo (master/env/report)
  desc: |
    La presenza della colonna "Puppet env" in Foreman suggerisce un uso legacy di Puppet,
    ma non è certo lo stato effettivo di master, CA, environmentpath e flusso dei report agent→Foreman.
  impact: Medium
  likelihood: Medium
  owner: Infra | CM
  status: Open
  mitigation: |
    Eseguire raccolta probatoria:
    - `puppet config print` (master, environmentpath)
    - `puppetserver ca summary`
    - `hammer puppet-env list`
    - `puppet agent -t --noop` su host campione in ≥2 siti + verifica report in Foreman
  evidence_expect: 
    - EVIDENCE/puppet/puppet_master_info.txt
    - EVIDENCE/puppet/puppet_envs.txt
    - EVIDENCE/puppet/agent_status_SAMPLE.tsv
    - EVIDENCE/puppet/reports_last.tsv

---

- id: R-P1-REX-TOPOLOGY
  title: Topologia REX/Ansible non definita (dinamica vs control node esterno)
  desc: |
    Non è chiaro se Foreman esegua job via Remote Execution/dynflow/ansible-runner
    o se esista un control node Ansible esterno con Foreman come dynamic inventory.
  impact: Medium
  likelihood: Medium
  owner: Infra | Automation
  status: Open
  mitigation: |
    Dichiarare il modello operativo (REX | ANSIBLE_CONTROL_NODE | HYBRID) e provarlo:
    - elenco capsule REX
    - 2 smoke-test (MXP, VA) con output salvato
    - dump configurazione Ansible (versione, inventory, callback)
  evidence_expect:
    - EVIDENCE/rex/rex_capsules.txt
    - EVIDENCE/rex/rex_smoketest_MXP.txt
    - EVIDENCE/rex/rex_smoketest_VA.txt
    - EVIDENCE/ansible/ansible_topology.txt

---

- id: R-P1-WIN-PATCH-MODEL
  title: Modello patching Windows non provato (WSUS/SCCM/Chocolatey/winget)
  desc: |
    È dichiarato “patching centralizzato Windows”, ma manca la prova del motore effettivo
    e del flusso di orchestrazione (Foreman/REX/Ansible o GPO/SCCM).
  impact: High
  likelihood: Medium
  owner: Workplace | Infra
  status: Open
  mitigation: |
    Documentare il modello e fornire un artefatto esecutivo + output recente di una run.
    In caso WSUS, includere estratto GPO rilevante.
  evidence_expect:
    - EVIDENCE/winpatch/model.md
    - EVIDENCE/winpatch/job_evidence.txt
    - EVIDENCE/winpatch/wsus_gpo.txt

---

- id: R-P1-DNS-DEPENDENCY
  title: Dipendenza da waiver DNS (P0) per la validazione dei nomi
  desc: |
    La validazione piena dei nomi (CN/SAN) e dei riferimenti host può essere condizionata
    dal waiver DNS ancora attivo (A/PTR non autoritativi in attesa di CR).
  impact: Medium
  likelihood: Medium
  owner: Infra | DNS
  status: Mitigating
  mitigation: |
    Continuare P1 con evidenze funzionali; pianificare re-run “strict” post-CR DNS per allineare
    riferimenti e certificati; collegare WAIVER_P0_DNS-001 e dns_drift.tsv.
  links:
    - ../P0_DNS_PKI_NET/WAIVER_P0_DNS.md
    - ../P0_DNS_PKI_NET/EVIDENCE/dns_drift.tsv

---

- id: R-P1-CREDS-LEAK
  title: Esposizione accidentale di credenziali nei log di evidenza
  desc: |
    Comandi Ansible/REX o dump config potrebbero includere segreti/token.
  impact: High
  likelihood: Low
  owner: All contributors
  status: Open
  mitigation: |
    Policy “secrets scrub”: revisione manuale prima del commit; evitare `-vvv` non necessario;
    usare filtri/mascheramento; rimuovere output sensibile; `.gitignore` per file a rischio.
  controls:
    - Pre-commit review
    - Mascheramento nei file *evidence*

---

- id: R-P1-SCOPE-CREEP
  title: Estensione non controllata dell’ambito durante l’As-Is
  desc: |
    Rischio di introdurre remediation non richieste o nuove feature mentre si mappa l’esistente,
    invalidando la natura probatoria del gate.
  impact: Medium
  likelihood: Medium
  owner: Gate Lead (Alberto)
  status: Open
  mitigation: |
    Applicare strictly il protocollo a gate: nessuna modifica di configurazione non necessaria
    durante P1. Le remediation vanno pianificate in gate successivi.
  governance:
    - DECISION_LOG.md (append-only)
    - SUBMISSION.md con “out of scope” esplicito

