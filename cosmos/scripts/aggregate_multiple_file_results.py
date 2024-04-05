# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

"""
This script aggregates results from multiple log files. It takes a directory containing log files as input and outputs a CSV file containing aggregated metrics from the log files.

Usage:
    python aggregate_multiple_files_result.py <FilesDirectory>

Arguments:
    FilesDirectory: The directory containing the log files to aggregate.

Raises:
    Exception: If the FilesDirectory argument is not provided.

Outputs:
    A CSV file named 'aggregation.csv' containing aggregated metrics from the log files.
"""

import csv
import glob
import os
import sys


def main():
    if len(sys.argv) == 1:
        raise Exception("Input log files directory not provided. Syntax = 'python aggregate_multiple_files_result.py "
                        "<FilesDirectory>'")
    path = sys.argv[1]
    # Initialize count and throughput variables
    total_read_count = 0
    total_read_failed_count = 0
    total_update_count = 0
    total_update_failed_count = 0
    total_write_count = 0
    total_write_failed_count = 0
    total_scan_count = 0
    total_scan_failed_count = 0
    total_throughput = 0

    # Loop over all log files in the provided directory
    for filename in glob.glob(os.path.join(path, '*.log')):
        with open(os.path.join(os.getcwd(), filename), 'r') as f:  # open in readonly mode
            current_file = open(filename, 'r')
            lines = current_file.readlines()
            # For each line in the current log file, check if it contains certain keywords
            # that indicate the type of operation and whether the operation was successful or failed
            # Then increment the corresponding count variable by the number of operations indicated in the line
            for line in lines:
                if '[READ], Operations,' in line:
                    total_read_count += int(line.replace('[READ], Operations, ', ''))
                elif '[READ-FAILED], Operations,' in line:
                    total_read_failed_count += int(line.replace('[READ-FAILED], Operations, ', ''))
                elif '[UPDATE], Operations,' in line:
                    total_update_count += int(line.replace('[UPDATE], Operations, ', ''))
                elif '[UPDATE-FAILED], Operations,' in line:
                    total_update_failed_count += int(line.replace('[UPDATE-FAILED], Operations, ', ''))
                elif '[INSERT], Operations,' in line:
                    total_write_count += int(line.replace('[INSERT], Operations, ', ''))
                elif '[INSERT-FAILED], Operations,' in line:
                    total_write_failed_count += int(line.replace('[INSERT-FAILED], Operations, ', ''))
                elif '[SCAN], Operations,' in line:
                    total_scan_count += int(line.replace('[SCAN], Operations, ', ''))
                elif '[SCAN-FAILED], Operations,' in line:
                    total_scan_failed_count += int(line.replace('[SCAN-FAILED], Operations, ', ''))
                elif '[OVERALL], Throughput(ops/sec), ' in line:
                    total_throughput += float(line.replace('[OVERALL], Throughput(ops/sec), ', ''))

    # Initialize latency variables
    total_read_avg = 0
    total_read_p95 = 0
    total_read_p99 = 0
    total_read_min = sys.maxsize
    total_read_max = 0

    total_read_failed_avg = 0
    total_read_failed_p95 = 0
    total_read_failed_p99 = 0
    total_read_failed_min = sys.maxsize
    total_read_failed_max = 0

    total_update_avg = 0
    total_update_p95 = 0
    total_update_p99 = 0
    total_update_min = sys.maxsize
    total_update_max = 0

    total_update_failed_avg = 0
    total_update_failed_p95 = 0
    total_update_failed_p99 = 0
    total_update_failed_min = sys.maxsize
    total_update_failed_max = 0

    total_write_avg = 0
    total_write_p95 = 0
    total_write_p99 = 0
    total_write_min = sys.maxsize
    total_write_max = 0

    total_write_failed_avg = 0
    total_write_failed_p95 = 0
    total_write_failed_p99 = 0
    total_write_failed_min = sys.maxsize
    total_write_failed_max = 0

    total_scan_avg = 0
    total_scan_p95 = 0
    total_scan_p99 = 0
    total_scan_min = sys.maxsize
    total_scan_max = 0

    total_scan_failed_avg = 0
    total_scan_failed_p95 = 0
    total_scan_failed_p99 = 0
    total_scan_failed_min = sys.maxsize
    total_scan_failed_max = 0

    # Loop over all log files in the provided directory again
    for filename in glob.glob(os.path.join(path, '*.log')):
        with open(os.path.join(os.getcwd(), filename), 'r') as f:  # open in readonly mode
            current_file = open(filename, 'r')
            lines = current_file.readlines()
            current_read_operation = 0
            current_read_failed_operation = 0
            current_update_operation = 0
            current_update_failed_operation = 0
            current_write_operation = 0
            current_write_failed_operation = 0
            current_scan_operation = 0
            current_scan_failed_operation = 0

            # For each line in the current log file, check if it contains certain keywords
            # that indicate the type of operation and whether the operation was successful or failed
            # Then calculate the weighted average, 95th percentile, and 99th percentile latencies for the current
            # operation and update the minimum and maximum latencies if necessary.
            for line in lines:
                if '[READ], ' in line and total_read_count == 0:
                    continue
                if '[READ], Operations,' in line:
                    current_read_operation += int(line.replace('[READ], Operations, ', ''))
                elif '[READ], AverageLatency(us), ' in line:
                    weighted_current_avg = (float(line.replace('[READ], AverageLatency(us), ',
                                                               '')) * current_read_operation) / total_read_count
                    total_read_avg += weighted_current_avg
                elif '[READ], 95thPercentileLatency(us), ' in line:
                    weighted_current_p95 = (float(line.replace('[READ], 95thPercentileLatency(us), ',
                                                               '')) * current_read_operation) / total_read_count
                    total_read_p95 += weighted_current_p95
                elif '[READ], 99thPercentileLatency(us), ' in line:
                    weighted_current_p99 = (float(line.replace('[READ], 99thPercentileLatency(us), ',
                                                               '')) * current_read_operation) / total_read_count
                    total_read_p99 += weighted_current_p99
                elif '[READ], MinLatency(us), ' in line:
                    weighted_current_min = int(line.replace('[READ], MinLatency(us), ',
                                                            ''))
                    if total_read_min > weighted_current_min:
                        total_read_min = weighted_current_min
                elif '[READ], MaxLatency(us), ' in line:
                    weighted_current_max = int(line.replace('[READ], MaxLatency(us), ',
                                                            ''))
                    if total_read_max < weighted_current_max:
                        total_read_max = weighted_current_max

                elif '[READ-FAILED], ' in line and total_read_failed_count == 0:
                    continue
                elif '[READ-FAILED], Operations,' in line:
                    current_read_failed_operation += int(line.replace('[READ-FAILED], Operations, ', ''))
                elif '[READ-FAILED], AverageLatency(us), ' in line:
                    weighted_current_avg = (float(line.replace('[READ-FAILED], AverageLatency(us), ',
                                                               '')) * current_read_failed_operation) / total_read_failed_count
                    total_read_failed_avg += weighted_current_avg
                elif '[READ-FAILED], 95thPercentileLatency(us), ' in line:
                    weighted_current_p95 = (float(line.replace('[READ-FAILED], 95thPercentileLatency(us), ',
                                                               '')) * current_read_failed_operation) / total_read_failed_count
                    total_read_failed_p95 += weighted_current_p95
                elif '[READ-FAILED], 99thPercentileLatency(us), ' in line:
                    weighted_current_p99 = (float(line.replace('[READ-FAILED], 99thPercentileLatency(us), ',
                                                               '')) * current_read_failed_operation) / total_read_failed_count
                    total_read_failed_p99 += weighted_current_p99
                elif '[READ-FAILED], MinLatency(us), ' in line:
                    weighted_current_min = int(line.replace('[READ-FAILED], MinLatency(us), ',
                                                            ''))
                    if total_read_failed_min > weighted_current_min:
                        total_read_failed_min = weighted_current_min
                elif '[READ-FAILED], MaxLatency(us), ' in line:
                    weighted_current_max = int(line.replace('[READ-FAILED], MaxLatency(us), ',
                                                            ''))
                    if total_read_failed_max < weighted_current_max:
                        total_read_failed_max = weighted_current_max

                elif '[UPDATE], ' in line and total_update_count == 0:
                    continue
                elif '[UPDATE], Operations,' in line:
                    current_update_operation += int(line.replace('[UPDATE], Operations, ', ''))
                elif '[UPDATE], AverageLatency(us), ' in line:
                    weighted_current_avg = (float(line.replace('[UPDATE], AverageLatency(us), ',
                                                               '')) * current_update_operation) / total_update_count
                    total_update_avg += weighted_current_avg
                elif '[UPDATE], 95thPercentileLatency(us), ' in line:
                    weighted_current_p95 = (float(line.replace('[UPDATE], 95thPercentileLatency(us), ',
                                                               '')) * current_update_operation) / total_update_count
                    total_update_p95 += weighted_current_p95
                elif '[UPDATE], 99thPercentileLatency(us), ' in line:
                    weighted_current_p99 = (float(line.replace('[UPDATE], 99thPercentileLatency(us), ',
                                                               '')) * current_update_operation) / total_update_count
                    total_update_p99 += weighted_current_p99
                elif '[UPDATE], MinLatency(us), ' in line:
                    weighted_current_min = int(line.replace('[UPDATE], MinLatency(us), ',
                                                            ''))
                    if total_update_min > weighted_current_min:
                        total_update_min = weighted_current_min
                elif '[UPDATE], MaxLatency(us), ' in line:
                    weighted_current_max = int(line.replace('[UPDATE], MaxLatency(us), ',
                                                            ''))
                    if total_update_max < weighted_current_max:
                        total_update_max = weighted_current_max

                elif '[UPDATE-FAILED], ' in line and total_update_failed_count == 0:
                    continue
                elif '[UPDATE-FAILED], Operations,' in line:
                    current_update_failed_operation += int(line.replace('[UPDATE-FAILED], Operations, ', ''))
                elif '[UPDATE-FAILED], AverageLatency(us), ' in line:
                    weighted_current_avg = (float(line.replace('[UPDATE-FAILED], AverageLatency(us), ',
                                                               '')) * current_update_failed_operation) / total_update_failed_count
                    total_update_failed_avg += weighted_current_avg
                elif '[UPDATE-FAILED], 95thPercentileLatency(us), ' in line:
                    weighted_current_p95 = (float(line.replace('[UPDATE-FAILED], 95thPercentileLatency(us), ',
                                                               '')) * current_update_failed_operation) / total_update_failed_count
                    total_update_failed_p95 += weighted_current_p95
                elif '[UPDATE-FAILED], 99thPercentileLatency(us), ' in line:
                    weighted_current_p99 = (float(line.replace('[UPDATE-FAILED], 99thPercentileLatency(us), ',
                                                               '')) * current_update_failed_operation) / total_update_failed_count
                    total_update_failed_p99 += weighted_current_p99
                elif '[UPDATE-FAILED], MinLatency(us), ' in line:
                    weighted_current_min = int(line.replace('[UPDATE-FAILED], MinLatency(us), ',
                                                            ''))
                    if total_update_failed_min > weighted_current_min:
                        total_update_failed_min = weighted_current_min
                elif '[UPDATE-FAILED], MaxLatency(us), ' in line:
                    weighted_current_max = int(line.replace('[UPDATE-FAILED], MaxLatency(us), ',
                                                            ''))
                    if total_update_failed_max < weighted_current_max:
                        total_update_failed_max = weighted_current_max

                elif '[INSERT], ' in line and total_write_count == 0:
                    continue
                elif '[INSERT], Operations,' in line:
                    current_write_operation += int(line.replace('[INSERT], Operations, ', ''))
                elif '[INSERT], AverageLatency(us), ' in line:
                    weighted_current_avg = (float(line.replace('[INSERT], AverageLatency(us), ',
                                                               '')) * current_write_operation) / total_write_count
                    total_write_avg += weighted_current_avg
                elif '[INSERT], 95thPercentileLatency(us), ' in line:
                    weighted_current_p95 = (float(line.replace('[INSERT], 95thPercentileLatency(us), ',
                                                               '')) * current_write_operation) / total_write_count
                    total_write_p95 += weighted_current_p95
                elif '[INSERT], 99thPercentileLatency(us), ' in line:
                    weighted_current_p99 = (float(line.replace('[INSERT], 99thPercentileLatency(us), ',
                                                               '')) * current_write_operation) / total_write_count
                    total_write_p99 += weighted_current_p99
                elif '[INSERT], MinLatency(us), ' in line:
                    weighted_current_min = int(line.replace('[INSERT], MinLatency(us), ',
                                                            ''))
                    if total_write_min > weighted_current_min:
                        total_write_min = weighted_current_min
                elif '[INSERT], MaxLatency(us), ' in line:
                    weighted_current_max = int(line.replace('[INSERT], MaxLatency(us), ',
                                                            ''))
                    if total_write_max < weighted_current_max:
                        total_write_max = weighted_current_max

                elif '[INSERT-FAILED], ' in line and total_write_failed_count == 0:
                    continue
                elif '[INSERT-FAILED], Operations,' in line:
                    current_write_failed_operation += int(line.replace('[INSERT-FAILED], Operations, ', ''))
                elif '[INSERT-FAILED], AverageLatency(us), ' in line:
                    weighted_current_avg = (float(line.replace('[INSERT-FAILED], AverageLatency(us), ',
                                                               '')) * current_write_failed_operation) / total_write_failed_count
                    total_write_failed_avg += weighted_current_avg
                elif '[INSERT-FAILED], 95thPercentileLatency(us), ' in line:
                    weighted_current_p95 = (float(line.replace('[INSERT-FAILED], 95thPercentileLatency(us), ',
                                                               '')) * current_write_failed_operation) / total_write_failed_count
                    total_write_failed_p95 += weighted_current_p95
                elif '[INSERT-FAILED], 99thPercentileLatency(us), ' in line:
                    weighted_current_p99 = (float(line.replace('[INSERT-FAILED], 99thPercentileLatency(us), ',
                                                               '')) * current_write_failed_operation) / total_write_failed_count
                    total_write_failed_p99 += weighted_current_p99
                elif '[INSERT-FAILED], MinLatency(us), ' in line:
                    weighted_current_min = int(line.replace('[INSERT-FAILED], MinLatency(us), ',
                                                            ''))
                    if total_write_failed_min > weighted_current_min:
                        total_write_failed_min = weighted_current_min
                elif '[INSERT-FAILED], MaxLatency(us), ' in line:
                    weighted_current_max = int(line.replace('[INSERT-FAILED], MaxLatency(us), ',
                                                            ''))
                    if total_write_failed_max < weighted_current_max:
                        total_write_failed_max = weighted_current_max

                elif '[SCAN], ' in line and total_scan_count == 0:
                    continue
                elif '[SCAN], Operations,' in line:
                    current_scan_operation += int(line.replace('[SCAN], Operations, ', ''))
                elif '[SCAN], AverageLatency(us), ' in line:
                    weighted_current_avg = (float(line.replace('[SCAN], AverageLatency(us), ',
                                                               '')) * current_scan_operation) / total_scan_count
                    total_scan_avg += weighted_current_avg
                elif '[SCAN], 95thPercentileLatency(us), ' in line:
                    weighted_current_p95 = (float(line.replace('[SCAN], 95thPercentileLatency(us), ',
                                                               '')) * current_scan_operation) / total_scan_count
                    total_scan_p95 += weighted_current_p95
                elif '[SCAN], 99thPercentileLatency(us), ' in line:
                    weighted_current_p99 = (float(line.replace('[SCAN], 99thPercentileLatency(us), ',
                                                               '')) * current_scan_operation) / total_scan_count
                    total_scan_p99 += weighted_current_p99
                elif '[SCAN], MinLatency(us), ' in line:
                    weighted_current_min = int(line.replace('[SCAN], MinLatency(us), ',
                                                            ''))
                    if total_scan_min > weighted_current_min:
                        total_scan_min = weighted_current_min
                elif '[SCAN], MaxLatency(us), ' in line:
                    weighted_current_max = int(line.replace('[SCAN], MaxLatency(us), ',
                                                            ''))
                    if total_scan_max < weighted_current_max:
                        total_scan_max = weighted_current_max

                elif '[SCAN-FAILED], ' in line and total_scan_failed_count == 0:
                    continue
                elif '[SCAN-FAILED], Operations,' in line:
                    current_scan_failed_operation += int(line.replace('[SCAN-FAILED], Operations, ', ''))
                elif '[SCAN-FAILED], AverageLatency(us), ' in line:
                    weighted_current_avg = (float(line.replace('[SCAN-FAILED], AverageLatency(us), ',
                                                               '')) * current_scan_failed_operation) / total_scan_failed_count
                    total_scan_failed_avg += weighted_current_avg
                elif '[SCAN-FAILED], 95thPercentileLatency(us), ' in line:
                    weighted_current_p95 = (float(line.replace('[SCAN-FAILED], 95thPercentileLatency(us), ',
                                                               '')) * current_scan_failed_operation) / total_scan_failed_count
                    total_scan_failed_p95 += weighted_current_p95
                elif '[SCAN-FAILED], 99thPercentileLatency(us), ' in line:
                    weighted_current_p99 = (float(line.replace('[SCAN-FAILED], 99thPercentileLatency(us), ',
                                                               '')) * current_scan_failed_operation) / total_scan_failed_count
                    total_scan_failed_p99 += weighted_current_p99
                elif '[SCAN-FAILED], MinLatency(us), ' in line:
                    weighted_current_min = int(line.replace('[SCAN-FAILED], MinLatency(us), ',
                                                            ''))
                    if total_scan_failed_min > weighted_current_min:
                        total_scan_failed_min = weighted_current_min
                elif '[SCAN-FAILED], MaxLatency(us), ' in line:
                    weighted_current_max = int(line.replace('[SCAN-FAILED], MaxLatency(us), ',
                                                            ''))
                    if total_scan_failed_max < weighted_current_max:
                        total_scan_failed_max = weighted_current_max

    # Convert read times to milliseconds
    total_read_avg_ms = total_read_avg / 1000
    total_read_p95_ms = total_read_p95 / 1000
    total_read_p99_ms = total_read_p99 / 1000
    total_read_min_ms = total_read_min / 1000
    total_read_max_ms = total_read_max / 1000

    # Convert read failed times to milliseconds
    total_read_failed_avg_ms = total_read_failed_avg / 1000
    total_read_failed_p95_ms = total_read_failed_p95 / 1000
    total_read_failed_p99_ms = total_read_failed_p99 / 1000
    total_read_failed_min_ms = total_read_failed_min / 1000
    total_read_failed_max_ms = total_read_failed_max / 1000

    # Convert update times to milliseconds
    total_update_avg_ms = total_update_avg / 1000
    total_update_p95_ms = total_update_p95 / 1000
    total_update_p99_ms = total_update_p99 / 1000
    total_update_min_ms = total_update_min / 1000
    total_update_max_ms = total_update_max / 1000

    # Convert update failed times to milliseconds
    total_update_failed_avg_ms = total_update_failed_avg / 1000
    total_update_failed_p95_ms = total_update_failed_p95 / 1000
    total_update_failed_p99_ms = total_update_failed_p99 / 1000
    total_update_failed_min_ms = total_update_failed_min / 1000
    total_update_failed_max_ms = total_update_failed_max / 1000

    # Convert write times to milliseconds
    total_write_avg_ms = total_write_avg / 1000
    total_write_p95_ms = total_write_p95 / 1000
    total_write_p99_ms = total_write_p99 / 1000
    total_write_min_ms = total_write_min / 1000
    total_write_max_ms = total_write_max / 1000

    # Convert write failed times to milliseconds
    total_write_failed_avg_ms = total_write_failed_avg / 1000
    total_write_failed_p95_ms = total_write_failed_p95 / 1000
    total_write_failed_p99_ms = total_write_failed_p99 / 1000
    total_write_failed_min_ms = total_write_failed_min / 1000
    total_write_failed_max_ms = total_write_failed_max / 1000

    # Convert scan times to milliseconds
    total_scan_avg_ms = total_scan_avg / 1000
    total_scan_p95_ms = total_scan_p95 / 1000
    total_scan_p99_ms = total_scan_p99 / 1000
    total_scan_min_ms = total_scan_min / 1000
    total_scan_max_ms = total_scan_max / 1000

    # Convert scan failed times to milliseconds
    total_scan_failed_avg_ms = total_scan_failed_avg / 1000
    total_scan_failed_p95_ms = total_scan_failed_p95 / 1000
    total_scan_failed_p99_ms = total_scan_failed_p99 / 1000
    total_scan_failed_min_ms = total_scan_failed_min / 1000
    total_scan_failed_max_ms = total_scan_failed_max / 1000

