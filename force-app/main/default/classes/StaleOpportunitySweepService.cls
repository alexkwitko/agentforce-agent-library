/**
 * StaleOpportunitySweepService — autonomous "stale deal" sweeper (headless agent brain).
 *
 * Finds OPEN opportunities idle longer than a threshold, logs a follow-up Task on each, and sets a
 * default NextStep where blank. Runs with no chat UI — invoked by a daily Schedulable, a Flow, or an
 * Agentforce action. This is the deterministic core; a reasoning step (e.g. generateAiAgentResponse to
 * draft a tailored next step) can be layered on top per the roadmap.
 *
 * Idempotent per run-day: it won't add a second open follow-up task it already created today.
 */
public without sharing class StaleOpportunitySweepService {

    public static final Integer DEFAULT_STALE_DAYS = 14;
    private static final String TASK_SUBJECT = 'Stale opportunity — follow up';

    public class SweepResult {
        public Integer scanned = 0;
        public Integer flagged = 0;
        public String message;
    }

    public static SweepResult sweep(Integer staleDays) {
        Integer days = (staleDays == null || staleDays <= 0) ? DEFAULT_STALE_DAYS : staleDays;
        Datetime cutoff = Datetime.now().addDays(-days);

        List<Opportunity> stale = [
            SELECT Id, Name, NextStep, OwnerId
            FROM Opportunity
            WHERE IsClosed = false AND LastModifiedDate < :cutoff
            LIMIT 200
        ];
        return flag(stale, days);
    }

    /** Flag a given set of stale opportunities — task + default next step, idempotent. Testable without date control. */
    @TestVisible
    private static SweepResult flag(List<Opportunity> stale, Integer days) {
        SweepResult res = new SweepResult();
        res.scanned = stale.size();
        if (stale.isEmpty()) { res.message = 'No stale opportunities found (threshold ' + days + ' days).'; return res; }

        // existing open follow-up tasks today -> idempotency
        Set<Id> oppIds = new Map<Id, Opportunity>(stale).keySet();
        Set<Id> alreadyHasTask = new Set<Id>();
        for (Task t : [SELECT WhatId FROM Task WHERE WhatId IN :oppIds AND Subject = :TASK_SUBJECT AND IsClosed = false]) {
            alreadyHasTask.add(t.WhatId);
        }

        List<Task> tasks = new List<Task>();
        List<Opportunity> toUpdate = new List<Opportunity>();
        for (Opportunity o : stale) {
            if (!alreadyHasTask.contains(o.Id)) {
                tasks.add(new Task(WhatId = o.Id, OwnerId = o.OwnerId, Subject = TASK_SUBJECT,
                    Description = 'This opportunity has been idle for ' + days + '+ days. Re-engage the buyer and update the stage.',
                    ActivityDate = Date.today().addDays(1), Status = 'Not Started', Priority = 'High'));
            }
            if (String.isBlank(o.NextStep)) {
                toUpdate.add(new Opportunity(Id = o.Id, NextStep = 'Re-engage buyer; confirm timeline and next milestone.'));
            }
        }
        if (!tasks.isEmpty()) insert tasks;
        if (!toUpdate.isEmpty()) update toUpdate;

        res.flagged = tasks.size();
        res.message = 'Scanned ' + res.scanned + ' stale opportunit(ies); created ' + res.flagged
            + ' follow-up task(s) and set ' + toUpdate.size() + ' default next step(s).';
        return res;
    }
}
