/**
 * seed_order.apex — an Account + product + Order with items for the Order / Commerce Concierge to look up & reorder.
 * Run:  sf apex run -o <org> -f scripts/apex/seed_order.apex
 */
Account a;
List<Account> al = [SELECT Id FROM Account WHERE Name='Demo Customer' LIMIT 1];
if (al.isEmpty()) { a = new Account(Name='Demo Customer'); insert a; } else { a = al[0]; }

Product2 p;
List<Product2> ps = [SELECT Id FROM Product2 WHERE Name='Bag of Coffee' LIMIT 1];
if (ps.isEmpty()) { p = new Product2(Name='Bag of Coffee', ProductCode='COFFEE-1', IsActive=true); insert p; } else { p = ps[0]; }

Id stdPb = [SELECT Id FROM Pricebook2 WHERE IsStandard=true LIMIT 1].Id;
PricebookEntry pbe;
List<PricebookEntry> pbes = [SELECT Id FROM PricebookEntry WHERE Pricebook2Id=:stdPb AND Product2Id=:p.Id LIMIT 1];
if (pbes.isEmpty()) { pbe = new PricebookEntry(Pricebook2Id=stdPb, Product2Id=p.Id, UnitPrice=20, IsActive=true); insert pbe; } else { pbe = pbes[0]; }

Order o = new Order(AccountId=a.Id, EffectiveDate=Date.today(), Status='Draft', Pricebook2Id=stdPb);
insert o;
insert new OrderItem(OrderId=o.Id, Product2Id=p.Id, PricebookEntryId=pbe.Id, Quantity=2, UnitPrice=20);
String num = [SELECT OrderNumber FROM Order WHERE Id=:o.Id].OrderNumber;

System.debug('============================================================');
System.debug('Talk to the Order Concierge and say:');
System.debug('   "What is the status of order ' + num + '?"  then  "Reorder it"');
System.debug('Order Number: ' + num + '  (Id: ' + o.Id + ')');
System.debug('============================================================');
