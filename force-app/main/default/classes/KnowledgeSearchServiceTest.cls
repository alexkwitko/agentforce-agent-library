@isTest
private class KnowledgeSearchServiceTest {

    @isTest static void search_noMatches_deflects() {
        Test.setFixedSearchResults(new List<Id>{});   // SOSL returns nothing in test context
        Test.startTest();
        KnowledgeSearchService.SearchResult res = KnowledgeSearchService.search('how do I reset my grinder');
        Test.stopTest();
        System.assertEquals(false, res.found);
        System.assert(res.message.containsIgnoreCase('could not find') || res.message.containsIgnoreCase('not available'), res.message);
    }

    @isTest static void blankQuery_guarded() {
        KnowledgeSearchService.SearchResult res = KnowledgeSearchService.search('   ');
        System.assertEquals(false, res.found);
        System.assertEquals(0, res.count);
    }

    @isTest static void format_withHits_listsArticles() {
        List<KnowledgeSearchService.Article> hits = new List<KnowledgeSearchService.Article>{
            new KnowledgeSearchService.Article('Cleaning your espresso machine', 'Daily and weekly cleaning steps.', '000001', 'cleaning'),
            new KnowledgeSearchService.Article('Warranty coverage', null, '000002', 'warranty')
        };
        KnowledgeSearchService.SearchResult res = KnowledgeSearchService.format(hits, null);
        System.assertEquals(true, res.found);
        System.assertEquals(2, res.count);
        System.assert(res.message.contains('Cleaning your espresso machine'), res.message);
        System.assert(res.message.contains('Warranty coverage'), res.message);
    }

    @isTest static void format_empty_deflects() {
        KnowledgeSearchService.SearchResult res = KnowledgeSearchService.format(new List<KnowledgeSearchService.Article>(), null);
        System.assertEquals(false, res.found);
        System.assertEquals(0, res.count);
        System.assert(res.message.containsIgnoreCase('could not find'), res.message);
    }

    @isTest static void action_returnsResult() {
        Test.setFixedSearchResults(new List<Id>{});
        SearchKnowledgeAction.Request req = new SearchKnowledgeAction.Request();
        req.query = 'returns policy';
        SearchKnowledgeAction.Result res = SearchKnowledgeAction.run(new List<SearchKnowledgeAction.Request>{ req })[0];
        System.assertEquals(false, res.found);
        System.assertNotEquals(null, res.message);
    }
}
