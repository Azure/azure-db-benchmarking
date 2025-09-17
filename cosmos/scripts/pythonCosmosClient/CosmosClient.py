import uuid

import aiohttp
import argparse
import asyncio
import random
import time
import logging

from azure.cosmos import PartitionKey, ConsistencyLevel
from azure.cosmos.aio import CosmosClient, DatabaseProxy
from azure.core.pipeline.transport import AioHttpTransport

# from logging.handlers import RotatingFileHandler
from logging import FileHandler
from datetime import datetime, timezone
from ProxyConnector import ProxiedTCPConnector
from AsyncAtomicInt import AsyncAtomicInt
from datetime import datetime
from Metrics import Metrics
from WorkloadType import WorkloadType

REPORT_INTERVAL = 10  # seconds
CSV_FILENAME = "metrics_log.csv"
CHART_FILENAME = "metrics_chart.png"
LATENCY_CHART_FILENAME = "latency_chart.png"
EXCEL_FILENAME = "metrics_summary.xlsx"

_NOISY_ERRORS = set([404, 409, 412])
_NOISY_SUB_STATUS_CODES = set([0, None])
_REQUIRED_ATTRIBUTES = ["resource_type", "verb", "operation_type", "status_code", "sub_status_code", "duration"]

async def init_container(client: CosmosClient, database_name, container_name):
    db: DatabaseProxy = await client.create_database_if_not_exists(database_name)
    container = await db.create_container_if_not_exists(
        id=container_name,
        partition_key=PartitionKey(path="/id"),
        offer_throughput=400
    )
    return container

def create_logger(file_name: str):
    logger = logging.getLogger()
    #prefix = os.path.splitext(file_name)[0] + "-" + str(os.getpid())
    # Create a rotating file handler
    handler = FileHandler(file_name)
    logger.setLevel(logging.DEBUG)
    # create filters for the logger handler to reduce the noise
    workload_logger_filter = WorkloadLoggerFilter()
    handler.addFilter(workload_logger_filter)
    logger.addHandler(handler)
    return logger


class WorkloadLoggerFilter(logging.Filter):
    def filter(self, record):
        if record.msg:
            if isinstance(record.msg, str):
                request_url_index = record.msg.find("Request URL:")
                response_status_index = record.msg.find("Response status:")
                if request_url_index == -1 and response_status_index == -1:
                    return True
        if all(hasattr(record, attr) for attr in _REQUIRED_ATTRIBUTES):
            # Check database account reads
            if record.resource_type == "databaseaccount" and record.verb == "GET" and record.operation_type == "Read":
                return True
            # Check if there is an error and omit noisy errors
            if record.status_code >= 400:
                return True
            # Check if the latency (duration) was above 100 ms
            if record.duration >= 100:
                return True
        return False

def get_cosmos_client(endpoint: str,
                      account_key: str,
                      use_envoy: bool,
                      proxy_host: str) -> (CosmosClient, aiohttp.ClientSession, ProxiedTCPConnector):
    logger = create_logger("azure-cosmosdb-client.log")
    envoy_host="localhost" if (proxy_host is None) or (proxy_host == "") else proxy_host
    print(f"Initializing a proxy connector with proxy_host={envoy_host} and proxy_port={5100} and use_envoy={use_envoy}")
    proxied_connector = ProxiedTCPConnector(
        proxy_host= envoy_host,
        proxy_port=5100,
        keepalive_timeout=30) if (use_envoy == True) else None

    session = aiohttp.ClientSession(
        connector=proxied_connector,
    ) if (use_envoy == True) else None

    cosmos_endpoint = endpoint #"https://localhost:5100" if (use_envoy == True) else endpoint
    return (CosmosClient(
        url=cosmos_endpoint,
        credential=account_key,
        transport=AioHttpTransport(session=session, session_owner=False),  # type: ignore
        #logging_enable=True,
        logger=logger,
        consistency_level=ConsistencyLevel.Session,
        connection_timeout=5,
        enable_diagnostics_logging=True,
        # retry_throttle_total=2,
        retry_total=3,
    ) if (use_envoy == True) else CosmosClient(
        url=cosmos_endpoint,
        credential=account_key,
        #logging_enable=True,
        logger=logger,
        consistency_level=ConsistencyLevel.Session,
        connection_timeout=5,
        enable_diagnostics_logging=True,
        # retry_throttle_total=2,
        retry_total=3,
    ), session, proxied_connector)

