## Overview
[YCSB](https://github.com/Azure/YCSB) is a popular java based open-source benchmarking tool for performance benchmarking NoSQL databases. The provided recipes encapsulate the workload definitions that are passed to YCSB for a "1-Click" experience. When using YCSB directly, sometimes the load phase needs to be executed before the run phase. The recipes combine the load and run phases to provide a one-click experience. The "Getting started" recipe in the next section is a read workload that combines both the phases. 

## Getting started
A quick getting started exercise to get a feel for the framework. The results should be available in 15-20 minutes after initiating the deployment.

1. Create a [Cosmos DB SQL API container](https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/quickstart-portal)

   |  Setting   |  value  | 
   | --- | --- |
   | Database Name | ycsb | 
   | Container Name | usertable | 
   | Partition Key  | /id |
   | Container Throughput  | Manual |  
   | Throughput | 400 RU/s | 
   
   
3. Create a [storage account](https://learn.microsoft.com/en-us/azure/storage/common/storage-account-create?tabs=azure-portal) and note down the connection string 
4. Create a [resource group](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/manage-resource-groups-portal) in the same region as the Cosmos DB account 
5. Click the deploy to Azure button and fill in the following missing parameter values:

   |  Parameter   |  Value  |
   | --- | --- |
   | Resource group | name of the resource group from spet 3 |
   | Results Storage Connection String | connection string of the storage account from step 2 |
   | Cosmos URI  | URI of the Cosmos DB account from step 1 |
   | Cosmos Key  | Primary key of the Cosmos DB account from step 1 |
   | Admin Password | Admin account password |

   [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-db-benchmarking%2Fmain%2Fcosmos%2Fsql%2Ftools%2Fjava%2Fycsb%2Frecipes%2Fread%2Ftry-it-read%2Fazuredeploy.json)

5. Navigate to the storage account created in step 2 to see the jobs status and results.

   - Job status can be found by browsing to the table in table storage browser 
   
     ![image](../../../../../images/metadata-status.png)
 
   - Once the job status says "Finished", results will be availabe in a container within the same storage account
   
     ![image](../../../../../images/results-container.png)
   
   - aggregation.csv has the aggregated results from all clients
    
     ![image](../../../../../images/results-csv.png)

## Basic Configuration
   
   |  Parameter   |  Default Value  | Description |
   | --- | --- | ---| 
   | Project Name | Benchmarking | this will become part of the VM name(ex: Benchmarking-vm1 ) |
   | Location | [resourceGroup().location] | location of the resource group |
   | Results Storage Connection String  |  | connection string of a storage account |
   | Cosmos Key  |  | URI of the Cosmos DB account |
   | VM Size  | varies by recipe | VM size |
   | VM Count | varies by recipe | Number of VMs |
   | Admin Username | benchmarking | The username for the VM's admin account |
   | Admin Password |  | password for the VM's admin account |
   | Threads | varies by recipe | Number of YCSB client threads  |
   | YCSB Record Count |varies by recipe |Number of records in the dataset at the start of the workload|  
   | Target Operations Per Second |varies by recipe | Maximum number of operations per second to be performed by each client/vm |
   | YCSB Operation Count  |varies by recipe |The number of operations to perform in the workload by each client/vm|
   | YCSB Git Hub Repo Name | Azure/YCSB |GitHub repository name for fetching YCSB code|
   | YCSB Git Hub Branch Name | main |GitHub branch name for fetching YCSB code |
   | Benchmarking Tools Repo Name |Azure/azure-db-benchmarking | GitHub repository name for benchmarking framwork code |
   | Benchmarking Tools Branch Name | main | GitHub branch name for benchmarking framwork code |
   | Skip Load Phase | varies by recipe | "True" will skip the YCSB load pshase |
   
## Advanced Configuration
   The default configuration is used to create a VNet and Subnet, but custom configuration can be provided.
   |  Parameter   |  Default Value  | Description |
   | --- | --- | ---| 
   | Vnet Name | [concat(parameters('projectName'), '-vnet')] | VNet name |
   | Vnet Address Prefixes | 10.2.0.0/16 | VNet address prefix |   
   | Vnet Subnet Name | default | subnet name | 
   | Vnet Subnet Address Prefix | 10.2.0.0/24 |  subnet address prefix |   
## Monitoring
Once a benchmarking job is triggered its status and few useful properties will be available in a storage table named "ycsbbenchmarkingMetadata". Each row represents one benchmarking job. A job can have one or more clients, each running on its own VM. The number of clients will always equal number of VMs. 

   |  Key   |  Description  | 
   | --- | --- |
   | JobStartTime | Start time of the job | 
   | JobFinishTime | Finish time of the job | 
   | JobStatus| can be either "Started" or "Finished"| 
   | NoOfClientsStarted | Total number of clients used for the Job |
   | NoOfClientsCompleted | Total number of clients that completed their workload task | 


## Results 
Once the "JobStatus" key has a value of "Finished", the results will be available in a newly created container, with a name of the format "ycsbbenchmarking-<Date>".
   
   |  File   |  Description  | 
   | --- | --- |
   | aggregation.csv | aggregated result from all the clients |    
   | Benchmarking-vm<n>-ycsb.log| YCSB log file for the run phase. There will be as many files as the clients| 
   | Benchmarking-vm<n>-ycsb.csv | an intermediary CSV file generated from the YCSB log file. Used to produce the final aggregated results | 

  
   
