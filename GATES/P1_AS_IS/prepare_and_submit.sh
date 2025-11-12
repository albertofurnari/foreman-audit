#!/usr/bin/env bash
# Gate P1 — orchestration helper:
# 1) collect evidence  2) verify & produce suggested summary
# 3) checksums + commit/push  4) open GitHub issue (SUBMITTED)

set -euo pipefail

GATE_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git -C "$GATE_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$REPO_ROOT" ] || { echo "Errore: eseguire dentro un repo git."; exit 1; }

cd "$GATE_DIR"

echo "== [P1] Step 1/4: Collect evidence =="
bash ./collect_p1.sh

echo
echo "== [P1] Step 2/4: Verify & suggested summary =="
bash ./verify_p1.sh

# Se è presente 'yq', proviamo ad applicare automaticamente i suggerimenti alla SUMMARY.yaml
if command -v yq >/dev/null 2>&1; then
  echo
  echo "== [P1] Applico suggerimenti a SUMMARY.yaml (best-effort con yq) =="
  SUG="$GATE_DIR/EVIDENCE/P1_SUGGESTED_SUMMARY.yaml"
  if [ -s "$SUG" ]; then
    # Merge "strategico": sovrascrive solo le chiavi note; lascia intatto il resto
    # NB: richiede yq v4+
    yq -y 'select(fileIndex == 0) * select(fileIndex == 1)' "$GATE_DIR/SUMMARY.yaml" "$SUG" > "$GATE_DIR/SUMMARY.yaml.tmp" || true
    if [ -s "$GATE_DIR/SUMMARY.yaml.tmp" ]; then
      mv "$GATE_DIR/SUMMARY.yaml.tmp" "$GATE_DIR/SUMMARY.yaml"
      echo "SUMMARY.yaml aggiornato da P1_SUGGESTED_SUMMARY.yaml"
    else
      echo "WARN: merge yq non applicato (output vuoto). Lasciato invariato SUMMARY.yaml."
      rm -f "$GATE_DIR/SUMMARY.yaml.tmp" 2>/dev/null || true
    fi
  else
    echo "Nessun P1_SUGGESTED_SUMMARY.yaml trovato; procedo senza merge."
  fi
else
  echo
  echo "== [P1] yq non trovato: lasciare SUMMARY.yaml invariato =="
  echo "Puoi copiare a mano i suggerimenti da: EVIDENCE/P1_SUGGESTED_SUMMARY.yaml"
fi

echo
echo "== [P1] Step 3/4: Checksums + commit/push =="
bash ./update_checksums.sh || true

cd "$REPO_ROOT"
git add GATES/P1_AS_IS
git commit -m "feat(P1): collect+verify evidence; update SUMMARY (if yq); checksums" || true
git push

echo
echo "== [P1] Step 4/4: Open GitHub Issue (state → SUBMITTED) =="
bash GATES/P1_AS_IS/open_issue.sh

echo
echo "Done. Rivedi l'Issue su GitHub per la doppia review."