async def write_workload(container, metrics: Metrics, ops, rate_limit=None):
    interval = 1 / rate_limit if rate_limit else 0
    for _ in range(ops):
        start = time.perf_counter_ns()
        timehash = datetime.now().strftime("%Y%m%d%H%M%S.%f")
        doc = {"id": f"user{(uuid.uuid4())}{timehash}", "value": random.random()}
        try:
            item = await container.create_item(doc)
            latency = (time.perf_counter_ns() - start) / 1_000
            await metrics.record(latency, True)
        except Exception as e:
            latency = (time.perf_counter_ns() - start) / 1_000
            await metrics.record(latency, False)
            print(str(e))

        if interval:
            elapsed = time.perf_counter_ns() - start
            to_sleep = (interval * 1_000_000_000 - elapsed)  / 1_000_000_000
            if to_sleep > 0:
                await asyncio.sleep(to_sleep)

async def load_generation(container, metrics: Metrics, count: int):
    num_workers = 10
    count_per_worker = int(count / num_workers)
    spill_over = int(count % num_workers)
    total_ingested_count = AsyncAtomicInt()

    tasks = [asyncio.create_task(add_document_worker(container, metrics, count_per_worker, total_ingested_count, i * count_per_worker))
             for i in range(num_workers)]

    if spill_over > 0:
        print(f"Adding spill over {spill_over} documents")
        tasks.append(asyncio.create_task(add_document_worker(container, metrics, spill_over, total_ingested_count, num_workers * count_per_worker)))

    await asyncio.gather(*tasks)
    docs_ingested: int = await total_ingested_count.get()
    if docs_ingested < count:
        raise Exception("Too few documents inserted.")
    else:
        print(f"Inserted {docs_ingested} documents.")

async def add_document_worker(container, metrics: Metrics, count: int, total_ingested: AsyncAtomicInt, index: int):
    #print(f"Adding {count} documents with partition key start index {index}")
    for i in range(index, index+count):
        start = time.perf_counter_ns()
        doc = {"id": f"user{i}", "value": random.random()}
        try:
            await container.upsert_item(doc)
            #out = await container.upsert_item(doc)
            # print(out)
            await total_ingested.increment(1)
            latency = (time.perf_counter_ns() - start) / 1_000
            await metrics.record(latency, True)
        except Exception as e:
            latency = (time.perf_counter_ns() - start) / 1_000
            await metrics.record(latency, False)
            print(str(e))

async def read_workload(container, metrics: Metrics, ops, num_docs_loaded: int, rate_limit=None):
    interval = 1 / float(rate_limit) if rate_limit else 0
    for _ in range(ops):
        start = time.perf_counter_ns()
        dummy_id = f"user{str(random.randint(0, num_docs_loaded - 1))}"
        try:
            await container.read_item(item=dummy_id, partition_key=dummy_id)
            latency = (time.perf_counter_ns() - start) / 1_000
            await metrics.record(latency, True)
        # except exceptions.CosmosResourceNotFoundError:
        #     latency = (time.perf_counter_ns() - start) / 1_000
        #     await metrics.record(latency, True)
        except Exception as e:
            latency = (time.perf_counter_ns() - start) / 1_000
            await metrics.record(latency, False)
            print(str(e))

        if interval:
            elapsed = time.perf_counter_ns() - start
            to_sleep = (interval * 1_000_000_000 - elapsed) / 1_000_000_000
            if to_sleep > 0:
                await asyncio.sleep(to_sleep)

