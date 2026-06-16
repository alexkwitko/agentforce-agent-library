/**
 * SummarizeOpportunityAction — Agentforce action: "review this opportunity."
 * Wraps OpportunityCoachService.summarize. One @InvocableMethod per class.
 */
public with sharing class SummarizeOpportunityAction {

    public class Request {
        @InvocableVariable(label='Opportunity ID' required=true) public Id opportunityId;
    }
    public class Result {
        @InvocableVariable public Boolean found;
        @InvocableVariable public String stage;
        @InvocableVariable public String recommendation;
        @InvocableVariable public String message;
    }

    @InvocableMethod(label='Summarize Opportunity'
        description='Summarizes an opportunity and recommends the next best step.')
    public static List<Result> run(List<Request> reqs) {
        List<Result> out = new List<Result>();
        for (Request r : reqs) {
            OpportunityCoachService.SummaryResult s = OpportunityCoachService.summarize(r.opportunityId);
            Result res = new Result();
            res.found = s.found; res.stage = s.stage; res.recommendation = s.recommendation; res.message = s.message;
            out.add(res);
        }
        return out;
    }
}
