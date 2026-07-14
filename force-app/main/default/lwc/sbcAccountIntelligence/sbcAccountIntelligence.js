import { LightningElement, api } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import getTrustedContext from "@salesforce/apex/SBC_AccountIntelligenceController.getTrustedContext";
import generateAccountIntelligence from "@salesforce/apex/SBC_AccountIntelligenceController.generateAccountIntelligence";

const STAGES = [
  "Gathering Salesforce context",
  "Reasoning over trusted evidence",
  "Validating grounded output"
];

export default class SbcAccountIntelligence extends NavigationMixin(
  LightningElement
) {
  _recordId;
  context;
  contextError;
  result;
  isLoading = false;
  loadingStatus = STAGES[0];
  loadingStage = 0;
  loadingTimer;

  @api
  get recordId() {
    return this._recordId;
  }

  set recordId(value) {
    if (value !== this._recordId) {
      this._recordId = value;
      this.result = undefined;
      this.loadContext();
    }
  }

  disconnectedCallback() {
    this.clearLoadingTimer();
  }

  async loadContext() {
    this.context = undefined;
    this.contextError = undefined;
    if (!this.recordId) {
      return;
    }
    try {
      this.context = await getTrustedContext({ accountId: this.recordId });
    } catch (error) {
      this.contextError = this.isPermissionError(error)
        ? "permission"
        : "context";
    }
  }

  async handleGenerate() {
    if (this.isGenerateDisabled) {
      return;
    }
    this.result = undefined;
    this.contextError = undefined;
    this.isLoading = true;
    this.startLoadingNarration();
    try {
      const response = await generateAccountIntelligence({
        accountId: this.recordId
      });
      this.result = this.buildResultView(response);
    } catch (error) {
      this.contextError = this.isPermissionError(error)
        ? "permission"
        : "service";
    } finally {
      this.isLoading = false;
      this.clearLoadingTimer();
    }
  }

  handleTryAgain() {
    this.contextError = undefined;
    this.handleGenerate();
  }

  handleEvidenceToggle(event) {
    const sectionKey = event.currentTarget.dataset.section;
    const evidenceId = event.currentTarget.dataset.id;
    const currentConclusion = this.result.conclusions.find(
      (conclusion) => conclusion.key === sectionKey
    );
    const willExpand =
      currentConclusion?.expandedEvidence?.evidenceId !== evidenceId;
    this.result = {
      ...this.result,
      conclusions: this.result.conclusions.map((conclusion) => {
        if (conclusion.key !== sectionKey) {
          return conclusion;
        }
        return {
          ...conclusion,
          evidence: conclusion.evidence.map((item) => ({
            ...item,
            ariaExpanded: willExpand && item.evidenceId === evidenceId
          })),
          expandedEvidence:
            conclusion.expandedEvidence?.evidenceId === evidenceId
              ? undefined
              : conclusion.evidence.find(
                  (item) => item.evidenceId === evidenceId
                )
        };
      })
    };
  }

  handleRecordNavigation(event) {
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId: event.currentTarget.dataset.recordId,
        actionName: "view"
      }
    });
  }

  buildResultView(response) {
    const value = response?.result || {};
    const catalog = new Map(
      (response?.evidenceCatalog || []).map((item) => [item.evidenceId, item])
    );
    const conclusion = (key, title, item, bodyField = "explanation") => ({
      key,
      sectionTitle: title,
      itemTitle: undefined,
      label: item?.level,
      body: item?.[bodyField] || "No significant signals identified",
      evidence: (item?.evidenceIds || [])
        .filter((id) => catalog.has(id))
        .map((id) => ({
          ...catalog.get(id),
          ariaLabel: `Show evidence ${id}`,
          ariaExpanded: false
        }))
    });
    const list = (prefix, title, values, bodyField = "explanation") =>
      (values?.length
        ? values
        : [{ title: "No significant signals identified" }]
      ).map((item, index) => ({
        ...conclusion(
          `${prefix}-${index}`,
          index === 0 ? title : undefined,
          item,
          bodyField
        ),
        itemTitle: item.title
      }));

    return {
      executiveSummary:
        value.executiveSummary || "No significant signals identified",
      score: value.healthScore?.score ?? 0,
      scoreStyle: `width: ${Math.min(100, Math.max(0, value.healthScore?.score ?? 0))}%`,
      statusText: `Status: ${this.scoreLabel(value.healthScore?.score)}`,
      conclusions: [
        conclusion("health-score", "Score Rationale", value.healthScore),
        conclusion("customer-health", "Customer Health", value.customerHealth),
        conclusion("churn-risk", "Churn Risk", value.churnRisk),
        ...list("growth", "Growth Opportunities", value.growthOpportunities),
        ...list("risk", "Business Risks", value.businessRisks),
        ...list(
          "action",
          "Recommended Actions",
          value.recommendedActions,
          "rationale"
        )
      ]
    };
  }

  startLoadingNarration() {
    this.loadingStage = 0;
    this.loadingStatus = STAGES[0];
    this.clearLoadingTimer();
    // The timer advances documented UX narration only and is always cleaned up.
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this.loadingTimer = setInterval(() => {
      this.loadingStage = Math.min(this.loadingStage + 1, STAGES.length - 1);
      this.loadingStatus = STAGES[this.loadingStage];
    }, 1400);
  }

  clearLoadingTimer() {
    if (this.loadingTimer) {
      clearInterval(this.loadingTimer);
      this.loadingTimer = undefined;
    }
  }

  isPermissionError(error) {
    const message = error?.body?.message || "";
    return /access|permission|insufficient/i.test(message);
  }

  scoreLabel(score) {
    if (score >= 75) return "Strong";
    if (score >= 50) return "Watch";
    return "Needs attention";
  }

  get isGenerateDisabled() {
    return (
      !this.recordId ||
      !this.context ||
      this.isLoading ||
      Boolean(this.contextError)
    );
  }

  get hasContext() {
    return Boolean(this.context);
  }

  get showPermissionError() {
    return this.contextError === "permission";
  }

  get showContextError() {
    return this.contextError === "context";
  }

  get showServiceError() {
    return this.contextError === "service";
  }

  get hasMissingRecordId() {
    return !this.recordId;
  }

  get formattedOpportunityValue() {
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: "USD",
      maximumFractionDigits: 0
    }).format(this.context?.openOpportunityTotalValue || 0);
  }

  get priorityCaseLabel() {
    return this.context?.hasHighPriorityCase ? "Yes" : "No";
  }
}
