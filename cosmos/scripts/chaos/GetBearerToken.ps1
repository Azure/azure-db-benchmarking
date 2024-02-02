param (
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$clientId,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$clientSecret,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$tenantId,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$resource
)

$tokenEndpoint = "https://login.microsoftonline.com/$tenantId/oauth2/token"

$body = @{
    grant_type    = "client_credentials"
    client_id     = $clientId
    client_secret = $clientSecret
    resource      = $resource
}

try {
    $response = Invoke-RestMethod -Uri $tokenEndpoint -Method POST -Body $body

    if ($null -ne $response -and $response.access_token -ne [string]::Empty) {
        $accessToken = $response.access_token
        $accessToken
    }
} 
catch {
    Write-Host "Error occurred while getting bearer token: $_"
}