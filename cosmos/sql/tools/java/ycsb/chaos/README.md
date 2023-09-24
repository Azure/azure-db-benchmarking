## SQL(Core) API Chaos:
The provided recipes encapsulate the workloads and chaos faults to provide a one-click experience to observe the resiliency of applications using Cosmos DB SDK. Every recipe has a detailed description of the workload, fault, and the expected result. Provided is also a build your own recipe for scenarios not covered in the one-click recipes.The faults simulate network outages and network delays on the clisent side. The former will result in complete or partial outage while the latter will degrade performance.

You can also download and execute the chaos tool within your own environment to validate the resiliency of your workloads. The tool suports both linux and windows OS. 

Next section walks you through the process of executing a small read recipe to familiarize you with the framework before you start with the actual recipes. If you feel comfortable you can skip this step and move to the actual recipes. 

 - [network-outage-recipes](./network-outage/recipes)
 - [build-your-own-recipe](./build-your-own-recipe)



