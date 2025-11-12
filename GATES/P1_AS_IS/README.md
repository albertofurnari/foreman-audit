# Gate P1 — As-Is Disambiguation

Obiettivo: fotografare **lo stato reale** di Puppet, Remote Execution/Ansible e Patching Windows con **evidenze probatorie**.  
Il gate passa **solo** se le evidenze soddisfano i criteri dichiarati.

---

## 1) Prerequisiti

- Console Foreman: `itmxvlpforaio01.it.cobra.group (192.168.8.130)`
- `git`, `hammer`, SSH funzionanti dalla console verso gli host campione
- DNS: **waiver P0** attivo (NSS override) documentato in `../P0_DNS_PKI_NET/`
- Nessuna modifica di configurazione: raccolta **read-only** (eccetto smoke-test a basso impatto)

---

## 2) Struttura cartella (principale)

```

GATES/P1_AS_IS/
├─ SUMMARY.yaml                 # scheda di stato del gate (compilata/manutenuta)
├─ GATE_STATE.json              # stato formale del gate (DRAFT/SUBMITTED/…)
├─ DECISION_LOG.md              # registro decisionale append-only
├─ RISKS.md                     # registro rischi
├─ SUBMISSION.md                # corpo della Issue per la doppia review
├─ collect_p1.sh                # raccolta evidenze (Puppet/REX+Ansible/Windows)
├─ verify_p1.sh                 # verifica ed estrazione SUGGESTED_SUMMARY
├─ update_checksums.sh          # generazione CHECKSUMS.txt
├─ open_issue.sh                # apertura issue GitHub “SUBMITTED”
├─ prepare_and_submit.sh        # orchestratore: collect → verify → push → issue
└─ EVIDENCE/
├─ puppet/
├─ rex/
├─ ansible/
└─ winpatch/

````

Guide pratiche:
- `PUPPET/README.md`
- `ANSIBLE/README.md`
- `WINDOWS_PATCHING/README.md`

---

## 3) Configurazione *minima* (host campione)

Modifica **una sola volta** in `collect_p1.sh`:

```bash
PUPPET_SAMPLE_HOSTS=("host-mxp01.fqdn" "host-va01.fqdn")
REX_MXP_HOST="host-mxp01.fqdn"
REX_VA_HOST="host-va01.fqdn"

# opzionale, se Ansible gira su un bastion separato
ANSIBLE_BASTION_HOST="ansible-bastion.fqdn"
ANSIBLE_BASTION_USER="automation"
````

Esempio veloce (con `sed`):

```bash
sed -i 's/host-mxp01.example/lin-mxp01.intra.cobra.it/' GATES/P1_AS_IS/collect_p1.sh
sed -i 's/host-va01.example/lin-va01.intra.cobra.it/'   GATES/P1_AS_IS/collect_p1.sh
```

> Nota: per Windows patching indicare gli host dentro i file di evidenza (`EVIDENCE/winpatch/*`).

---

## 4) Esecuzione standard (consigliata)

```bash
cd GATES/P1_AS_IS
bash prepare_and_submit.sh
```

Cosa fa:

1. **Collect**: genera file sotto `EVIDENCE/` (e placeholder per winpatch).
2. **Verify**: crea `EVIDENCE/P1_SUGGESTED_SUMMARY.yaml` e un `P1_REPORT.txt`.
3. **Apply (best-effort)**: se presente `yq`, fonde i suggerimenti in `SUMMARY.yaml`.
4. **Checksums + Commit/Push**
5. **Issue GitHub**: apre la review con stato `SUBMITTED`.

---

## 5) Esecuzione manuale (se preferisci a step)

```bash
cd GATES/P1_AS_IS

# 1) Raccolta
bash collect_p1.sh

# 2) Verifica e generazione suggerimenti
bash verify_p1.sh
# -> guarda EVIDENCE/P1_SUGGESTED_SUMMARY.yaml e EVIDENCE/P1_REPORT.txt
#    poi applica a mano sul SUMMARY.yaml (o usa yq)

# 3) Checksums + commit/push
bash update_checksums.sh
git add .
git commit -m "feat(P1): evidence + report + summary"
git push

# 4) Issue di submission
bash open_issue.sh
```

---

## 6) Criteri di **PASS** (riassunto operativo)

* **Puppet**

  * `present: true` (binari e/o master identificato)
  * `envs` coerenti (da hammer / environmentpath)
  * Almeno **1 host** MXP **e** **1 host** VA con:

    * `puppet agent -t --noop` reachable, **RC ∈ {0,2}**
    * `Last report` presente in Foreman
* **REX / Ansible**

  * `mode` esplicita: `REX | ANSIBLE_CONTROL_NODE | HYBRID`
  * `inventory_source`: `FOREMAN | STATIC | BOTH | UNKNOWN`
  * Smoke-test riuscito su **MXP** **e** **VA** (via `hammer job-invocation` o `ansible -m ping/command`)
* **Windows Patching**

  * `engine` e `orchestrated_by` **dichiarati**
  * `job_evidence.txt` con **run reale recente** (≤ 30 gg) su ≥ 1 host **per 2 siti**

Il verdetto proposto viene calcolato in `verify_p1.sh` e popola `P1_REPORT.txt`.

---

## 7) Sicurezza & igiene

* **No segreti** nelle evidenze. Se compaiono, redigere prima del commit.
* `.gitignore` filtra chiavi/cert noti; *non* filtra `EVIDENCE/` (cuore probatorio).
* Evitare output prolissi: mantenere **estratti significativi** con timestamp e host.

---

## 8) Troubleshooting rapido

* `hammer job-invocation` assente → plugin REX non installato/abilitato (o permessi).
* SSH verso host campione fallisce → controllare reachability/chiavi/utente.
* `puppet agent --noop` non parte → Puppet non installato/configurato sul target.
* Ansible “inventory vuoto” → definire plugin Foreman o `/etc/ansible/hosts`.

---

## 9) Sottomissione e doppia review

La Issue aperta richiede risposta **vincolata** nel formato:

```
=== REVIEW ===
Verdict: APPROVE | CHANGES_REQUESTED
Findings:
- [OK/ISSUE] <punto, citando file e riga>
Mandatory changes (if any):
- <azione puntuale + file di prova richiesto>
Optional improvements:
- <suggerimento non bloccante>
=== END ===
```

Al **GO**:

* Impostare `GATE_STATE.json → state: "APPROVED"`.
* Tag `gate-P1-approved`.
* Aprire gate **P2 — To-Be Design** (tassonomia, CV/LE, ruoli proxy).

---

## 10) Note su P0 (waiver DNS)

P1 procede con waiver DNS attivo. Tutti i riferimenti FQDN usano lo **stato corrente**; è previsto un re-run “strict” post-CR per riallineare CN/SAN, inventory e fonti contenuto.
