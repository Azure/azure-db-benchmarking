param (
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$clientId
)

try {
    $resource = "https://management.azure.com/"
    $response = Invoke-RestMethod -Method Get -Headers @{Metadata="true"} -Uri "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&client_id=$clientId&resource=$resource"

    if ($null -ne $response -and $response.access_token -ne [string]::Empty) {
        $accessToken = $response.access_token
        $accessToken
    }
} 
catch {
    Write-Host "Error occurred while getting bearer token: $_"
}