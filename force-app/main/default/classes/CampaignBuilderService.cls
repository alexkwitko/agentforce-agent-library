/**
 * CampaignBuilderService — the brain of the Campaign Builder (internal marketing copilot).
 *
 * createCampaign(): creates a Campaign. addMembers(): adds Leads or Contacts as CampaignMembers from a
 * simple recency filter (a lightweight, license-free stand-in for Data Cloud segmentation — swap in a
 * Data Cloud segment for production). Anti-hallucination — report only what these return.
 */
public without sharing class CampaignBuilderService {

    public class CampaignResult {
        public Boolean success = false;
        public Id campaignId;
        public String message;
    }
    public class MembersResult {
        public Boolean success = false;
        public Integer added = 0;
        public String message;
    }

    public static CampaignResult createCampaign(String name, String type) {
        CampaignResult res = new CampaignResult();
        if (String.isBlank(name)) { res.message = 'Give the campaign a name.'; return res; }
        Campaign c = new Campaign(Name = name.abbreviate(80), Type = String.isBlank(type) ? 'Email' : type, IsActive = true);
        insert c;
        res.success = true; res.campaignId = c.Id;
        res.message = 'Created campaign "' + c.Name + '".';
        return res;
    }

    /** Add up to maxMembers recent Leads (source='Lead') or Contacts (source='Contact') to the campaign. */
    public static MembersResult addMembers(Id campaignId, String source, Integer maxMembers) {
        MembersResult res = new MembersResult();
        if (campaignId == null) { res.message = 'No campaign id provided.'; return res; }
        Integer lim = (maxMembers == null || maxMembers <= 0) ? 50 : Math.min(maxMembers, 200);
        String src = String.isBlank(source) ? 'Lead' : source;

        List<CampaignMember> toAdd = new List<CampaignMember>();
        Set<Id> existingLeads = new Set<Id>();
        Set<Id> existingContacts = new Set<Id>();
        for (CampaignMember cm : [SELECT LeadId, ContactId FROM CampaignMember WHERE CampaignId = :campaignId]) {
            if (cm.LeadId != null) existingLeads.add(cm.LeadId);
            if (cm.ContactId != null) existingContacts.add(cm.ContactId);
        }

        if (src == 'Contact') {
            for (Contact c : [SELECT Id FROM Contact ORDER BY CreatedDate DESC LIMIT :lim]) {
                if (!existingContacts.contains(c.Id)) toAdd.add(new CampaignMember(CampaignId = campaignId, ContactId = c.Id));
            }
        } else {
            for (Lead l : [SELECT Id FROM Lead WHERE IsConverted = false ORDER BY CreatedDate DESC LIMIT :lim]) {
                if (!existingLeads.contains(l.Id)) toAdd.add(new CampaignMember(CampaignId = campaignId, LeadId = l.Id));
            }
        }
        if (!toAdd.isEmpty()) insert toAdd;
        res.success = true; res.added = toAdd.size();
        res.message = 'Added ' + toAdd.size() + ' ' + src.toLowerCase() + ' member(s) to the campaign.';
        return res;
    }
}
