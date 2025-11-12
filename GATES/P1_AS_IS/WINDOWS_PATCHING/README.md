# Windows Patching — Evidence Playbook (P1)

## Scopo
Stabilire **in modo probatorio**:
- Qual è il **motore reale** di patching Windows: `WSUS` · `SCCM` · `Chocolatey` · `winget` · (altro).
- **Come** viene orchestrato: `Foreman REX` · `Ansible` · `GPO` · `SCCM` · (altro).
- Produrre **evidenze di esecuzione** (log/output) su almeno **1 host campione** per **2 siti**.

> Output: file in `EVIDENCE/winpatch/` + riepilogo in `SUMMARY.yaml`.

---

## Evidenze attese (minimo)
Prodotte da `collect_p1.sh` (placeholders) e poi **riempite manualmente** con dati reali:

- `EVIDENCE/winpatch/model.md`  
  - Dichiarazione del modello operativo (Engine, Orchestrazione, Flusso).
- `EVIDENCE/winpatch/job_evidence.txt`  
  - Estratto **log/output** di una run reale (date/host/exit/result).
- `EVIDENCE/winpatch/wsus_gpo.txt`  *(se WSUS/GPO)*  
  - Parametri WUServer/WUStatusServer/Schedule.

*(Opzionale ma utile, se applicabile):*
- `EVIDENCE/winpatch/sccm_client.txt`
- `EVIDENCE/winpatch/choco_state.txt`
- `EVIDENCE/winpatch/winget_state.txt`

---

## Criteri di PASS/FAIL (sezione Windows del Gate P1)
- **PASS** se:
  - `model.md` specifica **Engine** e **Orchestrazione** *concrete*; **e**
  - `job_evidence.txt` contiene prova di una **run reale recente** (≤ 30 giorni), con esito chiaro su almeno **1 host** per **2 siti**.  
- **FAIL** se:
  - Solo descrizioni senza output/log, oppure evidenze non attribuibili (host/tempo/esito assenti).

---

## Raccolta evidenze — WSUS/GPO
> Eseguire su **host Windows campione** (MXP + VA). PowerShell **elevato**.

**Parametri chiave GPO/WSUS**
```powershell
# WSUS URLs (GPO)
Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' `
  -Name WUServer, WUStatusServer, TargetGroup, TargetGroupEnabled -ErrorAction SilentlyContinue

# AU schedule (GPO)
Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' `
  -Name UseWUServer, AUOptions, ScheduledInstallDay, ScheduledInstallTime -ErrorAction SilentlyContinue
````

**Stato Windows Update / cronologia**

```powershell
# Modulo standard (Windows 10/11)
Get-WindowsUpdateLog | Out-Null  # (solo se necessario; genera file su Desktop)
Get-Service wuauserv | Select Name,Status,StartType

# Se è installato PSWindowsUpdate (facoltativo):
Get-Module -ListAvailable PSWindowsUpdate | Select Name,Version
Get-WUHistory | Select Date, Title, Result | Select -First 20
```

**Salva in evidenza**

* Copia l’output rilevante in `EVIDENCE/winpatch/wsus_gpo.txt` e log salienti in `job_evidence.txt` (con **hostname** e **timestamp** in testa).

---

## Raccolta evidenze — SCCM (Microsoft Endpoint Configuration Manager)

> Su host Windows campione.

```powershell
# Presenza client SCCM
Get-CimInstance -Namespace root\ccm -ClassName SMS_Client | Select ClientId,ClientVersion

# Servizio agent
Get-Service CcmExec | Select Name,Status,StartType

# Log patching principale (estratti)
$logs = @(
  'C:\Windows\CCM\Logs\WUAHandler.log',
  'C:\Windows\CCM\Logs\UpdatesDeployment.log',
  'C:\Windows\CCM\Logs\UpdatesHandler.log'
)
foreach ($l in $logs) {
  if (Test-Path $l) {
    Write-Host "=== $l (last 60 lines) ==="
    Get-Content $l -Tail 60
  }
}
```

**Salva in evidenza**

* Colla l’output in `EVIDENCE/winpatch/sccm_client.txt` (includere host e data).
* Incolla estratti significativi (installazioni riuscite/fallite) in `job_evidence.txt`.

---

## Raccolta evidenze — Chocolatey / winget

> Su host Windows campione (se tali strumenti sono il “motore” operativo o parte del flusso).

**Chocolatey**

