/**
 * OpportunityCoachService — the brain of the Sales Opportunity Coach (internal copilot).
 *
 * summarize(): reads an Opportunity and returns a coaching summary + a recommended next step
 *              (heuristics that work in any org — no org-specific stage names required).
 * setNextStep(): records the chosen next step on the Opportunity and logs a follow-up Task.
 *
 * Read-mostly; anti-hallucination — the agent reports only what these methods return.
 */
public without sharing class OpportunityCoachService {

    public class SummaryResult {
        public Boolean found = false;
        public String name;
        public String stage;
        public Decimal amount;
        public Date closeDate;
        public String recommendation;
        public String message;
    }
    public class UpdateResult {
        public Boolean success = false;
        public String message;
    }

    public static SummaryResult summarize(Id oppId) {
        SummaryResult res = new SummaryResult();
        if (oppId == null) { res.message = 'Give me an opportunity to review.'; return res; }

        List<Opportunity> opps = [
            SELECT Id, Name, StageName, Amount, CloseDate, NextStep, Probability, IsClosed, IsWon,
                   LastModifiedDate, Account.Name
            FROM Opportunity WHERE Id = :oppId LIMIT 1
        ];
        if (opps.isEmpty()) { res.message = 'Opportunity not found.'; return res; }
        Opportunity o = opps[0];

        res.found = true;
        res.name = o.Name;
        res.stage = o.StageName;
        res.amount = o.Amount;
        res.closeDate = o.CloseDate;
        res.recommendation = recommend(o);

        Integer daysIdle = o.LastModifiedDate == null ? 0
            : Integer.valueOf((Datetime.now().getTime() - o.LastModifiedDate.getTime()) / (1000*60*60*24));
        Integer contacts = [SELECT COUNT() FROM OpportunityContactRole WHERE OpportunityId = :o.Id];

        res.message = o.Name + ' — stage "' + o.StageName + '"'
            + (o.Amount != null ? ', ' + String.valueOf(o.Amount) : '')
            + (o.CloseDate != null ? ', closes ' + o.CloseDate.format() : '')
            + '. Idle ' + daysIdle + ' day(s), ' + contacts + ' contact role(s).'
            + ' Recommended next step: ' + res.recommendation;
        return res;
    }

    /** Org-agnostic next-best-action heuristics. */
    private static String recommend(Opportunity o) {
        if (o.IsClosed) return o.IsWon ? 'Won — kick off onboarding and look for expansion.' : 'Closed lost — log the reason and nurture for re-engagement.';
        if (o.CloseDate != null && o.CloseDate < Date.today()) return 'Close date has passed — update the date or advance the stage; it is slipping.';
        if (String.isBlank(o.NextStep)) return 'No next step defined — agree and schedule a concrete next action with the buyer.';
        if (o.Probability != null && o.Probability >= 70) return 'High probability — confirm verbal commitment and prepare the paperwork/closing plan.';
        if ([SELECT COUNT() FROM OpportunityContactRole WHERE OpportunityId = :o.Id] == 0) return 'No contact roles — map the buying committee (economic buyer + champion).';
        return 'Advance the stage: validate the current next step is done, then set the following milestone.';
    }

    public static UpdateResult setNextStep(Id oppId, String nextStep) {
        UpdateResult res = new UpdateResult();
        if (oppId == null || String.isBlank(nextStep)) { res.message = 'Need an opportunity and a next step.'; return res; }

        List<Opportunity> opps = [SELECT Id, Name FROM Opportunity WHERE Id = :oppId LIMIT 1];
        if (opps.isEmpty()) { res.message = 'Opportunity not found.'; return res; }

        update new Opportunity(Id = oppId, NextStep = nextStep.abbreviate(255));
        insert new Task(WhatId = oppId, Subject = 'Next step: ' + nextStep.abbreviate(200),
                        ActivityDate = Date.today().addDays(2), Status = 'Not Started', Priority = 'Normal');
        res.success = true;
        res.message = 'Set next step on ' + opps[0].Name + ' and created a follow-up task.';
        return res;
    }
}
