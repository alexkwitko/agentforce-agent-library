@isTest
private class AccountInsightsServiceTest {

    @isTest static void brief_rollsUpSignals() {
        Account a = new Account(Name='Brief Co'); insert a;
        insert new Contact(LastName='Buyer', AccountId=a.Id);
        insert new Case(AccountId=a.Id, Subject='Open issue', Status='New');
        insert new Opportunity(Name='Deal', AccountId=a.Id, StageName='Prospecting',
            CloseDate=Date.today().addDays(30), Amount=10000);

        Test.startTest();
        SummarizeAccountAction.Request req = new SummarizeAccountAction.Request(); req.accountId = a.Id;
        SummarizeAccountAction.Result r = SummarizeAccountAction.run(new List<SummarizeAccountAction.Request>{ req })[0];
        Test.stopTest();

        System.assertEquals(true, r.found, r.message);
        System.assertEquals(1, r.openCases);
        System.assertEquals(1, r.openOpportunities);
        System.assert(r.message.contains('Brief Co'), r.message);
    }

    @isTest static void guards() {
        System.assertEquals(false, AccountInsightsService.brief(null).found);
    }
}
