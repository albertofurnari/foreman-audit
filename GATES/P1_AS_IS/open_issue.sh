#!/usr/bin/env bash
# Gate P1 — Apertura issue GitHub con submission e labeling
set -euo pipefail

BASE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$REPO_ROOT" ] || { echo "Errore: eseguire dentro il repo git."; exit 1; }
cd "$REPO_ROOT"

# ---- Config ----
SUBMIT_PATH="GATES/P1_AS_IS/SUBMISSION.md"
GATE_STATE_JSON="GATES/P1_AS_IS/GATE_STATE.json"
CHECKSUM_SCRIPT="GATES/P1_AS_IS/update_checksums.sh"
TITLE="[SUBMIT] Gate P1 — As-Is Disambiguation"
LABELS=("gate" "review")

# Deduci repo slug da 'origin' o usa variabile override
REPO_SLUG="${REPO_SLUG:-$(git remote get-url origin 2>/dev/null | sed -E 's#.*github.com[:/](.+/.+)(\.git)?#\1#;q')}"
[ -n "$REPO_SLUG" ] || { echo "Errore: impossibile dedurre REPO_SLUG. Esporta REPO_SLUG=owner/name"; exit 1; }

command -v gh >/dev/null 2>&1 || { echo "Errore: 'gh' non trovato. Installa GitHub CLI."; exit 1; }

# ---- Aggiorna stato gate a SUBMITTED ----
now_iso="$(date -Is)"
if command -v jq >/dev/null 2>&1; then
  tmp="$(mktemp)"
  jq --arg t "$now_iso" '.state="SUBMITTED" | .submitted_at=$t' "$GATE_STATE_JSON" > "$tmp" && mv "$tmp" "$GATE_STATE_JSON"
else
  # fallback sed (best effort)
  sed -i 's/"state": *"[^"]*"/"state": "SUBMITTED"/' "$GATE_STATE_JSON" || true
  sed -i "s/\"submitted_at\": *null/\"submitted_at\": \"${now_iso//\//-}\"/" "$GATE_STATE_JSON" || true
fi

# ---- Checksums e commit ----
if [ -x "$CHECKSUM_SCRIPT" ]; then
  "$CHECKSUM_SCRIPT" || true
fi

git add GATES/P1_AS_IS
git commit -m "chore(P1): submit gate (state→SUBMITTED) with evidence & checksums" || true
git push

# ---- Etichette assicurate ----
for L in "${LABELS[@]}"; do
  if ! gh label list --repo "$REPO_SLUG" --limit 200 | awk -F'\t' '{print $1}' | grep -qx "$L"; then
    gh label create "$L" --repo "$REPO_SLUG" --description "Gate workflow" || true
  fi
done

# ---- Creazione issue ----
gh issue create \
  --repo "$REPO_SLUG" \
  --title "$TITLE" \
  --body-file "$SUBMIT_PATH" \
  $(printf -- '--label %s ' "${LABELS[@]}")

echo "Issue creata per $REPO_SLUG: \"$TITLE\""

