public with sharing class SBC_AccountIntelligenceController {
  @AuraEnabled(cacheable=true)
  public static SBC_AccountIntelligencePresentation.ContextSummary getTrustedContext(
    Id accountId
  ) {
    return SBC_AccountIntelligencePresentation.createContextSummary(
      SBC_AccountIntelligenceContextService.buildContext(accountId)
    );
  }

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
