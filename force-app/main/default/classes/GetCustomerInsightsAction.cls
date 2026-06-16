/**
 * GetCustomerInsightsAction — Agentforce action: "look up this customer in Data Cloud."
 * Wraps DataCloudInsightsService.lookupByEmail. One @InvocableMethod per class.
 */
public with sharing class GetCustomerInsightsAction {

    public class Request {
        @InvocableVariable(label='Customer Email' required=true) public String email;
    }
    public class Result {
        @InvocableVariable public Boolean found;
        @InvocableVariable public String message;
    }

    @InvocableMethod(label='Get Customer Insights (Data Cloud)'
        description='Looks up the unified Data Cloud profile for a customer email to ground the agent.')
    public static List<Result> run(List<Request> reqs) {
        List<Result> out = new List<Result>();
        for (Request r : reqs) {
            DataCloudInsightsService.InsightResult ir = DataCloudInsightsService.lookupByEmail(r.email);
            Result res = new Result();
            res.found = ir.found; res.message = ir.message;
            out.add(res);
        }
        return out;
    }
}
