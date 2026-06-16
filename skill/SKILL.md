---
name: agentforce-agent-library
description: >
  Use when someone wants to install, run, demo, or customize the free Agentforce Agent Library in
  their own Salesforce org — a set of ready-made, tested Agentforce agents (Field Service Scheduler,
  Service Appointment Closer, Knowledge Concierge, Order/Commerce Concierge, Case Service Agent).
  Trigger when the user says things like "install the free agents", "set up the Agentforce library",
  "add a field service scheduling agent", "give me a working order/case/knowledge agent", or points at
  the agentforce-agent-library repo. License-aware: it installs only the agents the target org supports.
---

# Agentforce Agent Library — install & customize

This skill installs a library of free, working Agentforce agents into any Salesforce org, choosing only
the agents the org's licenses/objects support. Everything is real Apex + Agent Script with tests and
anti-hallucination guardrails.

## What's in the library

Read `agents.json` (the catalog) for the live list. As of writing:

| id | agent | needs (objects) |
|---|---|---|
| `field-service-scheduler` | Order → Work Order + appointment, offers slots, books | Field Service + Order |
| `service-appointment-closer` | Completes appointment + Work Order + notes | Field Service |
| `knowledge-concierge` | Answers only from published Knowledge articles | Lightning Knowledge (`*__kav`) |
| `order-concierge` | Order status lookup + reorder | Order Management / Commerce |
| `case-service-agent` | Open + resolve/close cases | Service Cloud (Case) |

## Install (do this)

1. **Confirm prerequisites**: `sf` CLI and `python3` installed; the org authenticated
   (`sf org login web --alias <org>`); Agentforce enabled in the org (Setup → Einstein/Agents).
2. **Detect what the org supports** (always show this first):
   ```bash
   python3 scripts/detect-capabilities.py <org>
   ```
   It prints which agents are ELIGIBLE and which are skipped (and why — a missing object).
3. **Install the eligible agents**:
   ```bash
   ./scripts/install.sh <org>
   ```
   This deploys each eligible agent's Apex + fields, assigns its permission set, publishes + activates
   the agent, and seeds demo data.
4. **Try one**:
   ```bash
   sf agent preview --api-name Field_Service_Scheduler --target-org <org>
   ```
   or Setup → Agents → pick the agent → Preview.

### Key gotchas (so you don't get stuck)
- **Agent bundles are NOT deployable via `project deploy`** ("Not available for deploy for this API
  version"). They publish via `sf agent publish authoring-bundle --api-name <Name>` (the installer does
  this). API version must be **≥ 64**.
- **`sf agent publish` leaves the agent INACTIVE.** You must `sf agent activate --api-name <Name>` (the
  installer does this too).
- **`KnowledgeArticleVersion` existing ≠ Knowledge usable.** It isn't a supported static Apex type
  unless Lightning Knowledge is fully on; the Knowledge agent uses dynamic SOSL (`Search.query`) so it
  compiles everywhere and degrades gracefully. The installer gates it on a real `*__kav` article type.
- **A polluted org can block tests** (e.g. a record-triggered flow on Order/Case insert). The library's
  tests pass in a clean org; the installer deploys with `NoTestRun` so existing org automation can't
  block installation.

## Customize (when asked)

- Field Service territories/hours/technician/skills/products → CONFIG block atop
  `scripts/apex/seed_field_service.apex`; re-run it.
- Scheduling rules → constants in `FieldServiceSchedulingService.cls`.
- Agent wording/guardrails → the `.agent` files under `force-app/main/default/aiAuthoringBundles/`,
  then re-publish that bundle.
- **Add a new agent** → follow the pattern: Apex service (idempotent, returns a result struct) → one
  `@InvocableMethod` wrapper per action → `.agent` bundle (router + subagents + anti-hallucination
  rule) → Apex test → permission set → add an entry to `agents.json` with its `requiredObjects`. The
  detector and installer pick it up automatically.

## Uninstall / inspect
- See active agents: Setup → Agents.
- The agents are standard Bot metadata; remove via Setup or `sf project delete source`.
