import { createElement } from "lwc";
import SbcAccountIntelligence from "c/sbcAccountIntelligence";
import getTrustedContext from "@salesforce/apex/SBC_AccountIntelligenceController.getTrustedContext";
import generateAccountIntelligence from "@salesforce/apex/SBC_AccountIntelligenceController.generateAccountIntelligence";
import { mockNavigate } from "lightning/navigation";

jest.mock(
  "@salesforce/apex/SBC_AccountIntelligenceController.getTrustedContext",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/SBC_AccountIntelligenceController.generateAccountIntelligence",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "lightning/navigation",
  () => {
    const Navigate = Symbol("Navigate");
    const navigationSpy = jest.fn();
    const NavigationMixin = (Base) =>
      class extends Base {
        [Navigate](pageReference) {
          navigationSpy(pageReference);
        }
      };
    NavigationMixin.Navigate = Navigate;
    return { NavigationMixin, mockNavigate: navigationSpy };
  },
  { virtual: true }
);

const RECORD_ID = "001000000000001AAA";
const CONTEXT = {
  accountName: "Synthetic Account",
  industry: "Technology",
  openOpportunityCount: 2,
  openOpportunityTotalValue: 50000,
  openCaseCount: 1,
  hasHighPriorityCase: true,
  contactCount: 3,
  openTaskCount: 1
};
const EVIDENCE = {
  evidenceId: "EV-001",
  sourceType: "Account",
  recordId: RECORD_ID,
  displayLabel: "Synthetic Account",
  factSummary: "Industry: Technology"
};
const RESPONSE = {
  result: {
    executiveSummary: "A concise grounded summary.",
    healthScore: {
      score: 82,
      explanation: "Strong signals.",
      evidenceIds: ["EV-001"]
    },
    customerHealth: {
      level: "Healthy",
      explanation: "Stable relationship.",
      evidenceIds: ["EV-001"]
    },
    churnRisk: {
      level: "Low",
      explanation: "No major churn signal.",
      evidenceIds: ["EV-001"]
    },
    growthOpportunities: [
      {
        title: "Expansion",
        explanation: "Pipeline exists.",
        evidenceIds: ["EV-001"]
      }
    ],
    businessRisks: [
      {
        title: "Support load",
        explanation: "One case is open.",
        evidenceIds: ["EV-001"]
      }
    ],
    recommendedActions: [
      {
        title: "Review pipeline",
        rationale: "Validate next steps.",
        evidenceIds: ["EV-001", "EV-999"]
      }
    ]
  },
  evidenceCatalog: [EVIDENCE]
};

const flushPromises = async () => {
  await Promise.resolve();
  await Promise.resolve();
  await Promise.resolve();
};

async function createComponent(context = CONTEXT) {
  getTrustedContext.mockResolvedValue(context);
  const element = createElement("c-sbc-account-intelligence", {
    is: SbcAccountIntelligence
  });
  element.recordId = RECORD_ID;
  document.body.appendChild(element);
  await flushPromises();
  return element;
}

function text(element) {
  return element.shadowRoot.textContent.replace(/\s+/g, " ").trim();
}

