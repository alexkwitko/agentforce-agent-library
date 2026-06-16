/**
 * CreateCampaignAction — Agentforce action: "create a campaign." Wraps CampaignBuilderService.createCampaign.
 */
public with sharing class CreateCampaignAction {

    public class Request {
        @InvocableVariable(label='Campaign Name' required=true) public String name;
        @InvocableVariable(label='Type' description='e.g. Email, Webinar, Advertisement.') public String type;
    }
    public class Result {
        @InvocableVariable public Boolean success;
        @InvocableVariable public Id campaignId;
        @InvocableVariable public String message;
    }

    @InvocableMethod(label='Create Campaign' description='Creates a marketing Campaign and returns its id.')
    public static List<Result> run(List<Request> reqs) {
        List<Result> out = new List<Result>();
        for (Request r : reqs) {
            CampaignBuilderService.CampaignResult c = CampaignBuilderService.createCampaign(r.name, r.type);
            Result res = new Result();
            res.success = c.success; res.campaignId = c.campaignId; res.message = c.message;
            out.add(res);
        }
        return out;
    }
}
