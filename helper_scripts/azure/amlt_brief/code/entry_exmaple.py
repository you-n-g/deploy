from openai import AzureOpenAI
from azure.identity import ChainedTokenCredential, AzureCliCredential, ManagedIdentityCredential, get_bearer_token_provider
import re
import os

scope = "api://trapi/.default"
client_id = os.environ.get("AZURE_CLIENT_ID")
credential = get_bearer_token_provider(ChainedTokenCredential(
    AzureCliCredential(),
    ManagedIdentityCredential(client_id=client_id)
),scope)

api_version = '2024-10-21'  # Ensure this is a valid API version see: https://learn.microsoft.com/en-us/azure/ai-services/openai/api-version-deprecation#latest-ga-api-release
model_name = 'gpt-35-turbo'  # Ensure this is a valid model name
model_version = '1106'  # Ensure this is a valid model version
deployment_name = re.sub(r'[^a-zA-Z0-9-_]', '', f'{model_name}_{model_version}')  # If your Endpoint doesn't have harmonized deployment names, you can use the deployment name directly: see: https://aka.ms/trapi/models
instance = 'gcr/shared' # See https://aka.ms/trapi/models for the instance name, remove /openai (library adds it implicitly) 
endpoint = f'https://trapi.research.microsoft.com/{instance}'

client = AzureOpenAI(
    azure_endpoint=endpoint,
    azure_ad_token_provider=credential,
    api_version=api_version,
)

response = client.chat.completions.create(
    model=deployment_name,
    messages=[
        {
            "role": "user",
            "content": "Give a one word answer, what is the capital of France?",
        },
    ]
)
response_content = response.choices[0].message.content
print(response_content)
