/**
 * schedule_lead_qualifier.apex — schedule the headless Lead Qualifier daily at 7am.
 * Run:  sf apex run -o <org> -f scripts/apex/schedule_lead_qualifier.apex
 */
String cron = '0 0 7 * * ?';
try {
    System.schedule('Lead Qualifier (daily)', cron, new LeadQualifierSchedulable());
    System.debug('Scheduled "Lead Qualifier (daily)" at 7am. It autonomously scores and rates open leads.');
} catch (Exception e) { System.debug('Already scheduled or could not schedule: ' + e.getMessage()); }
