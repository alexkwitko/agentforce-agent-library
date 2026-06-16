@isTest
private class LeadQualifierServiceTest {

    @isTest static void qualify_ratesAndTasksHotLeads() {
        // complete lead -> Hot (email+phone+company+industry)
        Lead hot = new Lead(LastName='Rich', Company='Acme', Email='r@acme.com', Phone='555', Industry='Technology');
        // sparse lead -> Cold (company only)
        Lead cold = new Lead(LastName='Sparse', Company='Tiny');
        insert new List<Lead>{ hot, cold };
        List<Lead> leads = [SELECT Id, FirstName, LastName, Company, Email, Phone, Industry, Rating, Status, OwnerId FROM Lead];

        Test.startTest();
        LeadQualifierService.QualifyResult r1 = LeadQualifierService.qualify(leads);
        LeadQualifierService.QualifyResult r2 = LeadQualifierService.qualify(leads); // idempotent tasks
        Test.stopTest();

        System.assertEquals(2, r1.scanned, r1.message);
        System.assertEquals(1, r1.hot, 'one hot lead');
        System.assertEquals('Hot', [SELECT Rating FROM Lead WHERE Id=:hot.Id].Rating);
        System.assertEquals('Cold', [SELECT Rating FROM Lead WHERE Id=:cold.Id].Rating);
        System.assertEquals(1, [SELECT COUNT() FROM Task WHERE WhoId=:hot.Id AND Subject='Hot lead — reach out today'],
            'one follow-up task, not duplicated');
    }

    @isTest static void sweep_andAction_run() {
        insert new Lead(LastName='Solo', Company='Co', Email='s@co.com', Phone='1', Industry='Retail');
        Test.startTest();
        QualifyLeadsAction.Result r = QualifyLeadsAction.run(new List<QualifyLeadsAction.Request>())[0];
        Test.stopTest();
        System.assert(r.scanned >= 1, r.message);
    }

    @isTest static void schedulable_runs() {
        Test.startTest();
        System.schedule('Lead Qualifier Test', '0 0 7 * * ?', new LeadQualifierSchedulable());
        Test.stopTest();
        System.assertEquals(1, [SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name='Lead Qualifier Test']);
    }
}
