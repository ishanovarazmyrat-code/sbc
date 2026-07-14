public with sharing class SBC_AccountIntelligenceService {
  private static final String MODEL = 'gpt-5.6';
  private static final Integer MAX_OUTPUT_TOKENS = 1000;
  private static final String SCHEMA_NAME = 'sbc_account_intelligence';
  private static final String INSTRUCTIONS = 'Use only supplied Salesforce evidence; never invent facts. Keep the summary to 2–3 short sentences and explanations to 1–2 concise sentences. Cite evidenceIds for every non-summary conclusion. Return at most three growth opportunities, three business risks, and three recommended actions. Context: ';

  public class AccountIntelligenceException extends Exception {
  }

  public class AccountIntelligenceResult {
    @AuraEnabled
    public String model { get; set; }
    @AuraEnabled
    public String executiveSummary { get; set; }
    @AuraEnabled
    public CustomerHealth customerHealth { get; set; }
    @AuraEnabled
    public HealthScore healthScore { get; set; }
    @AuraEnabled
    public ChurnRisk churnRisk { get; set; }
    @AuraEnabled
    public List<Signal> growthOpportunities { get; set; }
    @AuraEnabled
    public List<Signal> businessRisks { get; set; }
    @AuraEnabled
    public List<RecommendedAction> recommendedActions { get; set; }
  }

  public class CustomerHealth {
    @AuraEnabled
    public String level { get; set; }
    @AuraEnabled
    public String explanation { get; set; }
    @AuraEnabled
    public List<String> evidenceIds { get; set; }
  }

  public class HealthScore {
    @AuraEnabled
    public Integer score { get; set; }
    @AuraEnabled
    public String explanation { get; set; }
    @AuraEnabled
    public List<String> evidenceIds { get; set; }
  }

  public class ChurnRisk {
    @AuraEnabled
    public String level { get; set; }
    @AuraEnabled
    public String explanation { get; set; }
    @AuraEnabled
    public List<String> evidenceIds { get; set; }
  }

  public class Signal {
    @AuraEnabled
    public String title { get; set; }
    @AuraEnabled
    public String explanation { get; set; }
    @AuraEnabled
    public List<String> evidenceIds { get; set; }
  }

  public class RecommendedAction {
    @AuraEnabled
    public String title { get; set; }
    @AuraEnabled
    public String rationale { get; set; }
    @AuraEnabled
    public List<String> evidenceIds { get; set; }
  }

  public static AccountIntelligenceResult generate(
    SBC_AccountIntelligenceContextService.AccountIntelligenceContext context
  ) {
    if (
      context == null ||
      context.evidence == null ||
      context.evidence.isEmpty()
    ) {
      throw new AccountIntelligenceException(
        'Account Intelligence context is invalid.'
      );
    }
    String contextJson = serializeModelContext(context.evidence);
    SBC_OpenAIClient.StructuredResponse apiResponse = SBC_OpenAIClient.sendStructuredRequest(
      MODEL,
      INSTRUCTIONS + contextJson,
      SCHEMA_NAME,
      buildSchema(),
      MAX_OUTPUT_TOKENS
    );

    AccountIntelligenceResult result;
    try {
      result = (AccountIntelligenceResult) JSON.deserialize(
        apiResponse.outputText,
        AccountIntelligenceResult.class
      );
    } catch (Exception exceptionValue) {
      throw new AccountIntelligenceException(
        'Account Intelligence response is invalid.'
      );
    }

    validateRequiredFields(result);
    validateEvidence(result, context.evidence);
    result.model = apiResponse.model;
    return result;
  }

  private static String serializeModelContext(
    List<SBC_AccountIntelligenceContextService.Evidence> evidence
  ) {
    List<Object> modelEvidence = new List<Object>();
    for (
      SBC_AccountIntelligenceContextService.Evidence evidenceItem : evidence
    ) {
      modelEvidence.add(
        new Map<String, Object>{
          'evidenceId' => evidenceItem.evidenceId,
          'sourceType' => evidenceItem.sourceType,
          'facts' => evidenceItem.facts
        }
      );
    }
    return JSON.serialize(
      new Map<String, Object>{ 'evidence' => modelEvidence }
    );
  }

  private static Map<String, Object> buildSchema() {
    Map<String, Object> evidenceIdsSchema = new Map<String, Object>{
      'type' => 'array',
      'items' => new Map<String, Object>{ 'type' => 'string' },
      'minItems' => 1,
      'maxItems' => 2,
      'description' => 'One or two supplied evidence identifiers supporting the conclusion.'
    };
    Map<String, Object> signalSchema = objectSchema(
      new Map<String, Object>{
        'title' => new Map<String, Object>{ 'type' => 'string' },
        'explanation' => new Map<String, Object>{
          'type' => 'string',
          'description' => 'A concise explanation of one or two sentences.'
        },
        'evidenceIds' => evidenceIdsSchema
      },
      new List<String>{ 'title', 'explanation', 'evidenceIds' }
    );
    Map<String, Object> actionSchema = objectSchema(
      new Map<String, Object>{
        'title' => new Map<String, Object>{ 'type' => 'string' },
        'rationale' => new Map<String, Object>{
          'type' => 'string',
          'description' => 'A concise rationale of one or two sentences.'
        },
        'evidenceIds' => evidenceIdsSchema
      },
      new List<String>{ 'title', 'rationale', 'evidenceIds' }
    );

    return objectSchema(
      new Map<String, Object>{
        'executiveSummary' => new Map<String, Object>{
          'type' => 'string',
          'description' => 'An executive summary of two or three short sentences.'
        },
        'customerHealth' => objectSchema(
          new Map<String, Object>{
            'level' => new Map<String, Object>{ 'type' => 'string' },
            'explanation' => new Map<String, Object>{
              'type' => 'string',
              'description' => 'A concise explanation of one or two sentences.'
            },
            'evidenceIds' => evidenceIdsSchema
          },
          new List<String>{ 'level', 'explanation', 'evidenceIds' }
        ),
        'healthScore' => objectSchema(
          new Map<String, Object>{
            'score' => new Map<String, Object>{
              'type' => 'integer',
              'minimum' => 0,
              'maximum' => 100
            },
            'explanation' => new Map<String, Object>{
              'type' => 'string',
              'description' => 'A concise explanation of one or two sentences.'
            },
            'evidenceIds' => evidenceIdsSchema
          },
          new List<String>{ 'score', 'explanation', 'evidenceIds' }
        ),
        'churnRisk' => objectSchema(
          new Map<String, Object>{
            'level' => new Map<String, Object>{ 'type' => 'string' },
            'explanation' => new Map<String, Object>{
              'type' => 'string',
              'description' => 'A concise explanation of one or two sentences.'
            },
            'evidenceIds' => evidenceIdsSchema
          },
          new List<String>{ 'level', 'explanation', 'evidenceIds' }
        ),
        'growthOpportunities' => arraySchema(signalSchema),
        'businessRisks' => arraySchema(signalSchema),
        'recommendedActions' => arraySchema(actionSchema)
      },
      new List<String>{
        'executiveSummary',
        'customerHealth',
        'healthScore',
        'churnRisk',
        'growthOpportunities',
        'businessRisks',
        'recommendedActions'
      }
    );
  }

  private static Map<String, Object> objectSchema(
    Map<String, Object> properties,
    List<String> requiredFields
  ) {
    return new Map<String, Object>{
      'type' => 'object',
      'additionalProperties' => false,
      'properties' => properties,
      'required' => requiredFields
    };
  }

  private static Map<String, Object> arraySchema(
    Map<String, Object> itemSchema
  ) {
    return new Map<String, Object>{
      'type' => 'array',
      'items' => itemSchema,
      'maxItems' => 3
    };
  }

  private static void validateRequiredFields(AccountIntelligenceResult result) {
    if (
      result == null ||
      String.isBlank(result.executiveSummary) ||
      result.customerHealth == null ||
      String.isBlank(result.customerHealth.level) ||
      String.isBlank(result.customerHealth.explanation) ||
      result.healthScore == null ||
      result.healthScore.score == null ||
      result.healthScore.score < 0 ||
      result.healthScore.score > 100 ||
      String.isBlank(result.healthScore.explanation) ||
      result.churnRisk == null ||
      String.isBlank(result.churnRisk.level) ||
      String.isBlank(result.churnRisk.explanation) ||
      result.growthOpportunities == null ||
      result.businessRisks == null ||
      result.recommendedActions == null
    ) {
      throw new AccountIntelligenceException(
        'Account Intelligence response is invalid.'
      );
    }
  }

  private static void validateEvidence(
    AccountIntelligenceResult result,
    List<SBC_AccountIntelligenceContextService.Evidence> evidence
  ) {
    Set<String> knownEvidenceIds = new Set<String>();
    for (
      SBC_AccountIntelligenceContextService.Evidence evidenceItem : evidence
    ) {
      knownEvidenceIds.add(evidenceItem.evidenceId);
    }

    validateEvidenceIds(result.customerHealth.evidenceIds, knownEvidenceIds);
    validateEvidenceIds(result.healthScore.evidenceIds, knownEvidenceIds);
    validateEvidenceIds(result.churnRisk.evidenceIds, knownEvidenceIds);
    for (Signal signalValue : result.growthOpportunities) {
      if (
        signalValue == null ||
        String.isBlank(signalValue.title) ||
        String.isBlank(signalValue.explanation)
      ) {
        throw new AccountIntelligenceException(
          'Account Intelligence response is invalid.'
        );
      }
      validateEvidenceIds(signalValue.evidenceIds, knownEvidenceIds);
    }
    for (Signal signalValue : result.businessRisks) {
      if (
        signalValue == null ||
        String.isBlank(signalValue.title) ||
        String.isBlank(signalValue.explanation)
      ) {
        throw new AccountIntelligenceException(
          'Account Intelligence response is invalid.'
        );
      }
      validateEvidenceIds(signalValue.evidenceIds, knownEvidenceIds);
    }
    for (RecommendedAction actionValue : result.recommendedActions) {
      if (
        actionValue == null ||
        String.isBlank(actionValue.title) ||
        String.isBlank(actionValue.rationale)
      ) {
        throw new AccountIntelligenceException(
          'Account Intelligence response is invalid.'
        );
      }
      validateEvidenceIds(actionValue.evidenceIds, knownEvidenceIds);
    }
  }

  private static void validateEvidenceIds(
    List<String> evidenceIds,
    Set<String> knownEvidenceIds
  ) {
    if (evidenceIds == null || evidenceIds.isEmpty()) {
      throw new AccountIntelligenceException(
        'Account Intelligence response is invalid.'
      );
    }
    for (String evidenceId : evidenceIds) {
      if (!knownEvidenceIds.contains(evidenceId)) {
        throw new AccountIntelligenceException(
          'Account Intelligence response contains unknown evidence.'
        );
      }
    }
  }
}
