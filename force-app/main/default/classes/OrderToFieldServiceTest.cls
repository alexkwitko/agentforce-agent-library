@isTest
private class OrderToFieldServiceTest {

    private static Order makeOrder(Boolean serviceable) {
        Account a = new Account(Name='FS Test ' + (serviceable ? 'S' : 'N'));
        insert a;
        Product2 p = new Product2(Name='Install Product', IsActive=true, Requires_Field_Service__c=serviceable);
        insert p;
        Id stdPb = Test.getStandardPricebookId();
        PricebookEntry pbe = new PricebookEntry(Pricebook2Id=stdPb, Product2Id=p.Id, UnitPrice=100, IsActive=true);
        insert pbe;
        Order o = new Order(AccountId=a.Id, EffectiveDate=Date.today(), Status='Draft', Pricebook2Id=stdPb);
        insert o;
        insert new OrderItem(OrderId=o.Id, Product2Id=p.Id, PricebookEntryId=pbe.Id, Quantity=1, UnitPrice=100);
        return o;
    }

    @testSetup static void territory() {
        OperatingHours oh = new OperatingHours(Name='Test Hours', TimeZone='America/Chicago');
        insert oh;
        insert new ServiceTerritory(Name='Test Territory', OperatingHoursId=oh.Id, IsActive=true);
    }

    @isTest static void createsFieldService_andIsIdempotent() {
        Order o = makeOrder(true);
        Test.startTest();
        OrderToFieldService.Result r  = OrderToFieldService.fromOrder(o.Id);
        OrderToFieldService.Result r2 = OrderToFieldService.fromOrder(o.Id);   // idempotent
        OrderToFieldService.Request req = new OrderToFieldService.Request(); req.orderId = o.Id;
        OrderToFieldService.run(new List<OrderToFieldService.Request>{ req }); // invocable path
        OrderToFieldService.Result none = OrderToFieldService.fromOrder(null);
        Test.stopTest();

        System.assert(r.created, r.message);
        System.assertNotEquals(null, r.workOrderId);
        System.assertNotEquals(null, r.serviceAppointmentId);
        System.assertEquals(1, [SELECT COUNT() FROM WorkOrder WHERE Source_Order_Id__c = :String.valueOf(o.Id)]);
        System.assertEquals(1, [SELECT COUNT() FROM WorkOrderLineItem WHERE WorkOrderId = :r.workOrderId]);
        System.assertEquals(1, [SELECT COUNT() FROM ServiceAppointment WHERE ParentRecordId = :r.workOrderId]);
        System.assertEquals(false, r2.created, 'second run must be idempotent');
        System.assertEquals(null, none.workOrderId, 'null order -> no work');
    }

    @isTest static void noServiceableProducts_createsNothing() {
        Order o = makeOrder(false);
        Test.startTest();
        OrderToFieldService.Result r = OrderToFieldService.fromOrder(o.Id);
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM WorkOrder WHERE Source_Order_Id__c = :String.valueOf(o.Id)]);
    }
}
