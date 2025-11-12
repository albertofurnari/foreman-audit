#!/usr/bin/env bash
# Gate P1 — Verifica evidenze e sintesi risultati
# Legge i file in EVIDENCE/ e produce P1_REPORT.txt + P1_SUGGESTED_SUMMARY.yaml
set -euo pipefail

BASE="$(cd "$(dirname "$0")" && pwd)"
EVD="$BASE/EVIDENCE"
OUT_REPORT="$EVD/P1_REPORT.txt"
OUT_SUMMARY="$EVD/P1_SUGGESTED_SUMMARY.yaml"

ts() { date -Is; }
ok() { echo "OK"; }
ko() { echo "FAIL"; }
have() { command -v "$1" >/dev/null 2>&1; }

_exists_nonempty() { [[ -s "$1" ]]; }

_line() { printf '%*s\n' "${1:-80}" '' | tr ' ' '-'; }

# -------- Puppet checks --------
check_puppet() {
  local master_info="$EVD/puppet/puppet_master_info.txt"
  local envs_file="$EVD/puppet/puppet_envs.txt"
  local agent_sample="$EVD/puppet/agent_status_SAMPLE.tsv"
  local reports="$EVD/puppet/reports_last.tsv"

  local PRESENT="false" MASTER_FQDN="" ENVPATH="" REPORTS_OK="false"
  local ENV_ARR=()

  if _exists_nonempty "$master_info"; then
    # puppet present?
    if ! grep -qi 'comando non trovato' "$master_info"; then
      PRESENT="true"
    fi
    # try to extract server and environmentpath
    MASTER_FQDN="$(grep -E '^\s*[^#]*puppet config|server\s*=' -n "$master_info" | sed -n 's/.*server\s*=\s*\(.*\)/\1/p' | head -1 | tr -d '[:space:]')"
  fi

  if _exists_nonempty "$envs_file"; then
    ENVPATH="$(sed -n 's|.*environmentpath.*:\s*||p' "$envs_file" | head -1 | tr -d '[:space:]')"
    # hammer environment list (greedy but practical)
    # expected lines like: "ID | NAME | ..."
    while IFS= read -r line; do
      # take the second column if delimited by '|', otherwise any token with letters+underscores
      if [[ "$line" == *"|"* ]]; then
        name="$(echo "$line" | awk -F'|' 'NF>=2 {print $2}' | tr -d '[:space:]')"
        [[ -n "$name" && "$name" != "Name" && "$name" != "NAME" ]] && ENV_ARR+=("$name")
      else
        # fallback: lines like MXP_DEV
        [[ "$line" =~ ^[A-Za-z0-9._-]+$ ]] && ENV_ARR+=("$line")
      fi
    done < <(grep -E '^\s*[A-Za-z0-9_.-]+\s*(\|.*)?$' "$envs_file" || true)
  fi

  if _exists_nonempty "$agent_sample" && _exists_nonempty "$reports"; then
    # success criteria: at least one reachable host with RC in {0,2} AND reports_last has non-empty Last report
    local good_agents=0
    while IFS=$'\t' read -r host reachable rc last; do
      [[ "$host" == "host" ]] && continue
      [[ "$reachable" != "YES" ]] && continue
      [[ "$rc" == "0" || "$rc" == "2" ]] && ((good_agents++))
    done < "$agent_sample"

    local good_reports=0
    while IFS=$'\t' read -r host last env; do
      [[ "$host" == "host" ]] && continue
      [[ -n "$last" && "$last" != "N/A" && "$last" != "SKIPPED" ]] && ((good_reports++))
    done < "$reports"

    if (( good_agents>=1 && good_reports>=1 )); then
      REPORTS_OK="true"
    fi
  fi

  # emit results
  echo "$PRESENT" "$MASTER_FQDN" "$ENVPATH" "$REPORTS_OK" "|" "${ENV_ARR[*]}"
}

