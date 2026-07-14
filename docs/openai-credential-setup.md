# OpenAI credential setup for the connectivity spike

The OpenAI API key is a manual, server-side Salesforce Setup value. Never add
the key to this repository, Apex source, scripts, command history, or logs.

## External Credential

In **Setup → Named Credentials → External Credentials**, create:

- Label: `SBC OpenAI Authentication`
- Name: `SBC_OpenAI_Authentication`
- Authentication Protocol: `Custom`

Add a named principal:

- Parameter Name: `SBCOpenAI`
- Sequence Number: `1`
- Identity Type: `Named Principal`
- Authentication Parameter Name: `ApiKey`
- Authentication Parameter Value: the OpenAI API key

Add this custom header to the External Credential:

- Name: `Authorization`
- Value: `{!'Bearer ' & $Credential.SBC_OpenAI_Authentication.ApiKey}`
- Sequence Number: `1`

## Named Credential

In **Setup → Named Credentials → Named Credentials**, create:

- Label: `SBC OpenAI`
- Name: `SBC_OpenAI`
- URL: `https://api.openai.com`
- External Credential: `SBC OpenAI Authentication`
- Enabled for Callouts: enabled
- Generate Authorization Header: disabled
- Allow Formulas in HTTP Header: enabled
- Allow Formulas in HTTP Body: disabled

Grant the user who runs the smoke test access to the `SBCOpenAI` external
credential principal through a permission set or profile principal-access
mapping.

The Apex endpoint is `callout:SBC_OpenAI/v1/responses`; no Remote Site Setting
is required.
