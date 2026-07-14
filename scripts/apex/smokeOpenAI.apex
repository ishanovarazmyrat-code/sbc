SBC_OpenAIClient.ReadinessResponse result = SBC_OpenAIClient.assessReadiness();
System.debug(LoggingLevel.INFO, 'SBC connectivity status: ' + result.status);
System.debug(LoggingLevel.INFO, 'SBC connectivity model: ' + result.model);
System.debug(LoggingLevel.INFO, 'SBC connectivity summary: ' + result.summary);