# -------- REX / Ansible checks --------
check_rex_ansible() {
  local caps="$EVD/rex/rex_capsules.txt"
  local mxp="$EVD/rex/rex_smoketest_MXP.txt"
  local va="$EVD/rex/rex_smoketest_VA.txt"
  local topo="$EVD/ansible/ansible_topology.txt"

  local MODE="" INV_SRC="" MXP_OK="false" VA_OK="false"

  # crude heuristics for MODE & inventory source
  if _exists_nonempty "$caps" && grep -qi 'Remote Execution' "$caps"; then
    MODE="REX"
  fi
  if _exists_nonempty "$topo"; then
    grep -qi 'ansible --version' "$topo" && MODE="${MODE:-ANSIBLE_CONTROL_NODE}"
    if grep -qi 'foreman' "$topo" || grep -qi 'Foreman inventory' "$topo"; then
      INV_SRC="FOREMAN"
    elif grep -qi '/etc/ansible/hosts' "$topo"; then
      INV_SRC="${INV_SRC:+$INV_SRC|}STATIC"
    fi
    [[ -z "$INV_SRC" ]] && INV_SRC="UNKNOWN"
    [[ "$MODE" == "" && "$INV_SRC" != "UNKNOWN" ]] && MODE="HYBRID"
  fi

  # smoke success if file contains typical success markers or lacks obvious errors
  if _exists_nonempty "$mxp"; then
    if grep -qiE 'Job invocation created|exit status: 0|succeeded|success' "$mxp"; then MXP_OK="true"; fi
  fi
  if _exists_nonempty "$va"; then
    if grep -qiE 'Job invocation created|exit status: 0|succeeded|success' "$va"; then VA_OK="true"; fi
  fi

  echo "$MODE" "$INV_SRC" "$MXP_OK" "$VA_OK"
}

# -------- Windows patching checks --------
check_winpatch() {
  local model="$EVD/winpatch/model.md"
  local job="$EVD/winpatch/job_evidence.txt"

  local ENGINE="" ORCH="" EVIDENCE="false"
  if _exists_nonempty "$model"; then
    # extract Engine/Orchestrazione if provided
    ENGINE="$(grep -E '^- +Engine:' "$model" | sed 's/^- \+Engine:\s*//;s/\r$//' | head -1)"
    ORCH="$(grep -E '^- +Orchestrazione:' "$model" | sed 's/^- \+Orchestrazione:\s*//;s/\r$//' | head -1)"
  fi
  if _exists_nonempty "$job"; then
    # consider evidence only if not the placeholder line
    if ! head -1 "$job" | grep -q 'Incolla qui'; then
      EVIDENCE="true"
    fi
  fi
  echo "$ENGINE" "$ORCH" "$EVIDENCE"
}

