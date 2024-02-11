<#
.SYNOPSIS
    Script to perform experiment operations in Azure Cosmos DB Chaos Studio.

.DESCRIPTION
    This script contains functions to create, execute, and get the status of experiments in Azure Cosmos DB Chaos Studio. It uses Azure Resource Manager REST API to interact with the Chaos Studio service.

.PARAMETER experimentSubscriptionId
    The subscription ID of the Azure Cosmos DB account where the experiment will be performed.

.PARAMETER experimentResourceGroup
    The resource group name of the Azure Cosmos DB account where the experiment will be performed.

.PARAMETER experimentName
    The name of the experiment.

.PARAMETER experimentJSON
    The JSON representation of the experiment configuration.

.PARAMETER chaosStudioManagedIdentityClientId
    The client ID of the managed identity used to authenticate with Azure Resource Manager.

.FUNCTIONALITY
    - Get-AccessToken: Retrieves an access token from Microsoft Entra ID for authentication.
    - Execute-RestMethod: Executes a REST API call using the provided method, URI, token, and optional request body.
    - Create-Experiment: Creates an experiment in Azure Cosmos DB Chaos Studio.
    - Execute-Experiment: Executes an experiment in Azure Cosmos DB Chaos Studio.
    - Get-Experiment: Retrieves the status of an experiment in Azure Cosmos DB Chaos Studio.
    - Wait-ExperimentCreation: Waits for the experiment provisioning to complete.

.EXAMPLE
    $experimentSubscriptionId = "12345678-1234-1234-1234-1234567890ab"
    $experimentResourceGroup = "myResourceGroup"
    $experimentName = "myExperiment"
    $experimentJSON = '{...}'
    $chaosStudioManagedIdentityClientId = "12345678-1234-1234-1234-1234567890ab"

    Create-Experiment -experimentSubscriptionId $experimentSubscriptionId -experimentResourceGroup $experimentResourceGroup -experimentName $experimentName -experimentJson $experimentJSON -chaosStudioManagedIdentityClientId $chaosStudioManagedIdentityClientId

.NOTES
    Author: Darshan Patnekar
    Date: 02/08/2024
    Version: 1.0
#>
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
    try {
        $token = & .\get_control_plane_aad_token.ps1 -clientId $clientId

        if (-not $token) {
            throw "Failed to retrieve Microsoft Entra ID token"
        }

        Write-Host "Retrieved access token from Microsoft Entra ID"
        return $token
    }
    catch {
        Write-Host "Error occurred while authenticating to Azure Resource Manager: $_"
        return $null
    }
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

    try {
        Write-Host "Calling REST API '$uri' ."

        if($method -eq "Get")
        {
            Invoke-RestMethod -Method $method -Uri $uri -Headers $httpHeader
        }
        else 
        {
            Invoke-RestMethod -Method $method -Uri $uri -Body $body -Headers $httpHeader
        }
    }
    catch {
        Write-Host "Error occurred while calling REST API: $_"
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
    
    try {
        Execute-RestMethod -Method PUT -Uri $uri -Body $body -Token $token
    } 
    catch {
        Write-Host "Failed to create experiment: $_"
    }

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
    $uri = $uri + "?api-version=2023-04-01-preview"
    
    $body = '{"properties":{}}';
    
    try {
        Execute-RestMethod -Method POST -Uri $uri -Body $body -Token $token -Verbose
    } 
    catch {
        Write-Host "Failed to execute experiment: $_"
    }
}

function Get-Experiment {
    
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

    $uri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Chaos/experiments/"
    $uri = $uri + $experimentName;
    $uri = $uri + "?api-version=2023-11-01"
    
    $body = '{"properties":{}}';

    try {
        Execute-RestMethod -Method Get -Uri $uri -Body $body -Token $token -Verbose
    } 
    catch {
        Write-Host "Failed to get experiment: $_"
    }
}

function Wait-ExperimentCreation {
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
        [string] $experimentState,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [string] $token
    )

    while ($experimentState -eq 'Creating' -or $experimentState -eq 'Updating')
    {
        Write-Host "Wait for Experiment Provisioning to Complete"
        Start-Sleep -Seconds 60

        Write-Host "Checking status of Experiment Provisioning"
        try {
            $experiment = Get-Experiment -SubscriptionId $subscriptionId -ResourceGroup $resourceGroup -ExperimentName $experimentName -Token $token
            $experimentState = $experiment.provisioningState
            Write-Host "Experiment Provisioning State: $experimentState"
        } 
        catch {
            Write-Host "Failed to get experiment: $_"
            break
        }
    }
}

try {
    $token = Get-AccessToken -ClientId $chaosStudioManagedIdentityClientId

    $experimentCreation = Create-Experiment -SubscriptionId $experimentSubscriptionId -ResourceGroup $experimentResourceGroup -ExperimentName $experimentName -ExperimentJson $experimentJson -Token $token

    Write-Host "Experiment Creation response: " $experimentCreation

    Wait-ExperimentCreation -SubscriptionId $experimentSubscriptionId -ResourceGroup $experimentResourceGroup -ExperimentName $experimentName -ExperimentState $experimentCreation.provisioningState -Token $token

    $experimentExecution = Execute-Experiment -SubscriptionId $experimentSubscriptionId -ResourceGroup $experimentResourceGroup -ExperimentName $experimentName -Token $token

    Write-Host "Experiment Execution Started." $experimentExecution
}
catch {
    Write-Host "Error occurred: $_"
}
