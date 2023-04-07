#!/bin/bash

kubectl config use-context $4

BASE_CONFIG_MAP=test-env-config
STATUS_CHECK=$(kubectl get configmap  $BASE_CONFIG_MAP | grep $BASE_CONFIG_MAP )
if [ -z "$STATUS_CHECK" ]
then
     echo "base config map does not exist"
     kubectl create configmap $BASE_CONFIG_MAP --from-env-file=./test-env-file.properties
else 
     echo "base config map exists"
     kubectl delete configmap $BASE_CONFIG_MAP
     kubectl create configmap $BASE_CONFIG_MAP --from-env-file=./test-env-file.properties
fi

UUID=$(cat /proc/sys/kernel/random/uuid)
BENCHMARKING_SECRETS=benchmarking-secrets
STATUS_CHECK=$(kubectl get configmap  $UUID_CONFIG_MAP | grep $UUID_CONFIG_MAP )
if [ -z "$STATUS_CHECK" ]
then
     echo "UUID config map does not exist"
     kubectl create secret generic $BENCHMARKING_SECRETS --from-literal=GUID=$UUID --from-literal=RESULT_STORAGE_CONNECTION_STRING=$1 --from-literal=COSMOS_URI=$2 --from-literal=COSMOS_KEY=$3
else 
     echo "UUID config map exists"
     kubectl delete secret $BENCHMARKING_SECRETS
     kubectl create secret generic $BENCHMARKING_SECRETS --from-literal=GUID=$UUID --from-literal=RESULT_STORAGE_CONNECTION_STRING=$1 --from-literal=COSMOS_URI=$2 --from-literal=COSMOS_KEY=$3

fi

kubectl apply -f benchmarking-deployment-simple-1Pod.yaml