public with sharing class SBC_AccountIntelligenceController {
    @AuraEnabled
    public static SBC_AccountIntelligencePresentation.Response generateAccountIntelligence(
        Id accountId
    ) {
        SBC_AccountIntelligenceContextService.AccountIntelligenceContext context = SBC_AccountIntelligenceContextService.buildContext(
            accountId
        );
        return SBC_AccountIntelligencePresentation.create(
            SBC_AccountIntelligenceService.generate(context),
            context
        );
    }
}
