#!/bin/sh
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

if [ -n "$appInsightConnectionString" ] && [ "$appInsightConnectionString" != "null" ]; then
  echo "########## Setting up Application Insights ###########"
  export APPLICATIONINSIGHTS_CONNECTION_STRING=$appInsightConnectionString
  export APPLICATIONINSIGHTS_METRIC_INTERVAL_SECONDS=10
  export JAVA_OPTS=-javaagent:"/tmp/ycsb/ycsb-azurecosmos-binding-0.18.0-SNAPSHOT/lib/applicationinsights-agent-3.5.1.jar"
fi
