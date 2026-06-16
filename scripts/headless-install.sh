#!/usr/bin/env bash
#
# headless-install.sh — zero-click: create a scratch org, then run the license-aware install into it.
#
# ⚠️  Requires a Dev Hub (`sf org login web --set-default-dev-hub`) AND that your Dev Hub is entitled
#     to the features below (especially Agentforce/Einstein in scratch orgs, which is NOT guaranteed).
#     If scratch creation or `sf agent publish` fails, use a Developer/Trailhead org with Agentforce
#     enabled and run scripts/install.sh instead — that is the validated path.
#
# Usage:
#   ./scripts/headless-install.sh [alias]      # default alias: agentlib
#
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$HERE"
ALIAS="${1:-agentlib}"

command -v sf >/dev/null || { echo "ERROR: Salesforce CLI (sf) not found."; exit 1; }

echo "==> Creating scratch org '$ALIAS' (7 days)…"
sf org create scratch --definition-file config/project-scratch-def.json --alias "$ALIAS" \
  --duration-days 7 --set-default --wait 20

echo "==> Running the license-aware install into '$ALIAS'…"
bash scripts/install.sh "$ALIAS"

echo
echo "Scratch org '$ALIAS' is ready. Open it with:  sf org open --target-org $ALIAS"
