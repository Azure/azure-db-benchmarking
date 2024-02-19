## Introduction to Cosmos DB client-side network chaos tool

The `cosmosdb_client_network_chaos_tool.ps1` script is a PowerShell script that allows you to simulate network chaos scenarios for Azure Cosmos DB clients. It is designed to help you test the resilience and performance of your Cosmos DB applications under various network conditions. 
These conditions will only be experience by the clients that you wish to target for the performance test. The rest of clients and the Cosmos DB service itself won't notice any disruptions from the use of this tool.

### Features

- **Simulate network outage**: You can configure the script to simulate network outage between the Cosmos DB client and the service.
- **Simulate network latency**: The script can introduce artificial network latency to simulate slow network connections.

### Dependencies

The `cosmosdb_client_network_chaos_tool.ps1` script, installs the following dependencies:

- Chocolatey
- Python3
- Azure.Identity module for python

The script should be executed with Admin privileges for the above installations to succeed. The script will uninstall these dependencies at the end of the execution of the script.

### Prequisites
- Azure Chaos Studio Resource Provider needs to be enabled for the client subscription.
- An Azure VM that is in the same network as the Cosmos DB account that you wish to use. The ```Cosmos DB client-side network chaos tool``` should be downloaded onto this VM and then executed.
- For authentication between various components the following Identities are required to be set up:
    1. User-assigned Managed Identity assigned to the **Client VM** (mentioned above) and the **Cosmos DB account**. 
        - Assign the **Cosmos DB reader role** mentioned [here](https://learn.microsoft.com/en-us/azure/cosmos-db/how-to-setup-rbac#built-in-role-definitions) to this identity on the Cosmos DB account you wish to use for this experiment. Please note this role is not available on Azure Portal yet. The following Azure CLI command can be used to assign the reader role to the identity:
        ```azurecli
        $resourceGroupName='<resourceGroupName>'
        $accountName='<accountName>'
        $readOnlyRoleDefinitionId='00000000-0000-0000-0000-000000000001' # Cosmos DB reader role
        $scope = '/dbs/ToDoList/colls/Items'
        # For Service Principals make sure to use the Object ID as found in the Enterprise applications section of the Azure Active Directory portal blade.
        $principalId='e24b019b-51f5-4c82-88a6-610cd143d79f'
        az cosmosdb sql role assignment create --account-name $accountName --resource-group $resourceGroupName --scope $scope --principal-id $principalId --role-definition-id $readOnlyRoleDefinitionId
        ```
        - This tool supports two more forms of authentication between the **Client VM** and the **Cosmos DB account**:
            - Cosmos DB account's Master Key/Primary Key
            - Service Principal: The Service Principal needs to be assigned the **Cosmos DB reader role** the same way as mentioned above for the User-assigned managed Identity.     
    2. User-assigned Managed Identity assigned to the **Client VM** and the **resource group containing Chaos Studio experiment** (the experiment will be created in this resource group after the tool is executed). Assign '**Contributor**' role on the ResourceGroup containing the experiment.
    3. User-assigned Managed Identity assigned to the **Chaos Studio experiment** and the **target resource(s)**. Assign '**Reader**' role on the target resource(s). If there are multiple target resources, this identity and the role needs to be assigned to each of them.

- The target resource(s) need to be onboarded to Chaos Studio so that the Chaos Agent is installed on these target resource(s) and the following Agent-based capabilities are enabled for these target resource(s):
    1. Network disconnect (via Firewall)
    2. Network latency
    - For more info on target onboarding click [here](#target-onboarding)

- This tool supports two types of target resource(s):
    1. Azure Virtual Machines (VM): Multiple VMs are supported.
    2. Azure Virtual Machine Scale Set (VMSS): Exactly one VMSS is supported.
    - The tool can be used to target a list of VMs or a VMSS or both. These targets can be in different resource groups and subscriptions as long as they have the same identity assigned to them as that of the experiment and the identity has Reader role on these target resource(s).

### Parameters

---
| Name                 | Description|
|----------------------|------------|
**Mandatory Parameters**
| cosmosDBEndpoint| The endpoint URL of the Cosmos DB instance
|databaseId| The ID of the Cosmos DB database
|containerId| The ID of the Cosmos DB container
|faultRegion| The region where the fault will be induced
|durationOfFaultInMinutes| The duration of the fault in minutes.
|cosmosDBIdentityClientId| The client ID of the user-assigned managed identity used for authentication. If cosmosDBServicePrincipalClientSecret and cosmosDBServicePrincipalTenantId are also provided, cosmosDBIdentityClientId will be used as the Client ID for the service principal.
|chaosStudioSubscriptionId| The subscription ID of the Azure Chaos Studio
|chaosStudioResourceGroupName| The resource group name of the Azure Chaos Studio
|chaosStudioManagedIdentityClientId| The client ID of the managed identity used by the Azure Chaos Studio
|chaosExperimentManagedIdentityName| The name of the managed identity used by the chaos experiment
|chaosExperimentName| The name of the chaos experiment
**Optional Parameters**
|cosmosDBServicePrincipalClientSecret| The client secret of the service principal used for authentication
|cosmosDBServicePrincipalTenantId| The tenant ID of the service principal used for authentication
|cosmosDBMasterKey| The master key/primary key of the Cosmos DB account
|targetVMSubRGNameList| Specifies a comma-separated list of names for the target virtual machines in the format: "subscriptionId/resourceGroupName/virtualMachineName". e.g. "{12345678-1234-1234-1234-1234567890ab/rg1/vm1,12567841-4321-4321-1234-1234567890gh/rg2/vm2}"
|targetVMSSSubRGName| Specifies the name for the target virtual machine scale set in the format: "subscriptionId/resourceGroupName/virtualMachineScaleSetName". Only one virtual machine scale set can be specified. e.g. "12345678-1234-1234-1234-1234567890ab/rg/vmss"
|vmssInstanceIdList| A comma-separated list of VM instance IDs in the target VM scale set. e.g. "{0,1,2}".
|delayInMs| The delay in milliseconds between each chaos experiment iteration. Only required when performing Delay injection
---

- Note for Optional parameters:
    - cosmosDBMasterKey and cosmosDBIdentityClientId cannot be null at the same time. At least one of them should be provided. If both cosmosDBMasterKey and cosmosDBIdentityClientId are provided, the script will use cosmosDBIdentityClientId to get the access token.
    - cosmosDBServicePrincipalTenantId cannot be null when cosmosDBServicePrincipalClientSecret is provided.
    - Both targetVMSubRGNameList (list of target VMs) and targetVMSSSubRGName (target VMSS) cannot be null at the same time. At least one target is needed. Both can be speciifed together.
    - To target a VMSS for fault, VMSSInstanceIdList should specify which VM instances in the VMSS need to be targeted e.g. {0,1,2}. 

### Usage

To use the ```Cosmos DB client-side network chaos tool```, follow these steps:

1. On the **Client VM** mentioned in the Prequisites section, open a PowerShell terminal with **Admin Privileges** and navigate to the directory where you saved the script.
2. You may want to Run the following command to bypass powershell checks:
``` 
Powershell -ExecutionPolicy Bypass
```
3. For creating ```Network Outage Chaos```

    - Execute the tool by running the following command making sure to replace all the placeholders with appropriate values:
    ```
    .\cosmosdb_client_network_chaos_tool.ps1 -cosmosDBEndpoint "<cosmosDBEndpointUrl>" -databaseId "<databaseId>" -containerId "<containerId>" -faultRegion "<faultRegion>" -chaosStudioSubscriptionId "<chaosStudioSubscriptionId>" -chaosStudioResourceGroupName "<chaosStudioResourceGroupName>" -chaosStudioManagedIdentityClientId "<chaosStudioManagedIdentityClientId>" -chaosExperimentName "<chaosExperimentName>" -chaosExperimentManagedIdentityName "<chaosExperimentManagedIdentityName>" -durationOfFaultInMinutes <durationOfFaultInMinutes> -targetVMSubRGNameList "<targetVMSubRGNameList>" -targetVMSSSubRGName "<targetVMSSSubRGName>" -vmssInstanceIdList "<vmssInstanceIdList>"
    ```


    - Following is an example to understand the input formatting:
    ```
    .\cosmosdb_client_network_chaos_tool.ps1 -cosmosDBEndpoint "https://mycosmosdb.documents.azure.com:443/" -databaseId "mydatabase" -containerId "mycontainer" -faultRegion "East US" -chaosStudioSubscriptionId "12345678-1234-1234-1234-1234567890ab" -chaosStudioResourceGroupName "chaos-rg" -chaosStudioManagedIdentityClientId "87654321-4321-4321-4321-210987654321" -chaosExperimentName "myexperiment" -chaosExperimentManagedIdentityName "experiment-mi" -durationOfFaultInMinutes 10 -targetVMSubRGNameList "{12345678-1234-1234-1234-1234567890ab/rg1/vm1,12567841-4321-4321-1234-1234567890gh/rg2/vm2}" -targetVMSSSubRGName "12345678-1234-1234-1234-1234567890ab/rg1/vmss" -vmssInstanceIdList "{0,1,2}"
    ```
4. For creating ```Network Delay Chaos```
    - Just add one more parameter to the above command -delayInMs "<delayInMs>". So the complete command will look this:
    ```
    .\cosmosdb_client_network_chaos_tool.ps1 -cosmosDBEndpoint "<cosmosDBEndpointUrl>" -databaseId "<databaseId>" -containerId "<containerId>" -faultRegion "<faultRegion>" -chaosStudioSubscriptionId "<chaosStudioSubscriptionId>" -chaosStudioResourceGroupName "<chaosStudioResourceGroupName>" -chaosStudioManagedIdentityClientId "<chaosStudioManagedIdentityClientId>" -chaosExperimentName "<chaosExperimentName>" -chaosExperimentManagedIdentityName "<chaosExperimentManagedIdentityName>" -durationOfFaultInMinutes <durationOfFaultInMinutes> -targetVMSubRGNameList "<targetVMSubRGNameList>" -targetVMSSSubRGName "<targetVMSSSubRGName>" -vmssInstanceIdList "<vmssInstanceIdList>" -delayInMs "<delayInMs>"
    ```
    - ```Note```: the delayInMs parameter must have value greater than 0 in order to create the ```Network Delay Chaos```

5. Navigate to the ```Experiments``` tab in Chaos Studio in the Azure Portal to find the Chaos Studio experiment created by the tool. It may at times take upto to 10 minutes for the experiment to show up in Chaos Studio. Make sure the experiment is or eventually goes in ```Running``` state.

### <a name="target-onboarding"></a>Target Onboarding to Chaos Studio

- Go to Chaos Studio Resource Provider and select the ```Targets``` tab in the left blade. Then select the VM/VMSS that you wish to onboard. Click ```Enable targets``` in the top menu. Select ```Enable agent-based targets (VM, VMSS)```
![Image](Images\targetOnboarding1.png)

- Provide the Subscription and name for the User-assigned Managed Identity ```chaosExperimentManagedIdentityName```. You can optionally enable Application Insights by providing the details of your Application Insights account. Click Review + Enable.
![Image](Images\targetOnboarding2.png)

- Once the target is onboarded, you should be able to see ```Enabled``` under the ```Agent-Based``` column for the VM/VMSS. Select ```Manage actions```
![Image](Images\targetOnboarding2a.png)

- Under ```Agent-based capabilities``` check ```Network Disconnect (Via Firewall)``` and ```Network Latency``` while leaving everything else unchecked. 
![Image](Images\targetOnboarding3.png)


- To check whether you have successfully onboarded the target you can navigate to the VM/VMSS in Azure portal and select the ```Extensions + applications``` tab in the left blade and check if ```ChaosAgent``` is Provisioned Successfully.
![Image](Images\targetOnboarding4.png)
