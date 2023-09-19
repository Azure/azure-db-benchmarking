# 300 Reads Per Second

This recipe encapsulates a read workload that lasts for 20-25 minutes. Around 5 minutes into the execution a regional outage is simulated by dropping all the packets bound to the specified region. The client/SDK detects the outage, marks the region as unavailable for reads and retries the requests on the next available region. Once the packet drops end, approximately in 5 minutes, all the requests get routed to the primary region.

## Recipe definition 

|  Config   |  Value   |
| --- | --- |
| Database | Cosmos SQL API |
| Benchmarking tool | YCSB |
| Workload | Read |
| Max RPS | 300 |
| Duration | 20-25 minutes |
| Fault Type | Packet Drop |
| Fault Start | 5 Minutes after the workload starts |
| Fault duration | 5 minutes |
| Number of documents in DB | 30 |
| Document Size | ≈1 KB(YCSB default) |

## Execute
1. Create a Geo-Redundancy [Cosmos DB SQL API account and container](https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/quickstart-portal)

   |  Setting   |  value  | 
   | --- | --- |
   | Geo-Redundancy | enable |
   | Database Name | ycsb | 
   | Container Name | usertable | 
   | Partition Key  | /id |
   | Container Throughput Type | Manual |  
   | Container throughput | 400 RU/s |

2. Create a [storage account](https://learn.microsoft.com/en-us/azure/storage/common/storage-account-create?tabs=azure-portal) 
3. Create a [resource group](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/manage-resource-groups-portal) in the same region as the Cosmos DB account 
4. Click the deploy to Azure button and fill in the following missing parameter values:

   |  Parameter   |  Value  |
   | --- | --- |
   | Resource group | name of the resource group from step 3 |
   | Region | Make sure the region is the same as the Cosmos DB account primary region |
   | Results Storage Connection String | connection string of the storage account from step 2 |
   | Cosmos URI  | URI of the Cosmos DB account from step 1 |
   | Cosmos Key  | Primary key of the Cosmos DB account from step 1 |
   | Admin Password | Admin account password for the VM |
   | Preferred Region List | Comma separated preferred regions list. Ex: South Central US,East US |
   | faultRegion | Primary region. Ex: South Central US |
   
 [More details about the parameters](../../#basic-configuration)

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-db-benchmarking%2Fusers%2Fnakumars%2FdrCapablity%2Fcosmos%2Fsql%2Ftools%2Fjava%2Fycsb%2Fchaos%2Fread%2Ftry-it-read-outage%2Fazuredeploy.json)


## Output
The job status and results will be available in the following locations in the storage account provided
| Type | Location |
| --- | --- |
| Status  | ycsbbenchmarkingMetadata (Table) |
| Results | ycsbbenchmarking-{Date} (Container) |

 [More details about job status and results](../../#monitoring)
