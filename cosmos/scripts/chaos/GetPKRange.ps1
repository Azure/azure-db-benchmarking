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

$TokenVersion = "1.0"
$verbMethod = "GET"
$authKey = ""

if (![string]::IsNullOrEmpty($MasterKey)) {
    $pkRangesResourceType = "pkranges"
    $pkRangesResourceId = "dbs/" + $DatabaseID + "/colls/" + $ContainerId
    $date = Get-Date
    $utcDate = $date.ToUniversalTime()
    $xDate = $utcDate.ToString('r', [System.Globalization.CultureInfo]::InvariantCulture)
    $MasterKeyType = "master"
    $authKey = & .\GetCosmosDBAuthKey.ps1 -Verb $verbMethod -ResourceId $pkRangesResourceId -ResourceType $pkRangesResourceType -Date $xDate -MasterKey $MasterKey -KeyType $MasterKeyType -TokenVersion $TokenVersion
}

if (![string]::IsNullOrEmpty($accessToken))  
{
    $AadKeyType = "aad"
    $authKey = & .\GetCosmosDBAuthKey.ps1 -KeyType $AadKeyType -TokenVersion $TokenVersion -accessToken $AccessToken  
}

$header = @{
    
    "authorization" = "$authKey";
    "x-ms-version" = "2020-07-15";
    "Cache-Control" = "no-cache";
    "x-ms-date" = "$xDate";
    "Accept" = "application/json";
    "User-Agent" = "PowerShell-RestApi-Samples"
}

try
{
    $pkRangesResourceLink = "dbs/" + $DatabaseID + "/colls/" + $ContainerId + "/pkranges"
    $requestUri = "$Endpoint$pkRangesResourceLink"

    $result = Invoke-RestMethod -Uri $requestUri -Headers $header -Method $verbMethod -ContentType "application/json"
    $jsonResult = ConvertTo-Json -InputObject $result -Depth 10
    Write-Output $jsonResult;

}
catch
{
    # Dig into the exception to get the Response details.
    # Note that value__ is not a typo.
    Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__
    Write-Host "Exception Message:" $_.Exception.Message
}