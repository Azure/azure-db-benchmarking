import csv
import os
import sys


def main():
    if len(sys.argv) == 1:
        raise Exception("Input log file name not provided. Syntax = 'python converting_log_to_csv.py <FileLocation>'")
    path = sys.argv[1]
    input_file = open(path, 'r')
    lines = input_file.readlines()
    filename = os.path.basename(path)
    filename_withoutextention = os.path.splitext(filename)[0]

    # create the csv writer
    output_csv = open(filename_withoutextention + ".csv", 'w', newline='')
    writer = csv.writer(output_csv)
    header = ['Date', 'Time', 'Operation', 'RPS', 'Count', 'MAX(microsecond)', 'MIN(microsecond)', 'AVG(microsecond)',
              'P90(microsecond)', 'P99(microsecond)', 'P999(microsecond)', 'P9999(microsecond)']
    writer.writerow(header)

    # Strips the newline character
    for line in lines:
        line = line.strip()
        if not "current ops/sec" in line:
            continue
        array_after_split = line.strip().split('[')

        for i in range(len(array_after_split)):
            if i == len(array_after_split) - 1:
                break
            else:
                newline = array_after_split[0] + array_after_split[i + 1]
                parse_line_for_formatting(newline, writer)
    output_csv.close()
    print("Successfully created "+output_csv.name)


def parse_line_for_formatting(line, writer):
    # 2022-04-13 16:16:13:684 10 sec: 15743 operations; 1574.14 current ops/sec; est completion in 52 minutes READ:
    # Count=14959, Max=613887, Min=1110, Avg=12876.19, 90=25807, 99=78143, 99.9=493311, 99.99=609279]
    split_semicolon = line.split(';')

    # '2022-04-13 16:16:13:684 10 sec: 15743 operations'
    first_part = split_semicolon[0]
    first_part_split = first_part.split(' ')
    date = first_part_split[0]
    time = first_part_split[1].rsplit(':', 1)[0]

    # 1574.14 current ops/sec
    second_part = split_semicolon[1].strip()
    rps = second_part.rsplit('current ops/sec', 1)[0]

    # est completion in 52 minutes READ: Count=14959, Max=613887, Min=1110, Avg=12876.19, 90=25807, 99=78143,
    # 99.9=493311, 99.99=609279]
    third_part = split_semicolon[2].strip()
    if 'CLEANUP' in third_part:
        return
    operation = ''
    count = ''
    max_in_micro_sec = ''
    min_in_micro_sec = ''
    avg_in_micro_sec = ''
    p9999_in_micro_sec = ''
    p999_in_micro_sec = ''
    p99_in_micro_sec = ''
    p90_in_micro_sec = ''
    for metrics in third_part.split(' '):
        metrics = metrics.strip()
        metrics = metrics.replace(']', '')
        metrics = metrics.replace(',', '')

        if ':' in metrics:
            operation = metrics.replace(':', '')
        elif 'Count=' in metrics:
            count = metrics.replace('Count=', '')
        elif 'Max=' in metrics:
            max_in_micro_sec = metrics.replace('Max=', '')
        elif 'Min=' in metrics:
            min_in_micro_sec = metrics.replace('Min=', '')
        elif 'Avg=' in metrics:
            avg_in_micro_sec = metrics.replace('Avg=', '')
        elif '99.99=' in metrics:
            p9999_in_micro_sec = metrics.replace('99.99=', '')
        elif '99.9=' in metrics:
            p999_in_micro_sec = metrics.replace('99.9=', '')
        elif '99=' in metrics:
            p99_in_micro_sec = metrics.replace('99=', '')
        elif '90=' in metrics:
            p90_in_micro_sec = metrics.replace('90=', '')

    row_in_csv = [date, time, operation, rps, count, max_in_micro_sec, min_in_micro_sec, avg_in_micro_sec,
                  p90_in_micro_sec, p99_in_micro_sec, p999_in_micro_sec, p9999_in_micro_sec]
    writer.writerow(row_in_csv)


if __name__ == '__main__':
    main()
