#!/bin/sh

pip install 'litellm[proxy]'
pip install git+https://github.com/you-n-g/litellm@add_mi_cred


export AZURE_CLIENT_ID
export AZURE_SCOPE=api://trapi/.default
export AZURE_CREDENTIAL=ManagedIdentityCredential

echo $AZURE_CLIENT_ID

# NOTE: please copy the latest config from https://github.com/you-n-g/deploy/blob/master/configs/python/litellm.trapi.yaml
nohup litellm --config litellm.yaml &


export OPENAI_API_KEY=sk-1234
export OPENAI_BASE_URL=http://127.0.0.1:4000

cat <<"EOF" > litellm_access_example.py
from openai import Client
client = Client()
response = client.chat.completions.create(model="gpt-4o",
                                          messages=[{
                                              "role": "system",
                                              "content": "Assistant is a large language model trained by OpenAI."
                                          }, {
                                              "role": "user",
                                              "content": "Who were the founders of Microsoft?"
                                          }])
print(response)
EOF

python litellm_access_example.py

