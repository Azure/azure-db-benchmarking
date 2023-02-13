## Overview
[YCSB](https://github.com/brianfrankcooper/YCSB) is a popular java based open-source benchmarking tool for performance benchmarking NoSQL databases. The provided recipes encapsulate the workload definitions that are passed to YCSB. When using YCSB directly, sometimes the load phase needs to be executed before the run phase. The recipes combine the load and run phases to provide a one-click experience. [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) can also be used to execute the recipes. As you can see above, the recipes are organized by workload type and each recipe comes with instructions to help you execute them.

You can expect to see the following latencies for all the read and write workloads:

#### Read workload:
![image](../../../../../../images/read-latency.png)

#### Write workload:
![image](../../../../../../images/write-latency.png)

Next section walks you through the process of executing a small read recipe to familiarize you with the framework before you start with the actual recipes. If you feel comfortable you can skip this step and move to the actual recipes. 

 - [read-recipes](./read)
 - [write-recipes](./write)
 - [update-recipes](./update)
 - [scan-recipes](./scan)


## Try It 
A read recipe with a small read workload to familiarize you with the framework. The results should be available in 15-20 minutes after initiating the deployment.

1. Create a [Cosmos DB SQL API container](https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/quickstart-portal)

   |  Setting   |  value  | 
   | :--:  | :--:  |
   | Database Name | ycsb | 
   | Container Name | usertable | 
   | Partition Key  | /id |
   | Container Throughput  | Manual |  
   | Throughput | 400 RU/s | 
   
   
2. Create a [storage account](https://learn.microsoft.com/en-us/azure/storage/common/storage-account-create?tabs=azure-portal) and note down the connection string 
3. Create a [resource group](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/manage-resource-groups-portal) in the same region as the Cosmos DB account 
4. Click the deploy to Azure button and fill in the following missing parameter values:

   |  Parameter   |  Value  |
   | :--:  | :--:  |
   | Resource group | name of the resource group from spet 3 |
   | Results Storage Connection String | connection string of the storage account from step 2 |
   | Cosmos URI  | URI of the Cosmos DB account from step 1 |
   | Cosmos Key  | Primary key of the Cosmos DB account from step 1 |
   | Admin Password | Admin account password |

   [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-db-benchmarking%2Fmain%2Fcosmos%2Fsql%2Ftools%2Fjava%2Fycsb%2Frecipes%2Fread%2Ftry-it-read%2Fazuredeploy.json)

5. Navigate to the storage account created in step 2 to see the jobs status and results.

   - Job status can be found by browsing to the table in table storage browser 
   
     ![image](../../../../../../images/metadata-status.png)
 
   - Once the job status says "Finished", results will be availabe in a container within the same storage account
   
     ![image](../../../../../../images/results-container.png)
   
   - aggregation.csv has the aggregated results from all clients
    
     ![image](../../../../../../images/results-csv.png)
   
   - There will be a folder per VM with the detailed system diagnostics logs. These logs will help you diagnose issues. Check [common errors](#common-errors) section for details on errors.

     ![image](../../../../../../images/results-diagnostics.png)

6. Alternatively, create a paratemetr file or use the provided [sample parameter file](./parameter-files) to execute the recipe using [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli). Be sure to populate the parameter values in the parameter file.
    -  Local Template
     ```
     az deployment group create \
       --name <deploymen-name> \
       --resource-group <resource-group-name> \
       --template-file azuredeploy.json  \
       --parameters parameter.json  
      ```
    - Remote Template
    ```
    az deployment group create --name <deploymen-name> \
      --resource-group <resource-group-name> \
      --template-uri "https://raw.githubusercontent.com/Azure/azure-db-benchmarking/main/cosmos/sql/tools/java/ycsb/recipes/read/try-it-read/azuredeploy.json" \
      --parameters parameter.json
    ```
7. re-executing the recipe by setting "Skip Load Phase" to "true" , while leaving the rest of the parameter values unchanged, will execute just the read phase of the workload again, using the VM from the previous execution. 

## Common Errors
Following are the most common user mistakes that lead to errors. The error logs will be available in a container within the storage account provided. The only exception being the first error listed below. A unreachable storage account. In which case, the longs will be available only in the VM.

1. Following error will appear in "agent.out" in the "/home/benchmarking" of the client VM, if a incorrect storage connecting is passed. 
   ```
   Error while accessing storage account, exiting from this machine in agent.out on the VM 
   ```
2. Following error will appear in "agent.out" in the VM and in a folder within the results storage container if the Cosmos DB URI is incorrect or unreachable 
   ```
   Caused by: java.net.UnknownHostException: rtcosmosdbsss.documents.azure.com: Name or service not known 
   ```
3. Following error will appear in agent.out in the VM and in a folder within the results storage container if the Cosmos DB Key is incorrect
   ```
   The input authorization token can't serve the request. The wrong key is being used….
   ```

## Basic Configuration
   
   |  Parameter   |  Default Value  | Description |
   | :--:  | :--:  | :--: | 
   | Project Name | Benchmarking | this will become part of the VM name(ex: Benchmarking-vm1 ) |
   | Location | [resourceGroup().location] | location of the resource group |
   | Results Storage Connection String  |  | connection string of a storage account |
   | Cosmos URI  |  | Cosmos DB account URI |
   | Cosmos Key  |  | Cosmos DB account KEY |
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
   | Benchmarking Tools Repo Name |Azure/azure-db-benchmarking | GitHub repository name for benchmarking framework code |
   | Benchmarking Tools Branch Name | main | GitHub branch name for benchmarking framework code |
   | Skip Load Phase | false | "True" will skip the YCSB load pshase. Used to execute the run phase without running load again |
   
## Advanced Configuration
   The default configuration is used to create a VNet and Subnet, but custom configuration can be provided.
   |  Parameter   |  Default Value  | Description |
   | :--:  | :--:  | :--: | 
   | Vnet Name | [concat(parameters('projectName'), '-vnet')] | VNet name |
   | Vnet Address Prefixes | 10.2.0.0/16 | VNet address prefix |   
   | Vnet Subnet Name | default | subnet name | 
   | Vnet Subnet Address Prefix | 10.2.0.0/24 |  subnet address prefix |   
   
## Monitoring
Once a benchmarking job is triggered its status and few useful properties will be available in a storage table named "ycsbbenchmarkingMetadata". Each row represents one benchmarking job. A job can have one or more clients, each running on its own VM. The number of clients will always equal number of VMs. 

   |  Key   |  Description  | 
   | :--:  | :--: |
   | JobStartTime | Start time of the job | 
   | JobFinishTime | Finish time of the job | 
   | JobStatus| can be either "Started" or "Finished"| 
   | NoOfClientsStarted | Total number of clients used for the Job |
   | NoOfClientsCompleted | Total number of clients that completed their workload task | 


## Results 
Once the "JobStatus" key has a value of "Finished", the results will be available in a newly created container, with a name of the format "ycsbbenchmarking-<Date>".
   
   |  File   |  Description  | 
   | :--:  | :--:  |
   | aggregation.csv | aggregated result from all the clients |    
   | Benchmarking-vm<n>-ycsb.log| YCSB log file for the run phase. There will be as many files as the clients| 
   | Benchmarking-vm<n>-ycsb.csv | an intermediary CSV file generated from the YCSB log file. Used to produce the final aggregated results | 

  
   
