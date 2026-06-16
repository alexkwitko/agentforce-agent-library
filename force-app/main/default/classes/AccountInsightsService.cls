/**
 * AccountInsightsService — read-only Account 360 brief for the Account 360 Copilot (internal).
 *
 * Rolls up the signals a rep wants before a call: open cases, open pipeline, recent orders, key contacts.
 * Read-only. Anti-hallucination — the agent reports only what this returns.
 */
public without sharing class AccountInsightsService {

    public class Brief {
        public Boolean found = false;
        public String accountName;
        public Integer openCases = 0;
        public Integer openOpportunities = 0;
        public Decimal openPipeline = 0;
        public Integer recentOrders = 0;
        public Integer contacts = 0;
        public String message;
    }

    public static Brief brief(Id accountId) {
        Brief b = new Brief();
        if (accountId == null) { b.message = 'Give me an account to brief.'; return b; }

        List<Account> accs = [SELECT Id, Name FROM Account WHERE Id = :accountId LIMIT 1];
        if (accs.isEmpty()) { b.message = 'Account not found.'; return b; }
        b.found = true;
        b.accountName = accs[0].Name;

        b.openCases = [SELECT COUNT() FROM Case WHERE AccountId = :accountId AND IsClosed = false];
        for (Opportunity o : [SELECT Amount FROM Opportunity WHERE AccountId = :accountId AND IsClosed = false]) {
            b.openOpportunities++;
            if (o.Amount != null) b.openPipeline += o.Amount;
        }
        b.recentOrders = [SELECT COUNT() FROM Order WHERE AccountId = :accountId AND EffectiveDate = LAST_N_DAYS:180];
        b.contacts = [SELECT COUNT() FROM Contact WHERE AccountId = :accountId];

        b.message = b.accountName + ' — ' + b.openOpportunities + ' open opportunit(ies) worth '
            + String.valueOf(b.openPipeline) + ', ' + b.openCases + ' open case(s), '
            + b.recentOrders + ' order(s) in the last 180 days, ' + b.contacts + ' contact(s).';
        return b;
    }
}
