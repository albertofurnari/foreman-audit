# Ansible / Remote Execution — Evidence Playbook (P1)

## Scopo
Stabilire **in modo probatorio**:
- La **topologia operativa**:  
  - `REX` (Foreman/Smart Proxy con dynflow + ansible-runner),  
  - `ANSIBLE_CONTROL_NODE` (control node esterno con Foreman come *dynamic inventory*),  
  - `HYBRID` (co-esistenza).
- La **sorgente inventory**: `FOREMAN`, `STATIC` (`/etc/ansible/hosts` o simili) o `BOTH`.
- La **capacità esecutiva multi-sito** tramite due smoke-test (MXP e VA).

> Output: evidenze in `EVIDENCE/rex/` e `EVIDENCE/ansible/`, riepilogo in `SUMMARY.yaml`.

---

## Prerequisiti
- Accesso shell alla **console Foreman**.
- Se presente un **bastion Ansible** esterno, SSH verso tale host (variabili in `collect_p1.sh`: `ANSIBLE_BASTION_HOST`, `ANSIBLE_BASTION_USER`).
- **Nessuna modifica** di configurazione: comandi *read-only* o smoke-test a basso impatto (es. `uptime`, `ping`).

---

## Evidenze attese (file)
Prodotte da `collect_p1.sh`:

### REX (Foreman Remote Execution)
- `EVIDENCE/rex/rex_capsules.txt`  
  - `hammer proxy list` + `hammer proxy info --name <proxy>` (verifica *Features*: `Remote Execution`, `Ansible`, ecc.)
- `EVIDENCE/rex/rex_smoketest_MXP.txt`  
  - Esito job “Run Command: uptime” lanciato via `hammer job-invocation` su **host MXP**.
- `EVIDENCE/rex/rex_smoketest_VA.txt`  
  - Idem su **host VA**.

### Ansible (control node locale o bastion)
- `EVIDENCE/ansible/ansible_topology.txt`  
  - `ansible --version`  
  - `ansible-config dump | grep -E 'INVENTORY|CALLBACK|DEFAULT_INVENTORY|HOST_KEY_CHECKING'`  
  - Contenuto `(/etc/ansible/hosts)` se esiste  
  - Output `ansible-inventory --list` (troncato)

*(Opzionale per approfondire)*
- `EVIDENCE/ansible/ping_MXP.txt` — `ansible <group_or_host> -m ping` su target MXP  
- `EVIDENCE/ansible/ping_VA.txt` — idem per VA

---

## Criteri di PASS/FAIL (Gate P1 — sezione REX/Ansible)
- **PASS** se:
  - La **modalità** è esplicitata (`REX|ANSIBLE_CONTROL_NODE|HYBRID`) **e**
  - Si osserva **almeno 1 job riuscito** su host **MXP** e **1** su **VA**  
    *(via `hammer job-invocation` per REX o modulo `ping`/`command` per Ansible)*.
  - La **sorgente inventory** è dedotta da evidenze (`FOREMAN`, `STATIC`, o `BOTH`).
- **FAIL** se:
  - Mancano prove di esecuzione su **entrambi** i siti, oppure
  - `rex_capsules.txt` non mostra feature REX dove atteso e **nessun** canale alternativo è provato.

---

## Esecuzione manuale (se serve rifinire)

### 1) Ricognizione REX (da console Foreman)
```bash
hammer proxy list
hammer proxy info --name <proxy_name> | egrep -i 'Features|URL|Version|Status'
````

**Smoke-test REX**:

```bash
# MXP
hammer job-invocation create --feature "Run Command" \
  --command "uptime" --search-query "name = <host_mxp_fqdn>"

# VA
hammer job-invocation create --feature "Run Command" \
  --command "uptime" --search-query "name = <host_va_fqdn>"
```

> Evidenze: incolla gli output nei rispettivi file in `EVIDENCE/rex/`.

### 2) Ricognizione Ansible (locale **o** bastion)

**Locale (console Foreman):**

```bash
ansible --version || true
ansible-config dump | egrep 'INVENTORY|CALLBACK|DEFAULT_INVENTORY|HOST_KEY_CHECKING' || true
test -f /etc/ansible/hosts && sed -n '1,120p' /etc/ansible/hosts || true
ansible-inventory --list | head -n 80 || true
```

**Bastion esterno:**

```bash
ssh user@bastion 'ansible --version'
ssh user@bastion 'ansible-config dump | egrep "INVENTORY|CALLBACK|DEFAULT_INVENTORY|HOST_KEY_CHECKING"'
ssh user@bastion 'test -f /etc/ansible/hosts && sed -n "1,120p" /etc/ansible/hosts || true'
ssh user@bastion 'ansible-inventory --list | head -n 80 || true'
```

**Smoke-test modulo `ping` (se inventory disponibile):**

```bash
# Esempi: host esplicito o gruppo
ansible <host_mxp_or_group> -m ping
ansible <host_va_or_group>  -m ping
```

> Evidenze: salva l’output in `EVIDENCE/ansible/ping_MXP.txt` e `.../ping_VA.txt`.

---

## Interpretazione rapida

* `rex_capsules.txt` mostra **Remote Execution** attivo → **REX** disponibile.
* `ansible_topology.txt` con `foreman` nel path inventory/callback → inventory **FOREMAN**.
  Presenza di `/etc/ansible/hosts` con target → inventory **STATIC**. Entrambi → **BOTH**.
* Smoke-test con stringhe tipo `Job invocation created`, `exit status: 0`, `SUCCESS` → **OK**.
  Errori di chiave/SSH/host key checking → rivedere inventory e credenziali.

---

## Known pitfalls

* **REX bloccato**: porte 5647/22 o chiavi RE-X non distribuite agli host; capsule non associate al Location/Org corretti.
* **Inventory ambiguo**: gruppi duplicati o host non univoci tra FOREMAN e STATIC → esecuzioni imprevedibili.
* **Callback Ansible** non configurato: run eseguite ma **non** visibili in Foreman (se atteso).

---

## Output desiderato per `SUMMARY.yaml`

```yaml
rex_ansible:
  mode: "REX|ANSIBLE_CONTROL_NODE|HYBRID"
  inventory_source: "FOREMAN|STATIC|BOTH|UNKNOWN"
  mxp_job_ok: true|false
  va_job_ok: true|false
```

---

## Azioni successive (se FAIL)

* **REX non operativo**: distribuire chiave REX, verificare smart_proxy_dynflow, porte e trust; ripetere smoke-test.
* **Ansible senza inventory**: definire inventory coerente (FOREMAN plugin o statico), rimuovere duplicati; rieseguire `ping`.
* **HYBRID confuso**: documentare precedenze (quale inventory prevale) e segmentare per sito/gruppi.
