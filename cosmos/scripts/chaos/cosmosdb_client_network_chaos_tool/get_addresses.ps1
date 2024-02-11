<#
.SYNOPSIS
    Retrieves addresses from a Cosmos DB container.

.DESCRIPTION
    This script retrieves addresses from a Cosmos DB container using the specified parameters.

.PARAMETER Endpoint
    The endpoint URL of the Cosmos DB account.

.PARAMETER PartitionKeyIds
    The comma-separated list of partition key IDs.

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
    [string] $PartitionKeyIds,

    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $DatabaseID,

    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $ContainerId,

    [string] $AccessToken,
    [string] $MasterKey
)

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
        $addressesResourceType = "docs"
        $addressesResourceId = "dbs/"+$DatabaseID+"/colls/"+$ContainerId
        $date = Get-Date
        $utcDate = $date.ToUniversalTime()
        $xDate = $utcDate.ToString('r', [System.Globalization.CultureInfo]::InvariantCulture)
        $MasterKeyType = "master"
        $authKey = & .\get_cosmosdb_auth_key.ps1 -Verb $verbMethod -ResourceId $addressesResourceId -ResourceType $addressesResourceType -Date $xDate -MasterKey $MasterKeyType -KeyType $KeyType -TokenVersion $TokenVersion
    }
    else {
        throw "Both AccessToken and MasterKey cannot be null simultaneously. Atleast one of them should be provided."
    }

    $header = @{
        "authorization"         = "$authKey";
        "x-ms-version"          = "2020-07-15";
        "Cache-Control"         = "no-cache";
        "x-ms-date"             = "$xDate";
        "Accept"                = "application/json";
        "User-Agent"            = "PowerShell-RestApi-Samples"
    }

    $addressesResourceLink = "addresses/?"+"$"+"resolveFor=dbs%2f"+$DatabaseID+"%2fcolls%2f"+$ContainerId + "%2fdocs&"+"$"+"filter=protocol eq rntbd&"+"$"+"partitionKeyRangeIds="+$PartitionKeyIds
    $requestUri = "$Endpoint$addressesResourceLink"

    $result = Invoke-RestMethod -Uri $requestUri -Headers $header -Method $verbMethod -ContentType "application/json"
    $jsonResult = ConvertTo-Json -InputObject $result  -Depth 10
    Write-Output $jsonResult;
}
catch {
    Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__
    Write-Host "Exception Message:" $_.Exception.Message
}
