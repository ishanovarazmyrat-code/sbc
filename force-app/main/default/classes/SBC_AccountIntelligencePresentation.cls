public with sharing class SBC_AccountIntelligencePresentation {
  public class Response {
    @AuraEnabled
    public SBC_AccountIntelligenceService.AccountIntelligenceResult result {
      get;
      set;
    }
    @AuraEnabled
    public List<EvidenceCatalogItem> evidenceCatalog { get; set; }
  }

  public class EvidenceCatalogItem {
    @AuraEnabled
    public String evidenceId { get; set; }
    @AuraEnabled
    public String sourceType { get; set; }
    @AuraEnabled
    public Id recordId { get; set; }
    @AuraEnabled
    public String displayLabel { get; set; }
    @AuraEnabled
    public String factSummary { get; set; }
  }

  public class ContextSummary {
    @AuraEnabled
    public String accountName { get; set; }
    @AuraEnabled
    public String industry { get; set; }
    @AuraEnabled
    public Integer openOpportunityCount { get; set; }
    @AuraEnabled
    public Decimal openOpportunityTotalValue { get; set; }
    @AuraEnabled
    public Integer openCaseCount { get; set; }
    @AuraEnabled
    public Boolean hasHighPriorityCase { get; set; }
    @AuraEnabled
    public Integer contactCount { get; set; }
    @AuraEnabled
    public Integer openTaskCount { get; set; }
  }

  public static ContextSummary createContextSummary(
    SBC_AccountIntelligenceContextService.AccountIntelligenceContext context
  ) {
    ContextSummary summary = new ContextSummary();
    summary.openOpportunityCount = 0;
    summary.openOpportunityTotalValue = 0;
    summary.openCaseCount = 0;
    summary.hasHighPriorityCase = false;
    summary.contactCount = 0;
    summary.openTaskCount = 0;

    for (
      SBC_AccountIntelligenceContextService.Evidence evidence : context.evidence
    ) {
      if (evidence.sourceType == 'Account') {
        summary.accountName = stringValue(
          evidence.facts.get('name'),
          'Account'
        );
        summary.industry = stringValue(
          evidence.facts.get('industry'),
          'Not specified'
        );
      } else if (
        evidence.sourceType == 'Opportunity' &&
        evidence.facts.get('isClosed') == false
      ) {
        summary.openOpportunityCount++;
        if (evidence.facts.get('amount') != null) {
          summary.openOpportunityTotalValue += (Decimal) evidence.facts.get(
            'amount'
          );
        }
      } else if (
        evidence.sourceType == 'Case' &&
        evidence.facts.get('closedDate') == null
      ) {
        summary.openCaseCount++;
        if (
          String.valueOf(evidence.facts.get('priority'))
            .equalsIgnoreCase('High')
        ) {
          summary.hasHighPriorityCase = true;
        }
      } else if (evidence.sourceType == 'Contact') {
        summary.contactCount++;
      } else if (
        evidence.sourceType == 'Task' &&
        String.valueOf(evidence.facts.get('status')) != 'Completed'
      ) {
        summary.openTaskCount++;
      }
    }
    return summary;
  }

  public static Response create(
    SBC_AccountIntelligenceService.AccountIntelligenceResult result,
    SBC_AccountIntelligenceContextService.AccountIntelligenceContext context
  ) {
    Response response = new Response();
    response.result = result;
    response.evidenceCatalog = new List<EvidenceCatalogItem>();
    for (
      SBC_AccountIntelligenceContextService.Evidence evidence : context.evidence
    ) {
      response.evidenceCatalog.add(toCatalogItem(evidence));
    }
    return response;
  }

  private static EvidenceCatalogItem toCatalogItem(
    SBC_AccountIntelligenceContextService.Evidence evidence
  ) {
    EvidenceCatalogItem item = new EvidenceCatalogItem();
    item.evidenceId = evidence.evidenceId;
    item.sourceType = evidence.sourceType;
    item.recordId = evidence.recordId;

    List<String> summaryParts = new List<String>();
    if (evidence.sourceType == 'Account') {
      item.displayLabel = stringValue(evidence.facts.get('name'), 'Account');
      addFact(summaryParts, 'Industry', evidence.facts.get('industry'));
      addFact(summaryParts, 'Type', evidence.facts.get('type'));
      addFact(
        summaryParts,
        'Annual revenue',
        evidence.facts.get('annualRevenue')
      );
      addFact(
        summaryParts,
        'Employees',
        evidence.facts.get('numberOfEmployees')
      );
    } else if (evidence.sourceType == 'Opportunity') {
      item.displayLabel = stringValue(
        evidence.facts.get('name'),
        'Opportunity'
      );
      addFact(summaryParts, 'Stage', evidence.facts.get('stage'));
      addFact(summaryParts, 'Amount', evidence.facts.get('amount'));
      addFact(summaryParts, 'Close date', evidence.facts.get('closeDate'));
      addFact(summaryParts, 'Probability', evidence.facts.get('probability'));
    } else if (evidence.sourceType == 'Case') {
      item.displayLabel =
        'Case ' + stringValue(evidence.facts.get('caseNumber'), '');
      addFact(summaryParts, 'Status', evidence.facts.get('status'));
      addFact(summaryParts, 'Priority', evidence.facts.get('priority'));
      addFact(summaryParts, 'Created', evidence.facts.get('createdDate'));
      addFact(summaryParts, 'Closed', evidence.facts.get('closedDate'));
    } else if (evidence.sourceType == 'Task') {
      item.displayLabel = 'Task';
      addFact(summaryParts, 'Status', evidence.facts.get('status'));
      addFact(summaryParts, 'Priority', evidence.facts.get('priority'));
      addFact(summaryParts, 'Due', evidence.facts.get('activityDate'));
    } else if (evidence.sourceType == 'Contact') {
      item.displayLabel = stringValue(
        evidence.facts.get('title'),
        'Contact role'
      );
      addFact(summaryParts, 'Department', evidence.facts.get('department'));
      addFact(summaryParts, 'Created', evidence.facts.get('createdDate'));
    }

    item.factSummary = String.join(summaryParts, ' · ');
    return item;
  }

  private static void addFact(List<String> parts, String label, Object value) {
    if (value != null && !String.isBlank(String.valueOf(value))) {
      parts.add(label + ': ' + String.valueOf(value));
    }
  }

  private static String stringValue(Object value, String fallbackValue) {
    return value == null || String.isBlank(String.valueOf(value))
      ? fallbackValue
      : String.valueOf(value);
  }
}
