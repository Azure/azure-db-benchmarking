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

install_powershell() {
  # Update the list of packages
  sudo apt-get update
  # Install pre-requisite packages.
  sudo apt-get install -y wget apt-transport-https software-properties-common
  # Download the Microsoft repository GPG keys
  wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb"
  # Register the Microsoft repository GPG keys
  sudo dpkg -i packages-microsoft-prod.deb
  # Delete the the Microsoft repository GPG keys file
  rm packages-microsoft-prod.deb
  # Update the list of packages after we added packages.microsoft.com
  sudo apt-get update
  # Install PowerShell
  sudo apt-get install -y powershell
  # Start PowerShell
  pwsh
}

if ! command -v pwsh &>/dev/null; then
  install_powershell
fi

if ! command -v ifconfig &> /dev/null; then
    sudo apt install net-tools
fi

echo "endpoint $endpoint"
echo "databaseid $databaseid"
echo "containerid $containerid"
echo "wait_for_fault_to_start_in_sec $wait_for_fault_to_start_in_sec"
echo "duration_of_fault_in_sec $duration_of_fault_in_sec"
echo "fault_region $fault_region"
echo "drop_probability $drop_probability"
echo "delay_in_ms $delay_in_ms"

sleep $wait_for_fault_to_start_in_sec

database_account_response=$(pwsh -Command ./GetDatabaseAccount.ps1 -Endpoint $endpoint -MasterKey $masterkey)
echo "database_account_response = $database_account_response"

if [ ! -z "$fault_region" ]; then
  account_locations=$(echo $database_account_response | jq '.readableLocations[] | .name, .databaseAccountEndpoint')
  while
    read -r name
    read -r endpoint_url
  do
    name="${name%\"}"
    name="${name#\"}"
    if [ "${name,,}" = "${fault_region,,}" ]; then
      endpoint=$endpoint_url
      break
    fi
  done <<<$account_locations
fi

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
addresses_response=$(pwsh -Command ./GetAddresses.ps1 -Endpoint $endpoint -MasterKey $masterkey -PartitionKeyIds "'$comma_separated_pkid'" -DatabaseID $databaseid -ContainerId $containerid)
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

# if drop probability is not mentioned then drop all packets
if [ -z "$drop_probability" ]; then
  drop_probability=1
fi

interfaces=()

for iface in $(ifconfig -a | grep -v "SLAVE" | awk '/^[a-z]/ {print $1}' | tr ':' '\n' | awk NF); do
  if [[ $iface != lo* ]]; then
    interfaces+=("$iface")
  fi
done

for element in "${interfaces[@]}"; do
  echo "this $element"
done

gateway_endpoint_host_port=($(fetch_host_port $endpoint))
sudo iptables -I OUTPUT -d ${gateway_endpoint_host_port[0]} -p tcp --dport ${gateway_endpoint_host_port[1]} -m statistic --mode random --probability $drop_probability -j DROP
# if drop probability is not mentioned then drop all packets
if [ $delay_in_ms -gt 0 ]; then
  for device in "${interfaces[@]}"; do
    echo "sudo tc qdisc add dev $device root handle 1: prio"
    echo "sudo tc qdisc add dev $device parent 1:1 handle 2: netem delay ${delay_in_ms}ms"
    echo "sudo tc filter add dev $device protocol ip parent 1:0 prio 1 u32 match ip dst ${gateway_endpoint_host_port[0]} match ip dport ${gateway_endpoint_host_port[1]} 0xffff flowid 2:1"
  done
fi

uniq_backend_url=($(for url in "${backend_url[@]}"; do echo "${url}"; done | sort -u))
for i in "${uniq_backend_url[@]}"; do
  result=($(fetch_host_port $i))
  sudo iptables -I OUTPUT -d ${result[0]} -p tcp --dport ${result[1]} -m statistic --mode random --probability $drop_probability -j DROP
  if [ $delay_in_ms -gt 0 ]; then
    for device in "${interfaces[@]}"; do
      echo "sudo tc qdisc add dev $device root handle 1: prio"
      echo "sudo tc qdisc add dev $device parent 1:1 handle 2: netem delay ${delay_in_ms}ms"
      echo "sudo tc filter add dev $device protocol ip parent 1:0 prio 1 u32 match ip dst ${result[0]} match ip dport  ${result[1]} 0xffff flowid 2:1"
    done
  fi
done

sudo iptables -L --line-numbers

sleep $duration_of_fault_in_sec

sudo iptables -F OUTPUT
sudo iptables -L --line-numbers
