#!/bin/bash

while getopts s:u:k:c:r: flag
do
    case "${flag}" in
        s) storageconnstring=${OPTARG};;
        u) cosmosuri=${OPTARG};;
        k) cosmosmkey=${OPTARG};;
        c) clustername=${OPTARG};;
        r) clusterrg=${OPTARG};;
    esac
done

usage(){  
 echo "Usage: ./driver.sh -s '<storage-connection>' -u '<cosmos-uri>' -k '<cosmos-key>' -c '<aks-cluster-name>' -r '<aks-cluster-resource-group>'"
 }

if [[ -z "$storageconnstring" ]]
then
  echo "Srorage account connection string is missing. Pass it with -s flag"
  usage
  exit 1
fi

if [[ -z "$cosmosuri" ]]
then
  echo "Cosmos uri is missing. Pass it with -u flag"
  usage
  exit 1
fi

if [[ -z "$cosmosmkey" ]]
then
  echo "Cosmos key is missing. Pass it with -k flag"
  usage
  exit 1
fi

if [[ -z "$clustername" ]]
then
  echo "AKS cluster name is missing. Pass it with -c flag"
  usage
  exit 1
fi

if [[ -z "$clusterrg" ]]
then
  echo "Resource group name of the AKS cluster is missing. Pass it with -r flag"
  usage
  exit 1
fi


# get cluster credentials
az aks get-credentials -n $clustername -g $clusterrg

# setting the cluster
kubectl config use-context $clustername

# create recipe configmap from file that containes workload configuration 
RECIPE_CONFIG_MAP=benchmarking-recipe-config
STATUS_CHECK=$(kubectl get configmap  $RECIPE_CONFIG_MAP | grep $RECIPE_CONFIG_MAP )
if [ -n "$STATUS_CHECK" ]
then
     kubectl delete configmap $RECIPE_CONFIG_MAP
fi    
kubectl create configmap $RECIPE_CONFIG_MAP --from-env-file=./recipe-env-file.properties

# create secrets config map to store secrets and UUID 
UUID=$(cat /proc/sys/kernel/random/uuid)
BENCHMARKING_SECRETS=benchmarking-secrets
STATUS_CHECK=$(kubectl get secrets  $BENCHMARKING_SECRETS | grep $BENCHMARKING_SECRETS )
if [ -n "$STATUS_CHECK" ]
then
     kubectl delete secret $BENCHMARKING_SECRETS
fi
kubectl create secret generic $BENCHMARKING_SECRETS --from-literal=GUID=$UUID --from-literal=RESULT_STORAGE_CONNECTION_STRING=$storageconnstring --from-literal=COSMOS_URI=$cosmosuri --from-literal=COSMOS_KEY=$cosmosmkey

# generate base deployment template 
./generate-deploymnet-file.sh

# create resources
kubectl apply -f benchmarking-deployment-generated.yaml
