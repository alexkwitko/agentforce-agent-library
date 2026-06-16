/**
 * seed_field_service.apex — idempotent demo data + customizable org config for the Field Service agents.
 * Run:  sf apex run -o <org> -f scripts/apex/seed_field_service.apex
 *
 * ┌──────────────────────────────────────────────────────────────────────────┐
 * │ CONFIG — edit these to match your business, then re-run.                    │
 * └──────────────────────────────────────────────────────────────────────────┘
 */
String TERRITORY_NAME = 'Demo Territory';        // your service territory / region
String TIMEZONE       = 'America/Chicago';       // operating-hours time zone
String RESOURCE_NAME  = 'Demo Technician';       // the service resource (technician)
String SKILL_NAME     = 'Espresso Installation'; // a skill the work requires (optional)
String PRODUCT_NAME   = 'Espresso Machine Installation';
Decimal PRODUCT_PRICE = 1499;
// (Slot hours / business days are configured in FieldServiceSchedulingService: SLOT_HOURS, DAYS_TO_SCAN.)

// --- Field Service foundation ---------------------------------------------------
OperatingHours oh;
List<OperatingHours> ohs = [SELECT Id FROM OperatingHours WHERE Name = 'Demo Hours' LIMIT 1];
if (ohs.isEmpty()) { oh = new OperatingHours(Name='Demo Hours', TimeZone=TIMEZONE); insert oh; } else { oh = ohs[0]; }

ServiceTerritory st;
List<ServiceTerritory> sts = [SELECT Id FROM ServiceTerritory WHERE Name = :TERRITORY_NAME LIMIT 1];
if (sts.isEmpty()) { st = new ServiceTerritory(Name=TERRITORY_NAME, OperatingHoursId=oh.Id, IsActive=true); insert st; } else { st = sts[0]; }

ServiceResource sr;
List<ServiceResource> srs = [SELECT Id FROM ServiceResource WHERE Name = :RESOURCE_NAME LIMIT 1];
if (srs.isEmpty()) { sr = new ServiceResource(Name=RESOURCE_NAME, IsActive=true, ResourceType='T', RelatedRecordId=UserInfo.getUserId()); insert sr; } else { sr = srs[0]; }

if ([SELECT COUNT() FROM ServiceTerritoryMember WHERE ServiceTerritoryId=:st.Id AND ServiceResourceId=:sr.Id] == 0) {
    insert new ServiceTerritoryMember(ServiceTerritoryId=st.Id, ServiceResourceId=sr.Id, TerritoryType='P', EffectiveStartDate=System.now().addDays(-1));
}

// Skills (optional — wrapped in try/catch so the seed never fails if Skills aren't configured)
try {
    List<Skill> sk = [SELECT Id FROM Skill WHERE MasterLabel = :SKILL_NAME LIMIT 1];
    if (!sk.isEmpty() && [SELECT COUNT() FROM ServiceResourceSkill WHERE ServiceResourceId=:sr.Id AND SkillId=:sk[0].Id] == 0) {
        insert new ServiceResourceSkill(ServiceResourceId=sr.Id, SkillId=sk[0].Id, EffectiveStartDate=System.now().addDays(-1));
    }
} catch (Exception e) { System.debug('Skill assignment skipped: ' + e.getMessage()); }

// --- Serviceable product on the standard pricebook -----------------------------
Product2 p;
List<Product2> ps = [SELECT Id FROM Product2 WHERE Name=:PRODUCT_NAME LIMIT 1];
if (ps.isEmpty()) { p = new Product2(Name=PRODUCT_NAME, ProductCode='FS-INSTALL', IsActive=true, Requires_Field_Service__c=true); insert p; } else { p = ps[0]; }

Id stdPb = [SELECT Id FROM Pricebook2 WHERE IsStandard=true LIMIT 1].Id;
PricebookEntry pbe;
List<PricebookEntry> pbes = [SELECT Id FROM PricebookEntry WHERE Pricebook2Id=:stdPb AND Product2Id=:p.Id LIMIT 1];
if (pbes.isEmpty()) { pbe = new PricebookEntry(Pricebook2Id=stdPb, Product2Id=p.Id, UnitPrice=PRODUCT_PRICE, IsActive=true); insert pbe; } else { pbe = pbes[0]; }

// --- Customer + Order ----------------------------------------------------------
Account a;
List<Account> al = [SELECT Id FROM Account WHERE Name='Demo Customer' LIMIT 1];
if (al.isEmpty()) { a = new Account(Name='Demo Customer'); insert a; } else { a = al[0]; }

Order o = new Order(AccountId=a.Id, EffectiveDate=Date.today(), Status='Draft', Pricebook2Id=stdPb);
insert o;
insert new OrderItem(OrderId=o.Id, Product2Id=p.Id, PricebookEntryId=pbe.Id, Quantity=1, UnitPrice=PRODUCT_PRICE);

System.debug('============================================================');
System.debug('FIELD SERVICE DEMO READY. Talk to the Field Service Scheduler and say:');
System.debug('   "Schedule the installation for order ' + o.Id + '"');
System.debug('Order ID: ' + o.Id);
System.debug('============================================================');
