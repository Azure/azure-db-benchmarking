# SQL(Core) API Chaos:

- **Strictly for use in non-production only**

The provided recipes encapsulate the workloads and chaos faults to provide a one-click experience to observe the resiliency of applications using Cosmos DB SDK. Every recipe has a detailed description of the workload, fault, and the expected result. Provided is also a build your own recipe for scenarios not covered in the one-click recipes. The faults simulate network outages and network delays on the client side. The former will result in complete or partial outage while the latter will degrade performance.

You can also download and execute the chaos tool within your own environment to validate the resiliency of your workloads.

## Recipes
To use the recies please proceed to the following pages.
 - [network-fault-recipes](./network-faults/)
 - [build-your-own-recipe](./build-your-own-recipe)

## Download Tool
The tool can be used in both Windows and Linux OS. The tool uses “iptables” and Traffic control (tc) in Linux and “clumsy 0.2” in windows to create network chaos.

- [Tool download](./chaos-tool.zip)

## Linux
Download the tool on the Linux machine where you would like to execute the faults. Unzip the tool to extract the scripts and execute the following command from the folder with the scripts:

```
databaseid="<>" containerid="<>" endpoint=<> masterkey=<> wait_for_fault_to_start_in_sec= duration_of_fault_in_sec= <> drop_probability=<>  fault_region="<>" delay_in_ms=<> bash chaos_script.sh
```
**Parameters:**
   |  Parameter | Description | Mandatory |
   | --- | --- | ---|
   |databaseid | Id of the database | Yes|
   | containerid | Id of the container  | Yes |
   | endpoint |Account URI| Yes |
   | masterkey | Master key of the account | Yes |
   | wait_for_fault_to_start_in_se | Time in seconds to wait before starting the chaos | No |
   | duration_of_fault_in_sec | Duration of the chaos in seconds  | Yes |
   | drop_probability | Percentage of packets to drop  | No (both this and delayInMs cannot be null at the same time)|
   | delay_in_ms | Network delay in milliseconds | No|
   | fault_region | Region for the Fault | Yes|

## Windows
Download the tool on the Windows machine where you would like to execute the faults. Unzip the tool to extract the scripts and execute the following command from the folder with the scripts.

 ```
./chaos_script.ps1 -databaseId "" -containerId "" -endpoint "" -masterkey "" -waitForFaultToStartInSec "" -durationOfFaultInSec "" -dropPercentage "" -delayInMs "" -faultRegion ""
 ```

**Parameters:**
   |  Parameter | Description | Mandatory |
   | --- | --- | ---|
   |databaseId | Id of the database | Yes|
   | containerId | Id of the container  | Yes |
   | endpoint |Account URI| Yes |
   | masterkey | Master key of the account | Yes |
   | waitForFaultToStartInSec | Time in seconds to wait before starting the chaos | No |
   | durationOfFaultInSec | Duration of the chaos in seconds  | Yes |
   | dropPercentage | Percentage of packets to drop  | No (both this and delayInMs cannot be null at the same time)|
   | delayInMs | Network delay in milliseconds | No|
   | faultRegion | Region for the Fault | Yes|

   

   
