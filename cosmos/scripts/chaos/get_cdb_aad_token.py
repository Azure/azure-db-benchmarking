from azure.identity import DefaultAzureCredential
from azure.identity import ClientSecretCredential
import argparse

# This function returns an AAD token for the given endpoint using the given 
# 1. client_id only for managed identity
# 2. client_id, client_secret and tenant_id for service principal

def get_aad_token(endpoint, client_id, client_secret, tenant_id):
    if not client_secret:
        aad_credentials = DefaultAzureCredential(managed_identity_client_id=client_id)
    else: 
        aad_credentials = ClientSecretCredential(client_id, client_secret, tenant_id)
    
    result = endpoint.split(':')
    scope = result[0] + ":" + result[1] + "/.default"
    token = aad_credentials.get_token(scope)
    print (token.token)

parser = argparse.ArgumentParser()
parser.add_argument('--Endpoint', required=True, type=str, help='Endpoint')
parser.add_argument('--ClientId', required=True, type=str, help='ClientId')
parser.add_argument('--ClientSecret', required=False, type=str, help='ClientSecret', default=None)
parser.add_argument('--TenantId', required=False, type=str, help='TenantId', default=None)

args = parser.parse_args()

endpoint = args.Endpoint
client_id = args.ClientId
client_secret = args.ClientSecret
tenant_id = args.TenantId

get_aad_token(endpoint, client_id, client_secret, tenant_id)