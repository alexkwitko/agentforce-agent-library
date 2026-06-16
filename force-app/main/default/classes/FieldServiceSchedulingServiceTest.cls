@isTest
private class FieldServiceSchedulingServiceTest {

    @testSetup static void setup() {
        OperatingHours oh = new OperatingHours(Name='Sched Test Hours', TimeZone='America/Chicago');
        insert oh;
        ServiceTerritory st = new ServiceTerritory(Name='Sched Test Territory', OperatingHoursId=oh.Id, IsActive=true);
        insert st;
        ServiceResource sr = new ServiceResource(
            Name='Test Tech', IsActive=true, ResourceType='T', RelatedRecordId=UserInfo.getUserId()
        );
        insert sr;
        insert new ServiceTerritoryMember(
            ServiceTerritoryId=st.Id, ServiceResourceId=sr.Id,
            TerritoryType='P', EffectiveStartDate=System.now().addDays(-1)
        );
    }

    private static ServiceAppointment makeUnscheduledSA() {
        ServiceTerritory st = [SELECT Id FROM ServiceTerritory WHERE Name='Sched Test Territory' LIMIT 1];
        Account a = new Account(Name='Sched Acct');
        insert a;
        WorkOrder wo = new WorkOrder(AccountId=a.Id, Subject='Test WO', Status='New', ServiceTerritoryId=st.Id);
        insert wo;
        ServiceAppointment sa = new ServiceAppointment(
            ParentRecordId=wo.Id, Status='None', Subject='Test SA',
            ServiceTerritoryId=st.Id,
            EarliestStartTime=System.now().addDays(1), DueDate=System.now().addDays(14)
        );
        insert sa;
        return sa;
    }

    @isTest static void proposesAndBooks_viaActions() {
        ServiceAppointment sa = makeUnscheduledSA();
        Test.startTest();

        // get slots through the agent action
        GetAppointmentSlotsAction.Request gReq = new GetAppointmentSlotsAction.Request();
        gReq.serviceAppointmentId = sa.Id;
        GetAppointmentSlotsAction.Result gRes =
            GetAppointmentSlotsAction.run(new List<GetAppointmentSlotsAction.Request>{ gReq })[0];
        System.assertEquals(true, gRes.hasSlots, 'should offer slots: ' + gRes.message);
        System.assert(gRes.slots.size() >= 1, 'at least one slot');

        // book the first one by index, through the agent action
        BookAppointmentAction.Request bReq = new BookAppointmentAction.Request();
        bReq.serviceAppointmentId = sa.Id;
        bReq.selectedSlot = '1';
        BookAppointmentAction.Result bRes =
            BookAppointmentAction.run(new List<BookAppointmentAction.Request>{ bReq })[0];
        Test.stopTest();

        System.assertEquals(true, bRes.success, bRes.message);
        ServiceAppointment after = [SELECT Status, SchedStartTime, SchedEndTime FROM ServiceAppointment WHERE Id=:sa.Id];
        System.assertEquals('Scheduled', after.Status);
        System.assertNotEquals(null, after.SchedStartTime);
        System.assertEquals(1, [SELECT COUNT() FROM AssignedResource WHERE ServiceAppointmentId=:sa.Id], 'resource assigned');
    }

    @isTest static void bookByExactLabel_works() {
        ServiceAppointment sa = makeUnscheduledSA();
        List<FieldServiceSchedulingService.Slot> slots = FieldServiceSchedulingService.proposeSlots(sa.Id);
        System.assert(!slots.isEmpty());
        BookAppointmentAction.Request bReq = new BookAppointmentAction.Request();
        bReq.serviceAppointmentId = sa.Id;
        bReq.selectedSlot = slots[0].label;     // exact label round-trip
        Test.startTest();
        BookAppointmentAction.Result bRes =
            BookAppointmentAction.run(new List<BookAppointmentAction.Request>{ bReq })[0];
        Test.stopTest();
        System.assertEquals(true, bRes.success, bRes.message);
        System.assertEquals(slots[0].label, bRes.scheduledTime);
    }

    @isTest static void badSelection_isRejected() {
        ServiceAppointment sa = makeUnscheduledSA();
        BookAppointmentAction.Request bReq = new BookAppointmentAction.Request();
        bReq.serviceAppointmentId = sa.Id;
        bReq.selectedSlot = 'next tuesday at midnight';   // no match
        Test.startTest();
        BookAppointmentAction.Result bRes =
            BookAppointmentAction.run(new List<BookAppointmentAction.Request>{ bReq })[0];
        Test.stopTest();
        System.assertEquals(false, bRes.success);
        System.assert(bRes.message.contains('options are'), 'should re-list options');
    }

    @isTest static void nullGuards() {
        System.assertEquals(0, FieldServiceSchedulingService.proposeSlots(null).size());
        FieldServiceSchedulingService.BookResult br = FieldServiceSchedulingService.book(null, System.now());
        System.assertEquals(false, br.success);
    }
}
