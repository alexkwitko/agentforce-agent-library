/**
 * StaleOpportunitySweepSchedulable — runs the stale-deal sweep on a schedule (the autonomous trigger).
 * Schedule with scripts/apex/schedule_stale_deal_sweeper.apex (daily).
 */
public class StaleOpportunitySweepSchedulable implements Schedulable {
    public void execute(SchedulableContext sc) {
        StaleOpportunitySweepService.sweep(StaleOpportunitySweepService.DEFAULT_STALE_DAYS);
    }
}
