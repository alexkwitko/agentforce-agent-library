/**
 * CaseServiceService — log + resolve support Cases for the Case Service Agent.
 *
 * logCase():    creates a Case (Status New) and returns its number.
 * resolveCase(): records a resolution as a Case Comment and closes the Case.
 *
 * Anti-hallucination: callers must report only the case number/status returned here.
 */
public without sharing class CaseServiceService {

    public class LogResult {
        public Boolean success = false;
        public Id caseId;
        public String caseNumber;
        public String message;
    }
    public class ResolveResult {
        public Boolean success = false;
        public String status;
        public String message;
    }

    public static LogResult logCase(String subject, String description) {
        LogResult res = new LogResult();
        if (String.isBlank(subject)) { res.message = 'I need a short summary of the issue to open a case.'; return res; }

        Case c = new Case(Subject = subject, Description = description, Status = 'New', Origin = 'Web');
        insert c;
        Case created = [SELECT CaseNumber FROM Case WHERE Id = :c.Id LIMIT 1];
        res.success = true;
        res.caseId = c.Id;
        res.caseNumber = created.CaseNumber;
        res.message = 'Opened case ' + created.CaseNumber + '.';
        return res;
    }

    public static ResolveResult resolveCase(Id caseId, String resolution) {
        ResolveResult res = new ResolveResult();
        if (caseId == null) { res.message = 'No case id provided.'; return res; }

        List<Case> cases = [SELECT Id, Status, CaseNumber FROM Case WHERE Id = :caseId LIMIT 1];
        if (cases.isEmpty()) { res.message = 'Case not found.'; return res; }
        Case c = cases[0];

        if (String.isNotBlank(resolution)) {
            insert new CaseComment(ParentId = c.Id, CommentBody = resolution, IsPublished = true);
        }
        if (c.Status != 'Closed') { c.Status = 'Closed'; update c; }

        res.success = true;
        res.status = 'Closed';
        res.message = 'Case ' + c.CaseNumber + ' resolved and closed.';
        return res;
    }
}
