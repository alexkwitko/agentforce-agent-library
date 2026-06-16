#!/usr/bin/env bash
#
# install.sh — license-aware installer for the Agentforce Agent Library.
#
# It detects which agents your org can actually run (by checking that the backing objects exist),
# then for EACH eligible agent: deploys its metadata, assigns its permission set, publishes and
# activates its agent, and seeds demo data. Ineligible agents are skipped with a clear reason.
#
# Prereqs (all free):
#   • Salesforce CLI    https://developer.salesforce.com/tools/salesforcecli
#   • python3           (used by the capability detector)
#   • An org with Agentforce enabled (Setup → Einstein/Agents). Other features (Field Service,
#     Knowledge, etc.) are optional — agents needing them are simply skipped if absent.
#   • Authenticate once:   sf org login web --alias myorg
#
# Usage:
#   ./scripts/install.sh myorg     # org alias or username
#   ./scripts/install.sh           # uses your default target-org
#
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$HERE"

ORG_ARG="${1:-}"
ORG_FLAG=""
[[ -n "$ORG_ARG" ]] && ORG_FLAG="--target-org $ORG_ARG"

command -v sf >/dev/null || { echo "ERROR: Salesforce CLI (sf) not found."; exit 1; }
command -v python3 >/dev/null || { echo "ERROR: python3 not found (needed by the detector)."; exit 1; }

echo "============================================================"
echo " Agentforce Agent Library — license-aware install"
echo "============================================================"

# 1) Detect eligibility (prints a human table to your screen) and get the install plan.
python3 scripts/detect-capabilities.py $ORG_ARG >/dev/null   # show the table
PLAN="$(python3 scripts/detect-capabilities.py $ORG_ARG --plan)"

if [[ -z "$PLAN" ]]; then
  echo "No agents are installable in this org. Is Agentforce enabled and the org authenticated?"
  exit 1
fi

# 2) Install each eligible agent.
while IFS='|' read -r id bundle permset seed meta; do
  [[ -z "$id" ]] && continue
  echo
  echo ">>> Installing: $id"
  echo "    - deploying metadata"
  sf project deploy start $ORG_FLAG --metadata $meta --test-level NoTestRun --wait 30 >/dev/null

  if [[ -n "$permset" ]]; then
    echo "    - assigning permission set $permset"
    sf org assign permset --name "$permset" $ORG_FLAG >/dev/null 2>&1 || echo "      (already assigned)"
  fi

  echo "    - publishing agent $bundle"
  sf agent publish authoring-bundle --api-name "$bundle" $ORG_FLAG --skip-retrieve >/dev/null

  echo "    - activating agent"
  sf agent activate --api-name "$bundle" $ORG_FLAG >/dev/null 2>&1 \
    || echo "      (could not auto-activate — open Setup → Agents → $bundle → Activate)"

  if [[ -n "$seed" && -f "$seed" ]]; then
    echo "    - seeding demo data"
    sf apex run $ORG_FLAG -f "$seed" 2>/dev/null | grep -E "Number:|ID:|say:|Talk to" || true
  fi
  echo "    ✓ $id installed"
done <<< "$PLAN"

echo
echo "============================================================"
echo "✅  Done. Try an agent:"
echo "    sf agent preview --api-name <Bundle_Name> --target-org ${ORG_ARG:-<org>}"
echo "    (or Setup → Agents → pick an agent → Preview)"
echo "============================================================"
