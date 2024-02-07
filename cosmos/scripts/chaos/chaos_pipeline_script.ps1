param (
    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $endpoint,

    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $databaseId,

    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $containerId,

    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $durationOfFaultInMinutes,

    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $faultRegion,

    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $chaosStudioSubscriptionId,

    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $chaosStudioResourceGroupName,

    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $chaosStudioManagedIdentityClientId,

    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $chaosExperimentName,

    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $chaosExperimentManagedIdentityName,

    [string] $cosmosDBServicePrincipalClientSecret,
    [string] $cosmosDBServicePrincipalTenantId,
    [string] $cosmosDBMasterKey,
    [string] $waitForFaultToStartInSec,
    [string] $delayInMs,
    [string] $cosmosDBManagedIdentityClientId,
    [string] $targetVMSubRGNameList,
    [string] $targetVMSSSubRGName,
    [string] $vmssInstanceIdList
)

if ($null -eq $cosmosDBMasterKey -and $null -eq $cosmosDBManagedIdentityClientId) {
    throw "Both cosmosDBMasterKey and cosmosDBManagedIdentityClientId cannot be null at the same time."
}

if ($null -eq $targetVMSubRGNameList -and $null -eq $targetVMSSSubRGName) {
    throw "Both targetVMSubRGNameList and targetVMSSSubRGName cannot be null at the same time."
}

if (![string]::IsNullOrEmpty($targetVMSSSubRGName) -and [string]::IsNullOrEmpty($VMSSInstanceIdList)) {
    throw "To target a VMSS for fault, VMSSInstanceIdList should specify which VM instances need to be targetted e.g. 0,1,2."
}

$dataAccessToken = $null
if (![string]::IsNullOrEmpty($cosmosDBManagedIdentityClientId)) {
   if (![string]::IsNullOrEmpty($cosmosDBServicePrincipalClientSecret) -and ![string]::IsNullOrEmpty($cosmosDBServicePrincipalTenantId)) {
        $dataAccessToken = & python .\get_cdb_aad_token.py --Endpoint $endpoint --ClientId $cosmosDBManagedIdentityClientId --ClientSecret $cosmosDBServicePrincipalClientSecret --TenantId $cosmosDBServicePrincipalTenantId
    }
    else
    {
        $dataAccessToken = & python .\get_cdb_aad_token.py --Endpoint $endpoint --ClientId $cosmosDBManagedIdentityClientId
    }
}

$databaseAccountResponseJson = & .\GetDatabaseAccount.ps1 -Endpoint $endpoint -AccessToken $dataAccessToken -MasterKey $cosmosDBMasterKey
$databaseAccountResponseObject = $databaseAccountResponseJson | ConvertFrom-Json
$readableLocations = $databaseAccountResponseObject.readableLocations

foreach ($readableLocation in $readableLocations)
{
    if ($faultRegion -eq $readableLocation.name)
    {
        $endpoint = $readableLocation.databaseAccountEndpoint
    }
}

$pkRangeResponseJson = & .\GetPKRange.ps1 -Endpoint $endpoint -DatabaseID $databaseId -ContainerId $containerId -AccessToken $dataAccessToken -MasterKey $cosmosDBMasterKey
$pkRangeResponse = $pkRangeResponseJson | ConvertFrom-Json
$partitionKeyRanges = $pkRangeResponse.PartitionKeyRanges
$commaSeparatedPkid = ""
foreach ($partitionKeyRange in $partitionKeyRanges)
{
    # Check if the string is true or false
    if ($commaSeparatedPkid)
    {
        $commaSeparatedPkid += "," + $partitionKeyRange.id
    }
    else
    {
        $commaSeparatedPkid += $partitionKeyRange.id
    }
}

$addressesResponseJson = & .\GetAddresses.ps1 -Endpoint $endpoint -AccessToken $dataAccessToken -MasterKey $cosmosDBMasterKey -PartitionKeyIds $commaSeparatedPkid -DatabaseID $databaseId -ContainerId $containerId
$addressesResponse = $addressesResponseJson | ConvertFrom-Json
$addresses = $addressesResponse.Addresss
$backendUriList = New-Object System.Collections.Generic.List[uri]
foreach ($address in $addresses)
{
    $backendUriList += [uri]$address.physcialUri
}
$backendUriList = $backendUriList | Select-Object -uniq

