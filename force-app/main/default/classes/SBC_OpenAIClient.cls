public with sharing class SBC_OpenAIClient {
    private static final String NAMED_CREDENTIAL = 'callout:SBC_OpenAI';
    private static final String RESPONSES_PATH = '/v1/responses';
    private static final String MODEL = 'gpt-5.6';
    private static final Integer MAX_OUTPUT_TOKENS = 300;
    private static final Integer MAX_INPUT_LENGTH = 20000;
    private static final Integer TIMEOUT_MILLISECONDS = 30000;
    private static final String SYNTHETIC_PROMPT =
        'Return a structured readiness assessment for the SBC Build Week connectivity test.';

    public class ReadinessRequest {
        public String model;
        public String input;
        public Integer max_output_tokens;
        public Map<String, Object> text;
    }

    public class ReadinessResponse {
        public String status;
        public String summary;
        public String model;
    }

    public class StructuredResponse {
        public String model;
        public String outputText;
    }

    public class OpenAIClientException extends Exception {
    }

    public static ReadinessResponse assessReadiness() {
        HttpRequest request = new HttpRequest();
        request.setEndpoint(NAMED_CREDENTIAL + RESPONSES_PATH);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setTimeout(TIMEOUT_MILLISECONDS);
        request.setBody(JSON.serialize(buildRequest()));

        HttpResponse response;
        try {
            response = new Http().send(request);
        } catch (CalloutException exceptionValue) {
            throw new OpenAIClientException('OpenAI callout failed.');
        }

        if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
            throw new OpenAIClientException(
                'OpenAI request failed with HTTP status ' + response.getStatusCode() + '.'
            );
        }

        return parseResponse(response.getBody());
    }

    public static StructuredResponse sendStructuredRequest(
        String model,
        String input,
        String schemaName,
        Map<String, Object> schema,
        Integer maxOutputTokens
    ) {
        if (
            String.isBlank(model) ||
            String.isBlank(input) ||
            input.length() > MAX_INPUT_LENGTH ||
            String.isBlank(schemaName) ||
            schema == null ||
            maxOutputTokens == null ||
            maxOutputTokens <= 0
        ) {
            throw new OpenAIClientException('OpenAI structured request is invalid.');
        }

        HttpRequest request = new HttpRequest();
        request.setEndpoint(NAMED_CREDENTIAL + RESPONSES_PATH);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setTimeout(TIMEOUT_MILLISECONDS);
        request.setBody(
            JSON.serialize(
                new Map<String, Object>{
                    'model' => model,
                    'input' => input,
                    'max_output_tokens' => maxOutputTokens,
                    'text' => new Map<String, Object>{
                        'format' => new Map<String, Object>{
                            'type' => 'json_schema',
                            'name' => schemaName,
                            'strict' => true,
                            'schema' => schema
                        }
                    }
                }
            )
        );

        HttpResponse response;
        try {
            response = new Http().send(request);
        } catch (CalloutException exceptionValue) {
            throw new OpenAIClientException('OpenAI callout failed.');
        }

        if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
            throw new OpenAIClientException(
                'OpenAI request failed with HTTP status ' + response.getStatusCode() + '.'
            );
        }

        try {
            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(
                response.getBody()
            );
            String apiModel = (String) root.get('model');
            String outputText = findOutputText((List<Object>) root.get('output'));
            if (String.isBlank(apiModel) || !apiModel.startsWith(model)) {
                throw new OpenAIClientException('OpenAI response validation failed.');
            }

            StructuredResponse result = new StructuredResponse();
            result.model = apiModel;
            result.outputText = outputText;
            return result;
        } catch (OpenAIClientException exceptionValue) {
            throw exceptionValue;
        } catch (Exception exceptionValue) {
            throw new OpenAIClientException('OpenAI response validation failed.');
        }
    }

    private static ReadinessRequest buildRequest() {
        ReadinessRequest request = new ReadinessRequest();
        request.model = MODEL;
        request.input = SYNTHETIC_PROMPT;
        request.max_output_tokens = MAX_OUTPUT_TOKENS;

        Map<String, Object> schema = new Map<String, Object>{
            'type' => 'object',
            'additionalProperties' => false,
            'properties' => new Map<String, Object>{
                'status' => new Map<String, Object>{
                    'type' => 'string',
                    'enum' => new List<String>{ 'ready' }
                },
                'summary' => new Map<String, Object>{ 'type' => 'string' },
                'model' => new Map<String, Object>{
                    'type' => 'string',
                    'enum' => new List<String>{ MODEL }
                }
            },
            'required' => new List<String>{ 'status', 'summary', 'model' }
        };

        request.text = new Map<String, Object>{
            'format' => new Map<String, Object>{
                'type' => 'json_schema',
                'name' => 'sbc_connectivity_readiness',
                'strict' => true,
                'schema' => schema
            }
        };
        return request;
    }

    private static ReadinessResponse parseResponse(String responseBody) {
        try {
            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            String apiModel = (String) root.get('model');
            String outputText = findOutputText((List<Object>) root.get('output'));
            ReadinessResponse result = (ReadinessResponse) JSON.deserialize(
                outputText,
                ReadinessResponse.class
            );

            if (
                String.isBlank(apiModel) ||
                !apiModel.startsWith(MODEL) ||
                result == null ||
                String.isBlank(result.status) ||
                String.isBlank(result.summary) ||
                String.isBlank(result.model) ||
                result.model != MODEL
            ) {
                throw new OpenAIClientException('OpenAI response validation failed.');
            }

            result.model = apiModel;
            return result;
        } catch (OpenAIClientException exceptionValue) {
            throw exceptionValue;
        } catch (Exception exceptionValue) {
            throw new OpenAIClientException('OpenAI response validation failed.');
        }
    }

    private static String findOutputText(List<Object> outputItems) {
        if (outputItems == null) {
            throw new OpenAIClientException('OpenAI response validation failed.');
        }

        for (Object outputItemValue : outputItems) {
            Map<String, Object> outputItem = (Map<String, Object>) outputItemValue;
            if ((String) outputItem.get('type') != 'message') {
                continue;
            }

            List<Object> contentItems = (List<Object>) outputItem.get('content');
            if (contentItems == null) {
                continue;
            }

            for (Object contentItemValue : contentItems) {
                Map<String, Object> contentItem = (Map<String, Object>) contentItemValue;
                if ((String) contentItem.get('type') == 'output_text') {
                    String outputText = (String) contentItem.get('text');
                    if (!String.isBlank(outputText)) {
                        return outputText;
                    }
                }
            }
        }

        throw new OpenAIClientException('OpenAI response validation failed.');
    }
}
