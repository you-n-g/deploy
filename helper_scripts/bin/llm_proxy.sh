#!/bin/bash

DIR="$( cd "$(dirname "$(readlink -f "$0")")" || exit ; pwd -P )"

# https://docs.litellm.ai/docs/providers/litellm_proxy
key_shell.sh azure_ad_lite litellm --config $DIR/../../configs/python/litellm.yaml  --detailed_debug
