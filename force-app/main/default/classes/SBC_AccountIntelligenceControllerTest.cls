@IsTest
private class SBC_AccountIntelligenceControllerTest {
    @TestSetup
    static void createSyntheticAccount() {
        insert new Account(Name = 'Synthetic Intelligence Account', Industry = 'Technology');
    }

    @IsTest
    static void generatesAndParsesGroundedAccountIntelligence() {
        Test.setMock(HttpCalloutMock.class, new OpenAIResponseMock(200, validResult(null)));

        Test.startTest();
        SBC_AccountIntelligencePresentation.Response response = SBC_AccountIntelligenceController.generateAccountIntelligence(
            syntheticAccountId()
        );
        Test.stopTest();

        SBC_AccountIntelligenceService.AccountIntelligenceResult result = response.result;
        System.assertEquals('Synthetic account summary.', result.executiveSummary);
        System.assertEquals('Healthy', result.customerHealth.level);
        System.assertEquals(82, result.healthScore.score);
        System.assertEquals('Low', result.churnRisk.level);
        System.assertEquals(1, result.growthOpportunities.size());
        System.assertEquals(1, result.businessRisks.size());
        System.assertEquals(1, result.recommendedActions.size());
        System.assertEquals('gpt-5.6-sol', result.model);
        System.assertEquals(1, response.evidenceCatalog.size());
        System.assertEquals('EV-001', response.evidenceCatalog[0].evidenceId);
        System.assertEquals('Account', response.evidenceCatalog[0].sourceType);
        System.assertEquals(syntheticAccountId(), response.evidenceCatalog[0].recordId);
        System.assertEquals('Synthetic Intelligence Account', response.evidenceCatalog[0].displayLabel);
        System.assert(response.evidenceCatalog[0].factSummary.contains('Industry: Technology'));
        String serializedResponse = JSON.serialize(response);
        System.assert(!serializedResponse.contains('facts'));
        System.assert(!serializedResponse.contains('Email'));
        System.assert(!serializedResponse.contains('Phone'));
    }

    @IsTest
    static void rejectsInvalidJson() {
        Test.setMock(HttpCalloutMock.class, new OpenAIResponseMock(200, '{invalid-json'));
        assertAccountIntelligenceFailure('Account Intelligence response is invalid.');
    }

    @IsTest
    static void rejectsUnknownEvidenceIds() {
        Test.setMock(HttpCalloutMock.class, new OpenAIResponseMock(200, validResult('EV-999')));
        assertAccountIntelligenceFailure(
            'Account Intelligence response contains unknown evidence.'
        );
    }

    @IsTest
    static void rejectsMissingRequiredFields() {
        Map<String, Object> resultValue = baseResult();
        resultValue.remove('healthScore');
        Test.setMock(
            HttpCalloutMock.class,
            new OpenAIResponseMock(200, JSON.serialize(resultValue))
        );
        assertAccountIntelligenceFailure('Account Intelligence response is invalid.');
    }

    @IsTest
    static void sanitizesRateLimitFailure() {
        Test.setMock(HttpCalloutMock.class, new OpenAIResponseMock(429, '{}'));
        assertOpenAIFailure('OpenAI request failed with HTTP status 429.');
    }

    @IsTest
    static void sanitizesServerFailure() {
        Test.setMock(HttpCalloutMock.class, new OpenAIResponseMock(500, '{}'));
        assertOpenAIFailure('OpenAI request failed with HTTP status 500.');
    }

    @IsTest
    static void sanitizesTimeoutFailure() {
        Test.setMock(HttpCalloutMock.class, new TimeoutMock());
        assertOpenAIFailure('OpenAI callout failed.');
    }

    private static Id syntheticAccountId() {
        return [SELECT Id FROM Account WHERE Name = 'Synthetic Intelligence Account' LIMIT 1].Id;
    }

    private static void assertAccountIntelligenceFailure(String expectedMessage) {
        Test.startTest();
        try {
            SBC_AccountIntelligenceController.generateAccountIntelligence(syntheticAccountId());
            System.assert(false, 'Expected Account Intelligence validation to fail.');
        } catch (SBC_AccountIntelligenceService.AccountIntelligenceException exceptionValue) {
            System.assertEquals(expectedMessage, exceptionValue.getMessage());
        }
        Test.stopTest();
    }