$endpointUri = [uri]$endpoint
$endpointPort = $endpointUri.Port
$endpointHost = $endpointUri.Host
$endpointIpAddress = (Resolve-DnsName $endpointHost).IPAddress
$subnetMask = "255.255.255.255"

# Adding gateway endpoint for filtering
$filterString = "[{\`"portHigh\`":$endpointPort,\`"subnetMask\`":\`"$subnetMask\`",\`"address\`":\`"$endpointIpAddress\`",\`"portLow\`":$endpointPort}"

#HashSet to store the unique IP addresses
$uniqueIPAddressHashSet = New-Object System.Collections.Generic.HashSet[string]

foreach ($backendUri in $backendUriList)
{
    $backendHost = $backendUri.Host
    $ipAddress = (Resolve-DnsName $backendHost).IPAddress
    $uniqueIPAddressHashSet.Add($ipAddress)
}

# Adding backend nodes for filtering
foreach ($ipAddress in $uniqueIPAddressHashSet)
{
    $lowPort = 0
    $highPort = 65535
    if ($filterString)
    {
        $filterString += ",{\`"portHigh\`":\`"$highPort\`",\`"subnetMask\`":\`"$subnetMask\`",\`"address\`":\`"$ipAddress\`",\`"portLow\`":\`"$lowPort\`"}"
    }
    else
    {
        $filterString += "[{\`"portHigh\`":\`"$highPort\`",\`"subnetMask\`":\`"$subnetMask\`",\`"address\`":\`"$ipAddress\`",\`"portLow\`":\`"$lowPort\`"}"
    }
}

if ($filterString)
{
    $filterString += "]"
}    

# Create the experiment json
$experimentJSON = & .\create_experiment_json.ps1 -filterString $filterString -durationOfFaultInMinutes $durationOfFaultInMinutes -faultRegion $faultRegion -experimentName $chaosExperimentName -resourceGroup $chaosStudioResourceGroupName -subscriptionId $chaosStudioSubscriptionId -delayInMs $delayInMs -targetVMSubRGNameList $targetVMSubRGNameList -targetVMSSSubRGName $targetVMSSSubRGName -vmssInstanceIdList $vmssInstanceIdList -chaosExperimentManagedIdentityName $chaosExperimentManagedIdentityName

# Get the access token for control plane
$controlPlaneAccessToken = & .\get_control_plane_aad_token.ps1 -clientId $chaosStudioManagedIdentityClientId

# REST API Calls
# Create or Update the Chaos experiment
$createUpdateExperimentUri = "https://management.azure.com/subscriptions/" + $chaosStudioSubscriptionId + "/resourceGroups/" + $chaosStudioResourceGroupName + "/providers/Microsoft.Chaos/experiments/" + $chaosExperimentName + "?api-version=2023-11-01"

# Set the headers for the request
$headers = @{
    "Authorization" = "Bearer $controlPlaneAccessToken"
    "Content-Type" = "application/json"
    "Host" = "management.azure.com"
    "Content-Length" = $experimentJSON.Length
}

# Make the PUT request
$updateResponse = Invoke-RestMethod -Uri $createUpdateExperimentUri -Method PUT -Headers $headers -Body $experimentJSON

# Display the response
$updateResponse

Start-Sleep -Seconds 30

# Start the Chaos experiment
# Set the URI for the POST request
$startExperimentUri = "https://management.azure.com/subscriptions/$chaosStudioSubscriptionId/resourceGroups/$chaosStudioResourceGroupName/providers/Microsoft.Chaos/experiments/$chaosExperimentName/start?api-version=2023-11-01"

# Set the headers for the request
$headers = @{
    "Authorization" = "Bearer $controlPlaneAccessToken"
    "Content-Type" = "application/json"
    "Host" = "management.azure.com"
}

# Make the POST request
$startResponse = Invoke-RestMethod -Uri $startExperimentUri -Method POST -Headers $headers

# Display the response
$startResponse
