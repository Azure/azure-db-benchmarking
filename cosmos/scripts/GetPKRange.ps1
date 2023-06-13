param (

    [string] $Endpoint,
    [string] $MasterKey,
    [string] $DatabaseID,
    [string] $ContainerId
)

Function Generate-MasterKeyAuthorizationSignature
{

    [CmdletBinding()]

    param (

        [string] $Verb,
        [string] $ResourceId,
        [string] $ResourceType,
        [string] $Date,
        [string] $MasterKey,
        [String] $KeyType,
        [String] $TokenVersion
    )

    $keyBytes = [System.Convert]::FromBase64String($MasterKey)

    $sigCleartext = @($Verb.ToLower() + "`n" + $ResourceType.ToLower() + "`n" + $ResourceId + "`n" + $Date.ToString().ToLower() + "`n" + "" + "`n")

    $bytesSigClear = [Text.Encoding]::UTF8.GetBytes($sigCleartext)

    $hmacsha = new-object -TypeName System.Security.Cryptography.HMACSHA256 -ArgumentList (,$keyBytes)

    $hash = $hmacsha.ComputeHash($bytesSigClear)

    $signature = [System.Convert]::ToBase64String($hash)

    $key = [System.Web.HttpUtility]::UrlEncode('type=' + $KeyType + '&ver=' + $TokenVersion + '&sig=' + $signature)

    return $key
}

$KeyType = "master"
$TokenVersion = "1.0"
$date = Get-Date
$utcDate = $date.ToUniversalTime()
$xDate = $utcDate.ToString('r', [System.Globalization.CultureInfo]::InvariantCulture)
$pkRangesResourceType = "pkranges"
$pkRangesResourceId = "dbs/" + $DatabaseID + "/colls/" + $ContainerId
$pkRangesResourceLink = "dbs/" + $DatabaseID + "/colls/" + $ContainerId + "/pkranges"
$verbMethod = "GET"

$requestUri = "$Endpoint$pkRangesResourceLink"

$authKey = Generate-MasterKeyAuthorizationSignature -Verb $verbMethod -ResourceId $pkRangesResourceId -ResourceType $pkRangesResourceType -Date $xDate -MasterKey $MasterKey -KeyType $KeyType -TokenVersion $TokenVersion

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
    $result = Invoke-RestMethod -Uri $requestUri -Headers $header -Method $verbMethod -ContentType "application/json"
    $jsonResult = ConvertTo-Json -InputObject $result -Depth 10
    Write-Host $jsonResult;

}
catch
{
    # Dig into the exception to get the Response details.
    # Note that value__ is not a typo.
    Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__
    Write-Host "Exception Message:" $_.Exception.Message
}