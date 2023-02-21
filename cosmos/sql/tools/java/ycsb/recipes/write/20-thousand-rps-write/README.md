# 20 Thousand Writes Per Second

This recipe encapsulates a write only workload with a maximum requests per second of 20 thousand.

## Recipe definition 

|  Config   |  Value   |
| --- | --- |
| Database | Cosmos SQL API |
| Benchmarking tool | YCSB |
| Workload | Write |
| Max RPS | 20 Thousand |
| Duration | 1 Hour |
| Document Size | ≈1 KB(YCSB default) |


## Execute
1. Create a [Cosmos DB SQL API container](https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/quickstart-portal)

   |  Setting   |  value  | 
   | --- | --- |
   | Database Name | ycsb | 
   | Container Name | usertable | 
   | Partition Key  | /id |
   | Container Throughput Type | Manual |  
   | Container throughput | 260,000 RU/s[^1] |

[^1]: Container throughput is slightly higher than normal to accommodate for the YCSB request distribution skew. For more details about capacity planning refer to [Cosmos DB capacity planner](https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/estimate-ru-with-capacity-planner)

2. Create a [storage account](https://learn.microsoft.com/en-us/azure/storage/common/storage-account-create?tabs=azure-portal) 
3. Create a [resource group](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/manage-resource-groups-portal) in the same region as the Cosmos DB account 
4. Click the deploy to Azure button and fill in the following missing parameter values:

   |  Parameter   |  Value  |
   | --- | --- |
   | Resource group | name of the resource group from spet 3 |
   | Region | Make sure the region is the same as the Cosmos DB account region |
   | Results Storage Connection String | connection string of the storage account from step 2 |
   | Cosmos URI  | URI of the Cosmos DB account from step 1 |
   | Cosmos Key  | Primary key of the Cosmos DB account from step 1 |
   | Admin Password | Admin account password for the VM |
   
 [More details about the parameters](../../#basic-configuration)



[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-db-benchmarking%2Fmain%2Fcosmos%2Fsql%2Ftools%2Fjava%2Fycsb%2Frecipes%2Fwrite%2F20-thousand-rps-write%2Fazuredeploy.json)

## Output
The job status and results will be available in the following locations in the storage account provided
| Type | Location |
| --- | --- |
| Status  | ycsbbenchmarkingMetadata (Table) |
| Results | ycsbbenchmarking-{Date} (Container) |

 [More details about job status and results](../../#monitoring)