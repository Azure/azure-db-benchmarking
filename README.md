# Benchmarking Framework For Azure Databases
For many years relational databases have been the de facto option for every type of problem. The advent of public clouds and the ever-increasing array of database options they provide, forced people to discover alternative options that better serve their purpose. In Azure alone there are a plethora of database services ranging from relational to NoSQL. Choice is wonderful when you know exactly what you want, otherwise could lead to decision paralysis.

While there are many factors that influence the choice of a database, one factor that is always of importance is performance. This project aims to provide an easy-to-use framework for measuring performances of azure databases to allow you to make an informed decision. 

Of course, there are many good open-source tools for benchmarking databases, but they do require some manual work to execute which is cumbersome and error prone, especially for executing large workloads requiring multiple client machines. This framework fills the gap by automating:
-	Client provisioning 
-	Client configuration 
-	Execution
- Results aggregation 

The provided recipes encapsulate the workload definitions that are passed to the underlying benchmarking tool for a "1-Click" experience. The workload definitions were designed based on the best practices published for the database, the SDK/connector and the benchmarking tool. The recipes have been tested and validated for consistent results. 

The first version of the framework uses [YCSB](https://github.com/brianfrankcooper/YCSB), a popular open-source benchmarking tool, for performance benchmarking Cosmos DB SQL API and Mongo API. We intend to onboard more databases and benchmarking tools in the future. We welcome contributions.

> **Note**
> We are pleased to introduce a new client-side chaos tool that allows users to validate the resiliency of their applications during unexpected events. Please navigate to [Getting Started](cosmos/sql/tools/java/ycsb/chaos) page for more details
## Tech Stack
- ARM Templates
- Bash Scripts
- Python 
- Azure VMs
- Azure Storage Account
- GitHub

## Architecture

### System
![image](/images/system.png)

### Execution
1.	Azure VMs provisioned
2.	cloud-init installs required packages on all the VMs 
3.	Benchmarking framework is downloaded from GitHub on every VM
4.	On each VM, the benchmarking framework agent triggers the benchmarking task 
5.	On the VM with the name "{pojectName}-vm1", the benchmarking agent additionally, aggregates the results from all the VMs, uploads the results to storage container
 
## Project Structure
   - [/system](/system)  System setup scripts
   - [/cosmos](/cosmos)  Cosmos DB specific artifacts
     - [/cosmos/scripts](/cosmos/scripts)  Scripts for framework agent and result aggregation
     - [/cosmos/infra](/cosmos/infra)  Common resource creation templates  
     - [/cosmos/sql/tools/java/ycsb/recipes](/cosmos/sql/tools/java/ycsb/recipes) SQL API YCSB Recipes 
     - [/cosmos/mongoapi/tools/java/ycsb/recipes](/cosmos/mongoapi/tools/java/ycsb/recipes) Mongo API YCSB Recipes 


## Getting Started

   |  Database   |  Benchmarking Tool  | Instructions
   | :--:  | :--:  | :--:  |
   | Cosmos SQL API | YCSB | [Getting Started ](/cosmos/sql/tools/java/ycsb/recipes)
   | Cosmos Mongo API | YCSB | [Getting Started ](/cosmos/mongoapi/tools/java/ycsb/recipes)
   | Cosmos SQL API(Chaos) | YCSB | [Getting Started](cosmos/sql/tools/java/ycsb/chaos)


## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft 
trademarks or logos is subject to and must follow 
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.
