#!/bin/sh

# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

cloud-init status --wait
echo "##########CUSTOM_SCRIPT_URL###########: $CUSTOM_SCRIPT_URL"

if [ -n $PROJECT_NAME ] && [ $PROJECT_NAME =~ .*[-_ ].* ]; then
  echo "Error: PROJECT_NAME does not match the required pattern. Project Name must start or end with a letter or number, and can contain only letters and numbers. No blankspace or special characters are allowed."
  exit 1
fi

# check to enforce only once instance of the workload is running. 
if pgrep -xf "bash custom-script.sh"
then
    echo Failing the deployment as a workload is already executing. Please wait for the current workload to finish on all clients, status can be checked in Azure storage workload metadata table.


    exit 1
else
    echo Starting the worklaod.
# Running custom-script in background, arm template completion wont wait on this
# stdout and stderr will be logged in <$HOME>/agent.out and <$HOME>/agent.err
    curl -o custom-script.sh $CUSTOM_SCRIPT_URL
    nohup bash custom-script.sh > "/home/${ADMIN_USER_NAME}/agent.out" 2> "/home/${ADMIN_USER_NAME}/agent.err" &
fi
