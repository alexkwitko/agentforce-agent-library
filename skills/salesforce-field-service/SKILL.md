---
name: salesforce-field-service
description: Use when enabling, configuring, or troubleshooting Salesforce Field Service (FSL) — turning the feature on (FieldServiceSettings metadata), the data model (WorkOrder/WorkOrderLineItem/ServiceAppointment/ServiceTerritory/ServiceResource/ServiceTerritoryMember/WorkType/OperatingHours/AssignedResource/Skill/ServiceResourceSkill), seeding territories + technicians + skills, converting orders into work (Order→WorkOrder→WOLI→ServiceAppointment), custom auto-scheduling without the FSL managed package, and self-scheduling / job-completion agent actions. DX/CLI-first with exact field requirements and gotchas.
---

# Salesforce Field Service (FSL) Setup Playbook

Practical, **DX-first** playbook for standing up Field Service and wiring it to commerce/order flows. Drawn from a real build where D2C orders for serviceable products auto-created and auto-scheduled work. Patterns are domain-agnostic (installation, maintenance, repair, inspection).

## #0 rule: license present ≠ feature enabled
Having the FSL objects in the schema does **not** mean Field Service is turned on. Verify the toggle, not just the objects. (In the reference build, "Field Service" looked present because the objects existed, but it was actually **untoggled** — nothing worked until enabled.) Also: you do **not** need the FSL **managed package** for basic WorkOrder/ServiceAppointment scheduling — custom Apex covers it (see §4).

## #1 rule: DX/CLI/API first, UI last
`sf project deploy/retrieve`, `sf data`, `sf apex run`, `sf api request rest`. For Setup-UI-only steps, drive the org UI headlessly with `sf org open --path "<lightning path>" --url-only` (frontdoor auto-auths with the CLI token — no password). `sf org display` redacts the access token, so prefer `sf api request rest` / Apex session over raw curl.

## 1. Enable Field Service (metadata)
Deploy `FieldServiceSettings` with the **real** field names:
```xml
<FieldServiceSettings xmlns="http://soap.sforce.com/2006/04/metadata">
    <fieldServiceOrgPref>true</fieldServiceOrgPref>
    <enableWorkOrders>true</enableWorkOrders>
</FieldServiceSettings>
```
- **`enableFieldService` is NOT a valid field** — the real prefs are `fieldServiceOrgPref` + `enableWorkOrders`. Deploy and confirm `WorkOrder`/`ServiceAppointment` are usable.

## 2. Data model
- **`WorkOrder`** — the job. `AccountId`, `Subject`, `Status` ('New' → 'Scheduled' → ...), `ServiceTerritoryId`, `Pricebook2Id` (needed so WOLIs can carry a product). Add a `Source_Order_Id__c` (Text) for idempotency when generated from an Order.
- **`WorkOrderLineItem` (WOLI)** — line per serviceable item. To carry a `Product2Id`, the **parent WO must have `Pricebook2Id`** AND the WOLI must set `PricebookEntryId` (then `Product2Id` is allowed). `Quantity` requires a product. **Fallback**: if a context rejects the product link, drop `Product2Id`, `PricebookEntryId`, AND `Quantity` (keep `Description` only) inside a `try/catch`.
- **`ServiceAppointment` (SA)** — the schedulable unit. `ParentRecordId` = the WorkOrder Id. `Status='None'` = **unscheduled** (waiting to be booked). `EarliestStartTime`/`DueDate` define the window. To schedule: set `SchedStartTime`, `SchedEndTime`, `Status='Scheduled'`, and create an `AssignedResource`.
- **`ServiceTerritory`** — geographic/operational area; needs `OperatingHours`. `IsActive=true`.
- **`ServiceResource`** — a technician (links to a `User`). `IsActive=true`, `ResourceType='T'` (technician).
- **`ServiceTerritoryMember`** — maps a ServiceResource to a ServiceTerritory (with effective dates).
- **`AssignedResource`** — assigns a ServiceResource to a ServiceAppointment.
- **`WorkType`** — template (duration, required skills) for WorkOrders/SAs.
- **`Skill`** + **`ServiceResourceSkill`** — technician competencies; `SkillRequirement` on WorkType/WorkOrder for matching.
- **`OperatingHours`** + `TimeSlot` — availability windows for territories/resources.

## 3. Seed the foundation (order matters)
1. `OperatingHours` (+ `TimeSlot` rows).
2. `ServiceTerritory` (IsActive, OperatingHoursId).
3. `Skill` rows.
4. `ServiceResource` per tech (UserId, IsActive) → `ServiceResourceSkill` → `ServiceTerritoryMember`.
5. `WorkType` (with `SkillRequirement` if matching).
Do all of this via `sf apex run` or `sf data` — no UI needed.

## 4. Order → Field Service (the conversion + auto-schedule)
Pattern (`OrderToFieldService` Apex, callable from a record-triggered Flow, storefront, or Agentforce action):
- Query OrderItems where `Product2.Requires_Field_Service__c = true`.
- Idempotency: skip if a `WorkOrder` already exists with `Source_Order_Id__c = orderId`.
- Create `WorkOrder` (AccountId, default `ServiceTerritoryId`, `Pricebook2Id` from the Order) → one `WorkOrderLineItem` per serviceable line (with the PricebookEntry/Product2 + try/catch fallback) → one **unscheduled** `ServiceAppointment` (`Status='None'`, ParentRecordId=WO).
- **Auto-scheduling without the managed package**: a Queueable (e.g. `FieldServiceAutoBuilder`) that proposes slots (earliest available within the window for a territory resource) and books the first — set `SchedStartTime`/`SchedEndTime`/`Status='Scheduled'` + insert `AssignedResource`. Trigger it from an `OrderItem after insert` trigger or the order automation.
- Proven live in the reference build: D2C order → WO + WOLI + SA → auto-scheduled + tech-assigned.

## 5. Agent actions (optional, pairs with Agentforce)
- **Self-scheduling agent**: an action that lists open slots for the customer's territory and books the chosen one (writes SchedStartTime/End + AssignedResource).
- **Job-completion agent** (for the tech): close the SA (`Status='Completed'`), set actual times, mark the WorkOrder `Completed`, capture notes. One `@InvocableMethod` per Apex class.
- See the **salesforce-agentforce** skill for authoring/headless invocation.

## 6. Gotchas
- `enableFieldService` is invalid → use `fieldServiceOrgPref` + `enableWorkOrders`.
- WOLI `Product2Id` needs WO.`Pricebook2Id` + WOLI.`PricebookEntryId`; on rejection drop product+pricebookentry+quantity (Description-only).
- `ServiceAppointment.Status='None'` = unscheduled; `ParentRecordId` = WorkOrder.
- No FSL managed package required for basic create+schedule — custom Apex sets Sched times + AssignedResource.
- "Objects exist" ≠ "feature enabled" — always verify the toggle.
- Serviceable flag: a `Product2.Requires_Field_Service__c` checkbox is the clean trigger for which order lines spawn work.
