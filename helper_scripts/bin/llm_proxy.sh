#!/bin/bash

DIR="$( cd "$(dirname "$(readlink -f "$0")")" || exit ; pwd -P )"

key_shell.sh azure_ad_lite bash -c "echo CHAT_MODEL=\$CHAT_MODEL"  > $DIR/litellm_proxy.env

# Run the command every 60 seconds in the background
# watch -n 60 "key_shell.sh azure_ad_lite bash -c \"echo \$AZURE_OPENAI_AD_TOKEN\" > $DIR/litellm_live_token" &

# TODO: get it from az cli
# export AZURE_CLIENT_ID=ac7af33c-2c68-41bc-b9ac-8bea1deaa178
# export AZURE_TENANT_ID=72f988bf-86f1-41af-91ab-2d7cd011db47
# It may needs to read the code in Azure's default credential to know more about how to make it works

# https://docs.litellm.ai/docs/providers/litellm_proxy
key_shell.sh azure_ad_lite litellm --config $DIR/../../configs/python/litellm.yaml  # --detailed_debug  # --debug

# logic:
# llm_proxy => get proxy.env => openai model => vim openai config

# exit all jobs
