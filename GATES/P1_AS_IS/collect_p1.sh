#!/usr/bin/env bash
# Gate P1 — As-Is Disambiguation: evidence collector
# Safe-by-default: read-only probes; no config changes.
set -euo pipefail

# =========[ CONFIGURAZIONE MINIMA DA VALORIZZARE ]=========
# Host campione per le prove (usa FQDN raggiungibili via SSH se vuoi eseguire puppet/uptime da remoto)
PUPPET_SAMPLE_HOSTS=("host-mxp01.example" "host-va01.example")   # <-- SOSTITUISCI
REX_MXP_HOST="host-mxp01.example"                                # <-- SOSTITUISCI (o lascia vuoto per saltare)
REX_VA_HOST="host-va01.example"                                  # <-- SOSTITUISCI (o lascia vuoto per saltare)

# (Opzionale) Bastion Ansible: se definito, i comandi ansible verranno eseguiti lì via SSH
ANSIBLE_BASTION_HOST=""                                          # es. "ansible-bastion.intra.cobra.it" | vuoto per tentare localmente
ANSIBLE_BASTION_USER=""                                          # es. "automation" | vuoto per usare l'utente corrente

# SSH flags "non-interattivi"
SSH_OPTS=(-o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=7 -o ServerAliveInterval=5)

# =========[ PATH ]=========
BASE="$(cd "$(dirname "$0")" && pwd)"
EVD="$BASE/EVIDENCE"
mkdir -p "$EVD"/{puppet,rex,ansible,winpatch}

ts() { date -Is; }
log() { echo "[$(ts)] $*"; }

# =========[ UTILS ]=========
have() { command -v "$1" >/dev/null 2>&1; }

ssh_run() {
  local target="$1"; shift
  if [[ -z "$target" ]]; then return 1; fi
  ssh "${SSH_OPTS[@]}" "${target}" "$@" 2>&1
}

# =========[ PUPPET ]=========
collect_puppet() {
  log "PUPPET: raccolta informazioni master/CA/env"
  {
    echo "=== puppet config ==="
    have puppet && puppet config print server || echo "puppet: comando non trovato"
    have puppet && (puppet config print environmentpath --section master || puppet config print environmentpath) || true
    echo
    echo "=== puppetserver status (se esiste) ==="
    systemctl status puppetserver 2>&1 | sed -n '1,40p' || true
    echo
    echo "=== puppetserver CA summary/list ==="
    (have puppetserver && puppetserver ca summary) 2>&1 || (have puppetserver && puppetserver ca list --all) 2>&1 || echo "puppetserver: non disponibile"
  } > "$EVD/puppet/puppet_master_info.txt"

  {
    echo "=== hammer environment list (preferito) ==="
    if have hammer; then
      (hammer environment list || hammer puppet-environment list) 2>&1
    else
      echo "hammer: comando non trovato"
    fi
    echo
    echo "=== environmentpath (da puppet config) ==="
    have puppet && (puppet config print environmentpath --section master || puppet config print environmentpath) || true
  } > "$EVD/puppet/puppet_envs.txt"

  log "PUPPET: agent --noop sugli host campione (se raggiungibili via SSH)"
  : > "$EVD/puppet/agent_status_SAMPLE.tsv"
  echo -e "host\treachable\tagent_exit\tlast_lines" >> "$EVD/puppet/agent_status_SAMPLE.tsv"
  for H in "${PUPPET_SAMPLE_HOSTS[@]}"; do
    [[ -z "$H" || "$H" == *"example"* ]] && { echo -e "$H\tSKIPPED\t-\tCONFIGURE_SAMPLE_HOSTS" >> "$EVD/puppet/agent_status_SAMPLE.tsv"; continue; }
    if ssh "${SSH_OPTS[@]}" "$H" "true" >/dev/null 2>&1; then
      OUT="$(ssh_run "$H" 'sudo puppet --version 2>/dev/null; sudo puppet agent -t --noop || true' | tail -n 5 | tr '\t' ' ' )"
      # tenta di catturare exit code separatamente (non affidabile con pipe; usiamo marker)
      EXIT_CODE=$(ssh_run "$H" 'sudo bash -lc "puppet agent -t --noop >/tmp/puppet_noop.out 2>&1; echo -n \$?; echo \"|\"; tail -n 5 /tmp/puppet_noop.out"' || true)
      # formato "RC|<last_lines>"
      RC="${EXIT_CODE%%|*}"
      LAST="${EXIT_CODE#*|}"
      echo -e "$H\tYES\t${RC:-NA}\t${LAST:-$OUT}" >> "$EVD/puppet/agent_status_SAMPLE.tsv"
    else
      echo -e "$H\tNO\t-\tUNREACHABLE" >> "$EVD/puppet/agent_status_SAMPLE.tsv"
    fi
  done

  log "PUPPET: ultimo report in Foreman (hammer host info -> Last report)"
  : > "$EVD/puppet/reports_last.tsv"
  echo -e "host\tlast_report\tenvironment" >> "$EVD/puppet/reports_last.tsv"
  if have hammer; then
    for H in "${PUPPET_SAMPLE_HOSTS[@]}"; do
      [[ -z "$H" || "$H" == *"example"* ]] && { echo -e "$H\tSKIPPED\t-" >> "$EVD/puppet/reports_last.tsv"; continue; }
      INFO="$(hammer host info --name "$H" 2>/dev/null || true)"
      LAST="$(grep -E 'Last report' <<<"$INFO" | sed 's/.*Last report:\s*//')"
      ENV="$(grep -E '^Environment:' <<<"$INFO" | sed 's/.*Environment:\s*//')"
      echo -e "$H\t${LAST:-N/A}\t${ENV:-N/A}" >> "$EVD/puppet/reports_last.tsv"
    done
  else
    echo -e "HAMMER_NOT_FOUND\tN/A\tN/A" >> "$EVD/puppet/reports_last.tsv"
  fi
}

