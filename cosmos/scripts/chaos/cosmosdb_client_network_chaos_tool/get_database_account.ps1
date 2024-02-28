<#
.SYNOPSIS
    Retrieves the details of a database account.

.DESCRIPTION
    This script retrieves the details of a database account in Azure Cosmos DB.

.PARAMETER Endpoint
    The endpoint URL of the Azure Cosmos DB account.

.PARAMETER AccessToken
    The access token for authentication.

.PARAMETER MasterKey
    The master key for authentication.

.EXAMPLE
    get_database_account -Endpoint "https://mycosmosdb.documents.azure.com:443/" -AccessToken "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c" -MasterKey "myMasterKey"

.NOTES
    Author: Darshan Patnekar
    Date: 02/08/2024
    Version: 1.0    
#>
param (
    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $Endpoint,

    [string] $AccessToken,
    [string] $MasterKey
)

Add-Type -AssemblyName System.Web

$TokenVersion = "1.0"
$verbMethod = "GET"
$authKey = ""

try {
    if (![string]::IsNullOrEmpty($AccessToken)) 
    {
        $AadKeyType = "aad"
        $authKey = & .\get_cosmosdb_auth_key.ps1 -KeyType $AadKeyType -TokenVersion $TokenVersion -accessToken $AccessToken
    }
    elseif (![string]::IsNullOrEmpty($MasterKey))
    {
        $databaseAccountResourceId = ""
        $databaseAccountResourceType = ""
        $date = Get-Date
        $utcDate = $date.ToUniversalTime()
        $xDate = $utcDate.ToString('r', [System.Globalization.CultureInfo]::InvariantCulture)
        $MasterKeyType = "master"
        $authKey = & .\get_cosmosdb_auth_key.ps1 -Verb $verbMethod -ResourceId $databaseAccountResourceId -ResourceType $databaseAccountResourceType -Date $xDate -MasterKey $MasterKey -KeyType $MasterKeyType -TokenVersion $TokenVersion
    }
    else {
        throw "Both AccessToken and MasterKey cannot be null simultaneously. Atleast one of them should be provided."
    }

    $header = @{
        "authorization" = $authKey;
        "x-ms-version"  = "2020-07-15";
        "Cache-Control" = "no-cache";
        "x-ms-date"     = "$xDate";
        "Accept"        = "application/json";
        "User-Agent"    = "PowerShell-RestApi-Samples"
    }

    $retryCount = 3
    $retryDelay = 5
    $retryAttempts = 0
    $success = $false

    while (-not $success -and $retryAttempts -lt $retryCount) {
        try {
            $result = Invoke-RestMethod -Uri $Endpoint -Headers $header -Method $verbMethod -ContentType "application/json"
            $jsonResult = ConvertTo-Json -InputObject $result  -Depth 10
            Write-Output $jsonResult;
            $success = $true
        }
        catch {
            $retryAttempts++
            Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__
            Write-Host "Exception Message:" $_.Exception.Message
            if ($retryAttempts -lt $retryCount) {
                Write-Host "Retrying in $retryDelay seconds..."
                Start-Sleep -Seconds $retryDelay
            }
        }
    }

    if (-not $success) {
        throw "Failed to retrieve IP addresses and ports of the gateway and backend nodes after $retryCount attempts."
    }
}
catch {
    Write-Host "Error: $_"
}