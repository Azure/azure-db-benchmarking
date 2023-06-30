# Build you own fault

This will allow users to introduce network faults on the Cosmos DB nodes endpoint simulating real world disturbance as per their need. On the Multi region account once the underlying SDK detected a complete outage it failed over to the next region in the list. Read more about [Cosmo Global Data Distribution](https://learn.microsoft.com/en-us/azure/cosmos-db/distribute-data-globally) and [SDK behavior in multiregional environment](https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/troubleshoot-sdk-availability).

## Fault Parameters

Below parameters will be used during deployment which will control the faults.

| Name                     | Description                                                                                                                          |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------ |
| waitForFaultToStartInSec | Specifies amount of time in sec after workload start when fault introduce. -1 will disable the fault and runs regular benchmarking.  |
| durationOfFaultInSec     | Specifies amount of time in sec for the duration of fault. -1 will disable the fault and runs regular benchmarking.                  |
| faultRegion              | Specifies the region in which fault will be introduced, example West US. If nothing is specified, the Primary region will be picked. |
| dropProbability          | Specifies the percentate from 0.00 to 1.0 for packets drop during fault.                                                             |
| delayInMs                | Specifies amount of delay in ms to the network during the fault.                                                                     |

## Execute

1. Create a [Cosmos DB SQL API container](https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/quickstart-portal)

   | Setting                   | value        |
   | ------------------------- | ------------ |
   | Database Name             | ycsb         |
   | Container Name            | usertable    |
   | Partition Key             | /id          |
   | Container Throughput Type | Manual       |
   | Container throughput      | 400 RU/s[^1] |

[^1]: Container throughput is slightly higher than normal to accommodate for the YCSB request distribution skew. For more details about capacity planning refer to [Cosmos DB capacity planner](https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/estimate-ru-with-capacity-planner) 2. Create a [storage account](https://learn.microsoft.com/en-us/azure/storage/common/storage-account-create?tabs=azure-portal) 3. Create a [resource group](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/manage-resource-groups-portal) in the same region as the Cosmos DB account 4. Click the deploy to Azure button and fill in the following missing parameter values:

| Parameter                         | Value                                                            |
| --------------------------------- | ---------------------------------------------------------------- |
| Resource group                    | name of the resource group from step 3                           |
| Region                            | Make sure the region is the same as the Cosmos DB account region |
| Results Storage Connection String | connection string of the storage account from step 2             |
| Cosmos URI                        | URI of the Cosmos DB account from step 1                         |
| Cosmos Key                        | Primary key of the Cosmos DB account from step 1                 |
| Admin Password                    | Admin account password for the VM                                |

[More details about the parameters](../../#basic-configuration)

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-db-benchmarking%2Fusers%2Fnakumars%2FdrCapablity%2Fcosmos%2Fsql%2Ftools%2Fjava%2Fycsb%2Ffault-simulation%2Fbuild-your-own-fault%2Fazuredeploy.json)

## Output

The job status and results will be available in the following locations in the storage account provided
| Type | Location |
| --- | --- |
| Status | ycsbbenchmarkingMetadata (Table) |
| Results | ycsbbenchmarking-{Date} (Container) |

[More details about job status and results](../../#monitoring)
