#!/usr/bin/env -S uv run --no-project --with openai --with typer --with pandas --with 'numpy<2' --with azure-identity --with litellm python
# numpy < 2 due to following error:
#   A module that was compiled using NumPy 1.x cannot be run in
#   NumPy 2.3.5 as it may crash. To support both 1.x and 2.x
#   versions of NumPy, modules must be compiled with NumPy 2.0.
#   Some module may need to rebuild instead e.g. with 'pybind11>=2.12'.
"""
This file is used together with key_shell.sh
It is used to check the usability of the OpenAI API.
"""
import os
from openai import Client
from openai import AzureOpenAI
from litellm import completion
import typer
from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from pathlib import Path

DIRNAME = Path(__file__).absolute().resolve().parent

app = typer.Typer()


@app.command()
def azure(model: str | None = None):
    """
    Example function to demonstrate Azure OpenAI chat completion.

    .. code-block:: shell

        hc_llm.py azure --model=$CHAT_MODEL

    Args:
        deployment_name (str): The name of the model model. Default is "gpt-4o".
    """
    if model is None:
        model = os.getenv("CHAT_MODEL", "gpt-4o")
    client = AzureOpenAI()

    response = client.chat.completions.create(model=model,
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


from pydantic import BaseModel


class ResponseFormat(BaseModel):
    ans: str


@app.command()
def litellm(
    model: str | None = None,
    system_role: str = "system",
    test_response_format: bool = False,
    reasoning_effort: str | None = None,
):
    """
    Function to demonstrate LiteLLM API calling for models.

    Args:
        model (str): The name of the model. Default is taken from ``$CHAT_MODEL`` or
                     ``gpt-4o`` when unset.
        json_mode (bool): Request the model to return a JSON object (if the model
                          supports it).
        reasoning_effort (str | None): Forwarded to LiteLLM/OpenAI for advanced
                                       control. ``None`` disables the parameter.
    """
    if model is None:
        model = os.getenv("CHAT_MODEL", "gpt-4o")

    kwargs = {}
    if test_response_format:
        kwargs["response_format"] = ResponseFormat
    if reasoning_effort is not None:
        kwargs["reasoning_effort"] = reasoning_effort

    response = completion(
        model=model,
        messages=[
            {
                "role": system_role,
                "content": "Assistant is a large language model trained by OpenAI.",
            },
            {
                "role": "user",
                "content": "Who were the founders of Microsoft?",
            },
        ],
        **kwargs,
    )

    # Print the response
    print(response)


@app.command()
def native(model: str = os.getenv("CHAT_MODEL", "gpt-3.5-turbo"),
           json_mode: bool = False,
           system_role: str = "system",
           stream: bool = True,
           reasoning_effort: str | None = None):
    """
    Function to demonstrate a native OpenAI API call.

    Args:
        model (str): The name of the model to use. Default is "gpt-3.5-turbo".
        json_mode (bool): If True, the response will be in JSON format. Default is False.
                          It is usually to test if a model support json mode.
                          If supported, it will raise exception.
    """
    # openai.api_key = os.getenv("OPENAI_API_KEY")
    print(f"{model=}")
    client = Client()
    kwargs = {}
    if json_mode:
        kwargs['response_format'] = {"type": "json_object"}
    if reasoning_effort is not None:
        kwargs['reasoning_effort'] = reasoning_effort
    if not stream:
        response = client.chat.completions.create(
            model=model,
            messages=[{
                "role": system_role,
                "content": "Assistant is a large language model trained by OpenAI."
            }, {
                "role": "user",
                "content": "Who were the founders of Microsoft?"
            }],
            **kwargs)
        print(response)
    else:
        # use streaming to print the streaming output (synchronously, not async)
        response = client.chat.completions.create(
            model=model,
            messages=[{
                "role": system_role,
                "content": "Assistant is a large language model trained by OpenAI."
            }, {
                "role": "user",
                "content": "Who were the founders of Microsoft?"
            }],
            stream=True,
            **kwargs)
        for chunk in response:
            if hasattr(chunk.choices[0].delta, "content") and chunk.choices[0].delta.content:
                print(chunk.choices[0].delta.content, end="", flush=True)
        print()  # for newline after streaming output


@app.command()
def embedding(model: str = os.getenv("EMBEDDING_MODEL", "text-embedding-ada-002")):
    """
    Function to test embedding generation using OpenAI API.

    Args:
        model (str): The name of the embedding model to use. Default is "text-embedding-ada-002".
    """
    client = Client()
    response = client.embeddings.create(model=model, input="OpenAI provides tools for developers.")

    # Print the embedding vector
    print("Embedding Vector:")
    print(response)


@app.command()
def get_azure_ad_token(print_token: bool = True):
    credential = DefaultAzureCredential()
    token_provider = get_bearer_token_provider(
        credential,
        "https://cognitiveservices.azure.com/.default",
    )
    token = token_provider()
    if print_token:
        print(token)
    return token


import yaml
from tqdm import tqdm
from litellm import completion
import pandas as pd  # Import pandas for data handling


def load_model_names_and_params(yaml_file, startswith):
    with open(yaml_file, 'r') as file:
        config = yaml.safe_load(file)
    return [(model['model_name'], model['litellm_params'])
            for model in config['model_list']
            if model['model_name'].startswith(startswith)]


def check_model(model_name, error_log):
    try:
        native(model_name)
        return True
    except Exception as e:
        error_log.append((model_name, str(e)))
        return False


@app.command()
def check_all_model(fname="litellm.yaml", startswith="uni_"):
    """
    Health check does not support azure default token provider.
    """
    error_log = []
    available_models = []
    yaml_file = DIRNAME.parent.parent / f'configs/python/{fname}'
    model_data = load_model_names_and_params(yaml_file, startswith)

    for model_name, _ in tqdm(model_data, desc="Checking model availability"):
        available = check_model(model_name, error_log)
        status = "available" if available else "unavailable"
        print(f"Model {model_name} is {status}.")
        if available:
            available_models.append(model_name)

    # Use pandas to print the final availability
    df_available = pd.DataFrame(available_models, columns=['Available Models'])
    df_errors = pd.DataFrame(error_log, columns=['Model Name', 'Error'])

    if not df_available.empty:
        print("\nSummary of Available Models:")
        print(df_available.to_string(index=False))

    if not df_errors.empty:
        print("\nSummary of Errors:")
        print(df_errors.to_string(index=False))


if __name__ == "__main__":
    app()
