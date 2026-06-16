---
name: salesforce-d2c-setup
description: Use when setting up, configuring, or troubleshooting a Salesforce D2C (or B2B) Commerce store — WebStore/catalog/categories/pricebooks, product images (the CMS multipart upload), payment + shipping + tax integrations (mock or real), inventory, buyer groups + entitlement, buyer/Person-Account provisioning, guest browsing + guest checkout, the LWR storefront site (Experience Builder head markup, public access), the Commerce search index, and end-to-end checkout verification. DX/CLI-first with the exact metadata shapes, Connect/REST API bodies, Apex patterns, and hard-won gotchas (including what is genuinely Setup-UI-only).
---

# Salesforce D2C Commerce Setup Playbook

Practical, **DX-first** playbook for standing up a Salesforce **D2C (or B2B) Commerce** store end to end. Drawn from a real build (a coffee-equipment D2C store, "Bean & Brew"); the patterns apply to any catalog. Substitute your own products/brand.

## #0 rule: Official-first, standard components, no Frankenstein
Use the **standard Commerce (LWR) template + standard components** (product list, PDP, cart, checkout, search). Customize via theming + the standard component config, not a custom ecommerce build. Find the official Salesforce mechanism for each requirement (Commerce store, OrderDeliveryMethod, CommercePayments, entitlement policies, Guest Buyer Profile) and use it before hand-rolling Apex/custom objects.

## #1 rule: DX/CLI/API first, UI last
Order for every task:
1. **`sf` CLI** — `sf project deploy/retrieve`, `sf data`, `sf apex run`.
2. **Connect/REST API via CLI** — `sf api request rest "/services/data/v62.0/..."` (uses the stored session even though the raw token is hidden).
3. **Metadata XML deploy** (mdapi when source-format type inference fails).
4. **Apex self-callout** (for APIs with no `sf api` path, e.g. multipart uploads).
5. **Browser/Setup UI** — last resort. To drive the org UI headlessly **without a password**, use `sf org open --path "<lightning path>" --url-only` → navigate the browser to that frontdoor URL (auto-authenticates with the CLI token). `sf org display` **redacts** the access token (returns a 54-char placeholder), so raw `curl -H "Authorization: Bearer ..."` 401s — use `sf api request rest` or the Apex session instead.

---