    private static void assertOpenAIFailure(String expectedMessage) {
        Test.startTest();
        try {
            SBC_AccountIntelligenceController.generateAccountIntelligence(syntheticAccountId());
            System.assert(false, 'Expected OpenAI call to fail.');
        } catch (SBC_OpenAIClient.OpenAIClientException exceptionValue) {
            System.assertEquals(expectedMessage, exceptionValue.getMessage());
        }
        Test.stopTest();
    }

    private static String validResult(String evidenceOverride) {
        Map<String, Object> resultValue = baseResult();
        if (evidenceOverride != null) {
            ((Map<String, Object>) resultValue.get('customerHealth')).put(
                'evidenceIds',
                new List<String>{ evidenceOverride }
            );
        }
        return JSON.serialize(resultValue);
    }

    private static Map<String, Object> baseResult() {
        return new Map<String, Object>{
            'executiveSummary' => 'Synthetic account summary.',
            'customerHealth' => new Map<String, Object>{
                'level' => 'Healthy',
                'explanation' => 'Synthetic health explanation.',
                'evidenceIds' => new List<String>{ 'EV-001' }
            },
            'healthScore' => new Map<String, Object>{
                'score' => 82,
                'explanation' => 'Synthetic score explanation.',
                'evidenceIds' => new List<String>{ 'EV-001' }
            },
            'churnRisk' => new Map<String, Object>{
                'level' => 'Low',
                'explanation' => 'Synthetic churn explanation.',
                'evidenceIds' => new List<String>{ 'EV-001' }
            },
            'growthOpportunities' => new List<Object>{
                new Map<String, Object>{
                    'title' => 'Synthetic growth',
                    'explanation' => 'Synthetic growth explanation.',
                    'evidenceIds' => new List<String>{ 'EV-001' }
                }
            },
            'businessRisks' => new List<Object>{
                new Map<String, Object>{
                    'title' => 'Synthetic risk',
                    'explanation' => 'Synthetic risk explanation.',
                    'evidenceIds' => new List<String>{ 'EV-001' }
                }
            },
            'recommendedActions' => new List<Object>{
                new Map<String, Object>{
                    'title' => 'Synthetic action',
                    'rationale' => 'Synthetic action rationale.',
                    'evidenceIds' => new List<String>{ 'EV-001' }
                }
            }
        };
    }

    private class OpenAIResponseMock implements HttpCalloutMock {
        private Integer statusCode;
        private String outputText;

        OpenAIResponseMock(Integer statusCode, String outputText) {
            this.statusCode = statusCode;
            this.outputText = outputText;
        }

        public HttpResponse respond(HttpRequest request) {
            System.assertEquals('callout:SBC_OpenAI/v1/responses', request.getEndpoint());
            System.assertEquals('POST', request.getMethod());
            Map<String, Object> requestBody = (Map<String, Object>) JSON.deserializeUntyped(
                request.getBody()
            );
            System.assertEquals('gpt-5.6', requestBody.get('model'));
            System.assertEquals(null, requestBody.get('tools'));
            String inputValue = (String) requestBody.get('input');
            System.assert(
                inputValue.startsWith('Analyze only the supplied Salesforce evidence.')
            );
            System.assert(inputValue.contains('EV-001'));
            System.assert(inputValue.contains('Synthetic Intelligence Account'));
            System.assert(!inputValue.contains('recordId'));
            System.assert(!inputValue.contains('EmailMessage'));
            System.assert(!inputValue.contains('never-sent@example.invalid'));
            Map<String, Object> textConfig = (Map<String, Object>) requestBody.get('text');
            Map<String, Object> formatConfig = (Map<String, Object>) textConfig.get('format');
            System.assertEquals('sbc_account_intelligence', formatConfig.get('name'));
            Map<String, Object> schema = (Map<String, Object>) formatConfig.get('schema');
            Map<String, Object> properties = (Map<String, Object>) schema.get('properties');
            System.assert(properties.containsKey('executiveSummary'));
            System.assert(properties.containsKey('recommendedActions'));

            HttpResponse response = new HttpResponse();
            response.setStatusCode(statusCode);
            response.setBody(
                JSON.serialize(
                    new Map<String, Object>{
                        'model' => 'gpt-5.6-sol',
                        'output' => new List<Object>{
                            new Map<String, Object>{
                                'type' => 'message',
                                'content' => new List<Object>{
                                    new Map<String, Object>{
                                        'type' => 'output_text',
                                        'text' => outputText
                                    }
                                }
                            }
                        }
                    }
                )
            );
            return response;
        }
    }

    private class TimeoutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            throw new CalloutException('Synthetic timeout detail that must not escape.');
        }
    }
}
