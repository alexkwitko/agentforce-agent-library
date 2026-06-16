/**
 * seed_account.apex — an Account with a case + opportunity for the Account 360 Copilot to brief.
 * Run:  sf apex run -o <org> -f scripts/apex/seed_account.apex
 */
Account a;
List<Account> al = [SELECT Id FROM Account WHERE Name='Demo Customer' LIMIT 1];
if (al.isEmpty()) { a = new Account(Name='Demo Customer'); insert a; } else { a = al[0]; }

if ([SELECT COUNT() FROM Contact WHERE AccountId=:a.Id] == 0) insert new Contact(LastName='Demo Buyer', AccountId=a.Id);
if ([SELECT COUNT() FROM Case WHERE AccountId=:a.Id AND IsClosed=false] == 0)
    insert new Case(AccountId=a.Id, Subject='Demo open issue', Status='New', Origin='Web');
if ([SELECT COUNT() FROM Opportunity WHERE AccountId=:a.Id AND IsClosed=false] == 0)
    insert new Opportunity(Name='Demo Pipeline Deal', AccountId=a.Id, StageName='Prospecting',
        CloseDate=Date.today().addDays(30), Amount=15000);

System.debug('============================================================');
System.debug('Talk to the Account 360 Copilot and say:');
System.debug('   "Brief me on account ' + a.Id + '"');
System.debug('Account ID: ' + a.Id);
System.debug('============================================================');
