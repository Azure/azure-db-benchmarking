#!/bin/bash

kubectl config use-context $4

RECIPE_CONFIG_MAP=benchmarking-recipe-config
STATUS_CHECK=$(kubectl get configmap  $RECIPE_CONFIG_MAP | grep $RECIPE_CONFIG_MAP )
if [ -n "$STATUS_CHECK" ]
then
     kubectl delete configmap $RECIPE_CONFIG_MAP
fi    
kubectl create configmap $RECIPE_CONFIG_MAP --from-env-file=./recipe-env-file.properties


UUID=$(cat /proc/sys/kernel/random/uuid)
BENCHMARKING_SECRETS=benchmarking-secrets
STATUS_CHECK=$(kubectl get secrets  $BENCHMARKING_SECRETS | grep $BENCHMARKING_SECRETS )
if [ -n "$STATUS_CHECK" ]
then
     kubectl delete secret $BENCHMARKING_SECRETS
fi
kubectl create secret generic $BENCHMARKING_SECRETS --from-literal=GUID=$UUID --from-literal=RESULT_STORAGE_CONNECTION_STRING=$1 --from-literal=COSMOS_URI=$2 --from-literal=COSMOS_KEY=$3

kubectl apply -f benchmarking-deployment.yaml
