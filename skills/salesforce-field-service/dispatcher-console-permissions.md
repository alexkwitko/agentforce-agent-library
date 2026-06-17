# Field Service — Dispatcher Console & Permissions

The Dispatcher Console and the FSL permission sets come from the **managed package**. The managed-package permission sets are named **`FSL_*`** (e.g. `FSL_Dispatcher_Permissions`, `FSL_Dispatcher_License`) — query the org, don't assume the namespace prefix is populated.

## 0. Two consoles: Classic vs the new Scheduling Console (verified Summer '26)
- **Classic Dispatch Console** — the long-standing Aura/VF **Gantt + Map** (tab `FSL__FieldService`, label "Classic Dispatch Console", inside the **Field Service** app). Works on the classic optimization engine.
- **Scheduling Console** — the **new LWC-based** console (lighter, multi-screen; has **Optimize**, a policy selector, **Create**, a resource Gantt + an "All Service Appointments" list). **Requires Enhanced Scheduling & Optimization (ES&O) enabled.** Enable ES&O via `o2EngineEnabled=true` in `FieldServiceSettings` — **DX works**: deploy as **mdapi** (`--metadata-dir` with the file named **`FieldService.settings`**, NOT `.settings-meta.xml`, + a `package.xml` with `<name>Settings</name>`). Once ES&O is on, the **Scheduling Console** tab appears automatically (App Launcher → "Scheduling Console"; URL `lightning/page/dispatchConsole`). Same Dispatcher permission sets as Classic. (`o2EngineEnabled` is a largely one-way engine migration — confirm with the user before flipping it.)
- **⚠️ "We couldn't load the availability" / "couldn't check rule violations" in the new Scheduling Console — checklist (in priority order):**
  1. **Operating Hours need `TimeSlot` rows.** Territories whose OH has 0 time slots = no availability to compute. Add Mon–Fri windows (`TimeSlot`: `OperatingHoursId`, `DayOfWeek`, `StartTime`, `EndTime`, `Type='Normal'`). **This is the #1 cause.**
  2. Territories geocoded (Lat/Long) + resource has a `LastKnownLatitude/Longitude` home base.
  3. Resource is active (`ResourceType='T'`), has a **PRIMARY** `ServiceTerritoryMember`, skills, and the default policy has a **Resource Availability** work rule.
  - **If it STILL errors after all the above** (data fully correct + Classic console works on the same data): the ES&O **backend service was never provisioned**, even though the org prefs read ON. **Root cause (verified): enabling ES&O via the Metadata API does NOT provision the service.** `sf project deploy` of `<o2EngineEnabled>true</o2EngineEnabled>` (+`optimizationServiceAccess`) writes the *stored preference* (so the flag reads true and the **Scheduling Console** tab appears) but **skips the side-effecting provisioning handshake** that the Setup-UI button runs — registering the org with the Salesforce-hosted **O2/OIS optimization service** and seeding `FSL__O2_Settings__mdt`. Diagnose the "flag-on-but-not-provisioned" state by querying: `FSL__O2_Settings__mdt` = **0 records** and `FSL__Optimization_Request__c` = **0 ever** (engine has never run), while `RemoteSiteSetting` shows `FSL_O2_Optimize`/`FSL_OIS_FieldService_MULTI` **active** and `FieldServiceSettings` shows `o2EngineEnabled`+`optimizationServiceAccess`=true. (`FSL__O2_Toggle_Settings__mdt` isn't SOQL-queryable — "not supported".)
    - **The fix is genuinely UI-only** (no CLI/metadata path triggers provisioning): **Field Service Settings → Optimization → Activation**. Two things there: "Turn on Enhanced Scheduling and Optimization" (the ES&O engine toggle) AND **"Standard Optimization" → Create Optimization Profile**. The latter creates a `Field Service Optimization` profile + background user (the user the optimizer runs as) — **but it may be created INACTIVE** (activate it: `update User set IsActive=true`). After that the section says **"log in as the Field Service Optimization user"** to authorize: enable the **"Administrators Can Log in as Any User"** Login Access Policy (⚠️ a security setting — get user consent), **Login As** that user, and click **Activate Optimization**.
    - ⚠️ **Activate Optimization can hit a hard wall:** it opens `RemoteAccessAuthorizationPage` (OAuth consent for the FSL optimization **connected app**) → **"Insufficient Privileges."** KB 002134246 says fix via Setup → Connected Apps OAuth Usage → Install/Unblock the FSL Optimization connected app. **But verify the connected app even EXISTS first:** `sf data query --use-tooling-api -q "SELECT Name FROM ConnectedApplication WHERE Name LIKE '%ptimiz%'"`. In a Dev Edition org it may return **0** — the optimization connected app simply isn't provisioned, so there's nothing to install/unblock and the legacy optimizer **cannot be activated without Salesforce support**. (ES&O is "in-platform" yet `schedule()` still routed through this legacy optimization auth and stayed broken.)
    - ⚠️ **Don't `/secur/logout.jsp` out of a Login-As session — it's a FULL logout, not return-to-admin.** Recover credential-free with `sf org open --path "<setup path>"` (it sets the cookie; then a normal Lightning URL loads authenticated). Pasting a `frontdoor.jsp?otp=` URL into the browser is blocked by the auto-mode classifier.
    - The **`sfdc_fieldservice` ("Field Service Integration") perm set canNOT be assigned to a regular admin** ("license doesn't match") — not the fix.
    - **Until ES&O is provisioned, use the Classic Dispatch Console + manual dispatch** (classic engine; works on the same data).
- **"You must have Dispatcher license in order to load the Dispatcher console"** — the #1 console error. The console checks the **`FSL_Dispatcher_Permissions` + `FSL_Dispatcher_License` PERM SETS**, NOT just the **Field Service Dispatcher PSL**. Having the PSL alone is NOT enough — you must also assign those two FSL perm sets (PSL is the prerequisite for the perm-set assignment). Assigning them clears the error and the Gantt loads.

## The map shows nothing until territories are "designed" (geocoded)
The dispatcher **Map** plots ServiceTerritories by their **Latitude/Longitude** and resources by `LastKnownLatitude/Longitude`. Fresh territories have **no address/geo** → empty map. Fix (API-doable):
- Set `ServiceTerritory` `Street/City/PostalCode` + **`StateCode`/`CountryCode`** (use the Code fields — the org likely has State/Country picklists; setting `State`/`Country` text throws `FIELD_INTEGRITY_EXCEPTION`). **`Latitude`/`Longitude` ARE directly writable** on ServiceTerritory — set them so the territory pins without waiting on geocoding rules.
- Set the resource's `LastKnownLatitude/Longitude` (+ `LastKnownLocationDate`) for a home-base pin.
- **Territory boundary polygons** (`FSL__Polygon__c`, 0 by default) are drawn in the **Map → Polygons** UI (a visual draw activity); that's the optional "designed boundary" layer beyond geocoded pins.

## 1. The Dispatcher Console
A managed-package feature surfaced as the **Field Service** tab inside the **Field Service** Lightning app (NOT "Field Service Admin", which is the config app). The dispatcher's single screen to schedule/optimize/dispatch.

**Open it:** App Launcher → **Field Service** app → **Field Service** tab. Requires **FSL Dispatcher Permissions** (perm set) **+ Field Service Dispatcher PSL** — without both the tab/console won't render ("Insufficient Privileges" / blank console).

**Parts:**
- **Gantt** (right): resource list (technicians from loaded territories, with skills/utilization/hours) + timeline of appointments per resource; drag-and-drop, rule-violation indicators, live updates. Shows ~4 years past/future.
- **Appointment list** (left): filter/sort/search SAs; run mass/global actions (Schedule, Dispatch, Unschedule). Scoped to the territories loaded into the Gantt.
- **Map / Policy Map**: appointment + resource positions; custom icons/colors/**polygons** for territory boundaries; pick a scheduling policy and schedule on the map.
- **Scheduling actions**: Schedule, Optimize, Dispatch, Get Candidates, Book Appointment/Emergency, Unschedule/Pin/Reshuffle.

**Territory filtering:** a dispatcher loads territories into the Gantt (gear icon → Territory filtering); the list/resources/map scope to them. Dispatchers are tied to territories via `ServiceTerritoryMember` with **Member Role = Dispatcher**. Columns customizable via **field sets** (`service.pfs_fieldsets.htm`). Help: `sf.pfs_gantt.htm`, `service.pfs_appointments_list.htm`, `service.pfs_territory.htm`, `pfs_customize_dc.htm`.

## 2. Permission Set Licenses (PSLs)
Org-level entitlements enabled per user (Setup → Users → user → PSL Assignments).
| PSL | For | Who |
|---|---|---|
| **Field Service Standard** | Baseline access to FS objects. | Every FS user. |
| **Field Service Scheduling** | Be included in scheduling/optimization. | Schedulable technicians. |
| **Field Service Dispatcher** | **Gates the Dispatcher Console.** | All console users. |
| **Field Service Mobile** | The offline mobile app. | Mobile workers. |
Dispatcher ≈ Standard + Dispatcher (+ Scheduling if also schedulable). Technician ≈ Standard + Scheduling + Mobile. Help: `service.fs_perm_set_licenses.htm`.

## 3. FSL permission sets (created by Guided Setup)
Guided Setup **generates** these from package templates (Field Service Admin app → Field Service Settings → Permission Sets / "Create Permissions" per tile). They don't pre-exist.
| Permission Set (display) | Grants | Companion PSL |
|---|---|---|
| **FSL Admin Permissions** | Manage all FSL objects, the Admin app, FSL VF pages + Apex/config. | FSL Admin License + Sys Admin |
| **FSL Agent Permissions** | Global actions to create/book/schedule SAs (call-center). | FSL Agent License |
| **FSL Dispatcher Permissions** | Superset (Agent + Resource) + operate the Dispatcher Console + run optimization. | **FSL Dispatcher License** |
| **FSL Resource Permissions** | Minimum for a worker: update appointment status + last-known location. | FSL Resource License (+ Mobile + Scheduling) |
| **FSL Self Service / Community Dispatcher Permissions** | Community/Experience Cloud self-scheduling / external dispatcher. | matching community PSL |
"Create Permissions" stamps the named sets; re-run **"Update"** on each tile after a package upgrade. Help: `service.pfs_get_started.htm`, `service.fs_manage_permissions.htm`.

## 4. Assignment (API/Apex) — PSL FIRST, then perm set
A `PermissionSetAssignment` to an FSL perm set **fails** if the user lacks the underlying PSL.
```apex
// 1) PSL
Id pslId = [SELECT Id FROM PermissionSetLicense WHERE DeveloperName='FSL_Dispatcher_License' LIMIT 1].Id;
insert new PermissionSetLicenseAssign(AssigneeId=userId, PermissionSetLicenseId=pslId);
// 2) perm set (Name = API name; FSL namespace)
Id psId = [SELECT Id FROM PermissionSet WHERE Name LIKE '%Dispatcher%' AND NamespacePrefix='FSL' LIMIT 1].Id;
insert new PermissionSetAssignment(AssigneeId=userId, PermissionSetId=psId);
```
CLI: `sf data create record --sobject PermissionSetLicenseAssign --values "AssigneeId=<uid> PermissionSetLicenseId=<pslId>"` then `sf org assign permset --name <FSL perm set API name>` (PSL must already be assigned). **Query the real `DeveloperName`/`Name` per org** — they vary by org/version.

## 5. Custom permissions & FLS
- FSL ships **custom permissions** gating console actions (run optimization, drag-drop, dispatch) — toggled inside the FSL perm sets; you don't hand-build them (`service.pfs_custom_permissions.htm`).
- Users still need **object/field FLS** (profile or perm set) on WorkOrder/ServiceAppointment/ServiceResource/etc., and typically **Service Cloud User** on the dispatcher's user record. Field sets (not FLS) drive console columns.

## 6. End-to-end
**Dispatcher:** (1) user record: Service Cloud User + correct time zone (Gantt is TZ-sensitive); (2) PSLs: Field Service Standard + Field Service Dispatcher; (3) perm set: FSL Dispatcher Permissions (rolls up Agent + Resource); (4) `ServiceTerritoryMember` role Dispatcher on each managed territory; (5) open Field Service app → Field Service tab → load territories.
**Technician/resource:** (1) user: Service Cloud User + time zone; (2) PSLs: Field Service Standard + Field Service Scheduling + Field Service Mobile; (3) perm sets: FSL Resource Permissions + `FieldServiceMobileStandardPermSet`; (4) `ServiceResource` (`ResourceType='T'`, `IsActive=true`) linked to the user; (5) `ServiceTerritoryMember` **Primary** (+ secondary/relocation); (6) `ServiceResourceSkill` records.

## 7. UI-only vs API-doable
| Task | UI-only? | API? |
|---|---|---|
| Generate the FSL perm sets (Guided Setup tiles) | **UI-only** | No (inspect after) |
| Enable PSLs per user | works | **Yes** (`PermissionSetLicenseAssign`) |
| Assign FSL perm sets | works | **Yes** (`PermissionSetAssignment`; PSL first) |
| Territory/member/resource/skill records | works | **Yes** (standard objects) |
| Dispatcher Console interaction | UI | Partly (FSL Apex for schedule/optimize) |
| Enable Field Service feature | toggle | **Yes** (`FieldServiceSettings`) |

## Gotchas
- **PSL before perm set, always** — bulk onboarding must `PermissionSetLicenseAssign` first.
- **Guided-Setup perm-set creation is genuinely UI-only**; re-run "Update" tiles after package upgrades.
- **Namespacing** — FSL perm sets/custom perms carry the `FSL` prefix; query `PermissionSet WHERE NamespacePrefix='FSL'` before hardcoding. PSL `DeveloperName`s vary — query `PermissionSetLicense`.
- **Two apps**: "Field Service Admin" (config/Guided Setup) vs "Field Service" (runtime, holds the Dispatcher Console tab). Dispatchers open the latter.
- **Field Service tab needs BOTH** the Dispatcher PSL and the FSL Dispatcher Permissions perm set.
- **Dispatcher Permissions is a superset** (Agent + Resource) — don't separately assign those to a dispatcher.
- **Territory scoping is data-driven** (Gantt load + Member Role Dispatcher), not just permission-driven.
- **Time zone + Service Cloud User** matter on the dispatcher's user; FLS still applies or actions silently fail.
- Classic Dispatch Console (`pfs_customize_dc.htm`) vs Lightning Gantt (`sf.pfs_gantt.htm`) — follow the set matching your package/UI version.
