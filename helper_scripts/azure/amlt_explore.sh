#!/bin/bash

# dependency

pip install yq

# Creating workspace:

# Example of 

pip install -U amlt --index-url https://msrpypi.azurewebsites.net/stable/leloojoo


# test

cd ~/tmp/test_amlt
mkdir -p ~/tmp/test_amlt


# Need `Storage Account Contributor` role.
amlt cred storage set epeastus --subscription e033d461-1923-44a7-872b-78f1d35a86dd --resource-group Fin-Cluster  --allow-local-storage   False


# Need `Storage Table Data Contributor role` permission
amlt project list epeastus

amlt project create RD-Agent epeastus  # `amlt project checkout RD-Agent epeastus` in the future.


amlt target info sing -v


# Activate `Data Scientist MSR` role in Azure Portal


amlt workspace add RD-Agent --subscription e033d461-1923-44a7-872b-78f1d35a86dd --resource-group RDAgentAPP  # you should choose N!!

amlt workspace set-default mckinley01 RD-Agent


az extension add -n ml



cat << 'EOF' > uai.yml
identity: 
  type: system_assigned,user_assigned 
  user_assigned_identities: 
   '/subscriptions/e033d461-1923-44a7-872b-78f1d35a86dd/resourceGroups/RDAgentAPP/providers/Microsoft.ManagedIdentity/userAssignedIdentities/RDAgent_MI': {} 
primary_user_assigned_identity: /subscriptions/e033d461-1923-44a7-872b-78f1d35a86dd/resourceGroups/RDAgentAPP/providers/Microsoft.ManagedIdentity/userAssignedIdentities/RDAgent_MI
EOF


az ml workspace update -f uai.yml --subscription e033d461-1923-44a7-872b-78f1d35a86dd --resource-group RDAgentAPP --name RD-Agent

false << "EOF" > /dev/null
{
  "allow_roleassignment_on_rg": true,
  "application_insights": "/subscriptions/e033d461-1923-44a7-872b-78f1d35a86dd/resourceGroups/RDAgentAPP/providers/Microsoft.insights/components/rdagent4466146283",
  "description": "",
  "discovery_url": "https://eastus.api.azureml.ms/discovery",
  "display_name": "RD-Agent",
  "enable_data_isolation": false,
  "hbi_workspace": false,
  "id": "/subscriptions/e033d461-1923-44a7-872b-78f1d35a86dd/resourceGroups/RDAgentAPP/providers/Microsoft.MachineLearningServices/workspaces/RD-Agent",
  "identity": {
    "principal_id": "e94f5a51-fc98-4c7c-b7e2-51dfe028aeb9",
    "tenant_id": "72f988bf-86f1-41af-91ab-2d7cd011db47",
    "type": "system_assigned,user_assigned",
    "user_assigned_identities": {
      "/subscriptions/e033d461-1923-44a7-872b-78f1d35a86dd/resourceGroups/RDAgentAPP/providers/Microsoft.ManagedIdentity/userAssignedIdentities/RDAgent_MI": {
        "client_id": "4eeb969a-ad22-4bc4-8506-b75fcec3f38f",
        "principal_id": "1118d738-fcf3-45df-850e-19c699c7b943"
      }
    }
  },
  "key_vault": "/subscriptions/e033d461-1923-44a7-872b-78f1d35a86dd/resourceGroups/RDAgentAPP/providers/Microsoft.Keyvault/vaults/rdagent1824509333",
  "location": "eastus",
  "managed_network": {
    "isolation_mode": "disabled",
    "outbound_rules": []
  },
  "mlflow_tracking_uri": "azureml://eastus.api.azureml.ms/mlflow/v1.0/subscriptions/e033d461-1923-44a7-872b-78f1d35a86dd/resourceGroups/RDAgentAPP/providers/Microsoft.MachineLearningServices/workspace
s/RD-Agent",
  "name": "RD-Agent",
  "primary_user_assigned_identity": "/subscriptions/e033d461-1923-44a7-872b-78f1d35a86dd/resourceGroups/RDAgentAPP/providers/Microsoft.ManagedIdentity/userAssignedIdentities/RDAgent_MI",
  "public_network_access": "Enabled",
  "resourceGroup": "RDAgentAPP",
  "resource_group": "RDAgentAPP",
  "storage_account": "/subscriptions/e033d461-1923-44a7-872b-78f1d35a86dd/resourceGroups/Fin-Cluster/providers/Microsoft.Storage/storageAccounts/epeastus",
  "system_datastores_auth_mode": "identity",
  "tags": {}
}
EOF

