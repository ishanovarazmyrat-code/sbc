@IsTest
private class SBC_OpenAIClientTest {
    @IsTest
    static void returnsValidatedStructuredResponse() {
        Test.setMock(HttpCalloutMock.class, new ResponseMock(200, successfulResponse()));

        Test.startTest();
        SBC_OpenAIClient.ReadinessResponse result = SBC_OpenAIClient.assessReadiness();
        Test.stopTest();

        System.assertEquals('ready', result.status);
        System.assertEquals('Synthetic connectivity is ready.', result.summary);
        System.assertEquals('gpt-5.6-sol', result.model);
    }

    @IsTest
    static void sanitizesUnauthorizedResponse() {
        assertHttpFailure(401);
    }

    @IsTest
    static void sanitizesRateLimitResponse() {
        assertHttpFailure(429);
    }

    @IsTest
    static void sanitizesServerErrorResponse() {
        assertHttpFailure(500);
    }

    @IsTest
    static void sanitizesCalloutException() {
        Test.setMock(HttpCalloutMock.class, new ExceptionMock());

        Test.startTest();
        try {
            SBC_OpenAIClient.assessReadiness();
            System.assert(false, 'Expected a sanitized callout exception.');
        } catch (SBC_OpenAIClient.OpenAIClientException exceptionValue) {
            System.assertEquals('OpenAI callout failed.', exceptionValue.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void rejectsMalformedJson() {
        Test.setMock(HttpCalloutMock.class, new ResponseMock(200, '{not-json'));

        assertValidationFailure();
    }

    @IsTest
    static void rejectsMissingExpectedFields() {
        String responseBody = JSON.serialize(
            new Map<String, Object>{
                'model' => 'gpt-5.6-sol',
                'output' => new List<Object>{
                    new Map<String, Object>{
                        'type' => 'message',
                        'content' => new List<Object>{
                            new Map<String, Object>{
                                'type' => 'output_text',
                                'text' => '{"status":"ready","model":"gpt-5.6"}'
                            }
                        }
                    }
                }
            }
        );
        Test.setMock(HttpCalloutMock.class, new ResponseMock(200, responseBody));

        assertValidationFailure();
    }

    private static void assertHttpFailure(Integer statusCode) {
        Test.setMock(
            HttpCalloutMock.class,
            new ResponseMock(statusCode, '{"error":{"message":"sensitive remote detail"}}')
        );

        Test.startTest();
        try {
            SBC_OpenAIClient.assessReadiness();
            System.assert(false, 'Expected an HTTP failure.');
        } catch (SBC_OpenAIClient.OpenAIClientException exceptionValue) {
            System.assertEquals(
                'OpenAI request failed with HTTP status ' + statusCode + '.',
                exceptionValue.getMessage()
            );
            System.assert(!exceptionValue.getMessage().contains('sensitive remote detail'));
        }
        Test.stopTest();
    }

    private static void assertValidationFailure() {
        Test.startTest();
        try {
            SBC_OpenAIClient.assessReadiness();
            System.assert(false, 'Expected response validation to fail.');
        } catch (SBC_OpenAIClient.OpenAIClientException exceptionValue) {
            System.assertEquals('OpenAI response validation failed.', exceptionValue.getMessage());
        }
        Test.stopTest();
    }

    private static String successfulResponse() {
        return JSON.serialize(
            new Map<String, Object>{
                'model' => 'gpt-5.6-sol',
                'output' => new List<Object>{
                    new Map<String, Object>{
                        'type' => 'message',
                        'content' => new List<Object>{
                            new Map<String, Object>{
                                'type' => 'output_text',
                                'text' => JSON.serialize(
                                    new Map<String, Object>{
                                        'status' => 'ready',
                                        'summary' => 'Synthetic connectivity is ready.',
                                        'model' => 'gpt-5.6'
                                    }
                                )
                            }
                        }
                    }
                }
            }
        );
    }

    private class ResponseMock implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;

        ResponseMock(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }

        public HttpResponse respond(HttpRequest request) {
            System.assertEquals('callout:SBC_OpenAI/v1/responses', request.getEndpoint());
            System.assertEquals('POST', request.getMethod());
            System.assertEquals('application/json', request.getHeader('Content-Type'));
            System.assert(!request.getBody().contains('Account'));
            System.assert(!request.getBody().contains('Contact'));
            System.assert(!request.getBody().contains('Opportunity'));
            System.assert(!request.getBody().contains('Case'));
            System.assert(!request.getBody().contains('Task'));
            System.assert(!request.getBody().contains('email'));
            System.assert(!request.getBody().contains('phone'));

            Map<String, Object> requestBody = (Map<String, Object>) JSON.deserializeUntyped(
                request.getBody()
            );
            System.assertEquals('gpt-5.6', requestBody.get('model'));
            System.assertEquals(300, requestBody.get('max_output_tokens'));

            HttpResponse response = new HttpResponse();
            response.setStatusCode(statusCode);
            response.setBody(responseBody);
            return response;
        }
    }

    private class ExceptionMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            throw new CalloutException('Read timed out with sensitive transport detail.');
        }
    }
}
