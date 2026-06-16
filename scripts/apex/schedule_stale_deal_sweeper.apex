/**
 * schedule_stale_deal_sweeper.apex — schedule the headless Stale-Deal Sweeper to run daily at 6am.
 * Run:  sf apex run -o <org> -f scripts/apex/schedule_stale_deal_sweeper.apex
 */
String cron = '0 0 6 * * ?';   // every day at 6:00 AM
try {
    System.schedule('Stale Deal Sweeper (daily)', cron, new StaleOpportunitySweepSchedulable());
    System.debug('Scheduled "Stale Deal Sweeper (daily)" at 6am. It autonomously flags stale opportunities.');
} catch (Exception e) {
    System.debug('Already scheduled or could not schedule: ' + e.getMessage());
}
