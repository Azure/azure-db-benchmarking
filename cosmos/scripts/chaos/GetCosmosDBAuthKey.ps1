param (
    [string] $Verb,
    [string] $ResourceId,
    [string] $ResourceType,
    [string] $Date,
    [string] $MasterKey,
    [String] $KeyType,
    [String] $TokenVersion,
    [string] $accessToken
)

Function GenerateMasterKeyAuthorizationKey {

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
    $hmacsha = new-object -TypeName System.Security.Cryptography.HMACSHA256 -ArgumentList (, $keyBytes)
    $hash = $hmacsha.ComputeHash($bytesSigClear) 
    $signature = [System.Convert]::ToBase64String($hash)
    $key = [System.Web.HttpUtility]::UrlEncode('type=' + $KeyType + '&ver=' + $TokenVersion + '&sig=' + $signature)
    return $key
}

Function GenerateAadAuthorizationKey {

    [CmdletBinding()]

    param (
        [String] $KeyType,    
        [String] $TokenVersion,
        [string] $accessToken
    )

    $key = 'type=' + $AadKeyType + '&ver=' + $TokenVersion + '&sig=' + $accessToken
    return $key
}

if (![string]::IsNullOrEmpty($MasterKey)) {
    $authKey = GenerateMasterKeyAuthorizationKey -Verb $verbMethod -ResourceId $databaseAccountResourceId -ResourceType $databaseAccountResourceType -Date $xDate -MasterKey $MasterKey -KeyType $MasterKeyType -TokenVersion $TokenVersion
    Write-Output $authKey
}

if (![string]::IsNullOrEmpty($accessToken)) {
    $authKey = GenerateAadAuthorizationKey -KeyType $AadKeyType -TokenVersion $TokenVersion -accessToken $accessToken
    Write-Output $authKey
}