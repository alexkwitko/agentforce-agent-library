@isTest
private class CaseServiceServiceTest {

    @isTest static void logAndResolve_case() {
        Test.startTest();
        LogCaseAction.Request lreq = new LogCaseAction.Request();
        lreq.subject = 'Machine not heating';
        lreq.description = 'Customer reports no hot water.';
        LogCaseAction.Result lr = LogCaseAction.run(new List<LogCaseAction.Request>{ lreq })[0];
        System.assertEquals(true, lr.success, lr.message);
        System.assertNotEquals(null, lr.caseId);

        ResolveCaseAction.Request rreq = new ResolveCaseAction.Request();
        rreq.caseId = lr.caseId;
        rreq.resolution = 'Replaced the heating element; verified hot water.';
        ResolveCaseAction.Result rr = ResolveCaseAction.run(new List<ResolveCaseAction.Request>{ rreq })[0];
        Test.stopTest();

        System.assertEquals(true, rr.success, rr.message);
        System.assertEquals('Closed', rr.status);
        Case c = [SELECT Status FROM Case WHERE Id = :lr.caseId];
        System.assertEquals('Closed', c.Status);
        System.assertEquals(1, [SELECT COUNT() FROM CaseComment WHERE ParentId = :lr.caseId]);
    }

    @isTest static void guards() {
        CaseServiceService.LogResult blank = CaseServiceService.logCase('  ', 'x');
        System.assertEquals(false, blank.success);
        CaseServiceService.ResolveResult none = CaseServiceService.resolveCase(null, 'x');
        System.assertEquals(false, none.success);
    }
}
