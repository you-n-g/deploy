#!/bin/sh

api_base=$(gpg -q --decrypt $HOME/deploy/keys/gpt4.gpg | sed -n 1p)
azure_engine=$(gpg -q --decrypt $HOME/deploy/keys/gpt4.gpg | sed -n 2p)
api_key=$(gpg -q --decrypt $HOME/deploy/keys/gpt4.gpg | sed -n 3p)

# Shared keys
export OPENAI_API_KEY=$api_key
#
# Auzre keys
export OPENAI_API_TYPE='azure'
export OPENAI_API_BASE=$api_base
export OPENAI_API_AZURE_ENGINE=$azure_engine
export OPENAI_API_MODEL=$azure_engine
export AZURE_OPENAI_API_KEY=$api_key
export OPENAI_API_VERSION=2023-03-15-preview
export AZURE_OPENAI_ENDPOINT=$api_base
