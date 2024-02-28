<#
.SYNOPSIS
    Retrieves the control plane Microsoft Entra ID token.

.DESCRIPTION
    This script retrieves the control plane Microsoft Entra ID token using the provided client ID.

.PARAMETER clientId
    Specifies the client ID used to authenticate and authorize the request.

.EXAMPLE
    PS> get_control_plane_aad_token -clientId "12345678-1234-5678-1234-567812345678"
    
.NOTES
    Author: Darshan Patnekar
    Date: 02/08/2024
    Version: 1.0
#>

param (
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string] $clientId
)

Add-Type -AssemblyName System.Web

try {
    $resource = "https://management.azure.com/"
    $uri = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&client_id=" + $clientId + "&resource=" + $resource
    $response = Invoke-RestMethod -Method Get -Headers @{Metadata="true"} -Uri $uri

    if ($null -ne $response -and $response.access_token -ne [string]::Empty) {
        $accessToken = $response.access_token
        $accessToken
    }
} 
catch {
    Write-Host "Error occurred while retrieving the control plane Microsoft Entra ID token: $_"
}