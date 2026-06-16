@isTest
private class OrderConciergeServiceTest {

    private static Order makeOrder() {
        Account a = new Account(Name='Order Concierge Acct'); insert a;
        Product2 p = new Product2(Name='Bag of Coffee', IsActive=true); insert p;
        Id stdPb = Test.getStandardPricebookId();
        PricebookEntry pbe = new PricebookEntry(Pricebook2Id=stdPb, Product2Id=p.Id, UnitPrice=20, IsActive=true); insert pbe;
        Order o = new Order(AccountId=a.Id, EffectiveDate=Date.today(), Status='Draft', Pricebook2Id=stdPb); insert o;
        insert new OrderItem(OrderId=o.Id, Product2Id=p.Id, PricebookEntryId=pbe.Id, Quantity=2, UnitPrice=20);
        return o;
    }

    @isTest static void lookupByNumber_summarizes() {
        Order o = makeOrder();
        String num = [SELECT OrderNumber FROM Order WHERE Id=:o.Id].OrderNumber;
        Test.startTest();
        LookupOrderAction.Request req = new LookupOrderAction.Request(); req.orderRef = num;
        LookupOrderAction.Result res = LookupOrderAction.run(new List<LookupOrderAction.Request>{ req })[0];
        Test.stopTest();
        System.assertEquals(true, res.found, res.message);
        System.assertEquals('Draft', res.status);
        System.assertEquals(1, res.itemCount);
        System.assert(res.message.contains('Bag of Coffee'), res.message);
    }

    @isTest static void lookupById_works_andNotFound() {
        Order o = makeOrder();
        OrderConciergeService.LookupResult byId = OrderConciergeService.lookup(o.Id);
        System.assertEquals(true, byId.found);
        OrderConciergeService.LookupResult none = OrderConciergeService.lookup('00000000DOESNOT');
        System.assertEquals(false, none.found);
        OrderConciergeService.LookupResult blank = OrderConciergeService.lookup('  ');
        System.assertEquals(false, blank.found);
    }

    @isTest static void reorder_clonesItems() {
        Order o = makeOrder();
        Test.startTest();
        ReorderAction.Request req = new ReorderAction.Request(); req.orderId = o.Id;
        ReorderAction.Result res = ReorderAction.run(new List<ReorderAction.Request>{ req })[0];
        Test.stopTest();
        System.assertEquals(true, res.success, res.message);
        System.assertNotEquals(null, res.newOrderId);
        System.assertEquals(1, [SELECT COUNT() FROM OrderItem WHERE OrderId = :res.newOrderId]);
        OrderConciergeService.ReorderResult none = OrderConciergeService.reorder(null);
        System.assertEquals(false, none.success);
    }
}
