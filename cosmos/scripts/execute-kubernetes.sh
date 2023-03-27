#!/bin/bash

# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

echo "#####Building custom script url####"
customScriptUrl="https://raw.githubusercontent.com/${BENCHMARKING_FRAMEWORK_REPO}/${BENCHMARKING_FRAMEWORK_BRANCH}/cosmos/scripts/custom-script.sh"
export BENCHMARKING_TOOLS_URL="https://github.com/${BENCHMARKING_FRAMEWORK_REPO}.git"
export YCSB_GIT_REPO_URL="https://github.com/${YCSB_REPO}.git"
echo "BENCHMARKING_TOOLS_URL: $BENCHMARKING_TOOLS_URL"
echo "YCSB_GIT_REPO_URL: $YCSB_GIT_REPO_URL"
echo "customScriptUrl: $customScriptUrl"
curl -o custom-script.sh $customScriptUrl

# stdout and stderr will be logged in <$HOME>/custom-script.out, <$HOME>/custom-script.err and all output will go to the console
bash custom-script.sh > >(tee $"/home/${ADMIN_USER_NAME}/agent.out") 2> >(tee "/home/${ADMIN_USER_NAME}/agent.err" >&2)

