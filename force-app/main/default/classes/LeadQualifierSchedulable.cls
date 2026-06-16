/**
 * LeadQualifierSchedulable — runs lead qualification on a schedule (the autonomous trigger).
 * Schedule with scripts/apex/schedule_lead_qualifier.apex (daily).
 */
public class LeadQualifierSchedulable implements Schedulable {
    public void execute(SchedulableContext sc) {
        LeadQualifierService.sweep();
    }
}
