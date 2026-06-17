# Field Service — Dispatcher Console & Permissions

The Dispatcher Console and the FSL permission sets come from the **managed package**. The managed-package permission sets are named **`FSL_*`** (e.g. `FSL_Dispatcher_Permissions`, `FSL_Dispatcher_License`) — query the org, don't assume the namespace prefix is populated.

## 0. The two Dispatcher Consoles — and how to turn on the NEW one (Scheduling Console) WITHOUT breaking it
*(verified end-to-end on a Dev org, 2026-06)*

Field Service ships **two** dispatch consoles, both inside the **Field Service** Lightning app; the same FSL Dispatcher permission sets gate both (§4).

| | **Classic Dispatch Console** | **Scheduling Console (NEW, LWC)** |
|---|---|---|
| Tab / URL | tab `FSL__FieldService` (label "Classic Dispatch Console") | `lightning/page/dispatchConsole` (label "Scheduling Console") |
| UI | Aura/VF **Gantt + Map** | Lighter LWC: resource Gantt + "All Service Appointments" list + **Optimize** / policy selector / **Create** |
| Engine | classic optimizer | **Enhanced Scheduling & Optimization (ES&O)** — in-platform |
| Works out of the box? | **Yes** | **Only after ES&O is enabled via the UI wizard** (below) |

### ✅ Enable the new Scheduling Console + make it visible — the RIGHT way
The Scheduling Console tab appears only once **ES&O is enabled**, and ES&O only actually *works* if you enable it through the **Setup-UI wizard** (which provisions the in-platform optimization service). Exact path:
1. App Launcher → **Field Service Admin** app → **Field Service Settings** tab (URL `lightning/n/FSL__Field_Service_Settings`).
2. Left nav → **Optimization** → **ACTIVATION** sub-tab.
3. Under **"Enhanced Scheduling and Optimization"** click **Run Readiness Check**.
4. The check returns advisory items in up to 3 groups (*Update Your Configuration* / *Review Partially Supported Features* / *Consider Differences In Behavior*). **Tick the acknowledgment checkbox on every item** — each group's circle turns green. (They're "I've read this," not config edits.)
5. The **"Turn on Enhanced Scheduling and Optimization → Enable"** button activates once all groups are green. Click **Enable** → wait for "Enabling…" → green **Enabled**.
6. The **Scheduling Console** tab now appears (App Launcher → "Scheduling Console", or `…/lightning/page/dispatchConsole`). Give dispatchers the **FSL Dispatcher** perm sets (§4) — same as Classic.

**Verify it truly provisioned (not just flag-flipped):**
- Apex: `FSL.ScheduleService.schedule(policyId, saId)` on an unscheduled SA returns success and the **engine auto-picks slot+resource**. If it throws **`Schedule optimization incomplete`**, the service is NOT provisioned → re-run the Enable wizard.
- Console shows a **"% Booked"** figure per resource and **no red "We couldn't load the availability" banner**.

