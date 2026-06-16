# Salesforce Setup Skills

The agents in this library are useless without the **clouds** they run on. These four skills are the
distilled, hands-on playbooks for setting up those clouds the **DX-first** way (sf CLI / metadata /
Connect API first, UI only as a last resort) — every one written from real builds, with the exact
metadata shapes, API bodies, Apex patterns, and the gotchas that actually cost time.

They are [Claude Code **Agent Skills**](https://docs.claude.com/en/docs/claude-code/skills): drop a
folder into `~/.claude/skills/` and Claude auto-loads it whenever the work matches the skill's
description (or invoke it explicitly, e.g. `/salesforce-d2c-setup`).

| Skill | Use it when you're… |
|---|---|
| **salesforce-agentforce** | Building/deploying/troubleshooting **any** Agentforce solution — Agent Script bundles + headless invocation, Data Cloud (DLO/DMO, Identity Resolution, Calculated Insights), Messaging-for-Web (MIAW) chat + JWT verification, predictive models, email/notifications, the CRM-vs-Data-Cloud decision. |
| **salesforce-d2c-setup** | Standing up a **D2C / B2B Commerce** store — WebStore/catalog/pricebooks, the CMS product-image upload, payment + shipping + **tax** integrations, inventory, buyer groups + entitlement, Person-Account buyers, **guest browsing + checkout**, the LWR storefront site, the search index, end-to-end checkout. |
| **salesforce-field-service** | Enabling + configuring **Field Service** — `FieldServiceSettings`, the WorkOrder/ServiceAppointment data model, territories/technicians/skills, **Order→WorkOrder→appointment** conversion, custom **auto-scheduling without the managed package**, self-scheduling + job-completion agent actions. |
| **salesforce-service** | Setting up **Service Cloud** — Case lifecycle + queues/assignment/escalation, order-service (OrderSummary/ReturnOrder/refunds/credit), Lightning Knowledge, **Omni-Channel web-chat routing** (MIAW → agent), and the service-agent fix-tool/anti-hallucination layer. |

## Install

**Option A — copy the folders** (works with any Claude Code install):
```bash
git clone https://github.com/alexkwitko/agentforce-agent-library
cp -R agentforce-agent-library/skills/salesforce-* ~/.claude/skills/
```
That's it. Open Claude Code in your Salesforce project and ask it to "set up a D2C store" (or field
service, or service) — the matching skill loads automatically. Or invoke one directly:
`/salesforce-d2c-setup`, `/salesforce-field-service`, `/salesforce-service`, `/salesforce-agentforce`.

**Option B — symlink** (so `git pull` keeps them current):
```bash
for s in agentforce-agent-library/skills/salesforce-*; do
  ln -s "$(pwd)/$s" ~/.claude/skills/$(basename "$s")
done
```

## How they fit together

A realistic build uses several at once:
1. **salesforce-agentforce** — turn on Agentforce, design the agents, wire Data Cloud + chat.
2. **salesforce-d2c-setup** / **salesforce-field-service** / **salesforce-service** — stand up the cloud(s)
   the agents act on (a storefront to shop, field work to schedule, cases to resolve).
3. Install the **agents** from this repo's `agents.json` (`../scripts/install.sh`) — the license-aware
   installer deploys only what your org supports.

Everything is product-agnostic: the coffee-store / equipment / field-service examples are just
concrete illustrations — substitute your own objects and brand.
