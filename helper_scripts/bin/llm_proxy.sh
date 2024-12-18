#!/bin/bash

DIR="$(
  cd "$(dirname "$(readlink -f "$0")")" || exit
  pwd -P
)"
PORT=${1:-4000}
SELECT_CRED=${SELECT_CRED:-azure_ad_default_lite}

echo $SELECT_CRED

# new
export AZURE_SCOPE=api://trapi/.default
export AZURE_CREDENTIAL=AzureCliCredential

#Where the default model be placed
key_shell.sh $SELECT_CRED bash -c "echo CHAT_MODEL=\$CHAT_MODEL" >$DIR/litellm_proxy.env
# key_shell.sh $SELECT_CRED bash -c "echo AZURE_API_BASE=\$AZURE_API_BASE"
# key_shell.sh $SELECT_CRED bash -c "echo CHAT_MODEL=\$CHAT_MODEL"

# watch -n 120  "slee10 && OPENAI_BASE_URL=http://127.0.0.1:$PORT key_shell.sh openai hc_llm.py native" &> /dev/null &
# TODO: make sure the jobs start by '&' is stoped

# https://docs.litellm.ai/docs/providers/litellm_proxy
# key_shell.sh $SELECT_CRED `which litellm` $EXTRA_ARG --config $DIR/../../configs/python/litellm.yaml --port $PORT --detailed_debug # --debug
key_shell.sh $SELECT_CRED `which litellm` $EXTRA_ARG --config $DIR/../../configs/python/litellm.trapi.yaml --port $PORT --detailed_debug # --debug

# logic:
# llm_proxy => get proxy.env => openai model => vim openai config

# NOTE: known issue:
# https://github.com/BerriAI/litellm/issues/4417
# due to the issue above, we may need to use relaunch to restart the service.
# - client_ttl: 120 may not work as expected.
# You can fix it by
# - `pip install 'litellm[proxy]'`
# - `pip install git+https://github.com/you-n-g/litellm@feat/add_more_credential`
