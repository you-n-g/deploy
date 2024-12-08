#!/bin/bash

DIR="$( cd "$(dirname "$(readlink -f "$0")")" || exit ; pwd -P )"
PORT=${1:-4000}

key_shell.sh azure_ad_default_lite bash -c "echo CHAT_MODEL=\$CHAT_MODEL"  > $DIR/litellm_proxy.env

# watch -n 120  "slee10 && OPENAI_BASE_URL=http://127.0.0.1:$PORT key_shell.sh openai hc_llm.py native" &> /dev/null &
# TODO: make sure the jobs start by '&' is stoped

# https://docs.litellm.ai/docs/providers/litellm_proxy
key_shell.sh azure_ad_default_lite litellm --config $DIR/../../configs/python/litellm.yaml --port $PORT  --detailed_debug  # --debug

# logic:
# llm_proxy => get proxy.env => openai model => vim openai config




# NOTE: known issue:
# https://github.com/BerriAI/litellm/issues/4417
# due to the issue above, we may need to use relaunch to restart the service.
# - client_ttl: 120 may not work as expected.
