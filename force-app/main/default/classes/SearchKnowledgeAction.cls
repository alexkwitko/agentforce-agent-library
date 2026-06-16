/**
 * SearchKnowledgeAction — Agentforce action: "find an answer in our Knowledge base."
 * Wraps KnowledgeSearchService.search. One @InvocableMethod per class.
 */
public with sharing class SearchKnowledgeAction {

    public class Request {
        @InvocableVariable(label='Question' required=true
            description='The customer question or keywords to search published articles for.') public String query;
    }
    public class Result {
        @InvocableVariable public Boolean found;
        @InvocableVariable public Integer count;
        @InvocableVariable public String message;   // ready-to-speak summary of matching articles, or a deflection
    }

    @InvocableMethod(label='Search Knowledge'
        description='Searches published Knowledge articles and returns the matching titles and summaries.')
    public static List<Result> run(List<Request> reqs) {
        List<Result> out = new List<Result>();
        for (Request r : reqs) {
            KnowledgeSearchService.SearchResult sr = KnowledgeSearchService.search(r.query);
            Result res = new Result();
            res.found = sr.found;
            res.count = sr.count;
            res.message = sr.message;
            out.add(res);
        }
        return out;
    }
}
