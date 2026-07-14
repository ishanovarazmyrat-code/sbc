# SBC

## AI Business Capability Platform for Salesforce

SBC is a Salesforce-native platform for delivering reusable, evidence-backed AI business capabilities. Its first implemented capability, Account Intelligence, converts bounded CRM context into structured customer analysis while Salesforce remains the system of record and OpenAI provides reasoning only.

[![Latest Release](https://img.shields.io/github/v/release/ishanovarazmyrat-code/sbc?label=release)](https://github.com/ishanovarazmyrat-code/sbc/releases/latest)
![Salesforce](https://img.shields.io/badge/Salesforce-API%2067.0-0D9DDA?logo=salesforce&logoColor=white)
![OpenAI](https://img.shields.io/badge/OpenAI-Responses%20API-412991?logo=openai&logoColor=white)
![Structured Outputs](https://img.shields.io/badge/Structured%20Outputs-Strict%20JSON-2E844A)
![Apex](https://img.shields.io/badge/Apex-Tested-032D60)
![LWC](https://img.shields.io/badge/LWC-SLDS-0176D3)

## Overview

Customer-facing teams often need to interpret opportunities, cases, tasks, contacts, and account details before deciding what deserves attention. The relevant facts exist in Salesforce, but assembling them into a concise account view is time-consuming and inconsistent.

SBC addresses this problem through business capabilities that collect a bounded set of permitted CRM facts, ask an OpenAI model to reason only over those facts, and return a validated result to Salesforce. Grounding matters because an unsupported recommendation is not actionable. Each non-summary conclusion therefore cites evidence identifiers that resolve to sanitized Salesforce records.

Salesforce remains authoritative throughout the flow. The current Account Intelligence capability performs no CRM writes and does not treat model output as source data.

## Key Features

### Grounded AI

The model receives only context assembled from standard Salesforce objects. Instructions prohibit invented facts, and Apex rejects conclusions that cite unknown evidence identifiers.

### Structured Outputs

The OpenAI Responses API is called with a strict JSON Schema. Apex deserializes the response into typed Account Intelligence DTOs and validates required sections before returning it to the UI.

### Evidence-backed recommendations

Customer health, churn risk, growth signals, business risks, and recommended actions include evidence references. Users can expand those references inline to inspect the supporting CRM facts.

### Trusted CRM Context Snapshot

Before generation, the component presents a bounded, sanitized snapshot that includes account identity, industry, open opportunities, open cases, contacts, and open tasks. Sensitive free text and contact details are excluded from the presentation.

### Read-only architecture

The capability reads CRM context with sharing and user-mode queries. Intelligence generation has no production DML path.

### Zero-DML intelligence generation

Generating Account Intelligence returns a transient presentation response. It does not create Tasks or modify Account, Opportunity, Case, Contact, or Task records.

### Capability Registry

A lightweight Custom Metadata Type describes the available and planned capabilities without introducing a plugin or dispatch framework:

- Account Intelligence — Available
- Customer Recommendation — Planned
- Executive Customer Briefing — Planned

### Lightning Web Components

The `sbcAccountIntelligence` LWC provides the Account record-page experience using SLDS-aligned responsive styling, accessible loading and error states, and keyboard-operable evidence controls.

### Salesforce navigation

Evidence cards use `NavigationMixin` to open the supporting Salesforce record when a permitted record identifier is available.

### Centralized OpenAI model configuration

The Account Intelligence service owns the requested model and output budget. The current implementation requests `gpt-5.6`, uses low reasoning effort and low text verbosity, and preserves strict structured output. This configuration is code-based rather than an administrator-facing runtime setting.

## Architecture

SBC separates CRM access, AI reasoning, validation, presentation mapping, and UI rendering.

```text
Salesforce Account record page
            ↓
Lightning Web Component
            ↓
Apex Controller
            ↓
Account Intelligence Context and Service
            ↓
OpenAI Client via Named Credential
            ↓
OpenAI Responses API
            ↓
Strict structured JSON
            ↓
Apex validation and presentation layer
            ↓
LWC rendering and evidence inspection
```

Responsibilities remain explicit:

- The context service performs bounded, deterministic, access-aware Salesforce queries.
- The Account Intelligence service owns the reasoning instructions, schema, parsing, and evidence validation.
- The OpenAI client owns HTTP transport, timeout handling, and sanitized transport errors.
- The presentation layer maps internal evidence into an allow-listed UI response.
- The LWC renders facts and AI analysis as visually distinct concepts.

## Account Intelligence Experience

The Account record-page flow is designed to be understandable without leaving Salesforce:

1. **Capability Catalog** — shows Account Intelligence as selected and two future capabilities as disabled.
2. **Trusted CRM Context Snapshot** — presents the safe facts available before generation.
3. **Generate Intelligence** — invokes the current Account using the existing Apex controller path.
4. **Executive Summary** — provides the primary account-level takeaway.
5. **Account Health Score** — displays a score from 0 to 100 with an accessible textual status.
6. **Customer Health** — explains the assessed relationship health.
7. **Churn Risk** — identifies and explains retention risk.
8. **Growth Opportunities** — lists grounded expansion signals.
9. **Business Risks** — lists material concerns found in the supplied evidence.
10. **Recommended Actions** — presents ordered, read-only next steps.
11. **Evidence references** — expand inline and can navigate to the underlying Salesforce record.

Empty and sparse CRM data are handled explicitly. The component shows honest zero values and uses “No significant signals identified” rather than leaving unexplained blank sections.

## AI Safety

The implementation applies several controls around model output:

- **Salesforce-only grounding:** the model is instructed to reason only from supplied CRM evidence.
- **No fabricated evidence:** every cited evidence ID must exist in the context assembled by Apex.
- **Strict schema:** Structured Outputs enforce the required result shape and bounded signal lists.
- **Typed parsing:** Apex deserializes the result into capability-specific DTOs.
- **Required-field validation:** missing or malformed sections are rejected before presentation.
- **Sanitized presentation:** the LWC receives an allow-listed evidence catalog, not raw SObjects or arbitrary maps.
- **Read-only execution:** generation performs no CRM DML.
- **Human review:** the UI identifies the result as AI-generated analysis that should be verified before action.

## Technology Stack

| Area                          | Technology                                          |
| ----------------------------- | --------------------------------------------------- |
| CRM platform                  | Salesforce                                          |
| Server-side application       | Apex                                                |
| User interface                | Lightning Web Components and SLDS                   |
| AI integration                | OpenAI Responses API                                |
| Response contract             | Strict Structured Outputs with JSON Schema          |
| Authentication                | Salesforce Named Credential and External Credential |
| Capability configuration      | Salesforce Custom Metadata Type                     |
| Frontend testing              | Salesforce LWC Jest                                 |
| Source and deployment tooling | Salesforce CLI                                      |

## Project Structure

```text
force-app/main/default/
├── classes/                     Apex services, controller, client, and tests
├── customMetadata/              Capability Registry records
├── lwc/sbcAccountIntelligence/  Account record-page LWC and Jest tests
└── objects/SBC_Capability__mdt/ Capability Registry type and fields
config/                          Scratch-org definition
docs/                            Secure credential setup guidance
manifest/package.xml             Deployment manifest
scripts/                         Focused Apex and SOQL utility scripts
sfdx-project.json                Salesforce DX project configuration
```

The primary Apex boundaries are:

- `SBC_AccountIntelligenceContextService` — trusted CRM context
- `SBC_AccountIntelligenceService` — prompt, schema, parsing, and validation
- `SBC_OpenAIClient` — Named Credential HTTP transport
- `SBC_AccountIntelligencePresentation` — safe UI response mapping
- `SBC_AccountIntelligenceController` — thin LWC entry point
- `SBC_CapabilityRegistry` — lightweight capability discovery

## Local Development

### Prerequisites

- Node.js and npm
- Salesforce CLI (`sf`)
- A Salesforce org with API access
- An OpenAI API project with billing enabled
- The Named Credential and External Credential configuration described in [`docs/openai-credential-setup.md`](docs/openai-credential-setup.md)

### Install dependencies

```bash
npm install
```

### Authenticate a Salesforce org

```bash
sf org login web --alias sbcp
sf config set target-org=sbcp
```

Use a different alias when appropriate for your environment.

### Deploy the project manifest

```bash
sf project deploy start --target-org sbcp --manifest manifest/package.xml
```

The LWC is exposed for Account record pages. Add **SBC Account Intelligence** to an Account Lightning record page through Lightning App Builder after deployment.

### Run frontend checks

```bash
npx prettier --check README.md force-app/main/default/lwc/sbcAccountIntelligence
npx eslint force-app/main/default/lwc/**/*.js
npx sfdx-lwc-jest -- --runInBand
```

### Run the focused Apex regression

```bash
sf apex run test \
  --target-org sbcp \
  --tests SBC_AIContextServiceTest \
  --tests SBC_AccountIntelligenceControllerTest \
  --tests SBC_OpenAIClientTest \
  --tests SBC_CapabilityRegistryTest \
  --wait 20 \
  --result-format human
```

Do not store API keys in source files. Authentication material belongs in Salesforce credential configuration and user-assigned principal access.

## Testing

The v0.5.0 implementation has been validated with:

- **24/24 Apex tests** covering context construction, presentation mapping, structured parsing, evidence validation, HTTP failures, malformed responses, and registry behavior.
- **8/8 Jest tests** covering catalog state, context presentation, loading, result hierarchy, evidence expansion, Salesforce navigation, error handling, and accessibility attributes.
- **Latency optimization** using a 120-second Apex transport timeout, a 1,000-token Account Intelligence output budget, low reasoning effort, and low text verbosity.
- **Live synthetic validation** confirming a structured GPT-5.6 result, validated evidence, and zero generation DML.

Tests use synthetic records, `HttpCalloutMock`, and Salesforce's default test-data isolation. No sensitive customer data is required.

## Roadmap

### Current

- [x] Capability Registry
- [x] Account Intelligence

### Planned

- [ ] Customer Recommendation
- [ ] Executive Customer Briefing
- [ ] Opportunity Intelligence
- [ ] Revenue Intelligence
- [ ] Customer 360

Planned items describe product direction only; they are not implemented in the current release.

## Release History

### v0.5.0 — Account Intelligence Salesforce Experience

- Introduced the Account Intelligence vertical slice on Salesforce Account record pages.
- Added grounded GPT-5.6 reasoning with strict structured output.
- Added evidence-backed results and inline Salesforce evidence inspection.
- Added the Trusted CRM Context Snapshot and zero-DML generation flow.
- Optimized the synchronous callout path for the Lightning experience.

See the [GitHub release](https://github.com/ishanovarazmyrat-code/sbc/releases/tag/v0.5.0).

## Screenshots

### Overview

> TODO: Add an Account record-page overview screenshot.

### Loading

> TODO: Add a loading-state screenshot.

### Generated Intelligence

> TODO: Add a generated Account Intelligence screenshot.

### Evidence Expansion

> TODO: Add an expanded evidence-card screenshot.

## License

License to be determined.
