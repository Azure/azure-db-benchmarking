from azure.identity import DefaultAzureCredential
from azure.identity import ClientSecretCredential
import argparse

# Author: Darshan Patnekar
# Date: 02/08/2024
# Version: 1.0

def get_aad_token(endpoint, client_id, client_secret, tenant_id):
    """:
    This function returns a Microsoft Entra ID token for the given endpoint using the given 
        1. client_id, client_secret and tenant_id combination when using a service principal
        2. client_id only when using a managed identity

    Args:
        endpoint (str): The endpoint for which to retrieve the Microsoft Entra ID token.
        client_id (str): The client ID of the Microsoft Entra ID application.
        client_secret (str): The client secret of the Microsoft Entra ID application.
        tenant_id (str): The ID of the Microsoft Entra ID tenant.

    Returns:
        str: The Microsoft Entra ID token.

    Raises:
        Exception: If the Microsoft Entra ID token cannot be retrieved.
    """
    try:
        if client_id and client_secret and tenant_id:
            aad_credentials = ClientSecretCredential(client_id, client_secret, tenant_id)
        elif client_id and not client_secret and not tenant_id:
            aad_credentials = DefaultAzureCredential(managed_identity_client_id=client_id)
        else:
            raise Exception("Either provide Client ID only to retrieve the Microsoft Entra ID token using Manged Identity or provide Client ID, Client Secret and Tenant ID to retrieve the Microsoft Entra ID token using Service Principal.")
        
        result = endpoint.split(':')
        scope = result[0] + ":" + result[1] + "/.default"
        token = aad_credentials.get_token(scope)
        print(token.token)
    except Exception as e:
        raise Exception("Failed to retrieve Microsoft Entra ID token: " + str(e))

parser = argparse.ArgumentParser()
parser.add_argument('--Endpoint', required=True, type=str, help='Endpoint')
parser.add_argument('--ClientId', required=True, type=str, help='ClientId')
parser.add_argument('--ClientSecret', required=False, type=str, default=None, nargs='?', help='ClientSecret')
parser.add_argument('--TenantId', required=False, type=str, default=None, nargs='?', help='TenantId')

args = parser.parse_args()

endpoint = args.Endpoint
client_id = args.ClientId
client_secret = args.ClientSecret if args.ClientSecret else None
tenant_id = args.TenantId if args.TenantId else None

try:
    get_aad_token(endpoint, client_id, client_secret, tenant_id)
except Exception as e:
    print("Error occurred while retrieving the Microsoft Entra ID token:", str(e))