mkdir tmp

echo 'print(123)' > tmp/test.py

cat << 'EOF' > task.yaml
description: RD-Agent-test

target:
  service: sing
  # name: msroctobasicvc
  # name: palisades03
  name: mckinley01
  workspace_name: RD-Agent

# environment:
#   image: amlt-sing/acpt-2.2.1-py3.10-cuda12.1
environment:
  registry: singularitybase.azurecr.io
  image: base/job/pytorch/acpt-2.2.1-py3.10-cuda12.1:20240312T225111416

code:
  # local directory of the code. this will be uploaded to the server.
  local_dir: $CONFIG_DIR/tmp/

storage:
  shared_datastore:
    # storage_account_name: blob4wjp
    # container_name: shared
    # mount_dir: /data/Blob
    storage_account_name: epeastus
    container_name: cov19
    mount_dir: /data/Blob_EastUS

env_defaults:
  GPUS: 1
  RSLEX_DNS_RESOLUTION_CONCURRENCY: 1000

jobs:
  - name: test_v100_32g_GPUs${GPUS}
    identity: managed 
    tags: [Project_Name:Industry_Foundation_Models_Data_Science_Copilot,ProjectID:PRJ-0582-A42,Experiment:Scaling_GTL]
    submit_args: 
      env:
        _AZUREML_SINGULARITY_JOB_UAI: "/subscriptions/e033d461-1923-44a7-872b-78f1d35a86dd/resourceGroups/RDAgentAPP/providers/Microsoft.ManagedIdentity/userAssignedIdentities/RDAgent_MI" 
        RSLEX_DNS_RESOLUTION_CONCURRENCY: 1000
    sku: 32G${GPUS}-V100
    process_count_per_node: 1
    sla_tier: Premium
    priority: high
    command:
    - pwd
    - df -h
    - nvidia-smi
    - export RSLEX_DNS_RESOLUTION_CONCURRENCY=1000
    - sleep 2000
EOF

yq '.target.name="msrresrchlab"' task.yaml > task_basic.yaml


amlt run task.yaml


amlt run task_basic.yaml -y --pre  --az-login -d 'Rd-Agent-test'


ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyCommand="ssh -i ~/.ssh/id_rsa -W %h:%p -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null aiscuser@aisc-lab-westus2-cpml-aks-4.federation.singularity-lab.azure.com" aiscuser@node-0.cc6db2af-c3c3-48d2-8aa1-6898074a6bd2


# --az-login                      Mount the Azure login credentials into the container


amlt list # get the id of the job (in the EXPERIMENT_NAME column)
amlt ssh happy-boxer  # Waiting for job to start (status=queued).......
amlt ssh busy-wahoo
amlt ssh settled-lionfish
amlt ssh normal-pheasant
amlt ssh possible-parrot

ls ~/.azure/accessTokens.json
ls ~/.azure

curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash


# https://dev.azure.com/msresearch/GCR/_wiki/wikis/GCR%20Wiki/14286/Access-resources-in-the-job-container-using-UAI
# https://dev.azure.com/msresearch/MSR%20Engineering/_wiki/wikis/MSR-Engineering.wiki/13502/Accessing-APIs-with-OAuth
#
# https://dev.azure.com/msresearch/MSR%20Engineering/_wiki/wikis/MSR-Engineering.wiki/14214/UAMI-(User-Assigned-Managed-Identity)-Amulet-Example
# https://dev.azure.com/msresearch/MSR%20Engineering/_wiki/wikis/MSR-Engineering.wiki/13502/Accessing-APIs-with-OAuth?anchor=managed-idens

