# Agentforce Agent Library — Roadmap (the goal)

Build a free, open, installable library of **best-in-class agents for every business function the org is
licensed for**, in three kinds — **customer-facing**, **internal copilot**, **headless/autonomous** —
each grounded (where valuable) in **Data Cloud** (Calculated Insights, Unified Profile, Identity
Resolution, predictions, RAG), with **communication + handoff** wired, and a **skill** that lets anyone
customize them. Synthesized from the capability inventory ([01-capability-inventory.md](01-capability-inventory.md))
+ web research (sources at bottom).

## Agent kinds (the three reusable skeletons)

1. **Customer-facing (Service Agent)** — MIAW web chat / WhatsApp / voice. Anti-hallucination + PII gate.
   `agent_type: AgentforceServiceAgent`.
2. **Internal copilot (Employee Agent)** — utility bar / record page / Slack; runs as the logged-in user
   (respects their FLS/sharing). `agent_type: AgentforceEmployeeAgent`.
3. **Headless / autonomous** — no chat UI. Skeleton: **Schedulable/Record-Triggered Flow → invocable
   `generateAiAgentResponse`** (or **Agent API** `POST /services/agentforce/api/v1/sessions` with
   `bypassUser:true`) **+ an `@InvocableMethod` action the agent calls.** A scheduled job that only writes
   records is *automation*, not an agent — it becomes an agent when one step delegates a *decision* to
   agent reasoning.

## Cross-cutting building blocks (apply to every agent)

