param (
    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $filterString,

    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $durationOfFaultInMinutes,

    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $faultRegion,

    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $resourceGroup,

    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $subscriptionId,

    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $delayInMs,

    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $chaosExperimentManagedIdentityClientId,

    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $experimentName,

    [string] $targetVMSubRGNameList,
    [string] $targetVMSSSubRGName,
    [string] $vmssInstanceIdList

)

$json = ""
$experimentIdPrefix = "/subscriptions/" + $subscriptionId + "/resourceGroups/" + $resourceGroup + "/providers/Microsoft.Chaos/experiments/"
$jsonPath = ""

if ($delayInMs)
{
    $jsonPath = 'network-delay-fault.json'
    $json = Get-Content -Path $jsonPath | ConvertFrom-Json
    $experimentName = $experimentName + "_network_delay"
    $json.name = $experimentName
    $json.id = $experimentIdPrefix + $experimentName
    if ($json.properties.steps[0].branches[0].actions[0].parameters)
    {
        foreach ($parameter in $json.properties.steps[0].branches[0].actions[0].parameters) {
            if ($parameter.key -eq "latencyInMilliseconds") {
                $parameter.value = $delayInMs
                break
            }
        }
    }
}
else {
    $jsonPath = 'network-disconnect-fault.json'
    $json = Get-Content -Path $jsonPath | ConvertFrom-Json
    $experimentName = $experimentName + "_network_discon"
    $json.name = $experimentName
    $json.id = $experimentIdPrefix + $experimentName
}

#TO-DO
# Set the identity for the experiment 
$json.identity = @{
    "type" = "UserAssigned"
    "clientId" = $chaosExperimentManagedIdentityClientId
}

# Set the location of the experiment
if ($faultRegion)
{
    $faultRegion = $faultRegion -replace '\s', '' # Remove whitespace
    $json.location = $faultRegion
}

# Set the duration of the experiment
if ($durationOfFaultInMinutes)
{
    $json.properties.steps[0].branches[0].actions[0].duration = "PT" + $durationOfFaultInMinutes +"M"
}

# Set the targets for the experiment
$targetIndex = 0
if ($targetVMSubRGNameList) {
    $targets = $targetVMSubRGNameList -split ","

    foreach ($target in $targets) {
        $targetId = create_targetId -inputString $target -computeType "virtualMachines"
        $json.properties.selectors[0].targets[$targetIndex].id = $targetId
        $json.properties.selectors[0].targets[$targetIndex].type = "ChaosTarget"
        $targetIndex++
    }
}

if ($targetVMSSSubRGName) {
    $targetId = create_targetId -inputString $targetVMSSSubRGName -computeType "virtualMachineScaleSets"
    $json.properties.selectors[0].targets[$targetIndex].id = $targetId
    $json.properties.selectors[0].targets[$targetIndex].type = "ChaosTarget"
    $targetIndex++
}

# Set the destinationFilters and virtualMachineScaleSetInstances for the experiment
if ($json.properties.steps[0].branches[0].actions[0].parameters)
{
    foreach ($parameter in $json.properties.steps[0].branches[0].actions[0].parameters) {
        switch ($parameter.key) {
            "destinationFilters" {
                $parameter.value = $filterString
                break
            }
            "virtualMachineScaleSetInstances" {
                $parameter.value = $vmssInstanceIdList
                break
            }
        }
    }
}

# Convert the modified PowerShell object back to JSON
$newJson = ConvertTo-Json -InputObject $json -Depth 20

# Remove the escape characters
$newJson = $newJson.Replace('\\\','\')

# Write the new JSON back to the file
$newJson | Set-Content -Path $jsonPath

# Function to create the targetId for the experiment
function create_targetId {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [string] $inputString,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [string] $computeType
    )

    $parts = $inputString -split '/'
    $subscriptionId = $parts[0]
    $resourceGroupName = $parts[1]
    $vmName = $parts[2]

    $targetId = "/subscriptions/" + $subscriptionId + "/resourceGroups/" + $resourceGroupName + "/providers/Microsoft.Compute/$computeType/" + $vmName + "/providers/Microsoft.Chaos/targets/Microsoft-Agent"
    return $targetId
}