```powershell
choco -v
choco outdated | Select-Object -First 50
# Esempio di job reale (install/update):
# choco upgrade <package> -y --noop   # per simulazione sicura
```

**winget**

```powershell
winget --info
winget list | Select-Object -First 50
# Esempio (se usato per patching applicativo):
# winget upgrade --all --silent
```

**Salva in evidenza**

* `EVIDENCE/winpatch/choco_state.txt` e/o `EVIDENCE/winpatch/winget_state.txt`.
* Se esecuzione reale, inserire snippet in `job_evidence.txt` con **comando**, **esito**, **timestamp**.

---

## Orchestrazione — Foreman REX o Ansible

### A) Foreman Remote Execution (REX)

> Dalla **console Foreman** (Linux), usare `hammer` e allegare output.

```bash
# Verifica template e feature
hammer job-template list | egrep -i 'windows|update|patch'
hammer proxy info --name <proxy> | egrep -i 'Remote Execution|Ansible'

# Esecuzione smoke (esempio generico):
hammer job-invocation create \
  --feature "Run Command" \
  --command "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command \"Get-Service wuauserv | ft -a\"" \
  --search-query "name = <win-host-fqdn>"
```

**Salva in evidenza**

* Incolla output in `EVIDENCE/winpatch/job_evidence.txt` (indicando **Job ID**, **host**, **esito**).

### B) Ansible (control node o bastion)

> Se il patching avviene via Ansible, allegare **playbook** e **run reale**.

**Esempio playbook (Windows Update modulo `win_updates`)**

```yaml
# EVIDENCE/winpatch/playbook_win_updates_example.yml (se esiste)
- name: Apply Windows updates
  hosts: windows_mxp_va
  gather_facts: no
  vars:
    ansible_connection: winrm
    ansible_winrm_transport: ntlm
    ansible_winrm_server_cert_validation: ignore
  tasks:
    - name: Install applicable updates
      win_updates:
        category_names: ['CriticalUpdates','SecurityUpdates']
        reboot: yes
```

**Run di prova (estratto output)**

```bash
ansible-playbook playbook_win_updates_example.yml -i inventory.ini \
  | tee -a EVIDENCE/winpatch/job_evidence.txt
```

---

## Struttura suggerita per `job_evidence.txt`

```
=== WINDOWS PATCH RUN ===
host: <FQDN>
site: <MXP|VA|...>
when: <YYYY-MM-DD HH:MM:SS local>
engine: <WSUS|SCCM|Chocolatey|winget|Other>
orchestrated_by: <FOREMAN_REX|ANSIBLE|GPO|SCCM|Other>

--- OUTPUT (troncato a ~100 righe significative) ---
<log / stdout>
```

---

## Compilazione `model.md` (schema)

```markdown
# Windows Patching — Modello operativo

- Engine: WSUS | SCCM | Chocolatey | winget | Other (specificare)
- Orchestrazione: Foreman REX | Ansible | GPO | SCCM | Other
- Flusso:
  1) (es. GPO WSUS assegna server + schedule)
  2) (es. Ansible/REX lancia installazioni mensili)
  3) (es. reboot policy/maintenance window)
- Ambito OS: Windows 10/11; Server 2016/2019/2022
- Calendario: es. “Patch Tuesday + 7 giorni in DEV, +14 in PRD”
- Evidenze: collegamenti a `job_evidence.txt` e (se WSUS) `wsus_gpo.txt`
```

---

## Known Pitfalls

* **WSUS non autorevole** (DNS waiver P0): gli host puntano a nomi “temporanei”. Accetta per P1, ma pianifica `re-run` post-CR.
* **SCCM client non conforme**: `CcmExec` fermo, boundary incorrect → niente compliance.
* **WinRM/REX**: deleghe e credenziali errate → job Foreman/Ansible falliscono senza log utili.
* **Evidenze troppo verbose**: allegare estratti significativi (tagliare rumore), mantenere riferimenti temporali/host.

---

## Output desiderato per `SUMMARY.yaml`

```yaml
windows_patching:
  engine: "WSUS|SCCM|Chocolatey|winget|Other"
  orchestrated_by: "FOREMAN_REX|ANSIBLE|GPO|SCCM|Other"
  evidence: true|false
```

---

## Azioni successive (se FAIL)

* Nessuna prova di esecuzione → produrre una **run controllata** (maintenance window) su 1 host per 2 siti e raccogliere log.
* Modello non definito → compilare `model.md` con decisione chiara (engine/orchestrazione) prima di P2.
