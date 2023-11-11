<#
.SYNOPSIS
This script introduces network faults into a Cosmos DB environment for testing purposes.
.DESCRIPTION
The script takes several parameters to configure the fault injection, including the endpoint, master key, database ID, container ID, duration of fault, drop percentage, delay in milliseconds, fault region, and wait time for fault to start. It then uses these parameters to introduce network faults using the Clumsy utility.
.PARAMETER endpoint
The endpoint for the Cosmos DB instance.
.PARAMETER masterKey
The master key for the Cosmos DB instance.
.PARAMETER databaseId
The ID of the database in the Cosmos DB instance.
.PARAMETER containerId
The ID of the container in the database.
.PARAMETER durationOfFaultInSec
The duration of the network fault in seconds.
.PARAMETER dropPercentage
The percentage of packets to drop (optional).
.PARAMETER delayInMs
The delay to introduce in milliseconds (optional).
.PARAMETER faultRegion
The region where the fault should be introduced.
.PARAMETER waitForFaultToStartInSec
The time to wait before starting the fault in seconds (optional).
.EXAMPLE
.\chaos_script.ps1 -endpoint "https://my-cosmos-db.documents.azure.com:443/" -masterKey "my-master-key" -databaseId "my-database" -containerId "my-container" -durationOfFaultInSec 60 -dropPercentage 50 -delayInMs 200 -faultRegion "West US" -waitForFaultToStartInSec 10
This example introduces a network fault that drops 50% of packets and introduces a 200ms delay for 60 seconds in the "West US" region of the specified Cosmos DB instance. It waits 10 seconds before starting the fault.
#>

param (
    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $endpoint,

    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $masterKey,

    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $databaseId,

    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $containerId,

    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $durationOfFaultInSec,

    [string] $dropPercentage,

    [string] $delayInMs,
    
    [parameter(Mandatory = $true)]
    [string] $faultRegion,

    [string] $waitForFaultToStartInSec
)

if (!$dropPercentage -and !$delayInMs)
{
    throw "Both dropPercentage and delayInMs cannot be null together"
}

if ($waitForFaultToStartInSec)
{
    Start-Sleep -Seconds $waitForFaultToStartInSec
}

Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
choco install chocolatey-compatibility.extension
choco install clumsy  -y
#choco uninstall clumsy

$databaseAccountResponseJson = & .\GetDatabaseAccount.ps1 -Endpoint $endpoint -MasterKey $masterKey
$databaseAccountResponseObject = $databaseAccountResponseJson | ConvertFrom-Json
$readableLocations = $databaseAccountResponseObject.readableLocations

foreach ($readableLocation in $readableLocations)
{
    if ($faultRegion -eq $readableLocation.name)
    {
        $endpoint = $readableLocation.databaseAccountEndpoint
    }
}

$pkRangeResponseJson = & .\GetPKRange.ps1 -Endpoint $endpoint -MasterKey $masterKey -DatabaseID $databaseId -ContainerId $containerId
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

$addressesResponseJson = & .\GetAddresses.ps1 -Endpoint $endpoint -MasterKey $masterKey -PartitionKeyIds $commaSeparatedPkid -DatabaseID $databaseId -ContainerId $containerId
$addressesResponse = $addressesResponseJson | ConvertFrom-Json
$addresses = $addressesResponse.Addresss
$backendUriList = New-Object System.Collections.Generic.List[uri]
foreach ($address in $addresses)
{
    $backendUriList += [uri]$address.physcialUri
}
$backendUriList = $backendUriList | select -uniq

$endpointUri = [uri]$endpoint
$endpointHost = $endpointUri.Host
$endpointPort = $endpointUri.Port
$endpointIpAddress = (Resolve-DnsName $endpointHost).IPAddress
# Adding gateway endpoint for filtering
$filterStringList = New-Object System.Collections.ArrayList
$filterString = "(ip.DstAddr == $endpointIpAddress and tcp.DstPort == $endpointPort)"

$counterForUri = 0
# Adding backend nodes for filtering
foreach ($backendUri in $backendUriList)
{
    $counterForUri ++
    $backendHost = $backendUri.Host
    $ipAddress = (Resolve-DnsName $backendHost).IPAddress
    $backendPort = $backendUri.Port
    if ($filterString)
    {
        $filterString += " or (ip.DstAddr == $ipAddress and tcp.DstPort == $backendPort)"
    }
    else
    {
        $filterString += "(ip.DstAddr == $ipAddress and tcp.DstPort == $backendPort)"
    }
    # There is a filter length limit on Clumsy, therefore limiting uris in filter and adding them in a list
    if ($counterForUri -ge 30)
    {
        $filterStringList.Add($filterString)
        $counterForUri = 0
        $filterString = ""
    }
}
if ($filterString)
{
    $filterStringList.add($filterString)
}

if (!$dropPercentage)
{
    $dropPercentage = 0
}
if (!$delayInMs)
{
    $delayInMs = 0
}

# There is a filter length limit on Clumsy, therefore new process for each filter in a list
foreach ($filter in $filterStringList)
{
    # Start the fault
    clumsy.exe --filter $filter  --drop on  --drop-outbound on --drop-chance $dropPercentage --lag on --lag-outbound on --lag-chance 100.0 --lag-time $delayInMs
}
if ($durationOfFaultInSec)
{
    Start-Sleep -Seconds $durationOfFaultInSec
}

# Clearing the fault
Stop-Process -Name clumsy

# Uninstall Clumsy
choco uninstall clumsy -y