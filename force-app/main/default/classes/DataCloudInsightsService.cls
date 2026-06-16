/**
 * DataCloudInsightsService — grounds an agent in Salesforce Data Cloud (Data 360).
 *
 * Looks up a person's Unified Profile / Calculated-Insight attributes by email via ConnectApi.CdpQuery
 * (the supported agent→Data Cloud bridge). Portable + graceful: the query is wrapped so the class
 * compiles wherever Data Cloud is enabled and returns a friendly message when the configured DMO/CI
 * isn't present yet. The detector gates this agent on Data Cloud DMOs (%__dlm) existing.
 *
 * CONFIG — point these at your org's Unified Individual DMO (or a Calculated Insight). DMO API names end
 * in __dlm, CIs in __cio. Defaults match the common SSOT Individual model; change to fit your data model.
 */
public with sharing class DataCloudInsightsService {

    // ── CONFIG ──────────────────────────────────────────────────────────────
    @TestVisible private static String DMO        = 'UnifiedssotIndividual__dlm';
    @TestVisible private static String EMAIL_FIELD = 'ssot__PrimaryEmail__c';
    @TestVisible private static String NAME_FIELD  = 'ssot__FirstName__c';
    // ────────────────────────────────────────────────────────────────────────

    public class InsightResult {
        public Boolean found = false;
        public String message;
    }

    public static InsightResult lookupByEmail(String email) {
        InsightResult res = new InsightResult();
        if (String.isBlank(email)) { res.message = 'Give me the customer email to look up in Data Cloud.'; return res; }

        Integer rowCount;
        try {
            String safe = String.escapeSingleQuotes(email);
            String sql = 'SELECT ' + NAME_FIELD + ', ' + EMAIL_FIELD + ' FROM ' + DMO
                       + ' WHERE ' + EMAIL_FIELD + ' = \'' + safe + '\' LIMIT 1';
            ConnectApi.CdpQueryInput input = new ConnectApi.CdpQueryInput();
            input.sql = sql;
            ConnectApi.CdpQueryOutputV2 out = ConnectApi.CdpQuery.queryAnsiSqlV2(input);
            rowCount = (out == null || out.data == null) ? 0 : out.data.size();
        } catch (Exception e) {
            res.message = 'Data Cloud profile lookup is not available yet (configure the Unified Individual DMO / enable Data Cloud).';
            return res;
        }
        return format(email, rowCount);
    }

    /** Pure formatting — unit-testable without calling Data Cloud. */
    @TestVisible
    private static InsightResult format(String email, Integer rowCount) {
        InsightResult res = new InsightResult();
        if (rowCount == null || rowCount == 0) {
            res.found = false;
            res.message = 'No unified Data Cloud profile found for ' + email + '.';
            return res;
        }
        res.found = true;
        res.message = 'Data Cloud unified profile found for ' + email + '. Use its attributes to personalize your reply.';
        return res;
    }
}
