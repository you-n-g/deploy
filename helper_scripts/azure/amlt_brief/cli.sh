#!/bin/sh
false << "EOF" > /dev/null
The permissions have been assigned to the RDAgentTeam group.

Most of the resources are in the RDAgentAPP group except
- it reuses eastus storage in the Fin-Cluster group

TODO:
- [ ] Add Registry for our dedicate image
  - [ ] start litellm
  - [ ] Merge Kaggle RD-Agent MLE-bench in one single image.
EOF

DIR="$( cd "$(dirname "$(readlink -f "$0")")" || exit ; pwd -P )"

cd $DIR

# Check if the necessary package and command are installed
if ! pip show amlt > /dev/null 2>&1; then
  echo "Required package 'amlt' is not installed. Exiting."
  exit 1
fi

if ! command -v az > /dev/null 2>&1; then
  echo "Required command 'az' is not installed. Exiting."
  exit 1
fi


init_project() {
  # initialize the project for the first time
  # pip show amlt > /dev/null 2>&1 || pip install -U amlt --index-url https://msrpypi.azurewebsites.net/stable/leloojoo

  amlt cred storage set epeastus --subscription e033d461-1923-44a7-872b-78f1d35a86dd --resource-group Fin-Cluster  --allow-local-storage   False

  amlt project checkout RD-Agent epeastus  #  `amlt project create RD-Agent epeastus` for the first time.

  amlt target info sing -v

  amlt workspace add RD-Agent --subscription e033d461-1923-44a7-872b-78f1d35a86dd --resource-group RDAgentAPP  # you should choose N!! when interacting.

  az extension add -n ml

  az ml workspace update -f uai.yaml --subscription e033d461-1923-44a7-872b-78f1d35a86dd --resource-group RDAgentAPP --name RD-Agent
}


submit_task() {
  amlt run task.yaml -y --pre  --az-login -d 'Rd-Agent-test'  # submit project
  # use command like `amlt ssh <experiment name like loving-glowworm>` to login onto the server
}


${1:-submit_task}
