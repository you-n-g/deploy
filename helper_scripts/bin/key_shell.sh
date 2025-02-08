#!/bin/bash
false <<"EOF" >/dev/null
helper_scripts/bin/hc_llm.py azure --deployment=$CHAT_MODEL
EOF

DIR="$( cd "$(dirname "$(readlink -f "$0")")" || exit ; pwd -P )"

api_base=$(gpg -q --decrypt $HOME/deploy/keys/gpt.gpg | sed -n 1p)
azure_engine=$(gpg -q --decrypt $HOME/deploy/keys/gpt.gpg | sed -n 2p)
api_key=$(gpg -q --decrypt $HOME/deploy/keys/gpt.gpg | sed -n 3p)

# source the stdout from $(gpg -q --decrypt $HOME/deploy/keys/general.gpg)
if [ -f $HOME/deploy/keys/general.gpg ]; then
  eval "$(gpg -q --decrypt $HOME/deploy/keys/general.gpg)"
else
  echo "general.gpg not found; unable to source environment variables"
  exit 1
fi


# # Outlines: Credentials
openai_key_api_01() {
  OPENAI_API_KEY=sk-1234
  OPENAI_BASE_URL=http://127.0.0.1:4000

  if [ ! -e $DIR/litellm_proxy.env ]; then
    echo "litellm_proxy.env not found; llm_proxy.sh may not be run"
    exit 1
  fi

  # CHAT_MODEL=gpt-4o # avoid hardcode
  source $DIR/litellm_proxy.env
  CHAT_MODEL=$(python -c "print('$CHAT_MODEL'.split('/')[-1].split('_')[0])")
  echo $CHAT_MODEL
}

azure_key_api_01() {
  API_VERSION=2023-03-15-preview
  API_KEY=$api_key
  ENDPOINT=$api_base
  CHAT_MODEL=gpt-4o # you should specify it mannually
  export EXP_MODEL=gpt-4o
}

azure_ad_api_01() {
  CHAT_MODEL=gpt-4_0125-Preview
  export EXP_MODEL=gpt-4
  # CHAT_MODEL=gpt-4_turbo-2024-04-09
  # CHAT_MODEL=gpt-4-32k_0613
  # gpt-4_0125-Preview(2m) gpt-4_turbo-2024-04-09(1k) gpt-4-32k_0613(1k)
  API_VERSION=2024-08-01-preview
  END_POINT=https://gcraoai9ncusspot.openai.azure.com/
  AD_TOKEN=$(hc_llm.py get-azure-ad-token)
}

azure_ad_api_02() {
  CHAT_MODEL=gpt-4o_2024-05-13
  export EXP_MODEL=gpt-4o
  # CHAT_MODEL=gpt-4_1106-Preview
  # CHAT_MODEL=gpt-35-turbo_1106
  # We have: gpt-4_1106-Preview(5m) gpt-4o_2024-05-13(5m) gpt-35-turbo_1106 (10m)
  API_VERSION=2024-08-01-preview
  END_POINT=https://gcrgpt4aoai9spot.openai.azure.com/
  AD_TOKEN=$(hc_llm.py get-azure-ad-token)
}

azure_ad_api_03() {
  # CHAT_MODEL=gpt-4_1106-Preview
  # CHAT_MODEL=gpt-4_0125-Preview
  CHAT_MODEL=gpt-4o_2024-05-13
  export EXP_MODEL=gpt-4o
  # We have: gpt-4_1106-Preview(0.5m) gpt-4_0125-Preview(4m) gpt-4o_2024-05-13(5m)
  API_VERSION=2024-08-01-preview
  END_POINT=https://gcraoai9wus3spot.openai.azure.com/
  AD_TOKEN=$(hc_llm.py get-azure-ad-token)
}

azure_ad_api_select() {
  # azure_ad_api_01
  azure_ad_api_02  # 02 gpt-4o is always busy....
  # azure_ad_api_03  # 02 gpt-4o is always busy....
}

azure_key_api_select() {
  azure_key_api_01
}

# # Outlines: Usage format

# naming convention: underlying_protocol + sources + interface_protocol + model

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
  export CHAT_MODEL=azure/$CHAT_MODEL # you should specify it mannually
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
  export CHAT_MODEL=azure/$CHAT_MODEL # you should specify it mannually
}

azure_ad_default_lite() {
  azure_ad_lite
  unset AZURE_OPENAI_AD_TOKEN
}

openai() {
  openai_key_api_01
  export OPENAI_API_KEY=$OPENAI_API_KEY
  export OPENAI_BASE_URL=$OPENAI_BASE_URL
  export CHAT_MODEL=$CHAT_MODEL
}

openai_o3_mini() {
  openai_key_api_01
  export OPENAI_API_KEY=$OPENAI_API_KEY
  export OPENAI_BASE_URL=$OPENAI_BASE_URL
  export CHAT_MODEL=o3-mini
}

openai_lite() {
  openai_key_api_01
  export OPENAI_API_KEY=$OPENAI_API_KEY
  export OPENAI_API_BASE=$OPENAI_BASE_URL
  export CHAT_MODEL=$CHAT_MODEL
}

openai_lite_o3_mini() {
  openai_key_api_01
  export OPENAI_API_KEY=$OPENAI_API_KEY
  export OPENAI_API_BASE=$OPENAI_BASE_URL
  export CHAT_MODEL=o3-mini
}

deepseek_closeai_lite() {
  # export OPENAI_API_KEY=$CLOSEAI_API_KEY
  # export OPENAI_API_BASE=https://api.openai-proxy.org/v1
  # export CHAT_MODEL=deepseek-chat

  export DEEPSEEK_API_KEY=$CLOSEAI_API_KEY
  export DEEPSEEK_API_BASE=https://api.openai-proxy.org/v1
  export CHAT_MODEL=deepseek/deepseek-chat
}

anthropic_closeai_lite() {
  export ANTHROPIC_API_KEY=$CLOSEAI_API_KEY
  export ANTHROPIC_API_BASE=https://api.openai-proxy.org/anthropic
  export CHAT_MODEL=anthropic/claude-3-5-sonnet-latest
}

openai_closeai_lite_o3_mini() {
  export OPENAI_API_KEY=$CLOSEAI_API_KEY
  export OPENAI_API_BASE=https://api.openai-proxy.org/v1
  export CHAT_MODEL=o3-mini
}

deepseek_lite() {
  export DEEPSEEK_API_KEY=$DEEPSEEK_API_KEY
  export CHAT_MODEL=deepseek/deepseek-chat
}

# # Outlines: Extra alias and scenarios
azure_aider() {
  azure_lite
}

azure_ad_aider() {
  azure_ad_lite
}

lite_llm_proxy() {
  # https://docs.litellm.ai/docs/providers/litellm_proxy
  export LITELLM_PROXY_API_KEY=""
}

${1:-openai}

# Check if there are more than one argument
if [ "$#" -gt 1 ]; then
  # Print all arguments starting from the first one
  "${@:2}"
else
  # Start an interactive shell session
  exec $SHELL
fi
