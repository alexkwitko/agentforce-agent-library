/**
 * seed_opportunity.apex — an open Opportunity for the Sales Opportunity Coach to review.
 * Run:  sf apex run -o <org> -f scripts/apex/seed_opportunity.apex
 */
Account a;
List<Account> al = [SELECT Id FROM Account WHERE Name='Demo Customer' LIMIT 1];
if (al.isEmpty()) { a = new Account(Name='Demo Customer'); insert a; } else { a = al[0]; }

Opportunity o = new Opportunity(Name='Demo Expansion Deal', AccountId=a.Id,
    StageName='Prospecting', CloseDate=Date.today().addDays(20), Amount=25000);
insert o;

System.debug('============================================================');
System.debug('Talk to the Sales Opportunity Coach and say:');
System.debug('   "Review opportunity ' + o.Id + '"  then  "Set the next step to: book a discovery call"');
System.debug('Opportunity ID: ' + o.Id);
System.debug('============================================================');
