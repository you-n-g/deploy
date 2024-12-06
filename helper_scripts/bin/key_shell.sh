#!/bin/bash
false <<"EOF" >/dev/null
helper_scripts/bin/hc_llm.py azure --deployment=$CHAT_MODEL
EOF

api_base=$(gpg -q --decrypt $HOME/deploy/keys/gpt.gpg | sed -n 1p)
azure_engine=$(gpg -q --decrypt $HOME/deploy/keys/gpt.gpg | sed -n 2p)
api_key=$(gpg -q --decrypt $HOME/deploy/keys/gpt.gpg | sed -n 3p)

# Shared keys
openai() {
  export OPENAI_API_KEY=$api_key
}

# # Outlines: Credentials

azure_key_api_01() {
  API_VERSION=2023-03-15-preview
  API_KEY=$api_key
  ENDPOINT=$api_base
  CHAT_MODEL=gpt-4o # you should specify it mannually
}

azure_ad_api_01() {
  CHAT_MODEL=gpt-4_0125-Preview
  API_VERSION=2024-08-01-preview
  END_POINT=https://gcraoai9ncusspot.openai.azure.com/
  AD_TOKEN=$(hc_llm.py get-azure-ad-token)
}

azure_ad_api_02() {
  CHAT_MODEL=gpt-4o_2024-05-13
  # We have: gpt-4_1106-Preview gpt-4o_2024-05-13 gpt-35-turbo_1106
  API_VERSION=2024-08-01-preview
  END_POINT=https://gcrgpt4aoai9spot.openai.azure.com/
  AD_TOKEN=$(hc_llm.py get-azure-ad-token)
}

azure_ad_api_select() {
  azure_ad_api_02
}

azure_key_api_select() {
  azure_key_api_01
}


# # Outlines: Usage format

azure() {
  azure_key_api_select
  # Default of openai-python
  export OPENAI_API_VERSION=$API_VERSION
  export AZURE_OPENAI_API_KEY=$API_KEY
  export AZURE_OPENAI_ENDPOINT=$ENDPOINT
  export CHAT_MODEL=$CHAT_MODEL # you should specify it mannually

  # ChatGPT.nvim convention
  # export OPENAI_API_TYPE='azure'
  # export OPENAI_API_BASE=$api_base
  # export OPENAI_API_AZURE_ENGINE=$azure_engine

  # export OPENAI_API_MODEL=$azure_engine
  # export AZURE_OPENAI_API_KEY=$api_key
  # export OPENAI_API_VERSION=$API_VERSION
  # export AZURE_OPENAI_ENDPOINT=$api_base
}

azure_lite() {
  azure_key_api_select
  # aider uses litellm
  # https://github.com/BerriAI/litellm
  export AZURE_API_KEY=$API_KEY
  export AZURE_API_VERSION=$API_VERSION
  export AZURE_API_BASE=$ENDPOINT
  export CHAT_MODEL=$CHAT_MODEL # you should specify it mannually
}

azure_ad() {
  azure_ad_api_select
  export AZURE_OPENAI_ENDPOINT=$END_POINT
  export OPENAI_API_VERSION=$API_VERSION
  export AZURE_OPENAI_AD_TOKEN=$AD_TOKEN
  export CHAT_MODEL=$CHAT_MODEL # you should specify it mannually
}

azure_ad_lite() {
  azure_ad_api_select
  export AZURE_API_BASE=$END_POINT
  export AZURE_API_VERSION=$API_VERSION
  export AZURE_OPENAI_AD_TOKEN=$AD_TOKEN
  export CHAT_MODEL=$CHAT_MODEL # you should specify it mannually
}

# # Outlines: Extra alias and scenarios
azure_aider() {
  azure_lite
}

azure_ad_aider() {
  azure_ad_lite
}

${1:-azure}

# Check if there are more than one argument
if [ "$#" -gt 1 ]; then
  # Print all arguments starting from the first one
  "${@:2}"
else
  # Start an interactive shell session
  exec $SHELL
fi
