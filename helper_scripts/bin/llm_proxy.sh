#!/bin/bash

DIR="$( cd "$(dirname "$(readlink -f "$0")")" || exit ; pwd -P )"

key_shell.sh azure_ad_lite bash -c "echo CHAT_MODEL=\$CHAT_MODEL"  > $DIR/litellm_proxy.env
# https://docs.litellm.ai/docs/providers/litellm_proxy
key_shell.sh azure_ad_lite litellm --config $DIR/../../configs/python/litellm.yaml  # --detailed_debug  # --debug

# logic:
# llm_proxy => get proxy.env => openai model => vim openai config
