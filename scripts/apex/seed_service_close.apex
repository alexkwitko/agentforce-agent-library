/**
 * seed_service_close.apex — a Scheduled ServiceAppointment ready for the Service Appointment Closer to close.
 * Run:  sf apex run -o <org> -f scripts/apex/seed_service_close.apex
 * Reuses the Field Service foundation (run seed_field_service.apex first, or this creates its own).
 */
OperatingHours oh;
List<OperatingHours> ohs = [SELECT Id FROM OperatingHours WHERE Name='Demo Hours' LIMIT 1];
if (ohs.isEmpty()) { oh = new OperatingHours(Name='Demo Hours', TimeZone='America/Chicago'); insert oh; } else { oh = ohs[0]; }

ServiceTerritory st;
List<ServiceTerritory> sts = [SELECT Id FROM ServiceTerritory WHERE Name='Demo Territory' LIMIT 1];
if (sts.isEmpty()) { st = new ServiceTerritory(Name='Demo Territory', OperatingHoursId=oh.Id, IsActive=true); insert st; } else { st = sts[0]; }

Account a;
List<Account> al = [SELECT Id FROM Account WHERE Name='Demo Customer' LIMIT 1];
if (al.isEmpty()) { a = new Account(Name='Demo Customer'); insert a; } else { a = al[0]; }

WorkOrder wo = new WorkOrder(AccountId=a.Id, Subject='Demo visit to close', Status='In Progress', ServiceTerritoryId=st.Id);
insert wo;
ServiceAppointment sa = new ServiceAppointment(
    ParentRecordId=wo.Id, Status='Scheduled', Subject='Demo appointment', ServiceTerritoryId=st.Id,
    SchedStartTime=System.now().addHours(-2), SchedEndTime=System.now().addHours(-1),
    EarliestStartTime=System.now().addDays(-1), DueDate=System.now().addDays(7));
insert sa;

System.debug('============================================================');
System.debug('Talk to the Service Appointment Closer and say:');
System.debug('   "Close appointment ' + sa.Id + ' — installed and tested, all good"');
System.debug('ServiceAppointment ID: ' + sa.Id);
System.debug('============================================================');
