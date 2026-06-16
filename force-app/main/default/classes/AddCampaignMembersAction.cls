/**
 * AddCampaignMembersAction — Agentforce action: "add members to the campaign."
 * Wraps CampaignBuilderService.addMembers. One @InvocableMethod per class.
 */
public with sharing class AddCampaignMembersAction {

    public class Request {
        @InvocableVariable(label='Campaign ID' required=true) public Id campaignId;
        @InvocableVariable(label='Source' description='Lead or Contact (default Lead).') public String source;
        @InvocableVariable(label='Max Members' description='Cap on members to add (default 50).') public Integer maxMembers;
    }
    public class Result {
        @InvocableVariable public Boolean success;
        @InvocableVariable public Integer added;
        @InvocableVariable public String message;
    }

    @InvocableMethod(label='Add Campaign Members'
        description='Adds recent Leads or Contacts to a campaign as members.')
    public static List<Result> run(List<Request> reqs) {
        List<Result> out = new List<Result>();
        for (Request r : reqs) {
            CampaignBuilderService.MembersResult m = CampaignBuilderService.addMembers(r.campaignId, r.source, r.maxMembers);
            Result res = new Result();
            res.success = m.success; res.added = m.added; res.message = m.message;
            out.add(res);
        }
        return out;
    }
}
