<#
.SYNOPSIS
    Retrieves the authorization key for Cosmos DB.

.PARAMETER Verb
    The HTTP verb used in the request.

.PARAMETER ResourceId
    The ID of the resource.

.PARAMETER ResourceType
    The type of the resource.

.PARAMETER Date
    The date of the request.

.PARAMETER MasterKey
    The master key used for authentication.

.PARAMETER KeyType
    The type of the key. Possible values: {master, aad}

.PARAMETER TokenVersion
    The version of the token.

.PARAMETER AccessToken
    The access token.

.DESCRIPTION
    This script retrieves the authorization key for Cosmos DB using the provided parameters.

.EXAMPLE
    get_cosmosdb_auth_key -Verb "GET" -ResourceId "mycosmosdb" -ResourceType "dbs" -Date "2022-01-01" -MasterKey "mykey" -KeyType "master" -TokenVersion "1.0" -AccessToken "mytoken"

.NOTES
    Author: Darshan Patnekar
    Date: 02/08/2024
    Version: 1.0
#>

param (
    [string] $Verb,
    [string] $ResourceId,
    [string] $ResourceType,
    [string] $Date,
    [string] $MasterKey,
    [String] $KeyType,
    [String] $TokenVersion,
    [string] $AccessToken
)

Function GenerateAadAuthorizationKey {

    [CmdletBinding()]

    param (
        [String] $KeyType,    
        [String] $TokenVersion,
        [string] $AccessToken
    )

    $key = 'type=' + $KeyType + '&ver=' + $TokenVersion + '&sig=' + $AccessToken
    return $key
}

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

if (![string]::IsNullOrEmpty($AccessToken)) {
    $authKey = GenerateAadAuthorizationKey -KeyType $KeyType -TokenVersion $TokenVersion -AccessToken $AccessToken
    return $authKey
}

if (![string]::IsNullOrEmpty($MasterKey)) {
    $authKey = GenerateMasterKeyAuthorizationKey -Verb $Verb -ResourceId $ResourceId -ResourceType $ResourceType -Date $Date -MasterKey $MasterKey -KeyType $KeyType -TokenVersion $TokenVersion
    return $authKey
}

