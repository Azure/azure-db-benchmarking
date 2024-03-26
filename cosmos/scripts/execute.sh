#!/bin/sh

# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

cloud-init status --wait
echo "##########CUSTOM_SCRIPT_URL###########: $CUSTOM_SCRIPT_URL"

# check to enforce only once instance of the workload is running. 
if pgrep -xf "bash custom-script.sh"
then
    echo Failing the deployment as a workload is already executing. Please wait for the current workload to finish on all clients, status can be checked in Azure storage workload metadata table.


    exit 1
else
    echo Starting the workload.

# Setting up Application Insights
if [ -n "$APP_INSIGHT_CONN_STR" ] && [ "$APP_INSIGHT_CONN_STR" != "null" ]; then
  echo "########## Setting up Application Insights ###########"
  echo 'export APPLICATIONINSIGHTS_CONNECTION_STRING=${APP_INSIGHT_CONN_STR}' >> ~/.profile
  echo 'export APPLICATIONINSIGHTS_METRIC_INTERVAL_SECONDS=${APP_INSIGHT_METRIC_INTERVAL_IN_SECONDS}' >> ~/.profile
  echo 'export JAVA_OPTS=-javaagent:"/tmp/ycsb/ycsb-azurecosmos-binding-0.18.0-SNAPSHOT/lib/applicationinsights-agent-3.5.1.jar"' >> ~/.profile
  source ~/.profile
fi

# Running custom-script in background, arm template completion wont wait on this
# stdout and stderr will be logged in <$HOME>/custom-script.out and <$HOME>/custom-script.err
    curl -o custom-script.sh $CUSTOM_SCRIPT_URL
    nohup bash custom-script.sh >> "/home/${ADMIN_USER_NAME}/agent.out" 2>> "/home/${ADMIN_USER_NAME}/agent.err" &
fi