describe("c-sbc-account-intelligence", () => {
  afterEach(() => {
    while (document.body.firstChild)
      document.body.removeChild(document.body.firstChild);
    jest.clearAllMocks();
    jest.useRealTimers();
  });

  it("renders the three-state capability catalog", async () => {
    const element = await createComponent();
    const capabilities = element.shadowRoot.querySelectorAll(".capability");
    expect(capabilities).toHaveLength(3);
    expect(capabilities[0].getAttribute("aria-current")).toBe("true");
    expect(capabilities[0].textContent).toContain("Available • Selected");
    expect(capabilities[1].getAttribute("aria-disabled")).toBe("true");
    expect(capabilities[2].getAttribute("aria-disabled")).toBe("true");
    expect(capabilities[1].querySelector("button")).toBeNull();
    expect(capabilities[2].querySelector("button")).toBeNull();
  });

  it("renders only the safe trusted context facts", async () => {
    const element = await createComponent();
    expect(text(element)).toContain("Synthetic Account");
    expect(text(element)).toContain("Trusted CRM Context Snapshot");
    expect(text(element)).toContain("Salesforce CRM Facts");
    expect(text(element)).toContain("$50,000");
    expect(text(element)).toContain("High-priority CaseYes");
    expect(text(element)).not.toMatch(/email|phone/i);
  });

  it("calls Apex with recordId, disables during loading, and narrates stages", async () => {
    jest.useFakeTimers();
    let resolveRequest;
    generateAccountIntelligence.mockReturnValue(
      new Promise((resolve) => {
        resolveRequest = resolve;
      })
    );
    const element = await createComponent();
    element.shadowRoot
      .querySelector("lightning-button.generate-button")
      .click();
    await flushPromises();
    expect(generateAccountIntelligence).toHaveBeenCalledWith({
      accountId: RECORD_ID
    });
    expect(
      element.shadowRoot.querySelector("lightning-button.generate-button")
        .disabled
    ).toBe(true);
    expect(text(element)).toContain("Gathering Salesforce context");
    jest.advanceTimersByTime(1400);
    await flushPromises();
    expect(text(element)).toContain("Reasoning over trusted evidence");
    resolveRequest(RESPONSE);
    await flushPromises();
  });

  it("renders the complete result hierarchy, score status, and sparse sections", async () => {
    generateAccountIntelligence.mockResolvedValue(RESPONSE);
    const element = await createComponent();
    element.shadowRoot
      .querySelector("lightning-button.generate-button")
      .click();
    await flushPromises();
    const content = text(element);
    [
      "Executive Summary",
      "Account Health Score",
      "Customer Health",
      "Churn Risk",
      "Growth Opportunities",
      "Business Risks",
      "Recommended Actions"
    ].forEach((heading) => expect(content).toContain(heading));
    expect(content).toContain("82/100");
    expect(content).toContain("Status: Strong");
    expect(content).toContain("Score Rationale");

    generateAccountIntelligence.mockResolvedValue({
      result: {
        executiveSummary: "Sparse",
        healthScore: { score: 0 },
        growthOpportunities: [],
        businessRisks: [],
        recommendedActions: []
      },
      evidenceCatalog: []
    });
    element.shadowRoot
      .querySelector("lightning-button.generate-button")
      .click();
    await flushPromises();
    expect(text(element)).toContain("No significant signals identified");
  });

  it("maps valid evidence, skips unknown IDs, and expands and collapses inline", async () => {
    generateAccountIntelligence.mockResolvedValue(RESPONSE);
    const element = await createComponent();
    element.shadowRoot
      .querySelector("lightning-button.generate-button")
      .click();
    await flushPromises();
    const chips = element.shadowRoot.querySelectorAll(".evidence-chip");
    expect([...chips].every((chip) => chip.textContent === "EV-001")).toBe(
      true
    );
    expect(text(element)).not.toContain("EV-999");
    expect(chips[0].getAttribute("aria-label")).toBe("Show evidence EV-001");
    chips[0].click();
    await flushPromises();
    expect(
      element.shadowRoot
        .querySelector(".evidence-chip")
        .getAttribute("aria-expanded")
    ).toBe("true");
    expect(element.shadowRoot.querySelector(".evidence-card")).not.toBeNull();
    expect(text(element)).toContain("Industry: Technology");
    element.shadowRoot.querySelector(".evidence-chip").click();
    await flushPromises();
    expect(
      element.shadowRoot
        .querySelector(".evidence-chip")
        .getAttribute("aria-expanded")
    ).toBe("false");
    expect(element.shadowRoot.querySelector(".evidence-card")).toBeNull();
  });

  it("navigates to a valid Salesforce evidence record", async () => {
    generateAccountIntelligence.mockResolvedValue(RESPONSE);
    const element = await createComponent();
    element.shadowRoot
      .querySelector("lightning-button.generate-button")
      .click();
    await flushPromises();
    element.shadowRoot.querySelector(".evidence-chip").click();
    await flushPromises();
    element.shadowRoot.querySelector(".record-link").click();
    expect(mockNavigate).toHaveBeenCalledWith({
      type: "standard__recordPage",
      attributes: { recordId: RECORD_ID, actionName: "view" }
    });
  });

  it("shows permission and service failures without raw errors and supports retry", async () => {
    getTrustedContext.mockRejectedValue({
      body: { message: "Insufficient access" }
    });
    const denied = createElement("c-sbc-account-intelligence", {
      is: SbcAccountIntelligence
    });
    denied.recordId = RECORD_ID;
    document.body.appendChild(denied);
    await flushPromises();
    expect(text(denied)).toContain("You do not have access");
    document.body.removeChild(denied);

    generateAccountIntelligence
      .mockRejectedValueOnce({ body: { message: "HTTP 500 raw" } })
      .mockResolvedValueOnce(RESPONSE);
    const element = await createComponent();
    element.shadowRoot
      .querySelector("lightning-button.generate-button")
      .click();
    await flushPromises();
    expect(text(element)).toContain(
      "We could not generate intelligence right now"
    );
    expect(text(element)).not.toContain("HTTP 500");
    const retry = [
      ...element.shadowRoot.querySelectorAll("lightning-button")
    ].find((button) => button.label === "Try Again");
    retry.click();
    await flushPromises();
    expect(generateAccountIntelligence).toHaveBeenCalledTimes(2);
    expect(text(element)).toContain("Executive Summary");
  });

  it("handles missing recordId with accessible, noninteractive controls", async () => {
    const element = createElement("c-sbc-account-intelligence", {
      is: SbcAccountIntelligence
    });
    document.body.appendChild(element);
    expect(text(element)).toContain("Open this component on an Account record");
    expect(
      element.shadowRoot.querySelector("lightning-button.generate-button")
        .disabled
    ).toBe(true);
    expect(element.shadowRoot.querySelector("section")).not.toBeNull();
  });
});