- **Data Cloud grounding** (use the right primitive):
  - Exact fact / score / profile attr → **Apex `@InvocableMethod`** running `ConnectApi.CdpQuery.queryAnsiSqlV2` / `queryCalculatedInsights('X__cio',…)` / `queryProfileApi(...)`, or static SOQL on `__dlm`/`__cio` (Spring '25+).
  - Fuzzy / document answer → **Retriever (RAG)** over a Data Library; reference `{!$EinsteinSearch:<retriever>.results}` in a prompt template; return `Chunk__c`.
  - Precomputed analytics → **Calculated Insight (`__cio`)**: LTV, RFM, propensity, churn band.
  - Recognize the person → **Unified Individual (`UnifiedIndividual__dlm`)** + **Data Graph**; resolve via the channel's verified key (email/JWT/loyalty id) which must be an **Identity Resolution match key** (add **device id** to recognize pre-login browsers).
  - Prediction → train in Einstein Studio / BYOM → **Prediction Job writes a score DMO** → agent action reads it (agents read scored records, they don't call models).
- **Headless triggers** — **Data Cloud-Triggered Flow** on DMO change, or **Data Action → Platform Event → Flow → invocable** (e.g. "churn score > 0.8 → win-back agent").
- **Communication & handoff** — escalate to human via **Omni-Channel** (route to queue/agent); **multi-agent** via subagents within one bundle (router → subagents) or agent-to-agent via the **Agent API**; pass context through agent **variables** (linked `@MessagingSession` vars for web) and a shared journey/context Apex service.
- **Testing** — every agent ships an `AiEvaluationDefinition` + `sf agent test run`; multi-turn harness repeated ≥10× (non-deterministic). Remember: `sf agent publish` leaves it **inactive** → `sf agent activate`.

## The catalog (status • kind • objects • license tier)

Tier: **Core** = standard objects + Agentforce only (broadly installable). **Gated** = needs an extra
license/managed-package/feature (detector skips if objects absent).

### Sales  *(objects present ✅)*
| Agent | Kind | Objects | Tier | DC enrichment | Status |
|---|---|---|---|---|---|
| Sales / Opportunity Coach | copilot | Opportunity, OCR, OLI, Task, Account | Core | propensity CI, NBA prediction | **planned (next)** |
| Lead Qualifier / SDR | headless (+email) | Lead, Contact, Account, Task, Campaign | Core | lead-score prediction, UP | planned |
| Account 360 Copilot | copilot | Account, Contact, Opportunity, Case, Order | Core | LTV/RFM CI, UP, taste profile | planned |
| Forecasting Assistant | copilot | Opportunity, ForecastingItem | Core | — | later |
| Quoting / CPQ | copilot | Quote / SBQQ__Quote__c | **Gated (CPQ)** | — | gated |

### Service  *(Case ✅; Knowledge gated)*
| Agent | Kind | Objects | Tier | DC enrichment | Status |
|---|---|---|---|---|---|
| Case Service Agent (log + resolve) | copilot | Case, CaseComment | Core | — | ✅ **DONE** |
| Knowledge Concierge | customer | KnowledgeArticleVersion / `*__kav` | Gated (Lightning Knowledge) | RAG retriever | ✅ **DONE** (dynamic SOSL) |
| Service Concierge (deflection) | customer | Case, Knowledge, Order, Contact | Core/Gated | RAG + UP + order CI | planned |
| Case Resolution Copilot | copilot | Case, EmailMessage, Knowledge, Entitlement | Core | RAG suggested resolution | planned |
| Escalation / Triage Router | headless | Case, PendingServiceRouting | Core (Omni-Channel) | sentiment/topic classify | planned |

### Field Service  *(WorkOrder/SA ✅; ServiceReport gated)*
| Agent | Kind | Objects | Tier | Status |
|---|---|---|---|---|
| Field Service Scheduler | customer/headless | WorkOrder, WOLI, ServiceAppointment, ServiceTerritory, Order | Core | ✅ **DONE** |
| Service Appointment Closer | copilot | ServiceAppointment, WorkOrder (ServiceReport if present) | Core (+gated report) | ✅ **DONE** |
| Technician Mobile Copilot | copilot | WorkOrder, Asset, ProductItem | Gated (FSL pkg/mobile) | later |

### Commerce / Order  *(Order ✅; WebStore/WebCart ✅)*
| Agent | Kind | Objects | Tier | DC enrichment | Status |
|---|---|---|---|---|---|
| Order / Commerce Concierge (lookup + reorder) | customer | Order, OrderItem | Core | — | ✅ **DONE** |
| Personal Shopper / D2C Concierge | customer | Product2, WebStore, WebCart, CartItem, Order | Gated (Commerce) | reco prediction, UP, taste CI | planned |
| Returns / RMA Agent | customer/headless | ReturnOrder, ReturnOrderLineItem, Order, Case | Core | return-churn CI | planned |

### Marketing  *(Campaign ✅; segmentation gated on Data Cloud/MC)*
| Agent | Kind | Objects | Tier | Status |
|---|---|---|---|---|
| Campaign Builder | copilot | Campaign, CampaignMember | Core (advanced gated MC) | planned |
| Segmentation Agent | copilot/headless | Data Cloud segments/DMOs | Gated (Data Cloud) | planned |
| Win-back / NBA (headless) | headless | CampaignMember, Contact + churn CI | Gated (Data Cloud) | planned |

### Operations / Finance
| Agent | Kind | Objects | Tier | Status |
|---|---|---|---|---|
| Approvals Agent | copilot/headless | ProcessInstanceWorkitem + record | Core | planned |
| Contract Lifecycle | copilot | Contract, ContractLineItem, Order | Core | later |
| Invoice / Collections | headless | Invoice / Order, Account, Task | Gated (Revenue Cloud) | later |

### Internal / Cross-functional copilots
| Agent | Kind | Objects | Tier | Status |
|---|---|---|---|---|
| Stale-Deal / Pipeline Sweeper | **headless** | Opportunity, Task | Core | **planned (headless exemplar)** |
| Manager / Team Copilot | copilot | Opportunity, Case (team rollups) | Core | later |
| Employee Help (HR/IT) | copilot (Slack) | Case, Knowledge | Gated (ESM/ITSM) | later |

## Build phases

- **Phase 0 — DONE:** library scaffold, license-aware detector + installer, distribution skill, 5 agents
  (Field Service Scheduler, Service Appointment Closer, Knowledge Concierge, Order Concierge, Case Service Agent).
- **Phase 1 — Core copilots + first headless (no extra licenses):** Sales/Opportunity Coach (copilot),
  Account 360 Copilot, Lead Qualifier (headless), Stale-Deal Sweeper (headless exemplar), Approvals,
  Returns/RMA. *Proves all three kinds on standard objects.*
- **Phase 2 — Data Cloud-grounded agents:** add CI/UP/IR/prediction/RAG enrichment — Account 360 with
  LTV/RFM CI, Service Concierge with RAG + order CI, Win-back headless (Data Action → agent), Personal Shopper with reco prediction.
- **Phase 3 — Gated/advanced (detector-skipped where absent):** Knowledge full RAG, Quoting (CPQ),
  Service Report, Commerce storefront Personal Shopper, Marketing segmentation, Invoicing.
- **Phase 4 — Surfaces + comms:** Slack copilots, voice channel, Omni-Channel handoff, multi-agent
  orchestration (router + subagents), Agent API headless examples; per-agent `AiEvaluationDefinition` tests.

## Per-agent build pattern (unchanged, additive)

Apex service (idempotent, returns a result struct) → one `@InvocableMethod` wrapper **per action** →
`.agent` bundle (router + subagents + **anti-hallucination** rule) → Apex test → permission set →
entry in [`agents.json`](../agents.json) declaring `requiredObjects` (+ `requiredObjectsLike`, `kind`,
`mode`). The detector + installer pick it up automatically.

---
### Research sources
Agentforce by function: Salesforce News (SDR, Field Service, Commerce, HR/IT, Operations/ARM), Trailhead.
Data Cloud: `ConnectApi.CdpQuery` dev blogs, "Grounding agents in Data 360" Trailhead, Real-time IR,
Einstein Studio. Headless/copilot: Agent API dev docs (sessions/messages, `bypassUser`), "Build Headless
Agents with the Agent API", "Invoke Agentforce Agents with Apex and Flow", `AiEvaluationDefinition` docs.
(Full URLs captured in research notes.)
