# Puppet — Evidence Playbook (P1)

## Scopo
Raccogliere **evidenze probatorie** sullo stato Puppet:
- Master/CA attivi e punto di verità (`puppetserver`, CA summary).
- Percorso ambienti (`environmentpath`) e lista ambienti esposti a Foreman.
- Stato agent su host campione (MXP/VA) con run **--noop**.
- Ricezione report in Foreman per gli host campione.

---

## Prerequisiti
- Accesso shell alla **console Foreman**.
- SSH verso gli **host campione** definiti in `collect_p1.sh` (`PUPPET_SAMPLE_HOSTS`).
- `hammer` configurato sulla console (API Foreman funzionante).
- Nessuna modifica di config: le run sono **read-only** (`--noop`).

---

## Evidenze attese (file)
Prodotte da `collect_p1.sh`:

- `EVIDENCE/puppet/puppet_master_info.txt`  
  Contiene:
  - `puppet config print server`
  - `puppet config print environmentpath`
  - `systemctl status puppetserver` (se presente)
  - `puppetserver ca summary | list`

- `EVIDENCE/puppet/puppet_envs.txt`  
  Contiene:
  - `hammer environment list` (o `hammer puppet-environment list`)
  - `environmentpath` rilevato da `puppet config`

- `EVIDENCE/puppet/agent_status_SAMPLE.tsv`  
  Tabellare: `host  reachable  agent_exit  last_lines`  
  - `agent_exit`: 0=success, 2=changes (in noop significa che **applicherebbe** modifiche), altri=error/warn.

- `EVIDENCE/puppet/reports_last.tsv`  
  Tabellare: `host  last_report  environment` (estratto da `hammer host info`)

---

## Criteri di valutazione (P1 → PASS)
- **Master/CA** identificati (o assenza **esplicitamente** documentata).
- `environmentpath` coerente e **almeno** un ambiente riconosciuto in Foreman.
- Minimo **1 host** per **2 siti** con:
  - `puppet agent -t --noop` **raggiungibile** e **RC in {0,2}**.
  - **Last report** presente in Foreman (timestamp recente).

> Se l’infrastruttura è *agentless* o Puppet è *legacy dismesso*, documentarlo qui e nel `SUMMARY.yaml` (campo `present: false`) con motivazione.

---

## Esecuzione manuale (se serve rifinire)
> Di norma basta `collect_p1.sh`. Qui i comandi singoli “a vista”.

### Master/CA (da console Foreman)
```bash
puppet --version || true
puppet config print server || true
puppet config print environmentpath --section master || puppet config print environmentpath || true
systemctl status puppetserver | sed -n '1,60p' || true
puppetserver ca summary 2>/dev/null || puppetserver ca list --all 2>/dev/null || true
````

### Ambienti (da console Foreman)

```bash
hammer environment list 2>/dev/null || hammer puppet-environment list 2>/dev/null || true
```

### Agent (su host campione)

> Sostituisci `host.example` con i target; **noop** non applica modifiche.

```bash
ssh -o BatchMode=yes host.example 'sudo puppet --version 2>/dev/null; sudo puppet agent -t --noop || true'
```

### Report in Foreman (per host campione)

```bash
hammer host info --name host.example | egrep 'Last report|Environment'
```

---

## Interpretazione rapida

* **RC=0** in `--noop`: nessuna modifica prevista (catalog coerente).
* **RC=2** in `--noop`: il catalog applicherà modifiche (drift rilevato).
* Nessun `Last report` in Foreman:

  * Agent non configurato / non comunica / report processing KO.
  * Verificare `puppet.conf` (`server=`) e la **CA**.

---

## Known pitfalls

* Ambienti visualizzati in Foreman ma **non presenti** sull’`environmentpath` del master ⇒ ambienti **orfani** (FAIL).
* CA/Issuer incoerenti tra agent e master ⇒ esiti intermittenti o rifiuto report.
* DNS in waiver: usare FQDN **consistenti** con quelli attuali; post-CR rifare P1 check Puppet.

---

## Output desiderato per `SUMMARY.yaml`

```yaml
puppet:
  present: true|false
  master_fqdn: "<fqdn-master-o-smart-proxy>"
  environmentpath: "<path>"
  envs: ["MXP_DEV","MXP_PRD","VA_PRD"]
  reports_ok: true|false
```

---

## Azioni successive (se FAIL)

* **Master/CA mancanti:** definire piano di bonifica o rimozione completa (brownfield → greenfield).
* **Env orfani:** riallineo `environmentpath` vs Foreman (r10k/Code Manager) o pulizia ambienti in Foreman.
* **Report assenti:** debug connessione agent→master, trust CA, firewall, `reports`/`storeconfigs`.
