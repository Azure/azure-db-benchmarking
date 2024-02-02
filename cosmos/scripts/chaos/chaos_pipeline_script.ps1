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
    [string] $durationOfFaultInSec,

    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $faultRegion,

    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $subscriptionId,

    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $resourceGroup,

    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $chaosStudioManagedIdentityClientId,

    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $chaosExperimentManagedIdentityClientId,

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

$json = Get-Content -Path 'network-disconnect-fault.json' | ConvertFrom-Json

# Modify the desired value in the PowerShell object
$json.properties.steps[0].branches[0].actions[0].parameters[0].value = $filterString

if ($durationOfFaultInMinutes)
{
    $json.properties.steps[0].branches[0].actions[0].duration = "PT" + $durationOfFaultInMinutes +"M"
}

if ($faultRegion)
{
    $faultRegion = $faultRegion -replace '\s', '' # Remove whitespace
    $json.location = $faultRegion
}

$parts = $endpointHost.Split('.')
$accountName = $parts[0]

# $experimentName = $faultRegion + "_" + $accountName + "_" + $databaseId + "_" + $containerId + "_net_discnt"
$experimentName = $faultRegion + "_" + $accountName

if ($ResourceGroup -and $SubscriptionId)
{
    $json.id = "/subscriptions/" + $subscriptionId + "/resourceGroups/" + $resourceGroup + "/providers/Microsoft.Chaos/experiments/$experimentName"
    $json.name = $experimentName
}

# Convert the modified PowerShell object back to JSON
$newJson = ConvertTo-Json -InputObject $json -Depth 20

# Remove the escape characters
$newJson = $newJson.Replace('\\\','\')

# Write the new JSON back to the file
$newJson | Set-Content -Path 'network-disconnect-fault.json'

# Update the Chaos experiment
$updateExperimentUri = "https://management.azure.com/subscriptions/bc233076-e0b6-49b0-a4f3-e491cda98e9c/resourceGroups/darshan-chaos-experiments/providers/Microsoft.Chaos/experiments/$experimentName?api-version=2023-11-01"

# Read the content of network-disconnect-fault.json
$requestBody = Get-Content -Path 'network-disconnect-fault.json' -Raw

# Get the bearer token
$clientid = "b590b1e0-c76a-4e4f-bc0b-01bf12f37df9"
$resource = "https://management.azure.com/"
$response = Invoke-WebRequest -Uri "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&client_id=$clientid&resource=$resource" -Method GET -Headers @{Metadata="true"}
$content = $response.Content | ConvertFrom-Json
$MgmtAccessToken = $content.access_token

# Set the headers for the request
$headers = @{
    "Authorization" = "Bearer $MgmtAccessToken"
    "Content-Type" = "application/json"
    "Host" = "management.azure.com"
    "Content-Length" = $requestBody.Length
}

# Make the PUT request
$updateResponse = Invoke-RestMethod -Uri $updateExperimentUri -Method PUT -Headers $headers -Body $requestBody

# Display the response
$updateResponse

Start-Sleep -Seconds 30

# Start the Chaos experiment
# Set the URI for the POST request
$startExperimentUri = "https://management.azure.com/subscriptions/bc233076-e0b6-49b0-a4f3-e491cda98e9c/resourceGroups/darshan-chaos-experiments/providers/Microsoft.Chaos/experiments/network-disconnect-fault/start?api-version=2023-11-01"

# Set the headers for the request
$headers = @{
    "Authorization" = "Bearer $MgmtAccessToken"
    "Content-Type" = "application/json"
    "Host" = "management.azure.com"
}

# Make the POST request
$startResponse = Invoke-RestMethod -Uri $startExperimentUri -Method POST -Headers $headers

# Display the response
$startResponse
