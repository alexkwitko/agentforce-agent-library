/**
 * seed_knowledge.apex — best-effort sample Knowledge article for the Knowledge Concierge.
 * Run:  sf apex run -o <org> -f scripts/apex/seed_knowledge.apex
 *
 * Knowledge article TYPES (the *__kav object) are created in Setup (Lightning Knowledge), not via Apex/DX.
 * This script detects your first article type and, if found, creates + publishes a sample article.
 * If no article type exists yet, it prints the one-time setup steps.
 */
String kav;
for (String name : Schema.getGlobalDescribe().keySet()) {
    if (name.endsWith('__kav')) { kav = name; break; }
}

if (kav == null) {
    System.debug('============================================================');
    System.debug('Lightning Knowledge has no article type yet. One-time setup:');
    System.debug('  1. Setup → Knowledge Settings → enable Lightning Knowledge.');
    System.debug('  2. Object Manager → create a Knowledge object / record type (an article type).');
    System.debug('  3. Create + Publish a few articles (or re-run this script to auto-create a sample).');
    System.debug('The Knowledge Concierge agent is already installed and will answer once articles are published.');
    System.debug('============================================================');
} else {
    try {
        SObject art = Schema.getGlobalDescribe().get(kav).newSObject();
        art.put('Title', 'Cleaning your espresso machine');
        art.put('UrlName', 'cleaning-your-espresso-machine-' + String.valueOf(Datetime.now().getTime()));
        Map<String,Schema.SObjectField> f = Schema.getGlobalDescribe().get(kav).getDescribe().fields.getMap();
        if (f.containsKey('Summary')) art.put('Summary', 'Daily and weekly steps to keep your machine clean.');
        insert art;
        // publish (draft -> online)
        KbManagement.PublishingService.publishArticle((Id)art.get('KnowledgeArticleId'), true);
        System.debug('Sample article created + published in ' + kav + '. Ask the Knowledge Concierge: "How do I clean my machine?"');
    } catch (Exception e) {
        System.debug('Could not auto-create a sample article (' + e.getMessage() + '). Create + publish one in the UI; the agent is installed and ready.');
    }
}
