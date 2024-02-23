<#
.SYNOPSIS
    Retrieves the partition key range for a given Cosmos DB container.

.DESCRIPTION
    This script retrieves the partition key range for a specified Cosmos DB container. It requires the following parameters:
    - Endpoint: The URI endpoint of the Cosmos DB account.
    - DatabaseID: The ID of the Cosmos DB database.
    - ContainerId: The ID of the Cosmos DB container.
    - AccessToken: (Optional) The access token for authentication.
    - MasterKey: (Optional) The master key for authentication.

.PARAMETER Endpoint
    The URI endpoint of the Cosmos DB account.

.PARAMETER DatabaseID
    The ID of the Cosmos DB database.

.PARAMETER ContainerId
    The ID of the Cosmos DB container.

.PARAMETER AccessToken
    (Optional) The access token for authentication.

.PARAMETER MasterKey
    (Optional) The master key for authentication.

.NOTES
    Author: Darshan Patnekar
    Date: 02/08/2024
    Version: 1.0
#>

param (
    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $Endpoint,
    
    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $DatabaseID,

    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $ContainerId,

    [string] $AccessToken,

    [string] $MasterKey
)

Add-Type -AssemblyName System.Web

$TokenVersion = "1.0"
$verbMethod = "GET"
$authKey = ""

try {
    if (![string]::IsNullOrEmpty($AccessToken)) {
        $AadKeyType = "aad"
        $authKey = & .\get_cosmosdb_auth_key.ps1 -KeyType $AadKeyType -TokenVersion $TokenVersion -accessToken $AccessToken  
    }
    elseif (![string]::IsNullOrEmpty($MasterKey))
    {
        $pkRangesResourceType = "pkranges"
        $pkRangesResourceId = "dbs/" + $DatabaseID + "/colls/" + $ContainerId
        $date = Get-Date
        $utcDate = $date.ToUniversalTime()
        $xDate = $utcDate.ToString('r', [System.Globalization.CultureInfo]::InvariantCulture)
        $MasterKeyType = "master"
        $authKey = & .\get_cosmosdb_auth_key.ps1 -Verb $verbMethod -ResourceId $pkRangesResourceId -ResourceType $pkRangesResourceType -Date $xDate -MasterKey $MasterKey -KeyType $MasterKeyType -TokenVersion $TokenVersion
    }
    else {
        throw "Both AccessToken and MasterKey cannot be null simultaneously. Atleast one of them should be provided."
    }

    $header = @{
        "authorization" = "$authKey";
        "x-ms-version" = "2020-07-15";
        "Cache-Control" = "no-cache";
        "x-ms-date" = "$xDate";
        "Accept" = "application/json";
        "User-Agent" = "PowerShell-RestApi-Samples"
    }

    $pkRangesResourceLink = "dbs/" + $DatabaseID + "/colls/" + $ContainerId + "/pkranges"
    $requestUri = "$Endpoint$pkRangesResourceLink"

    $retryCount = 3
    $retryDelay = 5
    $retryAttempts = 0
    $success = $false

    while (-not $success -and $retryAttempts -lt $retryCount) {
        try {
            $result = Invoke-RestMethod -Uri $requestUri -Headers $header -Method $verbMethod -ContentType "application/json"
            $jsonResult = ConvertTo-Json -InputObject $result -Depth 10
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
        throw "Failed to retrieve partitionKey ranges after $retryCount attempts."
    }
}
catch {
    Write-Host "Error: $_"
}