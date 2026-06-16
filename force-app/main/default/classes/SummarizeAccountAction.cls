/**
 * SummarizeAccountAction — Agentforce action: "brief me on this account."
 * Wraps AccountInsightsService.brief. One @InvocableMethod per class.
 */
public with sharing class SummarizeAccountAction {

    public class Request {
        @InvocableVariable(label='Account ID' required=true) public Id accountId;
    }
    public class Result {
        @InvocableVariable public Boolean found;
        @InvocableVariable public Integer openCases;
        @InvocableVariable public Integer openOpportunities;
        @InvocableVariable public String message;
    }

    @InvocableMethod(label='Summarize Account'
        description='Returns an Account 360 brief: open cases, open pipeline, recent orders, contacts.')
    public static List<Result> run(List<Request> reqs) {
        List<Result> out = new List<Result>();
        for (Request r : reqs) {
            AccountInsightsService.Brief b = AccountInsightsService.brief(r.accountId);
            Result res = new Result();
            res.found = b.found; res.openCases = b.openCases;
            res.openOpportunities = b.openOpportunities; res.message = b.message;
            out.add(res);
        }
        return out;
    }
}
