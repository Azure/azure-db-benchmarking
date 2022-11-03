## Overview
The query used in the [YCSB](https://github.com/brianfrankcooper/YCSB) scan operation performs a [cross-partition query](https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/how-to-query-container#cross-partition-query). In Cosmos DB, when you run a cross-partition query on a container, you are effectively running one query per physical partition. As the partitions increase, both the latency and RUs consumed increase significantly. Cosmos DB SDKs can be tuned to [parallelize cross-partition queries](https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/how-to-query-container#parallel-cross-partition-query) to improve the latency, but the RU charges will remain high. The following table compares the latencies for parallel and serial query execution and the effect of physical partition on latency. 

   |  Machine   |  RPS  | Threads |Container throughput| Physical Partitions|Data Size| Latency P99 MS  (Serial) | Latency P99 MS (Parallel)| Latency Avg MS  (Serial) | Latency Avg MS (Parallel)| 
   | :--: | :--: |:--: | :--: | :--: |:--: | :--: |:--: | :--: |:--: |
   | D8s_v3 | 150 | 3 | 6,000  | 1  | 1,000  | 24.49 | 31.61 | 10.97 | 14.12
   | D8s_v3 | 150 | 6 | 12,000 | 2  | 2,000  | 41.56 | 37.18 | 18.77 | 16.40
   | D8s_v3 | 150 | 6 | 18,000 | 3  | 3,000  | 46.43 | 42.62 |20.95  | 18.78
   | D8s_v3 | 150 | 6 | 24,000 | 4  | 4,000  | 66.43 | 48.44 | 30.68 | 20.81
   | D8s_v3 | 150 | 6 | 30,000 | 5  | 5,000  | 67.32 | 56.57 | 31.85 | 23.90
   | D8s_v3 | 150 | 6 | 60,000 | 10 | 10,000 | 42.30 | 39.35 | 21.17 | 17.15
   
Having a limited number of cross-partition queries is unavoidable in some data models but as a best practice it’s highly recommended to design data models to avoid cross-partition queries, especially for large containers. Additionally, make sure the partition key adheres to the [partition key selection best practices](https://learn.microsoft.com/en-us/azure/cosmos-db/partitioning-overview#choose-partitionkey) for optimal results.

Considering the above factors, recipes for scan operation are not provided.
