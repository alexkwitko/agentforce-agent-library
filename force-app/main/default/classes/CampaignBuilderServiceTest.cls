@isTest
private class CampaignBuilderServiceTest {

    @isTest static void create_andAddLeadMembers() {
        insert new Lead(LastName='L1', Company='C1');
        insert new Lead(LastName='L2', Company='C2');
        Test.startTest();
        CreateCampaignAction.Request c = new CreateCampaignAction.Request(); c.name='Spring Promo'; c.type='Email';
        CreateCampaignAction.Result cr = CreateCampaignAction.run(new List<CreateCampaignAction.Request>{ c })[0];
        System.assertEquals(true, cr.success, cr.message);

        AddCampaignMembersAction.Request m = new AddCampaignMembersAction.Request();
        m.campaignId = cr.campaignId; m.source='Lead'; m.maxMembers=10;
        AddCampaignMembersAction.Result mr = AddCampaignMembersAction.run(new List<AddCampaignMembersAction.Request>{ m })[0];
        // idempotent second add
        AddCampaignMembersAction.Result mr2 = AddCampaignMembersAction.run(new List<AddCampaignMembersAction.Request>{ m })[0];
        Test.stopTest();

        System.assert(mr.added >= 2, mr.message);
        System.assertEquals(0, mr2.added, 'no duplicate members');
        System.assertEquals(mr.added, [SELECT COUNT() FROM CampaignMember WHERE CampaignId=:cr.campaignId]);
    }

    @isTest static void addContactMembers_andGuards() {
        Account a = new Account(Name='CM Acct'); insert a;
        insert new Contact(LastName='Ct', AccountId=a.Id);
        CampaignBuilderService.CampaignResult c = CampaignBuilderService.createCampaign('Webinar', null);
        CampaignBuilderService.MembersResult m = CampaignBuilderService.addMembers(c.campaignId, 'Contact', 5);
        System.assert(m.added >= 1, m.message);
        System.assertEquals(false, CampaignBuilderService.createCampaign('  ', null).success);
        System.assertEquals(false, CampaignBuilderService.addMembers(null, 'Lead', 5).success);
    }
}
