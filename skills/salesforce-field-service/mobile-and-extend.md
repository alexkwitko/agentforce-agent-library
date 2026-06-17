# Field Service — Mobile App & Extend Products

What's part of base FSL vs separately licensed. The mobile app, offline priming, Briefcase, push, and core shift objects are **part of FSL**. **Appointment Assistant, Visual Remote Assistant, Workforce Engagement, Salesforce Scheduler, and Agentforce** are **separate licenses**.

## 1. Field Service MOBILE APP (iOS/Android)
Native app "Salesforce Field Service" — **offline-first**; the field-facing client (console + scheduling stay on desktop).

**Two licensing layers (the #1 gotcha):**
- **Field Service Mobile** PSL → log into the app.
- **Field Service Scheduling** PSL → be scheduled / appear on the Gantt.
- A mobile worker (a `ServiceResource` type Technician) typically needs **both**.

**Standard perm set:** **`FieldServiceMobileStandardPermSet`** ("Field Service Mobile — Standard Permissions") — assign for the object/field access the app needs. Help: `service.mfs_perms_standard.htm`.

**Setup:**
1. Enable Field Service + install the managed package (adds geolocation, push, mobile app-settings).
2. Configure the **Field Service connected app** — required for push + Briefcase/offline transport.
3. Assign yourself **Field Service Admin Permissions**.
4. Guided Setup → **Create Service Resources**: pick the user, assign a territory, assign **both Scheduling + Mobile** licenses.
5. **Share the worker their own `ServiceResource` record (Read Only)** so the app can resolve "me".
6. Assign `FieldServiceMobileStandardPermSet` (+ resource perm sets).
7. **Field Service Mobile Settings** (Setup): branding, the **date-picker range** (Future/Past Days, default ~45 — drop to ~7/7 to speed priming), quick actions, required fields.
8. Push: Field Service Settings → Notifications → **Enable notifications** (`service.mfs_push_notifications.htm`).

**Offline — two mechanisms (don't confuse):**
- **Offline Priming** (built into the app) — auto pre-downloads the worker's assigned appointments + related records within the date window; supports queued offline actions. Tuned by the date range in Field Service Mobile Settings (`service.mfs_offline_parent.htm`).
- **Briefcase Builder** (Setup → Briefcase Builder → New) — declaratively pushes *extra* records offline beyond priming: a set of objects + filter criteria (≤10 filters, use **indexed fields**, Order By Sysmodstamp, ≥1 filter/object) assigned to users/groups. Needs the connected app.

Mobile workers update SA status (Dispatched → Traveling → On Site → Completed), capture notes/photos/signatures, add Products Consumed, run flows — offline-capable. Geolocation feeds the dispatcher + Appointment Assistant. Trailhead: `field-service-mobile`, `offline-briefcase`.

## 2. APPOINTMENT ASSISTANT — separate managed package (`FSA` namespace)
Customer-experience add-on; flagship feature **Real-Time Location**. Separately licensed.
- **Real-Time Location notifications** when the worker is en route (email / **SMS** / **WhatsApp**).
- **Live tracking + ETA on a map** (customer clicks a link, watches the worker approach).
- **"Arriving soon" / within-a-mile alert**.
- **Customer self-service** — accept a proposed schedule, adjust the time, or cancel.

**Setup:** (1) install from the same hub (`fsl.secure.force.com/install` → Appointment Assistant; or the d36…/install launcher) — incognito, Install for Admins Only, **approve third-party geolocation/optimization access**; (2) create a permission set, set its **License = Field Service Appointment Assistant**, enable the **Field Service Appointment Assistant** system permission; (3) assign to users; (4) configure the **Customer Journey** (channels + accept/adjust/cancel flow + tracking page). **Won't work with Trailhead Playground sample data** — needs a real org. Trailhead: `real-time-location-appointment-assistant`; install help `service.mfs_appointment_assistant_install_packages.htm`.

## 3. Visual Remote Assistant (separate license)
Live video / see-what-the-customer-sees with on-screen annotation — deflect truck rolls / assist field techs remotely. Requires Service Cloud or Field Service **+ a Visual Remote Assistant license**; Lightning Experience; install the managed package + configure perm sets. Help: `service.fs_intro_visual_assistance.htm`.

## 4. Workforce Engagement / shift scheduling (separate license)
Service Cloud Workforce Engagement (WFE) — forecast demand → recommend coverage → create/assign **shifts**. Shares the shift engine FSL uses but is a **separate add-on license**. Data model: `Shift`, `ShiftSegment`, `ShiftPattern`, `ShiftTemplate`, tied to `ServiceResource`. **Don't conflate** Field Service shifts ≠ WFE ≠ Salesforce Scheduler (three separate scheduling products). Help: `service.workforce_engagement_about_shift_scheduling_tools.htm`, `sf.fs_shifts_view.htm`.

## 5. Agentforce for Field Service (AI layer)
Built into the FS mobile app: **Pre-Work Brief** (audio work-order summary), **Knowledge Search** (NL search across Knowledge + bulletins + prior WOs → AI troubleshooting steps), **Post-Work Summary** (drafts the report, can schedule follow-ups), Siri-shortcut/voice access, and AI dispatch/scheduling. Rides on the Agentforce platform (separate consumption license). See the **salesforce-agentforce** skill.

## Gotchas
- **Two-layer mobile licensing**: Mobile PSL (login) ≠ Scheduling PSL (appears on Gantt) — a working tech needs both.
- **Resource must read itself** — share the worker their own `ServiceResource` (Read Only) or the app misbehaves.
- **Connected app is mandatory** for push + Briefcase/offline; both silently fail without it.
- **Priming ≠ Briefcase** — priming is auto/app-built (date-range tuned); Briefcase is admin-defined extra records.
- **Date-picker defaults ~45 days** → slow initial priming; drop to ~7/7.
- **Appointment Assistant**: install incognito, Admins Only, approve third-party access; doesn't work on TP sample data.
- **Three scheduling products** with overlapping shift concepts (Field Service / WFE / Salesforce Scheduler) — confirm which the org owns.
- **Separate licenses**: Appointment Assistant (FSA), Visual Remote Assistant, Workforce Engagement, Salesforce Scheduler, Agentforce — NOT part of base FSL.

Help slugs: `service.mfs_perms_standard.htm`, `service.fs_perm_set_licenses.htm`, `service.mfs_offline_parent.htm`, `service.mfs_push_notifications.htm`, `service.mfs_appointment_assistant_install_packages.htm`, `service.fs_intro_visual_assistance.htm`, `service.workforce_engagement_about_shift_scheduling_tools.htm`. Trailhead: `field-service-mobile`, `offline-briefcase`, `real-time-location-appointment-assistant`, `visual-remote-assistant`, `shift-creation-assignment`.
