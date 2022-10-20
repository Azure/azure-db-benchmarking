# 1 Million Reads Per Second
This recipe was created to simulate a read only workload with a maximum requests per second of 1 million. This one-click recipe combines both the load and run phases of YCSB.

## Recipe definition 

|     |     |
| --- | --- |
| Database | Cosmos SQL API |
| Container throughput | 1,200,000 RU/s* |
| Indexing | default |
| Benchmarking tool | YCSB |
| Workload | Read |
| Max RPS | 1 Million |
| Duration | 1 Hour |
| Data size |150,000 documents|
| Document Size | ≈1 KB(YCSB default) |

*Container throughput is slightly higher than normal to accommodate for the YCSB request distribution skew

## Execute
1. Create a Cosmos DB SQL API account, with a database "ycsb" and container "usertable" with manual throughput of 1,200,000 RU/s. Note down the endpoint and primary key 
3. Create an Azure storage account and note down the connection string 
4. Create a resource group in the same region as the Cosmos DB account 
5. Click the deploy to Azure button and fill in the following missing parameter values:

   |  Parameter   |  Value  |
   | --- | --- |
   | Resource group | name of the resource group from spet 3 |
   | Results Storage Connection String | connection string of the storage account from step 2 |
   | Cosmos URI  | URI of the Cosmos DB account from step 1 |
   | Cosmos Key  | Primary key of the Cosmos DB account from step 1 |
   | Admin Password | Admin account password for the VM |
   
   [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FRaviTella%2FBenckmarking%2Fmain%2Fcosmos%2Fsql%2Ftools%2Fjava%2Fycsb%2Frecipes%2Fread%2F1-million-rps-read%2Fazuredeploy.json)
## Output
The job metadata and results will be available in the following locations in the storage account provided
|     |     |
| --- | --- |
| Status  | ycsbbenchmarkingMetadata (Table) |
| Results | ycsbbenchmarking-{Date} (Container) |

 [More details about job status and results](../../../#monitoring)



