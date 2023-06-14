#!/bin/bash

fetch_host_port() {
  url=$1
  # extract the host and port
  hostport=$(echo ${url} | cut -d/ -f3)
  # extract the port
  port=$(echo $hostport | sed -e 's,^.*:,:,g' -e 's,.*:\([0-9]*\).*,\1,g' -e 's,[^0-9],,g')
  # extract the port
  host=$(echo $hostport | sed -e 's,:.*,,g')
  local host_port_arr=($host $port)
  echo "${host_port_arr[@]}"
}

echo "endpoint $endpoint"
echo "databaseid $databaseid"
echo "containerid $containerid"
echo "wait_for_fault_to_start_in_sec $wait_for_fault_to_start_in_sec"
echo "duration_of_fault_in_sec $duration_of_fault_in_sec"

sleep $wait_for_fault_to_start_in_sec

database_account_response=$(pwsh -Command ./GetDatabaseAccount.ps1 -Endpoint $endpoint -MasterKey $masterkey)
echo "database_account_response = $database_account_response"

account_locations=$(echo $database_account_response | jq '.writableLocations[] | .name, .databaseAccountEndpoint')

pk_ranges_response=$(pwsh -Command ./GetPKRange.ps1 -Endpoint $endpoint -MasterKey $masterkey -DatabaseID $databaseid -ContainerId $containerid)
echo "pk_ranges_response = $pk_ranges_response"

partition_key_ranges=$(echo $pk_ranges_response | jq '.PartitionKeyRanges[] | .id')
comma_separated_pkid=""
while
  read -r id
do
  id="${id%\"}"
  id="${id#\"}"
  if [ -z "$comma_separated_pkid" ]; then
    comma_separated_pkid+=$id
  else
    comma_separated_pkid+=",$id"
  fi
done <<<$partition_key_ranges
addresses_response=$(pwsh -Command ./GetAddresses.ps1 -Endpoint $endpoint -MasterKey $masterkey -PartitionKeyIds "'$comma_separated_pkid'"  -DatabaseID $databaseid -ContainerId $containerid)
echo "addresses_response = $addresses_response"

backend_addresses=$(echo $addresses_response | jq '.Addresss[] | .physcialUri')
# creating list for backend address
backend_url=()

while
  read -r endpoint_url
do
  result=($(fetch_host_port $endpoint_url))
  backend_url+=(${result[0]}:${result[1]})
done <<<"$backend_addresses"

while
  read -r name
  read -r endpoint_url
do
  result=($(fetch_host_port $endpoint_url))
  sudo iptables -I OUTPUT -d ${result[0]} -p tcp --dport ${result[1]} -j DROP
done <<<"$account_locations"

uniq_backend_url=($(for url in "${backend_url[@]}"; do echo "${url}"; done | sort -u))
for i in "${uniq_backend_url[@]}"; do
  result=($(fetch_host_port $i))
  sudo iptables -I OUTPUT -d ${result[0]} -p tcp --dport ${result[1]} -j DROP
done

sudo iptables -L --line-numbers

sleep $duration_of_fault_in_sec

sudo iptables -F OUTPUT
sudo iptables -L --line-numbers
