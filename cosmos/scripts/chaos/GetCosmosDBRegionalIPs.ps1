param (
    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $Region
)

$Region = $Region -replace '\s', '' # Remove whitespace
$serviceTags = Get-AzNetworkServiceTag -Location $Region
$cosmosdb = $serviceTags.Values | Where-Object { $_.Name -eq "AzureCosmosDB.$Region" }
$addressPrefixes = $cosmosdb.Properties.AddressPrefixes
$ipv4AddressPrefixes = $addressPrefixes | Where-Object { $_ -notmatch ":" }

function CidrToNetmask($ipv4AddressPrefixList) {
    $result = @()
    foreach ($ipv4AddressPrefix in $ipv4AddressPrefixList) {
        $network, $net_bits = $ipv4AddressPrefix -split '/'
        $host_bits = 32 - [int]$net_bits
        $netmask = [System.Net.IPAddress]::Parse(([UInt32]::MaxValue -shl $host_bits) -band [UInt32]::MaxValue).IPAddressToString
        $result += ,@($network, $netmask)
    }
    $result
}

CidrToNetmask $ipv4AddressPrefixes