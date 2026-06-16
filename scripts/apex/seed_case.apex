/**
 * seed_case.apex — an open Case for the Case Service Agent to resolve (it can also open new ones itself).
 * Run:  sf apex run -o <org> -f scripts/apex/seed_case.apex
 */
Case c = new Case(Subject='Grinder making a loud noise', Description='Customer hears grinding noise on startup.', Status='New', Origin='Web');
insert c;
String num = [SELECT CaseNumber FROM Case WHERE Id=:c.Id].CaseNumber;

System.debug('============================================================');
System.debug('Talk to the Case Service Agent and say:');
System.debug('   "Open a case: my machine wont turn on"  (it creates one), or');
System.debug('   "Resolve case ' + c.Id + ' — replaced the power cord"');
System.debug('Case Number: ' + num + '  (Id: ' + c.Id + ')');
System.debug('============================================================');