# =========[ REX / ANSIBLE ]=========
collect_rex_ansible() {
  log "REX: elenco capsule e features"
  if have hammer; then
    {
      echo "=== hammer proxy list ==="
      hammer proxy list 2>&1
      echo
      echo "=== hammer proxy info (Features) ==="
      # Estrai nomi dal CSV (colonna 2) oppure fallback
      hammer --csv proxy list 2>/dev/null | awk -F, 'NR>1{print $2}' | while read -r P; do
        [[ -z "$P" ]] && continue
        echo "--- $P ---"
        hammer proxy info --name "$P" 2>&1 | sed -n '1,120p'
      done
    } > "$EVD/rex/rex_capsules.txt"
  else
    echo "hammer non trovato" > "$EVD/rex/rex_capsules.txt"
  fi

  if have hammer && hammer --help 2>&1 | grep -q "job-invocation"; then
    log "REX: smoke test MXP (uptime)"
    if [[ -n "${REX_MXP_HOST:-}" && "$REX_MXP_HOST" != *"example"* ]]; then
      hammer job-invocation create --feature "Run Command" --command "uptime" \
        --search-query "name = ${REX_MXP_HOST}" 2>&1 | tee "$EVD/rex/rex_smoketest_MXP.txt" || true
    else
      echo "REX_MXP_HOST non configurato" > "$EVD/rex/rex_smoketest_MXP.txt"
    fi

    log "REX: smoke test VA (uptime)"
    if [[ -n "${REX_VA_HOST:-}" && "$REX_VA_HOST" != *"example"* ]]; then
      hammer job-invocation create --feature "Run Command" --command "uptime" \
        --search-query "name = ${REX_VA_HOST}" 2>&1 | tee "$EVD/rex/rex_smoketest_VA.txt" || true
    else
      echo "REX_VA_HOST non configurato" > "$EVD/rex/rex_smoketest_VA.txt"
    fi
  else
    echo "Remote Execution non disponibile (hammer job-invocation assente)" > "$EVD/rex/rex_smoketest_MXP.txt"
    echo "Remote Execution non disponibile (hammer job-invocation assente)" > "$EVD/rex/rex_smoketest_VA.txt"
  fi

  log "ANSIBLE: topologia (locale o bastion)"
  : > "$EVD/ansible/ansible_topology.txt"
  if [[ -n "${ANSIBLE_BASTION_HOST:-}" ]]; then
    TARGET="${ANSIBLE_BASTION_USER:+${ANSIBLE_BASTION_USER}@}${ANSIBLE_BASTION_HOST}"
    {
      echo "=== host: $TARGET ==="
      ssh_run "$TARGET" "ansible --version || true"
      echo
      ssh_run "$TARGET" "ansible-config dump 2>/dev/null | egrep 'INVENTORY|CALLBACK|HOST_KEY_CHECKING|DEFAULT_INVENTORY' || true"
      echo
      ssh_run "$TARGET" "test -f /etc/ansible/hosts && echo '--- /etc/ansible/hosts ---' && sed -n '1,120p' /etc/ansible/hosts || true"
      echo
      ssh_run "$TARGET" "ansible-inventory --list 2>/dev/null | head -n 80 || true"
    } >> "$EVD/ansible/ansible_topology.txt"
  else
    {
      echo "=== host: local ==="
      (ansible --version || true)
      echo
      (ansible-config dump 2>/dev/null | egrep 'INVENTORY|CALLBACK|HOST_KEY_CHECKING|DEFAULT_INVENTORY' || true)
      echo
      test -f /etc/ansible/hosts && { echo '--- /etc/ansible/hosts ---'; sed -n '1,120p' /etc/ansible/hosts; } || true
      echo
      (ansible-inventory --list 2>/dev/null | head -n 80 || true)
    } >> "$EVD/ansible/ansible_topology.txt"
  fi
}

# =========[ WINDOWS PATCHING ]=========
collect_windows_patching() {
  log "WINDOWS: modello e prove (placeholder se non disponibili)"
  # Se esistono file precompilati, non sovrascriverli
  if [[ ! -s "$EVD/winpatch/model.md" ]]; then
    cat > "$EVD/winpatch/model.md" <<'MD'
# Windows Patching — Modello operativo (da completare)
- Engine: WSUS | SCCM | Chocolatey | winget | Other (specificare)
- Orchestrazione: Foreman REX | Ansible | GPO | SCCM | Other
- Flusso:
  1) ...
  2) ...
- Ambito: versioni Windows (10/11/2016/2019/2022)
- Calendario: finestre, maintenance policy
- Evidenze attese: playbook/script/Job Template + output run
MD
  fi

  # Evidenza run (se già esistente non sovrascrivere)
  [[ -s "$EVD/winpatch/job_evidence.txt" ]] || echo "# Incolla qui output di una run reale (estratto log/CLI)" > "$EVD/winpatch/job_evidence.txt"
  # GPO/WSUS (opzionale)
  [[ -s "$EVD/winpatch/wsus_gpo.txt" ]] || echo "# Incolla qui export/impostazioni GPO rilevanti per WSUS (WUServer/WUStatusServer)" > "$EVD/winpatch/wsus_gpo.txt"
}

# =========[ MAIN ]=========
main() {
  log "== Gate P1: start collection =="
  collect_puppet
  collect_rex_ansible
  collect_windows_patching
  log "== Gate P1: collection complete =="
  log "Evidenze in: $EVD"
}

main "$@"

