#!/bin/bash

# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

# Diagnostic script to identify which managed identity is being used by the VM

echo "=========================================="
echo "VM Managed Identity Diagnostic Script"
echo "=========================================="
echo ""

echo "1. Checking VM Identity via Azure Instance Metadata Service (IMDS)..."
echo "----------------------------------------------------------------------"
IMDS_RESPONSE=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/identity/info?api-version=2021-02-01")
echo "$IMDS_RESPONSE" | jq '.'
echo ""

echo "2. Extracting Identity Details..."
echo "----------------------------------------------------------------------"
TENANT_ID=$(echo "$IMDS_RESPONSE" | jq -r '.tenantId // "N/A"')
echo "Tenant ID: $TENANT_ID"
echo ""

echo "3. Getting Access Token from IMDS..."
echo "----------------------------------------------------------------------"
TOKEN_RESPONSE=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/")
ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')

if [ "$ACCESS_TOKEN" != "null" ] && [ -n "$ACCESS_TOKEN" ]; then
  echo "✓ Successfully obtained access token"
  
  # Decode JWT to get principal ID
  echo ""
  echo "4. Decoding Token to Extract Principal Information..."
  echo "----------------------------------------------------------------------"
  # Extract payload (second part of JWT)
  PAYLOAD=$(echo "$ACCESS_TOKEN" | cut -d'.' -f2)
  # Add padding if needed
  PADDED_PAYLOAD="${PAYLOAD}$(printf '%*s' $((${#PAYLOAD} % 4)) '' | tr ' ' '=')"
  # Decode base64
  DECODED=$(echo "$PADDED_PAYLOAD" | base64 -d 2>/dev/null)
  
  echo "$DECODED" | jq '{
    oid: .oid,
    appid: .appid,
    uti: .uti,
    iss: .iss,
    aud: .aud
  }'
  
  OBJECT_ID=$(echo "$DECODED" | jq -r '.oid // "N/A"')
  APP_ID=$(echo "$DECODED" | jq -r '.appid // "N/A"')
  
  echo ""
  echo "Principal (Object) ID: $OBJECT_ID"
  echo "Application (Client) ID: $APP_ID"
else
  echo "✗ Failed to obtain access token"
  echo "$TOKEN_RESPONSE" | jq '.'
fi

echo ""
echo "5. Checking Azure CLI Login Status..."
echo "----------------------------------------------------------------------"
if az account show &>/dev/null; then
  echo "✓ Azure CLI is logged in"
  az account show | jq '{
    name: .name,
    tenantId: .tenantId,
    user: .user
  }'
else
  echo "✗ Azure CLI is not logged in"
  echo "Attempting login with managed identity..."
  az login --identity --allow-no-subscriptions
  if [ $? -eq 0 ]; then
    echo "✓ Successfully logged in with managed identity"
    az account show | jq '{
      name: .name,
      tenantId: .tenantId,
      user: .user
    }'
  else
    echo "✗ Failed to login with managed identity"
  fi
fi

echo ""
echo "6. Summary..."
echo "----------------------------------------------------------------------"
echo "VM's Managed Identity Information:"
echo "  - Tenant ID: $TENANT_ID"
echo "  - Principal (Object) ID: $OBJECT_ID"
echo "  - Client (Application) ID: $APP_ID"
echo ""
echo "To assign Cosmos DB RBAC role, use:"
echo "  az cosmosdb sql role assignment create \\"
echo "    --account-name <cosmos-account> \\"
echo "    --resource-group <resource-group> \\"
echo "    --role-definition-id 00000000-0000-0000-0000-000000000002 \\"
echo "    --principal-id $OBJECT_ID \\"
echo "    --scope /"
echo ""
echo "To assign Storage RBAC roles, use:"
echo "  az role assignment create \\"
echo "    --role 'Storage Blob Data Contributor' \\"
echo "    --assignee $APP_ID \\"
echo "    --scope /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Storage/storageAccounts/<storage-account>"
echo ""
echo "=========================================="
echo "Diagnostic Complete"
echo "=========================================="
