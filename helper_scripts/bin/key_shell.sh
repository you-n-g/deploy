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

  # aider conversion (maybe default)
  export AZURE_API_KEY=$api_key
  export AZURE_API_VERSION=$API_VERSION
  export AZURE_API_BASE=$api_base

  # ChatGPT.nvim convention
  # export OPENAI_API_TYPE='azure'
  # export OPENAI_API_BASE=$api_base
  # export OPENAI_API_AZURE_ENGINE=$azure_engine

  # export OPENAI_API_MODEL=$azure_engine
  # export AZURE_OPENAI_API_KEY=$api_key
  # export OPENAI_API_VERSION=$API_VERSION
  # export AZURE_OPENAI_ENDPOINT=$api_base
}

${1:-azure}

$SHELL