# -------- Main verify --------
main() {
  mkdir -p "$EVD"
  : > "$OUT_REPORT"

  echo "[${PWD}] Gate P1 — Verifica evidenze" | tee -a "$OUT_REPORT"
  _line 80 | tee -a "$OUT_REPORT"

  # Puppet
  read -r P_PRESENT P_MASTER P_ENVPATH P_REPORTS _ SEP_ENVS <<<"$(check_puppet)"
  ENVS="${SEP_ENVS:-}"
  P_ASSERT=$([ "$P_PRESENT" == "true" ] && [ "$P_REPORTS" == "true" ] && [[ -n "$ENVS" ]] && ok || ko)

  {
    echo "PUPPET:"
    echo "  present.............: $P_PRESENT"
    echo "  master_fqdn.........: ${P_MASTER:-N/A}"
    echo "  environmentpath.....: ${P_ENVPATH:-N/A}"
    echo "  envs_detected.......: ${ENVS:-[]}"
    echo "  reports_ok..........: $P_REPORTS"
    echo "  ASSERTION...........: puppet_active_and_reporting = $P_ASSERT"
  } | tee -a "$OUT_REPORT"

  _line 80 | tee -a "$OUT_REPORT"

  # REX/Ansible
  read -r R_MODE R_INV R_MXP_OK R_VA_OK <<<"$(check_rex_ansible)"
  R_ASSERT=$([ "${R_MXP_OK,,}" == "true" ] && [ "${R_VA_OK,,}" == "true" ] && ok || ko)

  {
    echo "REX / ANSIBLE:"
    echo "  mode................: ${R_MODE:-UNKNOWN}"
    echo "  inventory_source....: ${R_INV:-UNKNOWN}"
    echo "  mxp_job_ok..........: ${R_MXP_OK}"
    echo "  va_job_ok...........: ${R_VA_OK}"
    echo "  ASSERTION...........: rex_multi_site_exec_ok = $R_ASSERT"
  } | tee -a "$OUT_REPORT"

  _line 80 | tee -a "$OUT_REPORT"

  # Windows patching
  read -r W_ENG W_ORCH W_EVID <<<"$(check_winpatch)"
  W_ASSERT=$([ "${W_EVID,,}" == "true" ] && [[ -n "$W_ENG" ]] && ok || ko)

  {
    echo "WINDOWS PATCHING:"
    echo "  engine..............: ${W_ENG:-N/A}"
    echo "  orchestrated_by.....: ${W_ORCH:-N/A}"
    echo "  evidence_present....: ${W_EVID}"
    echo "  ASSERTION...........: windows_engine_proven = $W_ASSERT"
  } | tee -a "$OUT_REPORT"

  _line 80 | tee -a "$OUT_REPORT"

  # Gate verdict suggestion
  local verdict="REVIEW"
  if [[ "$P_ASSERT" == "OK" && "$R_ASSERT" == "OK" && "$W_ASSERT" == "OK" ]]; then
    verdict="PASS"
  fi

  {
    echo "GATE VERDICT (suggested): $verdict"
    echo
    echo "Suggested SUMMARY.yaml patch:"
    echo "--------------------------------"
    echo "puppet:"
    echo "  present: $P_PRESENT"
    echo "  master_fqdn: \"${P_MASTER:-}\""
    echo "  environmentpath: \"${P_ENVPATH:-}\""
    # print envs as YAML array
    if [[ -n "$ENVS" ]]; then
      # split by spaces
      IFS=' ' read -r -a env_arr <<< "$ENVS"
      printf "  envs: ["
      local first=1
      for e in "${env_arr[@]}"; do
        [[ -z "$e" ]] && continue
        if [[ $first -eq 1 ]]; then printf "\"%s\"" "$e"; first=0; else printf ", \"%s\"" "$e"; fi
      done
      echo "]"
    else
      echo "  envs: []"
    fi
    echo "  reports_ok: $P_REPORTS"
    echo
    echo "rex_ansible:"
    echo "  mode: \"${R_MODE:-}\""
    echo "  inventory_source: \"${R_INV:-}\""
    echo "  mxp_job_ok: ${R_MXP_OK}"
    echo "  va_job_ok: ${R_VA_OK}"
    echo
    echo "windows_patching:"
    echo "  engine: \"${W_ENG:-}\""
    echo "  orchestrated_by: \"${W_ORCH:-}\""
    echo "  evidence: ${W_EVID}"
    echo
    echo "assertions:"
    echo "  puppet_active_and_reporting: $([ "$P_ASSERT" == "OK" ] && echo true || echo false)"
    echo "  rex_multi_site_exec_ok: $([ "$R_ASSERT" == "OK" ] && echo true || echo false)"
    echo "  windows_engine_proven: $([ "$W_ASSERT" == "OK" ] && echo true || echo false)"
    echo
    echo "gate_verdict: \"$verdict\""
  } | tee "$OUT_SUMMARY" >/dev/null

  echo
  echo "Wrote: $OUT_REPORT"
  echo "Wrote: $OUT_SUMMARY"
}

main "$@"

