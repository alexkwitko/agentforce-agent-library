# Cloud Setup Guide — enable the clouds before installing agents

**Agents don't work without their cloud turned on.** This guide lists, per cloud, exactly what to enable,
where, whether it's scriptable or a one-time UI step, and which library agents depend on it. The
installer's detector (`scripts/detect-capabilities.py`) checks *objects*, so an agent is simply skipped
until its cloud is on — enable the cloud, re-run the installer, and the agent appears.

Legend: 🟩 scriptable (CLI/metadata) · 🟦 one-time UI toggle (no API) · 💲 paid add-on / managed package.

---

## 1. Agentforce (required for every agent)
- 🟦 **Setup → Einstein Setup → turn on Einstein.**
- 🟦 **Setup → Agents → enable Agentforce** (and **Agentforce Default/Employee Agent** for copilots; **Agentforce Service Agent** for customer chat).
- 🟦 For customer agents: **Setup → Messaging → Messaging for Web (MIAW)** deployment + an Embedded Service deployment.
- 🟩 Library handles publish/activate: `sf agent publish authoring-bundle` then `sf agent activate`.
- **Enables:** all 8 agents. Employee agents run as the logged-in user; service agents need a channel.

## 2. Data Cloud / Data 360 (CI, Unified Profile, Identity Resolution, predictions, RAG)
- 🟦 **Setup → Data Cloud Setup → Enable Data Cloud** (provisions ~24h on first enable).
- 🟦 **Data streams / DLOs:** create streams (CRM connector, Ingestion API, web SDK) → **DLO** (`__dll`).
- 🟩/🟦 **DMOs + mappings** (`ObjectSourceTargetMap`) — some deployable via Connect API/metadata; new CRM streams often UI-gated.
- 🟦 **Identity Resolution** ruleset (match rules on email/phone/**device**/loyalty id) — first run ~24h, reprocess daily. Add **device id** as a match key so agents recognize pre-login browsers.
- 🟦 **Calculated Insights** (`__cio`) — SQL aggregates (LTV, RFM, propensity).
- 🟦 **Predictions** — Einstein Studio Model Builder / BYOM → **Prediction Job** writes a score DMO.
- 🟦 **RAG** — Data Library + **Retriever** (Einstein Studio); reference `{!$EinsteinSearch:<retriever>.results}` in a prompt template.
- **Agent bridge (in code):** `@InvocableMethod` running `ConnectApi.CdpQuery.queryAnsiSqlV2` / `queryCalculatedInsights('X__cio')` / `queryProfileApi`, or static SOQL on `__dlm`/`__cio` (Spring '25+).
- **Enables (Phase 2):** Data-Cloud-grounded Account 360, Service Concierge (RAG), Win-back headless, Personal Shopper reco.

## 3. Field Service
- 🟦 **Setup → Field Service Settings → Enable Field Service.**
- 💲 **Install the Field Service managed package** (adds `ServiceReport`, dispatcher console, optimization).
- 🟩 Library seeds territory/operating-hours/resource/skill via `scripts/apex/seed_field_service.apex` (editable CONFIG block).
- **Enables:** Field Service Scheduler, Service Appointment Closer. (ServiceReport creation in the Closer is gated on the managed package — degrades gracefully.)

## 4. Salesforce Scheduler
- 🟦 **Setup → Salesforce Scheduler → enable**; add to a permission set; configure work-type-groups/territories for native appointment slots.
- The library's scheduler uses a **portable slot engine** (no Scheduler config required); swap in Scheduler's `getAppointmentSlots` for production.

## 5. Commerce (D2C + B2B)
- 🟦 **Setup → Commerce → enable D2C/B2B**; create a **WebStore** + **ProductCatalog**/**ProductCategory** on an LWR Experience site.
- 🟩 Products/catalog/pricebook seedable via Apex/CLI; the storefront site itself is UI-built (Experience Builder).
- **Enables:** Order/Commerce Concierge (works on standard `Order` today); Personal Shopper (Phase 3) needs `WebStore`/`WebCart`.

## 6. Order Management
- 🟦 **Setup → Order Management → enable** (for `OrderSummary`, fulfillment flows). Standard `Order`/`OrderItem` work without full OM.
- **Enables:** Order Concierge, Returns/RMA (uses standard `ReturnOrder`).

## 7. Sales Cloud
- 🟩 Standard `Lead`/`Opportunity`/`Campaign`/`Task` are on by default in most editions.
- 🟦 Collaborative Forecasting (for a Forecasting agent) is a Setup toggle.
- **Enables:** Sales Opportunity Coach, Account 360, Stale-Deal Sweeper, Lead Qualifier.

## 8. Service Cloud + Knowledge
- 🟩 Standard `Case`/`Entitlement` available by default.
- 🟦 **Lightning Knowledge:** Setup → Knowledge Settings → enable; **create an article type (`*__kav`) + publish articles.** (This is why Knowledge Concierge is gated — the agent compiles via dynamic SOSL but only answers once articles exist.)
- 🟦 **Omni-Channel** for escalation/routing (Escalation/Triage agent).
- **Enables:** Case Service Agent, Knowledge Concierge, Service Concierge.

## 9. Voice
- 🟦 **Setup → Voice → set up Service Cloud Voice** (Partner Telephony / Amazon Connect). Lets a service agent run on the voice channel.

## 10. Slack
- 🟦 Connect Slack to Salesforce (Slack app + identity); add an **Employee Agent** to Slack. Only employee-type agents deploy to Slack.
- **Enables:** any copilot (Account 360, Sales Coach) surfaced in Slack.

---

## Licensed-but-NOT-installed in the reference org (agents gate off these)
| Capability | Why blocked | Library behavior |
|---|---|---|
| **CPQ Quote** (`Quote`/`SBQQ__Quote__c`) | CPQ managed package not installed | Quoting agent skipped by detector |
| **ServiceReport** | FSL managed package not installed | Closer creates report only if object present |
| **OrderSummary** | full Order Management not enabled | Order agents use base `Order` |
| **Revenue Cloud billing** (`BlngInvoice`) | Revenue Cloud not installed | Invoice agent skipped |
| **Knowledge `__kav`** | no published article type | Knowledge agent installed but answers only once articles exist |

## The reliable end-to-end path
1. Enable **Agentforce** (#1) + whatever clouds you want agents for.
2. `sf org login web --alias myorg`
3. `./scripts/install.sh myorg` → detector installs only the eligible agents; re-run after enabling more clouds.
