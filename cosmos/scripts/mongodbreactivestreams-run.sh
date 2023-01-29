#!/bin/bash

# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

if [ -z "$workload_type" ]; then
    workload=workloada
else
    workload=$workload_type
fi

if [ -z "$ycsb_operation" ]; then
    operation=load
else
    operation=$ycsb_operation
fi

# Updating workload file
if [ ! -z "$recordcount" ]; then
   sed -i "s/^[#]*\s*recordcount=.*/recordcount=$recordcount/" workloads/$workload
fi

if [ ! -z "$operationcount" ]; then
   sed -i "s/^[#]*\s*operationcount=.*/operationcount=$operationcount/" workloads/$workload
fi

if [ ! -z "$insertstart" ]; then
   sed -i "$ ainsertstart=$insertstart" workloads/$workload
fi

if [ ! -z "$insertcount" ]; then
   sed -i "$ ainsertcount=$insertcount" workloads/$workload
fi

if [ ! -z "$insertorder" ]; then
   sed -i "$ ainsertorder=$insertorder" workloads/$workload
fi

if [ ! -z "$fieldcount" ]; then
   sed -i "$ afieldcount=$fieldcount" workloads/$workload
fi

if [ ! -z "$core_workload_insertion_retry_limit" ]; then
   sed -i "$ acore_workload_insertion_retry_limit=$core_workload_insertion_retry_limit" workloads/$workload
fi

if [ ! -z "$readproportion" ]; then
   sed -i "s/^[#]*\s*readproportion=.*/readproportion=$readproportion/" workloads/$workload
fi

if [ ! -z "$updateproportion" ]; then
   sed -i "s/^[#]*\s*updateproportion=.*/updateproportion=$updateproportion/" workloads/$workload
fi

if [ ! -z "$scanproportion" ]; then
   sed -i "s/^[#]*\s*scanproportion=.*/scanproportion=$scanproportion/" workloads/$workload
fi

if [ ! -z "$insertproportion" ]; then
   sed -i "s/^[#]*\s*insertproportion=.*/insertproportion=$insertproportion/" workloads/$workload
fi

if [ ! -z "$requestdistribution" ]; then
   sed -i "s/^[#]*\s*requestdistribution=.*/requestdistribution=$requestdistribution/" workloads/$workload
fi


# REQUIRED URI
if [ ! -z "$uri" ]; then
   sed -i "s|^[#]*\s*mongodbreactivestreams.uri\ =.*|mongodbreactivestreams.uri\ =\ $uri|" mongodbreactivestreams.properties
fi


log_filename="/tmp/ycsb.log"

if [ ! -z "$threads" ] && [ ! -z "$target" ]
then
  ./bin/ycsb.sh $operation mongodbreactivestreams -P workloads/$workload -P mongodbreactivestreams.properties -s -threads $threads -target $target 2>&1 | tee -a "$log_filename"
elif [ ! -z "$threads" ]
then
  ./bin/ycsb.sh $operation mongodbreactivestreams -P workloads/$workload -P mongodbreactivestreams.properties -s -threads $threads 2>&1 | tee -a "$log_filename"
elif [ ! -z "$target" ]
then
  ./bin/ycsb.sh $operation mongodbreactivestreams -P workloads/$workload -P mongodbreactivestreams.properties -s -target $target 2>&1 | tee -a "$log_filename"
else
  ./bin/ycsb.sh $operation mongodbreactivestreams -P workloads/$workload -P mongodbreactivestreams.properties -s 2>&1 | tee -a "$log_filename"
fi
