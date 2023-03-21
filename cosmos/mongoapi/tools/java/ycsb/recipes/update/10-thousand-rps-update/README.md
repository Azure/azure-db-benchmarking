# 10 Thousand Updates Per Second
This recipe encapsulates a update only workload with a maximum requests per second of 10 thousand. This "1-Click" recipe combines both the load and run phases of YCSB.

## Recipe definition 

|  Config   |  Value   |
| --- | --- |
| Database | Cosmos DB for Mongo DB |
| Benchmarking tool | YCSB |
| Workload | Update |
| Max RPS | 10 Thousand |
| Duration | 1 Hour |
| Number of documents in DB |50,000 |
| Document Size | ≈1 KB(YCSB default) |

## Execute
1. Create a [Mongo DB collection](https://learn.microsoft.com/en-us/azure/cosmos-db/mongodb/quickstart-java)

   |  Setting   |  value  | 
   | --- | --- |
   | Database Name | ycsb | 
   | Container Name | usertable | 
   | Partition Key  | _id |
   | Container Throughput Type | Manual |  
   | Container throughput | 168,000 RU/s[^1] |

[^1]: Container throughput is slightly higher than normal to accommodate for the YCSB request distribution skew. For more details about capacity planning refer to [Cosmos DB capacity planner](https://learn.microsoft.com/en-us/azure/cosmos-db/mongodb/estimate-ru-capacity-planner)  
   
2. Create a [storage account](https://learn.microsoft.com/en-us/azure/storage/common/storage-account-create?tabs=azure-portal) 
3. Create a [resource group](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/manage-resource-groups-portal) in the same region as the Cosmos DB account 
4. Click the deploy to Azure button and fill in the following missing parameter values:

   |  Parameter   |  Value  |
   | --- | --- |
   | Resource group | name of the resource group from step 3 |
   | Region | Make sure the region is the same as the Cosmos DB account region |
   | Results Storage Connection String | connection string of the storage account from step 2 |
   | Cosmos Connection String  | Primary Connection String for the account from step 1 | 
   | Admin Password | Admin account password for the VM |

[More details about the parameters](../../#basic-configuration)   
 
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-db-benchmarking%2Fmain%2Fcosmos%2Fmongoapi%2Ftools%2Fjava%2Fycsb%2Frecipes%2Fupdate%2F5-thousand-rps-update%2Fazuredeploy.json)

## Output
The job status and results will be available in the following locations in the storage account provided
| Type | Location |
| --- | --- |
| Status  | ycsbbenchmarkingMetadata (Table) |
| Results | ycsbbenchmarking-{Date} (Container) |

 [More details about job status and results](../../#monitoring)

