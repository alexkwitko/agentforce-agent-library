/**
 * ResolveCaseAction — Agentforce action: "resolve and close a case." Wraps CaseServiceService.resolveCase.
 */
public with sharing class ResolveCaseAction {

    public class Request {
        @InvocableVariable(label='Case ID' required=true) public Id caseId;
        @InvocableVariable(label='Resolution' description='How the issue was resolved (recorded as a case comment).') public String resolution;
    }
    public class Result {
        @InvocableVariable public Boolean success;
        @InvocableVariable public String status;
        @InvocableVariable public String message;
    }

    @InvocableMethod(label='Resolve Case' description='Records a resolution comment and closes the Case.')
    public static List<Result> run(List<Request> reqs) {
        List<Result> out = new List<Result>();
        for (Request r : reqs) {
            CaseServiceService.ResolveResult rr = CaseServiceService.resolveCase(r.caseId, r.resolution);
            Result res = new Result();
            res.success = rr.success; res.status = rr.status; res.message = rr.message;
            out.add(res);
        }
        return out;
    }
}
