@isTest
private class ServiceAppointmentCloseServiceTest {

    private static ServiceAppointment makeScheduledSA() {
        OperatingHours oh = new OperatingHours(Name='Close Test Hours', TimeZone='America/Chicago');
        insert oh;
        ServiceTerritory st = new ServiceTerritory(Name='Close Test Territory', OperatingHoursId=oh.Id, IsActive=true);
        insert st;
        Account a = new Account(Name='Close Acct'); insert a;
        WorkOrder wo = new WorkOrder(AccountId=a.Id, Subject='Close WO', Status='In Progress', ServiceTerritoryId=st.Id);
        insert wo;
        ServiceAppointment sa = new ServiceAppointment(
            ParentRecordId=wo.Id, Status='Scheduled', Subject='Close SA',
            ServiceTerritoryId=st.Id,
            SchedStartTime=System.now().addHours(-2), SchedEndTime=System.now().addHours(-1),
            EarliestStartTime=System.now().addDays(-1), DueDate=System.now().addDays(7)
        );
        insert sa;
        return sa;
    }

    @isTest static void closes_andRollsUpWorkOrder() {
        ServiceAppointment sa = makeScheduledSA();
        Test.startTest();
        CloseServiceAppointmentAction.Request req = new CloseServiceAppointmentAction.Request();
        req.serviceAppointmentId = sa.Id;
        req.completionNotes = 'Installed and tested the machine.';
        CloseServiceAppointmentAction.Result res =
            CloseServiceAppointmentAction.run(new List<CloseServiceAppointmentAction.Request>{ req })[0];
        Test.stopTest();

        System.assertEquals(true, res.success, res.message);
        System.assertEquals('Completed', res.workOrderStatus);
        ServiceAppointment after = [SELECT Status, ActualEndTime FROM ServiceAppointment WHERE Id=:sa.Id];
        System.assertEquals('Completed', after.Status);
        System.assertNotEquals(null, after.ActualEndTime);
        WorkOrder wo = [SELECT Status, Completion_Notes__c FROM WorkOrder WHERE Id=:sa.ParentRecordId];
        System.assertEquals('Completed', wo.Status);
        System.assertEquals('Installed and tested the machine.', wo.Completion_Notes__c);
    }

    @isTest static void secondClose_isIdempotent() {
        ServiceAppointment sa = makeScheduledSA();
        Test.startTest();
        ServiceAppointmentCloseService.close(sa.Id, 'first');
        ServiceAppointmentCloseService.CloseResult r2 = ServiceAppointmentCloseService.close(sa.Id, 'second');
        Test.stopTest();
        System.assertEquals(true, r2.success);
        System.assert(r2.message.containsIgnoreCase('already'), r2.message);
    }

    @isTest static void nullGuard() {
        ServiceAppointmentCloseService.CloseResult r = ServiceAppointmentCloseService.close(null, 'x');
        System.assertEquals(false, r.success);
    }
}
