# Capability Inventory — AgentforceDev (reference org)

Snapshot of what this dev org is **licensed** for and what is **actually usable** (objects present).
The installer gates on *objects present*, not license names — because several licenses are active while
their backing objects/managed packages are not installed.

> Pulled 2026-06-15 from `PermissionSetLicense` + `UserLicense` (active) and `EntityDefinition`.

## Capability domains the org is licensed for

| Domain | Key licenses (active) | Build agents on it? |
|---|---|---|
| **Agentforce — agents** | Agentforce (Default) = employee agents; Agentforce Service Agent Builder/User = customer service agents; Agent platform builder; Einstein Agent (user lic) | ✅ Yes — employee + service + headless |
| **Data Cloud (Data 360)** | Data Cloud; Customer Data Cloud for Marketing; SegmentIntelligencePsl | ✅ CI, Unified Profile, Identity Resolution, predictions, retrievers/RAG |
| **Field Service** | Field Service Standard / Dispatcher / Mobile / Scheduling; Facility Manager; Salesforce Scheduler (+ Greeter) | ✅ WorkOrder/ServiceAppointment/Territory/Skill present. ⚠️ `ServiceReport` object NOT installed (needs FSL managed package) |
| **Commerce (D2C + B2B)** | B2B Commerce; B2B Buyer (Manager); Commerce Admin/Merchandiser/Partner/Session/User; D2C Commerce Shopper | ✅ `WebStore`, `WebCart` present |
| **Order Management** | Lightning Order Management User; 1Commerce OM; Order Management Community; Orders Platform | ✅ `Order`, `OrderItem`, `FulfillmentOrder`, `ReturnOrder` present. ⚠️ `OrderSummary` NOT present (full OMS not on) |
| **Sales** | Sales User; Sales Console User; Sales Engagement Basic; Einstein Activity Capture | ✅ `Lead`, `Opportunity`, `OpportunityLineItem`, `Campaign`, `Task` present |
| **Service** | Service User; Enhanced Chat User; Messaging User | ✅ `Case`, `Entitlement`, `MessagingSession` present. ⚠️ `Knowledge__kav` NOT created (Lightning Knowledge needs an article type; `KnowledgeArticleVersion` exists but isn't Apex-usable yet) |
| **CPQ / Quoting** | Salesforce CPQ License + CPQ AA License | ⚠️ **Licensed but NOT usable** — `Quote`/`SBQQ__Quote__c` objects absent (CPQ managed package not installed) |
| **Revenue / Subscription / Payments** | Subscription Management User/Partner/Experience; Salesforce Payments Internal/External | ⚠️ Partial — verify Revenue Cloud objects before building; `BlngInvoice` absent |
| **Voice** | Salesforce Voice (Partner Telephony); Voice with Amazon | ✅ Voice channel available for agents |
| **Slack** | Slack Service User | ✅ Employee-agent delivery to Slack |
| **Prompt / Grounding** | Einstein Prompt Templates (5/5 used) | ✅ Prompt templates + retrievers |
| **Identity** | Identity Connect; Identity; External Identity | ✅ Identity for IR / external users |
| **Analytics** | Tableau Next Limited Consumer; Analytics View Only | ➖ Reporting, not agents |

## Object reality check (what Apex/agents can actually use)

**Present & usable:** Account, Contact, Lead, Opportunity, OpportunityLineItem, Campaign, Task, Case,
Entitlement, Asset, Contract, Order, OrderItem, FulfillmentOrder, ReturnOrder, Product2, Pricebook2,
ProductCategory, WebStore, WebCart, WorkOrder, WorkOrderLineItem, ServiceAppointment, ServiceResource,
ServiceResourceSkill, ServiceTerritory, Skill, MessagingSession.

**Licensed but NOT installed (gate agents off these — detector skips them):**
`Quote` / `SBQQ__Quote__c` (CPQ), `ServiceReport` (FSL managed pkg), `OrderSummary` (full OMS),
`BlngInvoice` (Revenue Cloud billing), `Knowledge__kav` (no published article type yet),
`LiveChatTranscript` (using MIAW `MessagingSession` instead).

## What this means for the library

- **Build now (no extra setup):** Sales (Lead/Opp/Account), Service (Case/Entitlement), Order/Commerce,
  Field Service core (WorkOrder/SA), Data-Cloud-grounded agents, headless + copilots — all on present objects.
- **Build but gate (detector skips where absent):** Knowledge (needs `*__kav`), Quoting (CPQ), Service
  Reports (FSL pkg), Invoicing (Revenue Cloud), full OMS order summaries.
- **The detector (`scripts/detect-capabilities.py`) already enforces this** by checking object presence per agent.
