<#
.SYNOPSIS
This script performs client-side network chaos testing for a Cosmos DB account in the specified Azure region.

.DESCRIPTION
This script is used to simulate client-side network chaos on client VMs/VMSS. Two types of Chaos can be created: 1. Outage, 2. Delay. It accepts various parameters to configure the chaos experiment.

.PARAMETER cosmosDBEndpoint
The endpoint URL of the Cosmos DB account.

.PARAMETER databaseId
The ID of the Cosmos DB database.

.PARAMETER containerId
The ID of the Cosmos DB container.

.PARAMETER faultRegion
The region where the fault will be induced.

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
The duration of the fault in minutes.

.PARAMETER cosmosDBServicePrincipalClientSecret
(Optional*) The client secret of the service principal used for authentication.

.PARAMETER cosmosDBServicePrincipalTenantId
(Optional*) The tenant ID of the service principal used for authentication.

.PARAMETER cosmosDBMasterKey
(Optional*) The master key of the Cosmos DB account. If provided, the script will use the master key to get the access token.

.PARAMETER delayInMs
(Optional*) The delay/latency induced in the network in milliseconds. Only required when performing Network Delay chaos.

.PARAMETER cosmosDBIdentityClientId
(Optional*) The client ID of the user-assigned managed identity used for authentication.
If cosmosDBServicePrincipalClientSecret and cosmosDBServicePrincipalTenantId are also provided, cosmosDBIdentityClientId will be used as the Client ID for the service principal.

.PARAMETER targetVMSubRGNameList
(Optional*) Specifies a comma-separated list of names for the target virtual machines in the format: "subscriptionId/resourceGroupName/virtualMachineName". e.g. "{12345678-1234-1234-1234-1234567890ab/rg1/vm1, 12567841-4321-4321-1234-1234567890gh/rg2/vm2}".

.PARAMETER targetVMSSSubRGName
(Optional*) Specifies the name for the target virtual machine scale set in the format: "subscriptionId/resourceGroupName/virtualMachineScaleSetName". Only one virtual machine scale set can be specified. e.g. "12345678-1234-1234-1234-1234567890ab/rg/vmss".

.PARAMETER vmssInstanceIdList
(Optional*) A comma-separated list of VM instance IDs in the target VM scale set. e.g. "{0,1,2}". The VMs with these Ids within the VMSS will only be targeted. Any other VMs in the VMSS won't be targeted by the chaos.

Note for Optional* parameters:
cosmosDBMasterKey and cosmosDBIdentityClientId cannot be null at the same time. At least one of them should be provided. If both cosmosDBMasterKey and cosmosDBIdentityClientId are provided, the script will use cosmosDBIdentityClientId to get the access token.
cosmosDBServicePrincipalTenantId cannot be null when cosmosDBServicePrincipalClientSecret is provided.
Both targetVMSubRGNameList (list of target VMs) and targetVMSSSubRGName (target VMSS) cannot be null at the same time. At least one target is needed. Both can be speciifed together.
To target a VMSS for fault, VMSSInstanceIdList should specify which VM instances in the VMSS need to be targeted e.g. 0,1,2.  

.EXAMPLE
For Outage Chaos:
.\cosmosdb_client_network_chaos_tool.ps1 -cosmosDBEndpoint "https://mycosmosdb.documents.azure.com:443/" -databaseId "mydatabase" -containerId "mycontainer" -faultRegion "East US" -chaosStudioSubscriptionId "12345678-1234-1234-1234-1234567890ab" -chaosStudioResourceGroupName "chaos-rg" -chaosStudioManagedIdentityClientId "87654321-4321-4321-4321-210987654321" -chaosExperimentName "myexperiment" -chaosExperimentManagedIdentityName "experiment-mi" -durationOfFaultInMinutes 10 -targetVMSubRGNameList "12345678-1234-1234-1234-1234567890ab/rg1/vm1,12567841-4321-4321-1234-1234567890gh/rg2/vm2" -targetVMSSSubRGName "12345678-1234-1234-1234-1234567890ab/rg1/vmss" -vmssInstanceIdList "0,1,2"

For Delay Chaos an additional parameter delayInMs is required:
-delayInMs 1000

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

