@isTest
private class StaleOpportunitySweepServiceTest {

    @isTest static void flag_createsTaskAndNextStep_idempotent() {
        // LastModifiedDate can't be set in tests, so exercise the flag logic directly with a real opp.
        Account a = new Account(Name='Sweep Acct'); insert a;
        Opportunity o = new Opportunity(Name='Idle Deal', AccountId=a.Id, StageName='Prospecting',
            CloseDate=Date.today().addDays(30));   // no NextStep
        insert o;
        List<Opportunity> stale = [SELECT Id, Name, NextStep, OwnerId FROM Opportunity WHERE Id=:o.Id];

        Test.startTest();
        StaleOpportunitySweepService.SweepResult r1 = StaleOpportunitySweepService.flag(stale, 14);
        StaleOpportunitySweepService.SweepResult r2 = StaleOpportunitySweepService.flag(stale, 14); // idempotent
        Test.stopTest();

        System.assertEquals(1, r1.scanned);
        System.assertEquals(1, r1.flagged, r1.message);
        System.assertEquals(0, r2.flagged, 'second run must not duplicate the open task');
        System.assertEquals(1, [SELECT COUNT() FROM Task WHERE WhatId=:o.Id AND Subject='Stale opportunity — follow up']);
        System.assertNotEquals(null, [SELECT NextStep FROM Opportunity WHERE Id=:o.Id].NextStep);
    }

    @isTest static void action_runsSweepQuery() {
        // exercises the SOQL path of sweep() via the invocable (no stale data -> clean result)
        SweepStaleOpportunitiesAction.Result r =
            SweepStaleOpportunitiesAction.run(new List<SweepStaleOpportunitiesAction.Request>())[0];
        System.assertNotEquals(null, r.message);
    }

    @isTest static void sweep_noStale_returnsClean() {
        Account a = new Account(Name='Fresh Acct'); insert a;
        insert new Opportunity(Name='Fresh Deal', AccountId=a.Id, StageName='Prospecting', CloseDate=Date.today().addDays(30));
        Test.startTest();
        StaleOpportunitySweepService.SweepResult res = StaleOpportunitySweepService.sweep(14);
        Test.stopTest();
        System.assertEquals(0, res.flagged);
    }

    @isTest static void schedulable_runs() {
        Test.startTest();
        String cron = '0 0 6 * * ?';
        System.schedule('Stale Deal Sweeper Test', cron, new StaleOpportunitySweepSchedulable());
        Test.stopTest();
        System.assertEquals(1, [SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name='Stale Deal Sweeper Test']);
    }
}