### ❌ What NOT to do (this is exactly what breaks it)
- **Do NOT enable ES&O by metadata alone.** Deploying `<o2EngineEnabled>true</o2EngineEnabled>` (+`optimizationServiceAccess`) in `FieldServiceSettings` flips the stored flag and makes the tab appear — **but skips the provisioning handshake**. You end up with the tab visible yet `schedule()` throwing "Schedule optimization incomplete" and the console showing "We couldn't load the availability." Metadata is fine to *read/verify* the flag; **the real enable must be the UI wizard.**
- **Do NOT chase the "Standard Optimization" section** ("Create Optimization Profile" → "log in as the Field Service Optimization user" → "Activate Optimization" → connected-app OAuth). That is the **LEGACY ClickSoftware optimizer** and a **dead-end red herring for ES&O** (which is in-platform). It leads to a `RemoteAccessAuthorizationPage` that throws **"Insufficient Privileges"**, and in a Dev org references a connected app that doesn't even exist (`SELECT Name FROM ConnectedApplication WHERE Name LIKE '%ptimiz%'` → 0). Ignore that whole section for ES&O.
- **Do NOT run unschedule + schedule in the SAME Apex transaction** — transient "time slot/resource no longer available, try again." Use two separate executions.
- **Do NOT exit a Login-As session via `/secur/logout.jsp`** — that's a FULL logout (kills your admin session too). Return via the banner's own "Log out", or recover credential-free with `sf org open --path "<path>"` (don't paste a `frontdoor.jsp?otp=` URL — the auto-mode classifier blocks it).
- `o2EngineEnabled` is a **largely one-way engine migration** — confirm with the user before first enabling. (The UI *does* offer "Turn Off", used in the repair below.)
- The **`sfdc_fieldservice` ("Field Service Integration") perm set is NOT assignable to a regular admin** ("license doesn't match") — it's not the fix for anything here.

### 🛠️ If the Scheduling Console is broken — how to fix it
**Symptoms:** tab visible but **"We couldn't load the availability"** banner, and/or Apex `schedule()`/`scheduleExtended()` throws **`Schedule optimization incomplete`**. **Diagnose** the "flag-on-but-not-provisioned" state: `FSL__Optimization_Request__c` count = **0** (engine never ran) while `FieldServiceSettings.o2EngineEnabled` = true and `RemoteSiteSetting` `FSL_O2_Optimize`/`FSL_OIS_FieldService_MULTI` are active. (Caused almost always by enabling ES&O via metadata.)

**Fix (UI, ~1 min) — re-run the wizard:** Field Service Settings → Optimization → **ACTIVATION** →
1. **Turn Off** Enhanced Scheduling and Optimization (clears the half-provisioned state).
2. **Run Readiness Check** → tick all acknowledgment boxes (all groups green).
3. **Enable** → wait for green **Enabled**.
4. Re-test: unschedule an SA, then in a **separate** transaction `FSL.ScheduleService.schedule(policyId, saId)` → auto-schedules; the console availability loads (resource shows "% Booked").

**Also rule out the DATA causes of "couldn't load availability"** (these break availability even when ES&O IS provisioned), in priority order:
1. **OperatingHours has 0 `TimeSlot` rows** — the #1 cause. Add Mon–Fri windows (`TimeSlot`: `OperatingHoursId`, `DayOfWeek`, `StartTime`, `EndTime`, `Type='Normal'`).
2. Territories geocoded (Lat/Long) + resource `LastKnownLatitude/Longitude` home base.
3. Resource active (`ResourceType='T'`) with a **PRIMARY** `ServiceTerritoryMember` + skills; default policy has a **Service Resource Availability** work rule.

**Worst case, you're never blocked:** the **Classic Dispatch Console + manual dispatch** (set `SchedStartTime`/`SchedEndTime` + `Status='Scheduled'` + insert `AssignedResource`) works on the same data regardless of ES&O state.

- **"You must have Dispatcher license in order to load the Dispatcher console"** — the #1 console error. The console checks the **`FSL_Dispatcher_Permissions` + `FSL_Dispatcher_License` PERM SETS**, NOT just the **Field Service Dispatcher PSL**. Having the PSL alone is NOT enough — you must also assign those two FSL perm sets (PSL is the prerequisite for the perm-set assignment). Assigning them clears the error and the Gantt loads.

## The map shows nothing until territories are "designed" (geocoded)
The dispatcher **Map** plots ServiceTerritories by their **Latitude/Longitude** and resources by `LastKnownLatitude/Longitude`. Fresh territories have **no address/geo** → empty map. Fix (API-doable):
- Set `ServiceTerritory` `Street/City/PostalCode` + **`StateCode`/`CountryCode`** (use the Code fields — the org likely has State/Country picklists; setting `State`/`Country` text throws `FIELD_INTEGRITY_EXCEPTION`). **`Latitude`/`Longitude` ARE directly writable** on ServiceTerritory — set them so the territory pins without waiting on geocoding rules.
- Set the resource's `LastKnownLatitude/Longitude` (+ `LastKnownLocationDate`) for a home-base pin.
### Territory boundary polygons (`FSL__Polygon__c`) — KML import or draw, NOT Apex
Polygons are the "designed boundary" layer beyond geocoded pins; they drive both the **visual map boundaries** and the **geofence → territory assignment** (`FSL.PolygonUtils` resolves a lat/long to its containing territory — verify the exact method signature against your org's `FSL` namespace).

- **⚠️ You CANNOT create `FSL__Polygon__c` via Apex/API DML.** A managed **validation rule** rejects every externally-supplied value — `FIELD_CUSTOM_VALIDATION_EXCEPTION: Polygon KML data structure is invalid: []` — for raw `<Polygon>` KML, full `<kml>` docs, GeoJSON, JSON coordinate arrays, AND null/empty `FSL__KML__c` (all verified). The valid internal `FSL__KML__c` structure is generated only by the FSL map tooling, so DML/`sf data create` is a dead end. (The fields exist — `FSL__KML__c`, `FSL__Color__c` (#hex), bounding box `FSL__Mi_La__c`/`FSL__Ma_La__c`/`FSL__Mi_Lo__c`/`FSL__Ma_Lo__c`, `FSL__Service_Territory__c` — but you can't insert them directly.)
- **✅ Supported creation paths — both in the Classic Dispatch Console → Map** (enable polygons first; the polygon tools live on the **Map**, not in Field Service Admin):
  1. **Draw**: Map → polygon/draw tool → click out the boundary on the map → assign it to a Service Territory. Good for one-off shapes.
  2. **Import Polygons in KML** (bulk / "bigger polygons"): Map → **Import KML** → upload a standard **OGC KML** file. The importer generates the valid `FSL__Polygon__c` records (this is why it works where Apex doesn't). Each `<Placemark>` becomes one polygon and is matched to a Service Territory (by the Placemark `<name>` / selection during import). This is the right path to create large or many boundaries at once.
- **KML file shape** (standard OGC KML; coordinates are **`lon,lat[,alt]`**, space-separated, ring should close first=last):
  ```xml
  <?xml version="1.0" encoding="UTF-8"?>
  <kml xmlns="http://www.opengis.net/kml/2.2"><Document>
    <Placemark><name>Kwitko Metro</name><Polygon><outerBoundaryIs><LinearRing><coordinates>
      -122.55,37.83,0 -122.35,37.83,0 -122.35,37.45,0 -122.55,37.45,0 -122.55,37.83,0
    </coordinates></LinearRing></outerBoundaryIs></Polygon></Placemark>
  </Document></kml>
  ```
  (KML import has a file-size / polygon-count limit — confirm the current value for your release. Source: Salesforce Help "Import Service Territory Polygons in KML" `service.pfs_import_kml.htm`, "Create and Manage Map Polygons" `service.pfs_map_polygons.htm`, "Enable Map Polygons" `service.pfs_map_polygons_enable.htm`.)
- **Net:** to make/replace big territory polygons, build a KML file with the boundary coordinates and **Import Polygons in KML** in the Map — do NOT attempt `FSL__Polygon__c` DML.

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
