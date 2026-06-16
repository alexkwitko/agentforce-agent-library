/**
 * KnowledgeSearchService — searches your PUBLISHED Knowledge articles for the agent to ground on.
 *
 * Returns only what Knowledge actually contains (titles, summaries, article numbers) so the agent
 * answers from real articles and deflects safely when nothing matches. Result formatting is split
 * out (format()) so it is unit-testable without inserting Knowledge records (article-type creation
 * is org-setup-gated).
 */
public without sharing class KnowledgeSearchService {

    private static final Integer MAX_HITS = 5;

    public class Article {
        public String title;
        public String summary;
        public String articleNumber;
        public String urlName;
        public Article(String t, String s, String n, String u) { title=t; summary=s; articleNumber=n; urlName=u; }
    }
    public class SearchResult {
        public Boolean found = false;
        public Integer count = 0;
        public String message;
        public List<Article> articles = new List<Article>();
    }

    public static SearchResult search(String query) {
        SearchResult res = new SearchResult();
        if (String.isBlank(query)) { res.message = 'Tell me what you need help with and I will check our articles.'; return res; }

        List<Article> hits = new List<Article>();
        try {
            // Dynamic SOSL so this class compiles in any org — orgs without Lightning Knowledge
            // do not support KnowledgeArticleVersion as a static type. Degrades gracefully (catch).
            String safe = String.escapeSingleQuotes(query);
            String sosl = 'FIND \'' + safe + '\' IN ALL FIELDS '
                + 'RETURNING KnowledgeArticleVersion(Id, Title, Summary, ArticleNumber, UrlName '
                + 'WHERE PublishStatus = \'Online\' AND Language = \'en_US\') LIMIT 5';
            List<List<SObject>> r = Search.query(sosl);
            if (!r.isEmpty()) {
                for (SObject so : r[0]) {
                    hits.add(new Article(
                        (String) so.get('Title'),
                        (String) so.get('Summary'),
                        (String) so.get('ArticleNumber'),
                        (String) so.get('UrlName')
                    ));
                    if (hits.size() >= MAX_HITS) break;
                }
            }
        } catch (Exception e) {
            res.message = 'Knowledge search is not available in this org yet (no published article type).';
            return res;
        }
        return format(hits, res);
    }

    /** Pure formatting — safe to unit-test with in-memory Article structs. */
    public static SearchResult format(List<Article> hits, SearchResult res) {
        if (res == null) res = new SearchResult();
        res.articles = (hits == null) ? new List<Article>() : hits;
        res.count = res.articles.size();
        if (res.articles.isEmpty()) {
            res.found = false;
            res.message = 'I could not find a published article on that. Would you like me to connect you with a person?';
            return res;
        }
        res.found = true;
        List<String> lines = new List<String>();
        for (Article a : res.articles) {
            String line = '• ' + a.title;
            if (String.isNotBlank(a.summary)) line += ' — ' + a.summary;
            lines.add(line);
        }
        res.message = 'Here is what our Knowledge base says:\n' + String.join(lines, '\n');
        return res;
    }
}
