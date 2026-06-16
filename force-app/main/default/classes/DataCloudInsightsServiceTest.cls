@isTest
private class DataCloudInsightsServiceTest {

    @isTest static void format_foundAndNotFound() {
        DataCloudInsightsService.InsightResult none = DataCloudInsightsService.format('a@b.com', 0);
        System.assertEquals(false, none.found);
        System.assert(none.message.containsIgnoreCase('no unified'), none.message);

        DataCloudInsightsService.InsightResult hit = DataCloudInsightsService.format('a@b.com', 1);
        System.assertEquals(true, hit.found);
        System.assert(hit.message.containsIgnoreCase('unified'), hit.message);
    }

    @isTest static void lookup_guard_andGracefulWhenNoDataCloud() {
        // blank guard
        System.assertEquals(false, DataCloudInsightsService.lookupByEmail('  ').found);
        // real call: in test context CdpQuery is unavailable -> caught -> graceful message (not found, no throw)
        DataCloudInsightsService.InsightResult r = DataCloudInsightsService.lookupByEmail('test@example.com');
        System.assertEquals(false, r.found);
        System.assertNotEquals(null, r.message);
    }

    @isTest static void action_returnsResult() {
        GetCustomerInsightsAction.Request req = new GetCustomerInsightsAction.Request();
        req.email = 'test@example.com';
        GetCustomerInsightsAction.Result res = GetCustomerInsightsAction.run(new List<GetCustomerInsightsAction.Request>{ req })[0];
        System.assertNotEquals(null, res.message);
    }
}
