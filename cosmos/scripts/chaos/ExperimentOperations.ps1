param(
    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $experimentSubscriptionId,

    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $experimentResourceGroup,

    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $experimentName,

    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $experimentJSON,

    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string] $chaosStudioManagedIdentityClientId
)

function Get-AccessToken {

    param (
        [parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [string] $clientId
    )
    
    Write-Verbose "Authenticating to Azure Resource Manager..."
    $token =  & .\get_control_plane_aad_token.ps1 -clientId $clientId

    if (-not $token)
    {
        throw "Failed to retrieve Microsoft Entra ID token"
    }

    Write-Host "Retrieved access token from Microsoft Entra ID"
    return $token
}

function Execute-RestMethod {

    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [string] $method,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [string] $uri,

        [parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [string] $token,

        [Parameter(Mandatory=$false)]
        [string] $body
    )

    $httpHeader = @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "application/json"
        "Host" = "management.azure.com"
    }

    Write-Host "Calling ARM API '$uri' ."

    if($method -eq "Get")
    {
        Invoke-RestMethod -Method $method -Uri $uri -Headers $httpHeader
    }
    else 
    {
        Invoke-RestMethod -Method $method -Uri $uri -Body $body -Headers $httpHeader
    }
}

function Create-Experiment {
    
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [string] $subscriptionId,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [string] $resourceGroup,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [string] $experimentName,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [string] $experimentJson,

        [parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [string] $token
    )

    $uri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Chaos/experiments/"
    $uri = $uri + $experimentName;
    $uri = $uri + "?api-version=2023-11-01"
    
    $body = $experimentJson
    
    Execute-RestMethod -Method PUT -Uri $uri -Body $body -Token $token

}

function Execute-Experiment {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [string] $subscriptionId,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [string] $resourceGroup,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [string] $experimentName,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [string] $token
    )

    Write-Host "Executing Experiment " $experimentName "from Subscription " $subscriptionId "under ResourceGroup " $resourceGroup
     
    $uri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Chaos/experiments/"
    $uri = $uri + $experimentName + "/start";
    $uri = $uri + "?api-version=2023-11-01"
    
    $body = '{"properties":{}}';
    
    Execute-RestMethod -Method POST -Uri $uri -Body $body -Token $token -Verbose
}

function Wait-ExperimentCompletion {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [string] $statusUrl,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [string] $token
    )
    
    $status = Execute-RestMethod -Method Get -Uri $statusUrl -Token $token -Verbose

    while ($status.properties.status -ne "Success" -and $status.properties.status -ne "Failed")
    {
        Write-Host "Current Experiment Status is " $status.properties.status ". Waiting for experiment completion"
        Start-Sleep -Seconds 60
        $status = Execute-RestMethod -Method Get -Uri $statusUrl -Token $token -Verbose
    }

    if($status.properties.status -eq "Success")
    {
        Write-Host "Experiment completed Successfully."
    } 
    else
    {
        Write-Host "Experiment execution Failed."
    }

    $executionDetailsUrl = $statusUrl.Replace("statuses","executiondetails");

    Execute-RestMethod -Method Get -Uri $executionDetailsUrl -Token $token -Verbose
}

$token = Get-AccessToken -ClientId $chaosStudioManagedIdentityClientId

$experimentCreation = Create-Experiment -SubscriptionId $experimentSubscriptionId -ResourceGroup $experimentResourceGroup -ExperimentName $experimentName -ExperimentJson $experimentJson -Token $token

Write-Host "Experiment Creation response: " $experimentCreation

Start-Sleep -Seconds 30

$experimentExecution = Execute-Experiment -SubscriptionId $experimentSubscriptionId -ResourceGroup $experimentResourceGroup -ExperimentName $experimentName -Token $token

Write-Host "Experiment Execution Started." $experimentExecution


# $executionDetails = Wait-ExperimentCompletion -StatusUrl $experimentCreation.statusUrl -Token $token

# $executionDetails | Format-List

# if ($status.properties.status -eq "Failed")
# {
#     throw $executionDetails;
# }