def str_to_bool(s: str) -> bool:
    return s.strip().lower() in ("true", "1", "yes", "y")

async def main(args):
    use_envoy_bool = str_to_bool(args.use_envoy)
    print(f"{args.endpoint} is connecting to {use_envoy_bool}")
    client, session, connector = get_cosmos_client(args.endpoint, args.key, use_envoy_bool, args.proxy_host)
    async with client:
        container = await init_container(client, args.database, args.container)

        print(f"{'Type':<6} | {'Ops/sec':>6} | {'Avail':>6} | {'P99':>6} | {'P99.9':>7} | {'P99.99':>8}")
        print("-" * 64)

        if args.workload_type.lower() == WorkloadType.WRITE.value:
            write_metrics = Metrics("WRITE")

            start_time = time.perf_counter_ns()
            reporter = asyncio.create_task(
                Metrics.print_and_log_metrics(start_time, write_metrics)
            )

            rate_per_worker = args.target_ops_per_sec // args.concurrency if args.target_ops_per_sec > 0 else None

            await asyncio.gather(
                *[write_workload(container, write_metrics, args.ops // args.concurrency, rate_per_worker) for _ in
                  range(args.concurrency)]
            )

            reporter.cancel()
        elif args.workload_type.lower() == WorkloadType.READ.value:
            load_metrics = Metrics("LOAD")
            read_metrics = Metrics("READ")

            start_time = time.perf_counter_ns()
            reporter = asyncio.create_task(
                Metrics.print_and_log_metrics(start_time, load_metrics)
            )

            await asyncio.gather(load_generation(container, load_metrics, args.read_document_count))
            reporter.cancel()
            print("Load phase completed. Starting read workload.")

            start_time = time.perf_counter_ns()
            reporter = asyncio.create_task(Metrics.print_and_log_metrics(start_time, read_metrics, True))
            rate_per_worker = args.target_ops_per_sec // args.concurrency if args.target_ops_per_sec > 0 else None

            print(f"🛠️ Starting read workload with {rate_per_worker} ops/sec on each of the {args.concurrency} threads. Each thread will handle {args.ops // args.concurrency} ops.")
            await asyncio.gather(
                *[read_workload(container, read_metrics, args.ops // args.concurrency, args.read_document_count, rate_per_worker) for _ in
                  range(args.concurrency)]
            )

            reporter.cancel()
        else:
            print("Invalid workload type.")
            exit(1)

        #Metrics.generate_summary_artifacts(CSV_FILENAME)
        print(f"✅ Benchmark complete. Results saved. {datetime.now(timezone.utc).isoformat()}")

    if use_envoy_bool:
        await session.close()
        await connector.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Cosmos DB Performance Benchmark Tool")
    parser.add_argument("--endpoint", type=str, required=True, help="Cosmos DB endpoint URL")
    parser.add_argument("--key", type=str, required=True, help="Cosmos DB primary key")
    parser.add_argument("--database", type=str, default="BenchmarkDB", help="Database name")
    parser.add_argument("--container", type=str, default="BenchmarkContainer", help="Container name")
    parser.add_argument("--ops", type=int, default=10000, help="Total operations per workload")
    parser.add_argument("--concurrency", type=int, default=50, help="Concurrent tasks per workload")
    parser.add_argument("--target_ops_per_sec", type=int, default=0, help="Target operations/sec (0 = unthrottled)")
    parser.add_argument("--workload_type", type=str, default="READ", help="Workload type (read / write)")
    parser.add_argument("--read_document_count", type=int, default=10000, help="Total documents inserted for read operations")
    parser.add_argument("--use_envoy", type=str, default="False", help="Use Envoy Proxy for connecting to Cosmos DB")
    parser.add_argument("--proxy_host", type=str, help="Proxy endpoint URL")
    args = parser.parse_args()

    asyncio.run(main(args))
