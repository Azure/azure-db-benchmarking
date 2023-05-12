#!/bin/bash
generatedfile=benchmarking-deployment-generated.yaml
propfile="recipe-env-file.properties"

rm -f /p/a/t/h $generatedfile

function prop {
    grep "${1}" ${propfile} | cut -d'=' -f2
}

podcount=$(prop 'POD_COUNT')
memorylimit=$(prop 'MEMORY_LIMIT')
cpulimit=$(prop 'CPU_LIMIT')
value=`cat ../benchmarking-deployment-template.yaml`

for (( i=1; i <= $podcount; i++ ))
do
    echo "$value" | sed -e "s/<podcount>/$podcount/;s/<podindex>/$i/;s/<podname>/client$i/;s/<deploymentname>/benchmarking-$i-$podcount/;s/<memorylimit>/$memorylimit/;s/<cpulimit>/$cpulimit/"  >> $generatedfile
    if [ $podcount -gt 1 ] && [ $i -lt $podcount ]
    then
        echo "---" >> $generatedfile
    fi
done
