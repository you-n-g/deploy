#!/usr/bin/env python
"""
This file is used together with key_shell.sh
It is used to check the usability of the OpenAI API.
"""
import os
from openai import AzureOpenAI
from litellm import completion
import typer
from azure.identity import DefaultAzureCredential, get_bearer_token_provider

app = typer.Typer()


@app.command()
def azure(deployment: str | None = None):
    """
    Example function to demonstrate Azure OpenAI chat completion.

    .. code-block:: shell

        hc_llm.py azure --deployment=$CHAT_MODEL

    Args:
        deployment_name (str): The name of the model deployment. Default is "gpt-4o".
    """
    if deployment is None:
        deployment = os.getenv("CHAT_MODEL", "gpt-4o")
    client = AzureOpenAI()

    response = client.chat.completions.create(model=deployment,
                                              messages=[{
                                                  "role": "system",
                                                  "content": "Assistant is a large language model trained by OpenAI."
                                              }, {
                                                  "role": "user",
                                                  "content": "Who were the founders of Microsoft?"
                                              }])

    # Print the response in JSON format with indentation
    print(response.model_dump_json(indent=2))
    # Print the content of the first choice message
    print(response.choices[0].message.content)


@app.command()
def azure_lite(deployment: str | None = None):
    """
    Function to demonstrate LiteLLM API calling for Azure OpenAI.

    Args:
        deployment (str): The name of the model deployment. Default is "gpt-4o".
    """
    if deployment is None:
        deployment = os.getenv("CHAT_MODEL", "gpt-4o")

    response = completion(
        model=f"azure/{deployment}",
        messages=[{
            "role": "system",
            "content": "Assistant is a large language model trained by OpenAI."
        }, {
            "role": "user",
            "content": "Who were the founders of Microsoft?"
        }]
    )

    # Print the response in JSON format with indentation
    print(response)


@app.command()
def get_azure_ad_token():
    credential = DefaultAzureCredential()
    token_provider = get_bearer_token_provider(
        credential,
        "https://cognitiveservices.azure.com/.default",
    )
    print(token_provider())


if __name__ == "__main__":
    app()