try {
    $date = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
    $outputLogFilePath = "logs\outputLog\cosmosdb_client_network_chaos_tool_outputLog_$date.txt"

    try {
        if (-not (Test-Path -Path $outputLogFilePath)) {
            New-Item -ItemType File -Path $outputLogFilePath -Force
        }
    }
    catch {
        Write-Host "An error occurred while creating the output log file: $_"
    }

    # Start the transcript
    Start-Transcript -Path $outputLogFilePath -Append

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

    if ([string]::IsNullOrEmpty($delayInMs)) {
        $delayInMs = "0"
    }

    # Install tool's dependencies on the client VM
    try {
        &.\setup_vm.ps1
    } 
    catch {
        Write-Host "An error occurred while running setup_vm.ps1: $_"
    }

    # Get Cosmos DB access token for supported authentication methods
    if (![string]::IsNullOrEmpty($cosmosDBIdentityClientId)) {
        try {
            $dataPlaneAccessToken = & python .\get_cdb_aad_token.py --Endpoint $cosmosDBEndpoint --ClientId $cosmosDBIdentityClientId --ClientSecret $cosmosDBServicePrincipalClientSecret --TenantId $cosmosDBServicePrincipalTenantId
        }
        catch {
            Write-Host "An error occurred while getting the data plane access token: $_"
            throw "Cannot proceed further without valid dataplane access token. Exiting..."
        }
    }

    # Get the readable locations
    try {
        $databaseAccountResponseJson = & .\get_database_account.ps1 -Endpoint $cosmosDBEndpoint -AccessToken $dataPlaneAccessToken -MasterKey $cosmosDBMasterKey
        $databaseAccountResponseObject = $databaseAccountResponseJson | ConvertFrom-Json
        $readableLocations = $databaseAccountResponseObject.readableLocations
        $faultRegion = $faultRegion -replace '\s', ''

        foreach ($readableLocation in $readableLocations)
        {
            $readableLocation = $readableLocation -replace '\s', ''
            if ($faultRegion -eq $readableLocation.name)
            {
                $cosmosDBEndpoint = $readableLocation.databaseAccountEndpoint
            }
        }
    } 
    catch {
        Write-Host "An error occurred while getting the database account: $_"
        throw "Cannot proceed further without valid database account info. Exiting..."
    }

    # Get the partition key ranges
    try {
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
    } 
    catch {
        Write-Host "An error occurred while getting the partitionKey ranges: $_"
        throw "Cannot proceed further without valid partitionKey ranges. Exiting..."
    }

    # Get IP addresses and ports of the gateway and backend nodes
    try {
        $addressesResponseJson = & .\get_addresses.ps1 -Endpoint $cosmosDBEndpoint -AccessToken $dataPlaneAccessToken -MasterKey $cosmosDBMasterKey -PartitionKeyIds $commaSeparatedPkid -DatabaseID $databaseId -ContainerId $containerId
        $addressesResponse = $addressesResponseJson | ConvertFrom-Json
        $addresses = $addressesResponse.Addresss
        $backendUriList = New-Object System.Collections.Generic.List[uri]
        foreach ($address in $addresses)
        {
            $backendUriList += [uri]$address.physcialUri
        }
        $backendUriList = $backendUriList | Select-Object -uniq
    }
    catch {
        Write-Host "An error occurred while getting the IP addresses and ports of the gateway and backend nodes: $_"
        throw "Cannot proceed further without valid IP addresses and ports of the gateway and backend nodes. Exiting..."
    }

    try {
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
    }
    catch {
        Write-Host "An error occurred while creating the destinationFilters: $_"
        throw "Cannot proceed further without valid destinationFilters. Exiting..."
    }    

    # Create the experiment json
    try {
        $experimentJSON = & .\create_experiment_json.ps1 -FilterString $filterString -DurationOfFaultInMinutes $durationOfFaultInMinutes -FaultRegion $faultRegion -ExperimentName $chaosExperimentName -ResourceGroup $chaosStudioResourceGroupName -SubscriptionId $chaosStudioSubscriptionId -DelayInMs $delayInMs -TargetVMSubRGNameList $targetVMSubRGNameList -TargetVMSSSubRGName $targetVMSSSubRGName -VmssInstanceIdList $vmssInstanceIdList -ChaosExperimentManagedIdentityName $chaosExperimentManagedIdentityName
    }
    catch {
        Write-Host "An error occurred while creating the experiment JSON: $_"
        throw "Cannot proceed further without valid experiment JSON. Exiting..."
    }

    # Create the experiment on Chaos Studio and Start the experiment
    try {
        $retryCount = 0
        $maxRetries = 3
        $retryDelaySeconds = 5

        do {
            try {
                & .\experiment_operations.ps1 -ExperimentSubscriptionId $chaosStudioSubscriptionId -ExperimentResourceGroup $chaosStudioResourceGroupName  -ExperimentName $chaosExperimentName -ExperimentJSON $experimentJSON -ChaosStudioManagedIdentityClientId $chaosStudioManagedIdentityClientId
                break  # Exit the loop if the operation succeeds
            }
            catch {
                $retryCount++
                if ($retryCount -le $maxRetries) {
                    Write-Host "An error occurred while creating the experiment on Chaos Studio. Retrying in $retryDelaySeconds seconds..."
                    Start-Sleep -Seconds $retryDelaySeconds
                }
                else {
                    Write-Host "Max retry count reached. Exiting..."
                    break
                }
            }
        } while ($retryCount -le $maxRetries)
    }
    catch {
        Write-Host "An error occurred while creating the experiment on Chaos Studio: $_"
    }
}
catch {
    Write-Host "Error: $_"
}
finally {
    # Cleanup the VM after the experiment
    & .\cleanup_vm.ps1

    # Stop the transcript
    Stop-Transcript
}