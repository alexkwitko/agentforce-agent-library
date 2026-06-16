/**
 * LogCaseAction — Agentforce action: "open a support case." Wraps CaseServiceService.logCase.
 */
public with sharing class LogCaseAction {

    public class Request {
        @InvocableVariable(label='Subject' required=true description='Short summary of the issue.') public String subject;
        @InvocableVariable(label='Description' description='Details of the issue.') public String description;
    }
    public class Result {
        @InvocableVariable public Boolean success;
        @InvocableVariable public Id caseId;
        @InvocableVariable public String caseNumber;
        @InvocableVariable public String message;
    }

    @InvocableMethod(label='Log Case' description='Creates a new support Case and returns its number.')
    public static List<Result> run(List<Request> reqs) {
        List<Result> out = new List<Result>();
        for (Request r : reqs) {
            CaseServiceService.LogResult lr = CaseServiceService.logCase(r.subject, r.description);
            Result res = new Result();
            res.success = lr.success; res.caseId = lr.caseId; res.caseNumber = lr.caseNumber; res.message = lr.message;
            out.add(res);
        }
        return out;
    }
}
