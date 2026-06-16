# Agentforce Agent Library

**Free, open, genuinely-working Agentforce agents you can install in any Salesforce org in minutes.**

No demoware. Every agent here is real Apex + a real Agent Script bundle, with tests, idempotency,
anti-hallucination guardrails, and a one-command installer that **checks your org's licenses and
installs only the agents it can actually run.**

> Built to be the opposite of the slide-deck "AI strategy" — hands on the keyboard, working software,
> yours to keep and change.

---

## The agents

Three **kinds**: 🟢 customer-facing · 🔵 internal copilot · 🟣 headless/autonomous.

| Agent | Kind | What it does | Needs (objects) |
|---|---|---|---|
| **Field Service Scheduler** | 🟢 customer | Turns an Order for a serviceable product into a Work Order + appointment, offers real available time slots, and books the customer's choice. | Field Service (`WorkOrder`, `ServiceAppointment`, `ServiceTerritory`) + `Order` |
| **Service Appointment Closer** | 🔵 copilot | Marks an appointment Completed, rolls the Work Order to Completed, records completion notes (and a Service Report where available). | Field Service (`ServiceAppointment`, `WorkOrder`) |
| **Knowledge Concierge** | 🟢 customer | Answers questions **only** from your published Knowledge articles; deflects to a human when nothing matches. | Lightning Knowledge (a published `*__kav` article type) |
| **Order / Commerce Concierge** | 🟢 customer | Looks up an order by number, summarizes status + items, and reorders it on request. | Order Management / Commerce (`Order`, `OrderItem`) |
| **Case Service Agent** | 🔵 copilot | Opens support cases and resolves/closes them with a recorded resolution. | Service Cloud (`Case`) |
| **Sales Opportunity Coach** | 🔵 copilot | Summarizes an opportunity's health, recommends the next-best step, and records it (with a follow-up task) on request. | Sales (`Opportunity`, `Task`) |
| **Stale-Deal Sweeper** | 🟣 headless | Runs daily with no chat UI — finds open opportunities idle past a threshold, logs follow-up tasks, and sets a next step where blank. | Sales (`Opportunity`, `Task`) |
| **Account 360 Copilot** | 🔵 copilot | Read-only rep brief: open cases, open pipeline, recent orders, contacts. | Sales (`Account`, `Case`, `Opportunity`) |
| **Lead Qualifier** | 🟣 headless | Runs daily — scores open leads on completeness, stamps Rating (Hot/Warm/Cold), logs follow-ups for hot leads. | Sales (`Lead`, `Task`) |
| **Campaign Builder** | 🔵 copilot | Creates a campaign and adds recent leads/contacts as members (license-free stand-in for Data Cloud segmentation). | Marketing (`Campaign`, `CampaignMember`) |
| **Data Cloud Insights** | 🔵 copilot | Grounds the rep in a customer's unified Data Cloud profile by email (`ConnectApi.CdpQuery`); degrades gracefully until the DMO is configured. | Data Cloud license |

See [`docs/02-agent-roadmap.md`](docs/02-agent-roadmap.md) for the full ~25-agent roadmap (Sales, Service, Field Service, Commerce, Marketing, Ops) and [`docs/01-capability-inventory.md`](docs/01-capability-inventory.md) for how agents map to org licenses.

The installer **detects** which of these your org supports (by checking the backing objects exist —
not just the license name) and skips the rest with a clear message.

---

## Install (one command)

**Prerequisites (all free):**
- [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) (`sf`)
- `python3` (used by the capability detector)
- A Salesforce org with **Agentforce enabled** (Setup → Einstein/Agents). A free
  [Agentforce Developer Edition](https://www.salesforce.com/form/agentforce/developer-edition-signup/) works.

```bash
# 1. authenticate your org once
sf org login web --alias myorg

# 2. install everything your org's licenses allow
git clone https://github.com/OWNER/agentforce-agent-library
cd agentforce-agent-library
./scripts/install.sh myorg
```

The installer will, for **each eligible agent**: deploy its Apex + fields, assign its permission set,
publish + activate the agent, and seed demo data. Then try one:

```bash
sf agent preview --api-name Field_Service_Scheduler --target-org myorg
```
…or **Setup → Agents → (pick an agent) → Preview**.

### Fully headless (scratch org)
If you have a Dev Hub entitled to these features:
```bash
./scripts/headless-install.sh agentlib   # creates a scratch org, then installs into it
```
> ⚠️ Agentforce in *scratch* orgs depends on your Dev Hub entitlement and isn't guaranteed. The
> reliable path is an Agentforce-enabled Developer org + `scripts/install.sh`.

### Why not a one-click "Deploy to Salesforce" button?
Agent Script bundles (the agents themselves) are published with `sf agent publish`, which a metadata
button can't do. The Apex/fields/permission sets *could* deploy via a button, but the agents still
need the CLI step — so we ship one honest `install.sh` that does the whole thing.

---

## Customize it (it's yours)

- **Field Service config** (territories, hours, technician, skills, products): edit the CONFIG block at
  the top of [`scripts/apex/seed_field_service.apex`](scripts/apex/seed_field_service.apex) and re-run it.
- **Scheduling rules** (slot hours, days scanned, slot length): constants in
  [`FieldServiceSchedulingService.cls`](force-app/main/default/classes/FieldServiceSchedulingService.cls).
- **Agent behavior / tone / guardrails**: edit the `.agent` files in
  [`force-app/main/default/aiAuthoringBundles/`](force-app/main/default/aiAuthoringBundles), then
  `sf agent publish authoring-bundle --api-name <Name>`.
- **Add your own agent**: follow the pattern (Apex service → one `@InvocableMethod` wrapper per action
  → `.agent` bundle → test → permission set → entry in [`agents.json`](agents.json)). The installer
  picks it up automatically.

---

## How it's built (the pattern)

Each agent is the same shape — copy it to build your own:

1. **Apex service** — the brain (pure logic, idempotent, returns a result struct).
2. **Invocable action wrapper(s)** — one `@InvocableMethod` per class (Apex allows only one), each a thin
   adapter the agent calls.
3. **Agent Script bundle** (`.agent`) — router + subagents, with a mandatory **anti-hallucination** rule:
   never claim an action happened unless it was called this turn and returned success.
4. **Apex test** — real assertions; deploys green where the backing objects exist.
5. **Permission set** — class + field access.
6. **Catalog entry** in `agents.json` — declares the objects required (the install gate) + components.

[`agents.json`](agents.json) is the single source of truth; `scripts/detect-capabilities.py` reads it to
decide eligibility, and `scripts/install.sh` reads it to install.

---

## License

Free to use, copy, and modify. Provided as-is.
