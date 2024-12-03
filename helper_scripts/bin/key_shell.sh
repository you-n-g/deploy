#!/bin/sh

api_base=$(gpg -q --decrypt $HOME/deploy/keys/gpt.gpg | sed -n 1p)
azure_engine=$(gpg -q --decrypt $HOME/deploy/keys/gpt.gpg | sed -n 2p)
api_key=$(gpg -q --decrypt $HOME/deploy/keys/gpt.gpg | sed -n 3p)

# Shared keys
openai() {
  export OPENAI_API_KEY=$api_key
}

azure() {
  API_VERSION=2023-03-15-preview

  # Default of openai-python
  export OPENAI_API_VERSION=$API_VERSION
  export AZURE_OPENAI_API_KEY=$api_key
  export AZURE_OPENAI_ENDPOINT=$api_base
  # export AZURE_OPENAI_AD_TOKEN=

  # ChatGPT.nvim convention
  # export OPENAI_API_TYPE='azure'
  # export OPENAI_API_BASE=$api_base
  # export OPENAI_API_AZURE_ENGINE=$azure_engine

  # export OPENAI_API_MODEL=$azure_engine
  # export AZURE_OPENAI_API_KEY=$api_key
  # export OPENAI_API_VERSION=$API_VERSION
  # export AZURE_OPENAI_ENDPOINT=$api_base
}

azure_ad() {
  export AZURE_OPENAI_ENDPOINT=https://gcraoai9ncusspot.openai.azure.com/
  export OPENAI_API_VERSION=2024-08-01-preview
  export AZURE_OPENAI_AD_TOKEN=$(hc_openai.py get-azure-ad-token)
  export CHAT_MODEL=gpt-4_0125-Preview # you should specify it mannually
}

azure_aider() {
  # aider uses litellm
  # https://github.com/BerriAI/litellm
  # () ad_token can be also supported
  export AZURE_API_KEY=$api_key
  export AZURE_API_VERSION=$API_VERSION
  export AZURE_API_BASE=$api_base
}

${1:-azure}

$SHELL