# create the csv writer
    output_csv = open("aggregation" + ".csv", 'w', newline='')
    writer = csv.writer(output_csv)
    header = ['Operation', 'Count', 'Throughput', 'Min(millisecond)', 'Max(millisecond)', 'Avg(millisecond)',
              'P95(millisecond)', 'P99(millisecond)']
    writer.writerow(header)
    if total_read_count > 0:
        row_in_csv = ['READ', total_read_count, int(total_throughput), total_read_min_ms, total_read_max_ms,
                      int(total_read_avg_ms), int(total_read_p95_ms),
                      int(total_read_p99_ms)]
        writer.writerow(row_in_csv)
    if total_read_failed_count > 0:
        row_in_csv = ['READ-FAILED', total_read_failed_count, int(total_throughput), total_read_failed_min_ms,
                      total_read_failed_max_ms,
                      int(total_read_failed_avg_ms),
                      int(total_read_failed_p95_ms), int(total_read_failed_p99_ms)]
        writer.writerow(row_in_csv)
    if total_update_count > 0:
        row_in_csv = ['UPDATE', total_update_count, int(total_throughput), total_update_min_ms, total_update_max_ms,
                      int(total_update_avg_ms), int(total_update_p95_ms),
                      int(total_update_p99_ms)]
        writer.writerow(row_in_csv)
    if total_update_failed_count > 0:
        row_in_csv = ['UPDATE-FAILED', total_update_failed_count, int(total_throughput), total_update_failed_min_ms,
                      total_update_failed_max_ms, int(total_update_failed_avg_ms),
                      int(total_update_failed_p95_ms), int(total_update_failed_p99_ms)]
        writer.writerow(row_in_csv)
    if total_write_count > 0:
        row_in_csv = ['WRITE', total_write_count, int(total_throughput), total_write_min_ms, total_write_max_ms,
                      int(total_write_avg_ms), int(total_write_p95_ms),
                      int(total_write_p99_ms)]
        writer.writerow(row_in_csv)
    if total_write_failed_count > 0:
        row_in_csv = ['WRITE-FAILED', total_write_failed_count, int(total_throughput), total_write_failed_min_ms,
                      total_write_failed_max_ms, int(total_write_failed_avg_ms),
                      int(total_write_failed_p95_ms), int(total_write_failed_p99_ms)]
        writer.writerow(row_in_csv)
    if total_scan_count > 0:
        row_in_csv = ['SCAN', total_scan_count, int(total_throughput), total_scan_min_ms, total_scan_max_ms,
                      int(total_scan_avg_ms), int(total_scan_p95_ms),
                      int(total_scan_p99_ms)]
        writer.writerow(row_in_csv)
    if total_scan_failed_count > 0:
        row_in_csv = ['SCAN-FAILED', total_scan_failed_count, int(total_throughput), total_scan_failed_min_ms,
                      total_scan_failed_max_ms, int(total_scan_failed_avg_ms),
                      int(total_scan_failed_p95_ms), int(total_scan_failed_p99_ms)]
        writer.writerow(row_in_csv)

    output_csv.close()
    print("Successfully created " + output_csv.name)


if __name__ == '__main__':
    main()