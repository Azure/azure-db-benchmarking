<#
.SYNOPSIS
    This script is used to configure and execute a chaos experiment on an Azure Cosmos DB container.

.DESCRIPTION
    The script accepts various parameters to specify the configuration of the chaos experiment.

.PARAMETER cosmosDBEndpoint
    The endpoint URL of the Azure Cosmos DB account.

.PARAMETER databaseId
    The ID of the database within the Azure Cosmos DB account.

.PARAMETER containerId
    The ID of the container within the specified database.

.PARAMETER faultRegion
    The region where the fault will be injected.

.PARAMETER chaosStudioSubscriptionId
    The subscription ID of the Azure Chaos Studio.

.PARAMETER chaosStudioResourceGroupName
    The resource group name of the Azure Chaos Studio.

.PARAMETER chaosStudioManagedIdentityClientId
    The client ID of the managed identity used by the Azure Chaos Studio.

.PARAMETER chaosExperimentName
    The name of the chaos experiment.

.PARAMETER chaosExperimentManagedIdentityName
    The name of the managed identity used by the chaos experiment.

.PARAMETER durationOfFaultInMinutes
    The duration of the fault injection in minutes.

.PARAMETER cosmosDBServicePrincipalClientSecret
    (Optional) The client secret of the service principal used to authenticate with Azure Cosmos DB.

.PARAMETER cosmosDBServicePrincipalTenantId
    (Optional) The tenant ID of the service principal used to authenticate with Azure Cosmos DB.

.PARAMETER cosmosDBMasterKey
    (Optional) The master key of the Azure Cosmos DB account.

.PARAMETER delayInMs
    (Optional) The delay in milliseconds between each chaos experiment iteration.

.PARAMETER cosmosDBIdentityClientId
    (Optional) The client ID of the managed identity used to authenticate with Azure Cosmos DB.

.PARAMETER targetVMSubRGNameList
    (Optional) Specifies a comma-separated list of names for the target virtual machines in the format: "subscriptionId/resourceGroup/virtualMachineName".

.PARAMETER targetVMSSSubRGName
    (Optional) Specifies the name for the target virtual machine scale set in the format: "subscriptionId/resourceGroup/virtualMachineScaleSetName". Only one virtual machine scale set can be specified.

.PARAMETER vmssInstanceIdList
    (Optional) A comma-separated list of virtual machine scale set instance IDs.

.NOTES
    Author: Darshan Patnekar
    Date: 02/08/2024
    Version: 1.0
#>

param (
    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $cosmosDBEndpoint,

    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $databaseId,

    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $containerId,

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

    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $durationOfFaultInMinutes,

    [string] $cosmosDBServicePrincipalClientSecret,

    [string] $cosmosDBServicePrincipalTenantId,

    [string] $cosmosDBMasterKey,

    [string] $delayInMs,

    [string] $cosmosDBIdentityClientId,

    [string] $targetVMSubRGNameList,

    [string] $targetVMSSSubRGName,

    [string] $vmssInstanceIdList
)

# Conditional Validations for the input parameters

if ($null -eq $cosmosDBMasterKey -and $null -eq $cosmosDBIdentityClientId) {
    throw "Both cosmosDBMasterKey and cosmosDBIdentityClientId cannot be null at the same time."
}

if (![string]::IsNullOrEmpty($cosmosDBServicePrincipalClientSecret) -and [string]::IsNullOrEmpty($cosmosDBServicePrincipalTenantId)) {
    throw "cosmosDBServicePrincipalTenantId cannot be null when cosmosDBServicePrincipalClientSecret is provided."
}

if ($null -eq $targetVMSubRGNameList -and $null -eq $targetVMSSSubRGName) {
    throw "Both targetVMSubRGNameList (list of target VMs) and targetVMSSSubRGName (target VMSS) cannot be null at the same time. Atleast one target is needed."
}

if (![string]::IsNullOrEmpty($targetVMSSSubRGName) -and [string]::IsNullOrEmpty($VMSSInstanceIdList)) {
    throw "To target a VMSS for fault, VMSSInstanceIdList should specify which VM instances need to be targetted e.g. 0,1,2."
}

# Check if Python is installed on the VM, if not install it
&.\setup_vm.ps1

$dataPlaneAccessToken = $null
if (![string]::IsNullOrEmpty($cosmosDBIdentityClientId)) {
   if (![string]::IsNullOrEmpty($cosmosDBServicePrincipalClientSecret) -and ![string]::IsNullOrEmpty($cosmosDBServicePrincipalTenantId)) {
        # Using the service principal to get the access token
        $dataPlaneAccessToken = & python .\get_cdb_aad_token.py --Endpoint $cosmosDBEndpoint --ClientId $cosmosDBIdentityClientId --ClientSecret $cosmosDBServicePrincipalClientSecret --TenantId $cosmosDBServicePrincipalTenantId
    }
    else
    {
        # Using the user-assigned managed identity to get the access token
        $dataPlaneAccessToken = & python .\get_cdb_aad_token.py --Endpoint $cosmosDBEndpoint --ClientId $cosmosDBIdentityClientId
    }
}

# Get the readable locations
$databaseAccountResponseJson = & .\get_database_account.ps1 -Endpoint $cosmosDBEndpoint -AccessToken $dataPlaneAccessToken -MasterKey $cosmosDBMasterKey
$databaseAccountResponseObject = $databaseAccountResponseJson | ConvertFrom-Json
$readableLocations = $databaseAccountResponseObject.readableLocations

foreach ($readableLocation in $readableLocations)
{
    if ($faultRegion -eq $readableLocation.name)
    {
        $cosmosDBEndpoint = $readableLocation.databaseAccountEndpoint
    }
}

# Get the partition key ranges
$pkRangeResponseJson = & .\get_pk_range.ps1 -Endpoint $cosmosDBEndpoint -DatabaseID $databaseId -ContainerId $containerId -AccessToken $dataPlaneAccessToken -MasterKey $cosmosDBMasterKey
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

# Get IP addresses and ports of the gateway and backend nodes
$addressesResponseJson = & .\get_addresses.ps1 -Endpoint $cosmosDBEndpoint -AccessToken $dataPlaneAccessToken -MasterKey $cosmosDBMasterKey -PartitionKeyIds $commaSeparatedPkid -DatabaseID $databaseId -ContainerId $containerId
$addressesResponse = $addressesResponseJson | ConvertFrom-Json
$addresses = $addressesResponse.Addresss
$backendUriList = New-Object System.Collections.Generic.List[uri]
foreach ($address in $addresses)
{
    $backendUriList += [uri]$address.physcialUri
}
$backendUriList = $backendUriList | Select-Object -uniq

$endpointUri = [uri]$cosmosDBEndpoint
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

# Create the experiment on Chaos Studio and Start the experiment
& .\experiment_operations.ps1 -experimentSubscriptionId $chaosStudioSubscriptionId -experimentResourceGroup $chaosStudioResourceGroupName  -experimentName $chaosExperimentName -experimentJSON $experimentJSON -chaosStudioManagedIdentityClientId $chaosStudioManagedIdentityClientId

# Cleanup the VM after the experiment
& .\cleanup_vm.ps1