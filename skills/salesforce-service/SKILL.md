---
name: salesforce-service
description: Use when setting up, configuring, or troubleshooting Salesforce Service Cloud — Case management + lifecycle (statuses, record types, queues, assignment/escalation rules), order-service flows (OrderSummary, ReturnOrder, refunds/cancellations, store credit), Lightning Knowledge (enablement, articles, agent access via SOSL), Omni-Channel routing for web chat (MIAW → agent via Omni-Channel Flow + Route Work), service-agent fix tools + traceability, and transcript/Case persistence. DX/CLI-first with exact objects, field requirements, and hard-won gotchas. Pairs with the salesforce-agentforce skill for the AI Service Agent.
---

# Salesforce Service Cloud Setup Playbook

Practical, **DX-first** playbook for standing up Service Cloud — case handling, order-related service (returns/refunds/cancellations), Knowledge, web-chat routing, and the service-agent action layer. Drawn from a real commerce-service build; objects map to any domain (a Case maps to a ticket/claim; an Order to any transaction).

## #0 rule: Official-first, standard objects, no Frankenstein
Use **standard Service objects** — `Case`, `Queue`, `EntitlementProcess`, `ReturnOrder`, `OrderSummary`, Lightning `Knowledge` — and declarative routing (assignment/escalation rules, Omni-Channel Flow) before any custom object/Apex. Hand-roll only thin Apex glue invoked by Flow when no native path exists, and say why.

## #1 rule: DX/CLI/API first, UI last
`sf project deploy/retrieve`, `sf data`, `sf apex run`, `sf api request rest`. Some Service features are **enablement-gated** (Lightning Knowledge, Order Management/OrderSummary, Omni-Channel) — when a metadata deploy silently no-ops, that feature likely needs a Setup toggle first. Drive Setup-UI-only steps headlessly via `sf org open --path "<lightning path>" --url-only` (frontdoor auto-auths with the CLI token; no password). `sf org display` redacts the token → prefer `sf api request rest` / Apex session over raw curl.

## 1. Case management + lifecycle
- **`Case`** is the core record. Configure: record types (e.g. Order Issue, Return, General), `Status` picklist + a clear lifecycle (New → In Progress → Escalated → Closed), `Origin` (Web, Chat, Email), priority.
- **Queues** (`Group` with `Type='Queue'` + `QueueSObject` for Case) for team routing; **assignment rules** (`CaseAssignmentRule`) to auto-route; **escalation rules** for SLA breaches.
- **Validation rules** to enforce required fields per status (e.g. resolution required to Close).
- Persist context on the Case: use `Case.Description` and child `Task` records for chat transcripts / interaction history (a "Chat transcript" Task + summary on the Case).
- **Entitlements/Milestones** (`Entitlement`, `EntitlementProcess`, `MilestoneType`) for SLA tracking if licensed.

## 2. Order-related service (returns / refunds / cancellations)
- **`OrderSummary`** (Order Management) is the serviceable view of an order — enable Order Management; OrderSummary is **enablement-gated** (metadata alone won't create the capability).
- **`ReturnOrder`** + `ReturnOrderLineItem` for RMAs; status mapping for the return lifecycle; tie return-churn analytics to the customer profile.
- Refunds/cancellations/store-credit as **Apex service methods** (one `@InvocableMethod` per class) invoked by Flow or an Agentforce action — with **traceability**: log who/when/why on every action (cross-agent journey logging), and write back to the Case/Order.
- Real fix tools (issue store credit, resolve case, cancel/refund) should be **gated** (verified identity, permission set) and idempotent.

## 3. Lightning Knowledge
- **Enable Lightning Knowledge** first (Setup toggle / `KnowledgeSettings`) — without it, `KnowledgeArticleVersion`/`__kav` aren't usable from Apex the normal way.
- Articles = `Knowledge__kav` (data categories for topic/region). Publish articles for the agent/console to ground on.
- **Agent access gotcha**: when Knowledge is partially enabled or you can't bind a specific `__kav` type at compile time, query articles with **dynamic SOSL** (`Search.query`) rather than static SOQL against a typed `__kav`.
- For an AI Service Agent, ground on Knowledge via the Agentforce Data Library / retriever (see the **salesforce-agentforce** skill) rather than hand-rolling retrieval.

## 4. Web chat → live/AI agent routing (Omni-Channel)
- **Messaging for Web (MIAW)** is the web chat channel. Web chat does **NOT** route directly to an Agentforce agent — it routes via **Omni-Channel Flow + a "Route Work" action** to the agent/queue. If you see "Agents are not available," the routing flow/Omni config is the cause.
- Set up: Omni-Channel (enable), Service Channel for messaging, routing configuration (capacity), an **Omni-Channel Flow** that routes the `MessagingSession` to the agent or a queue via Route Work.
- Pass context (e.g. signed-in `loggedInEmail`) from the pre-chat/channel param → **Update Records the `MessagingSession`** field in the routing flow → the agent reads it (agent var sourced from that field as `linked`, not mutable). Test in a NEW chat session.
- See the **salesforce-agentforce** skill for MIAW JWT user-verification + conversation-identity hardening, and the AI Service Agent itself.

## 5. Service-agent action layer + traceability
- Expose service operations (lookup customer, open/resolve case, process return, issue credit) as Apex `@InvocableMethod`s (one per class) callable by the Service Agent or Flow.
- **Anti-hallucination**: actions must verify state before claiming success and return real record IDs/outcomes; don't let the agent assert "done" without the backend write succeeding (a known failure mode — tests can encode the insecure expectation; fix tests → run → fix agent → re-run).
- Log every service action (who/when/why/what changed) for cross-agent traceability and audit.

## 6. Verification
- Create a Case from each Origin → routes to the right queue/owner; escalation fires on SLA.
- Return/refund/credit flow updates the Order/OrderSummary + Case and logs the action.
- Web chat connects to the agent (not "unavailable"), recognizes a signed-in customer, and persists the transcript to the Case/Task.

## Gotchas
- Lightning Knowledge / Order Management / Omni-Channel are **enablement-gated** — toggle first; metadata deploy alone silent-fails.
- Web chat → agent needs **Omni-Channel Flow + Route Work**, not a direct bind.
- Pass chat identity by writing the `MessagingSession` field in the routing flow; agent var must be `linked` to that field.
- `KnowledgeArticleVersion`/`__kav` from Apex → use dynamic SOSL when the type isn't compile-time bindable.
- Service-agent actions must verify backend success before reporting success (anti-hallucination); gate destructive fix tools.
- `sf org open --url-only` = headless Setup-UI auth with no password; `sf org display` redacts the token.
