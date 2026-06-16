/**
 * SweepStaleOpportunitiesAction — invocable wrapper so the stale-deal sweep can be run from a Flow,
 * a scheduled process, or an Agentforce action (headless). One @InvocableMethod per class.
 */
public with sharing class SweepStaleOpportunitiesAction {

    public class Request {
        @InvocableVariable(label='Stale Days' description='How many idle days makes an opportunity stale (default 14).')
        public Integer staleDays;
    }
    public class Result {
        @InvocableVariable public Integer scanned;
        @InvocableVariable public Integer flagged;
        @InvocableVariable public String message;
    }

    @InvocableMethod(label='Sweep Stale Opportunities'
        description='Finds open opportunities idle past a threshold, logs follow-up tasks, and sets default next steps.')
    public static List<Result> run(List<Request> reqs) {
        List<Result> out = new List<Result>();
        if (reqs == null || reqs.isEmpty()) reqs = new List<Request>{ new Request() };
        for (Request r : reqs) {
            StaleOpportunitySweepService.SweepResult s = StaleOpportunitySweepService.sweep(r.staleDays);
            Result res = new Result();
            res.scanned = s.scanned; res.flagged = s.flagged; res.message = s.message;
            out.add(res);
        }
        return out;
    }
}