## 1. Store + data model (the spine)
Core objects: `WebStore`, `ProductCatalog`, `ProductCategory`, `ProductCategoryProduct` (product→category junction), `Product2`, `PricebookEntry` (standard + the store's pricebook → `WebStorePricebook`), `BuyerGroup`, `CommerceEntitlementPolicy`, `CommerceEntitlementBuyerGroup` (policy↔group), `WebStoreBuyerGroup` (store↔group), `WebStoreCatalog` (store↔catalog).

- The standard **"Commerce Store (LWR)"** template in some orgs is **B2B-only** (no separate D2C template); the D2C distinction is buyer access + guest, not a different template. Create the store from the standard template either way.
- Products need a `PricebookEntry` in **both** the standard pricebook and the **store pricebook** to be sellable. (8 products × 2 = 16 entries in the reference build.)
- Add products to a category via `ProductCategoryProduct(ProductCategoryId, ProductId)`; rebuild the search index afterward (see §8).
- `Product2` images are NOT a URL field — see §3.

## 2. Catalog distinct from other stores
If one org hosts multiple brands/stores, keep catalogs distinct: separate `Product2` SKUs per brand, add only the brand's products to that store's category, and (if a category was shared) remove the other brand's `ProductCategoryProduct` rows. Use a `Brand__c` picklist on `Order`/`Web_Event__c` as a *dimension* (not a separate identity) when you want one unified customer across brands.

## 3. Product images — the hard part (CMS multipart upload)
`ProductMedia` (the image link) requires `ProductId` + `ElectronicMediaId` (→ **`ManagedContent`**, required) + `ElectronicMediaGroupId`. Gotchas that cost the most time:
- `ManagedContent` is **NOT DML-createable**; `ManagedContentVersion` is **not an SObject**. Images must be created through the **Connect CMS API**.
- The CMS `source.ref` will **NOT** accept a `ContentDocument`/`ContentVersion` Id ("This image reference isn't available").
- The standard media groups already exist per store: query `ElectronicMediaGroup` — you'll find **Tile Image, Product List Image, Product Detail Images** (+ Banner, Attachments). Reuse them; `ElectronicMediaGroup` is not createable.
- CMS workspace = `ManagedContentSpace` (query `SELECT Id, Name FROM ManagedContentSpace`).

**Winning create recipe** (`POST /connect/cms/contents`, multipart):
- JSON part named `content`: `{"contentSpaceOrFolderId":"<spaceId>","title":"...","urlName":"img-...","contentType":"sfdc_cms__image","contentBody":{"sfdc_cms:media":{"source":{"type":"file"}}}}`
  - `source.type` **must be the constant `"file"`**; do **NOT** include `ref` and do **NOT** include `sfdc_cms:altText` (both rejected with `additionalProperties` errors).
- Binary part named **exactly `contentData`** (the API demands this name regardless of `ref`), with `filename` + `Content-Type: image/png`.
- **Order matters**: content part FIRST, then the `contentData` binary part.

**How to send multipart headlessly** (`sf api request rest` can't do multipart; the token is redacted): build the whole multipart body in **Python**, base64 it, and POST from **Apex self-callout**:
- Add a `RemoteSiteSetting` for the org My-Domain (deploy as **mdapi** — source-format `.remoteSiteSetting-meta.xml` throws `TypeInferenceError`; use a `package.xml` + mdapi dir).
- Apex: `req.setEndpoint('https://<mydomain>.my.salesforce.com/services/data/v62.0/connect/cms/contents'); req.setHeader('Authorization','Bearer '+UserInfo.getSessionId()); req.setHeader('Content-Type','multipart/form-data; boundary=...'); req.setBodyAsBlob(EncodingUtil.base64Decode(b64));`
- **Anonymous-apex script cap ≈ 1MB** → upload **one image per run** (a batch of 8 base64 bodies = 207KB and still failed "Script too large" when combined with maps; loop one at a time, ~25KB each).
- Generate images with **Pillow** (available locally) — clean branded PNGs render fine.

**Then link + publish:**
- `ProductMedia` IS DML-createable: `insert new ProductMedia(ProductId=p, ElectronicMediaId=managedContentId, ElectronicMediaGroupId=<group>, SortOrder=n)` — one per group (List/Detail/Tile = 3 per product).
- Publish the content: `POST /connect/cms/contents/publish` body `{"contentIds":[...]}` (field is **`contentIds`**, not `managedContentIds`/`ids`). Returns a `deploymentId` / `#DEPLOYED`.
- Verify per product via `GET /services/data/v62.0/commerce/webstores/{webStoreId}/products/{productId}` → `defaultImage.url` populated + `mediaGroups`. The product **search** API (`POST .../search/product-search`) is what the LIST page reads — confirm it returns `defaultImage` too.
- Direct media URLs require the storefront session; a bare-domain `curl` 301→404s to the wrong site — that's expected, not a defect.

## 4. Payment (mock for demo, real otherwise)
- Mock: an Apex `CommercePayments.PaymentGatewayAdapter` that always approves. `PaymentGatewayProvider` **can't be inserted via Apex DML** — create with `sf data create record`. Then `PaymentGateway` + a `NamedCredential`.
- Wire to the store: `StoreIntegratedService(StoreId, ServiceProviderType='Payment', Integration=<PaymentGateway.Id>)`. Verify: `SELECT ServiceProviderType, Integration FROM StoreIntegratedService WHERE StoreId='...'`.

## 5. Shipping
- `OrderDeliveryMethod` (e.g. "Standard Shipping", `IsActive=true`). The standard checkout can use a flat delivery method without a custom Apex shipping service. For dynamic rates, register a shipping integration like tax (§6).

## 6. Tax (mock = a real store-completeness win)
- Apex `class BeanBrewMockTax implements sfdc_checkout.CartTaxCalculations { IntegrationStatus startCartProcessAsync(IntegrationInfo, Id cartId) {...} }` — compute e.g. 8% per `CartItem`, write `CartTax` rows.
- **Gotcha**: `sfdc_checkout.IntegrationStatus` has **no `message` field** — set only `.status` (`SUCCESS`/`FAILED`); log errors via `System.debug`.
- Register: `RegisteredExternalService(DeveloperName, MasterLabel, ExternalServiceProviderType='Tax', ExternalServiceProviderId=<ApexClass.Id>)` then `StoreIntegratedService(StoreId, ServiceProviderType='Tax', Integration=<RegisteredExternalService.Id>)`. Both ARE Apex-DML-creatable. `StoreIntegratedService.ServiceProviderType` enum: Flow, Price, Promotions, Inventory, Shipment, Tax, Payment, Extension.

## 7. Inventory / supply chain
- `ProductInventory`/OCI is a separate (heavy, often UI-gated) enablement. **Without it, products sell as available by default** — fine for demos.
- For Woo-style stock parity, seed `Product2.Stock_On_Hand__c` (this field often already exists from a Woo sync). It's a data layer, not a hard checkout block unless OCI is on.

## 8. Search index
- Rebuild after catalog/category/image/entitlement changes: `POST /services/data/v62.0/commerce/management/webstores/{id}/search/indexes` body `{}`. Poll `GET` the same endpoint until `indexStatus != "InProgress"` (≈2–5 min). The LIST page reads the index; PDP reads live.

## 9. Buyers + entitlement (authenticated)
- A buyer = `Account` → `BuyerAccount(BuyerId, BuyerStatus='Active', IsActive=true)` → `BuyerGroupMember(BuyerGroupId, BuyerId)`. **`BuyerStatus` defaults to `Pending` — must be `Active`** or carts fail "Invalid effective accountId."
- D2C buyers are **Person Accounts**.
- The store's buyer group must have an **active `CommerceEntitlementPolicy`** (`CanViewProduct`/`CanViewPrice`=true) linked via `CommerceEntitlementBuyerGroup`, and the group linked to the store via `WebStoreBuyerGroup`. The note in Setup: "each assigned buyer group must have at least one active entitlement."
- **REST cart as internal admin doesn't work**: `POST /commerce/webstores/{id}/carts?effectiveAccountId=X` returns "Invalid effective accountId" even for a valid Active buyer — D2C checkout runs in the **shopper's storefront session** (guest or community user), not an admin REST context. To prove checkout, use the live storefront.

## 10. Guest browsing + guest checkout (the saga)
1. **Site public access**: in the site's `DigitalExperienceBundle`, `sfdc_cms__site/<site>/content.json` → `contentBody.authenticationType` must be **`AUTHENTICATED_WITH_PUBLIC_ACCESS_ENABLED`** (valid enum; NOT `AUTHENTICATED_AND_ANONYMOUS`). Deploy (mdapi) + `sf community publish --name "<site>"`.
2. **WebStore flags** (Apex updateable): `OptionsGuestBrowsingEnabled`, `OptionsGuestCartEnabled`, `OptionsGuestCheckoutEnabled`, `OptionsPreserveGuestCartEnabled`; `GuestBuyerProfileId` (object prefix `3K0`, only Id/Name queryable).
3. **CRITICAL — run the official Guest Access automation in Setup UI**: Commerce app → Store → **Settings → Store → Buyer Access tab → Guest Access → Disable → Enable → Continue**. This is the step that **assigns object permissions to the guest profile**, creates the Guest Buyer Profile, sets person-account default, and sets Experience-Builder public access. **Setting the WebStore flags via Apex does NOT run this automation** — the UI banner literally says "Click Disable and then Enable to run the full automation." There is **no headless API** for the guest entitlement/permission assignment.
4. Confirm Store Access → Buyer Groups = your buyer group (re-assigning errors as a duplicate = it's wired).
5. Rebuild the search index; **guest catalog visibility can lag** (entitlement + index recalc; minutes to hours in a Dev Edition org). Even with a complete, correct setup the guest grid may stay empty for a while — verify in an authenticated session meanwhile.
- Drive all the Setup-UI steps headlessly via the `sf org open --url-only` frontdoor (no password).

## 11. Storefront site config (head markup / analytics beacon)
- LWR "Head Markup" (Experience Builder → Settings → Advanced) lives in the bundle at `digitalExperiences/site/<site>/sfdc_cms__appPage/mainAppPage/content.json` → `contentBody.headMarkup`. You can inject a script (e.g. a Data Cloud Web SDK beacon) there, deploy the focused `DigitalExperienceBundle` (mdapi, members `site/<site>` + `content/<space>`), then `sf community publish`. Retrieve with `sf project retrieve start -m DigitalExperienceBundle --target-metadata-dir ...`.
- Publish is async ("you'll get an email"); a row-lock `OracleRowLockedException` means two publishes collided — run ONE `sf community publish` at a time.

## 12. End-to-end verification
- Storefront HTTP 200 + product APIs return images/prices.
- Authenticated buyer: products + images + price + cart + checkout (payment+shipping+tax lines) → Order.
- Order → downstream (e.g. Field Service WO/SA) if serviceable products exist — see the **salesforce-field-service** skill.

## Gotcha quick list
- `sf org display` redacts the token → use `sf api request rest` / Apex session.
- `ManagedContent` not DML-able; CMS image = multipart `contentData` part, `source.type:"file"` no `ref`, no `altText`, content part first.
- Anonymous apex ≈1MB cap → one image upload per run.
- `RemoteSiteSetting` source-format fails type inference → deploy mdapi.
- `IntegrationStatus` has no `message` field.
- `BuyerAccount.BuyerStatus` defaults Pending → set Active.
- `authenticationType` enum = `AUTHENTICATED` | `UNAUTHENTICATED` | `AUTHENTICATED_WITH_PUBLIC_ACCESS_ENABLED`.
- Guest object-permission assignment is the **Disable→Enable Guest Access automation** (UI-only); Apex flags don't trigger it.
- REST cart with `effectiveAccountId` fails for internal-admin context; checkout needs the shopper session.
- `sf org open --url-only` = headless org-UI auth with no password.
