# Build you own fault

This will allow users to introduce network faults on the Cosmos DB nodes endpoint simulating real world disturbance as per their need. On the Multi region account once the underlying SDK detected a complete outage it failed over to the next region in the list. Read more about [Cosmo Global Data Distribution](https://learn.microsoft.com/en-us/azure/cosmos-db/distribute-data-globally) and [SDK behavior in multiregional environment](https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/troubleshoot-sdk-availability).

## Execute

1. Create a [Cosmos DB SQL API container](https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/quickstart-portal)

   | Setting                   | value        |
   | ------------------------- | ------------ |
   | Database Name             | ycsb         |
   | Container Name            | usertable    |
   | Partition Key             | /id          |
   | Container Throughput Type | as appropriate |
   | Container throughput      | as appropriate |


2. Create a [storage account](https://learn.microsoft.com/en-us/azure/storage/common/storage-account-create?tabs=azure-portal) 
3. Create a [resource group](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/manage-resource-groups-portal) in the same region as the Cosmos DB account 
4. Click the deploy to Azure button and fill in the following missing parameter values:

| Parameter                         | Value                                                            |
| --------------------------------- | ---------------------------------------------------------------- |
| Resource group                    | name of the resource group from step 3                           |
| Region                            | Make sure the region is the same as the Cosmos DB account region |
| Results Storage Connection String | connection string of the storage account from step 2             |
| Cosmos URI                        | URI of the Cosmos DB account from step 1                         |
| Cosmos Key                        | Primary key of the Cosmos DB account from step 1                 |
| Admin Password                    | Admin account password for the VM                                |
| Preferred Region List             | Comma separated preferred regions list. Ex: South Central US,East US.  [More about SDKs Failover configuration](https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/troubleshoot-sdk-availability) |
| faultRegion                       | Region which should experience the fault. Ex: South Central US |
| waitForFaultToStartInSec          | Time in seconds to wait before starting the fault |
| durationOfFaultInSec              | Specifies amount of time in sec for the duration of fault. -1 will disable the fault and runs regular benchmarking |
| dropProbability                   | Percentage of packets to drop during fault. Range 0.00(no drop) to 1.0(drop all packets) |
| delayInMs                         | Network delay in milliseconds |


[More details about the parameters](../../#basic-configuration)

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-db-benchmarking%2Fusers%2Fnakumars%2FdrCapablity%2Fcosmos%2Fsql%2Ftools%2Fjava%2Fycsb%2Fchaos%2Fbuild-your-own-recipe%2Fazuredeploy.json)

## Output
You can visualize the total request count by region by creating a [Azure Monitor metrics chart](https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/metrics-getting-started) for Azure Cosmos DB.

The job status and results will be available in the following locations in the storage account provided
| Type | Location |
| --- | --- |
| Status | ycsbwithfaultMetadata (Table) |
| Results | ycsbwithfault-{Date} (Container) |

[More details about job status and results](../../#monitoring)
