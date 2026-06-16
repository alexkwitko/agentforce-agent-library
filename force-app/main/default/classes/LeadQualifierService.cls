/**
 * LeadQualifierService — autonomous lead qualification (headless agent brain).
 *
 * Scores open, unconverted leads on profile completeness and stamps Rating (Hot/Warm/Cold), then logs a
 * follow-up Task for Hot leads. Runs with no chat UI — invoked by a daily Schedulable, a Flow, or an
 * Agentforce action. Deterministic core; a reasoning step (draft tailored outreach) can layer on top.
 *
 * Idempotent: won't add a second open follow-up task for a Hot lead it already flagged.
 */
public without sharing class LeadQualifierService {

    private static final String TASK_SUBJECT = 'Hot lead — reach out today';

    public class QualifyResult {
        public Integer scanned = 0;
        public Integer hot = 0;
        public String message;
    }

    public static QualifyResult sweep() {
        List<Lead> open = [
            SELECT Id, FirstName, LastName, Company, Email, Phone, Industry, Rating, Status, OwnerId
            FROM Lead WHERE IsConverted = false AND Status != 'Closed - Not Converted'
            LIMIT 200
        ];
        return qualify(open);
    }

    /** Score + rate a given set of leads. Testable without scheduling/date control. */
    @TestVisible
    private static QualifyResult qualify(List<Lead> leads) {
        QualifyResult res = new QualifyResult();
        res.scanned = leads.size();
        if (leads.isEmpty()) { res.message = 'No open leads to qualify.'; return res; }

        Set<Id> hotIds = new Set<Id>();
        List<Lead> toUpdate = new List<Lead>();
        for (Lead l : leads) {
            Integer score = 0;
            if (String.isNotBlank(l.Email)) score++;
            if (String.isNotBlank(l.Phone)) score++;
            if (String.isNotBlank(l.Company)) score++;
            if (String.isNotBlank(l.Industry)) score++;
            String rating = score >= 3 ? 'Hot' : (score == 2 ? 'Warm' : 'Cold');
            if (l.Rating != rating) toUpdate.add(new Lead(Id = l.Id, Rating = rating));
            if (rating == 'Hot') hotIds.add(l.Id);
        }
        if (!toUpdate.isEmpty()) update toUpdate;

        // follow-up tasks for hot leads (idempotent)
        Set<Id> alreadyTasked = new Set<Id>();
        if (!hotIds.isEmpty()) {
            for (Task t : [SELECT WhoId FROM Task WHERE WhoId IN :hotIds AND Subject = :TASK_SUBJECT AND IsClosed = false]) {
                alreadyTasked.add(t.WhoId);
            }
        }
        List<Task> tasks = new List<Task>();
        for (Lead l : leads) {
            if (hotIds.contains(l.Id) && !alreadyTasked.contains(l.Id)) {
                tasks.add(new Task(WhoId = l.Id, OwnerId = l.OwnerId, Subject = TASK_SUBJECT,
                    ActivityDate = Date.today(), Status = 'Not Started', Priority = 'High'));
            }
        }
        if (!tasks.isEmpty()) insert tasks;

        res.hot = hotIds.size();
        res.message = 'Qualified ' + res.scanned + ' lead(s): ' + res.hot + ' Hot; updated '
            + toUpdate.size() + ' rating(s) and logged ' + tasks.size() + ' follow-up task(s).';
        return res;
    }
}
