/**
 * SetOpportunityNextStepAction — Agentforce action: "set the next step on this opportunity."
 * Wraps OpportunityCoachService.setNextStep. One @InvocableMethod per class.
 */
public with sharing class SetOpportunityNextStepAction {

    public class Request {
        @InvocableVariable(label='Opportunity ID' required=true) public Id opportunityId;
        @InvocableVariable(label='Next Step' required=true) public String nextStep;
    }
    public class Result {
        @InvocableVariable public Boolean success;
        @InvocableVariable public String message;
    }

    @InvocableMethod(label='Set Opportunity Next Step'
        description='Records the next step on an opportunity and logs a follow-up task.')
    public static List<Result> run(List<Request> reqs) {
        List<Result> out = new List<Result>();
        for (Request r : reqs) {
            OpportunityCoachService.UpdateResult u = OpportunityCoachService.setNextStep(r.opportunityId, r.nextStep);
            Result res = new Result();
            res.success = u.success; res.message = u.message;
            out.add(res);
        }
        return out;
    }
}
