@isTest
private class OpportunityCoachServiceTest {

    private static Opportunity makeOpp(String stage, Date close, String nextStep, Decimal prob) {
        Account a = new Account(Name='Coach Acct'); insert a;
        Opportunity o = new Opportunity(Name='Big Deal', AccountId=a.Id, StageName=stage,
            CloseDate=close, NextStep=nextStep, Amount=50000, Probability=prob);
        insert o;
        return o;
    }

    @isTest static void summarize_and_recommend_paths() {
        // no next step -> recommend defining one
        Opportunity o1 = makeOpp('Prospecting', Date.today().addDays(30), null, 10);
        SummarizeOpportunityAction.Request req = new SummarizeOpportunityAction.Request(); req.opportunityId = o1.Id;
        SummarizeOpportunityAction.Result r = SummarizeOpportunityAction.run(new List<SummarizeOpportunityAction.Request>{ req })[0];
        System.assertEquals(true, r.found, r.message);
        System.assert(r.recommendation.containsIgnoreCase('next step'), r.recommendation);

        // past close date -> slipping
        Opportunity o2 = makeOpp('Negotiation', Date.today().addDays(-5), 'Send contract', 60);
        System.assert(OpportunityCoachService.summarize(o2.Id).recommendation.containsIgnoreCase('passed'));

        // high probability -> closing plan
        Opportunity o3 = makeOpp('Negotiation', Date.today().addDays(10), 'Final review', 80);
        System.assert(OpportunityCoachService.summarize(o3.Id).recommendation.containsIgnoreCase('commitment'));

        // guards
        System.assertEquals(false, OpportunityCoachService.summarize(null).found);
    }

    @isTest static void setNextStep_updatesAndLogsTask() {
        Opportunity o = makeOpp('Prospecting', Date.today().addDays(30), null, 10);
        Test.startTest();
        SetOpportunityNextStepAction.Request req = new SetOpportunityNextStepAction.Request();
        req.opportunityId = o.Id; req.nextStep = 'Book discovery call with economic buyer';
        SetOpportunityNextStepAction.Result res = SetOpportunityNextStepAction.run(new List<SetOpportunityNextStepAction.Request>{ req })[0];
        Test.stopTest();
        System.assertEquals(true, res.success, res.message);
        System.assertEquals('Book discovery call with economic buyer', [SELECT NextStep FROM Opportunity WHERE Id=:o.Id].NextStep);
        System.assertEquals(1, [SELECT COUNT() FROM Task WHERE WhatId=:o.Id]);
        System.assertEquals(false, OpportunityCoachService.setNextStep(null, 'x').success);
    }
}
