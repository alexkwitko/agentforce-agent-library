/**
 * QualifyLeadsAction — invocable wrapper so lead qualification runs from a Flow, schedule, or agent.
 * One @InvocableMethod per class.
 */
public with sharing class QualifyLeadsAction {

    public class Request {
        @InvocableVariable(label='(unused) trigger') public String note;
    }
    public class Result {
        @InvocableVariable public Integer scanned;
        @InvocableVariable public Integer hot;
        @InvocableVariable public String message;
    }

    @InvocableMethod(label='Qualify Leads'
        description='Scores open leads, stamps Rating, and logs follow-up tasks for hot leads.')
    public static List<Result> run(List<Request> reqs) {
        LeadQualifierService.QualifyResult s = LeadQualifierService.sweep();
        Result res = new Result();
        res.scanned = s.scanned; res.hot = s.hot; res.message = s.message;
        return new List<Result>{ res };
    }
}
