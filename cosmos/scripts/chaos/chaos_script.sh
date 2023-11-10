#!/bin/bash

if [ -z "$fault_region" ]; then
  echo "Error: fault_region parameter cannot be null. Please provide a value for this parameter."
  exit 1
fi

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
if [ "$1" == "-h" | "$1" == "--help" ]; then
  echo "Usage: ./chaos_script.sh [OPTIONS]"
  echo "Simulates network faults by dropping packets and adding latency."
  echo
  echo "Options:"
  echo "  --endpoint ENDPOINT               The endpoint to target."
  echo "  --databaseid DATABASEID           The ID of the database."
  echo "  --containerid CONTAINERID         The ID of the container."
  echo "  --wait_for_fault_to_start_in_sec  The time to wait before starting the fault, in seconds."
  echo "  --duration_of_fault_in_sec        The duration of the fault, in seconds."
  echo "  --fault_region FAULT_REGION       The region where the fault should occur."
  echo "  --drop_probability DROP_PROB      The probability of dropping a packet (0-1)."
  echo "  --delay_in_ms DELAY               The delay to add to packets, in milliseconds."
  echo "  --help                            Display this help message."
  echo
  echo "Example:"
  echo "  ./chaos_script.sh --endpoint http://example.com --databaseid mydatabase --containerid mycontainer --wait_for_fault_to_start_in_sec 10 --duration_of_fault_in_sec 60 --fault_region uswest --drop_probability 0.1 --delay_in_ms 100"
  exit 0
fi

if ! command -v pwsh &>/dev/null; then
  install_powershell
fi

if ! command -v ifconfig &>/dev/null; then
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
  drop_probability=0
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
if [ ${#interfaces[@]} -ne 0 ]; then
  for device in "${interfaces[@]}"; do
    echo "sudo tc qdisc add dev $device root handle 1: prio"
    echo "sudo tc qdisc add dev $device parent 1:1 handle 2: netem delay ${delay_in_ms}ms"
    sudo tc qdisc add dev $device root handle 1: prio
    sudo tc qdisc add dev $device parent 1:1 handle 2: netem delay ${delay_in_ms}ms
  done
fi

gateway_endpoint_host_port=($(fetch_host_port $endpoint))
if [ $(echo "$drop_probability > 0" | bc) -eq 1 ]; then
  sudo iptables -I OUTPUT -d ${gateway_endpoint_host_port[0]} -p tcp --dport ${gateway_endpoint_host_port[1]} -m statistic --mode random --probability $drop_probability -j DROP
fi
# if drop probability is not mentioned then drop all packets
if [ $delay_in_ms -gt 0 ]; then
  for device in "${interfaces[@]}"; do
    ip_address=$(getent hosts ${gateway_endpoint_host_port[0]} | awk '{ print $1 }')
    echo "sudo tc filter add dev $device protocol ip parent 1:0 prio 1 u32 match ip dst $ip_address match ip dport ${gateway_endpoint_host_port[1]} 0xffff flowid 2:1"
    sudo tc filter add dev $device protocol ip parent 1:0 prio 1 u32 match ip dst $ip_address match ip dport ${gateway_endpoint_host_port[1]} 0xffff flowid 2:1
  done
fi

uniq_backend_url=($(for url in "${backend_url[@]}"; do echo "${url}"; done | sort -u))
for i in "${uniq_backend_url[@]}"; do
  result=($(fetch_host_port $i))
  if [ $(echo "$drop_probability > 0" | bc) -eq 1 ]; then
    sudo iptables -I OUTPUT -d ${result[0]} -p tcp --dport ${result[1]} -m statistic --mode random --probability $drop_probability -j DROP
  fi

  if [ $delay_in_ms -gt 0 ]; then
    for device in "${interfaces[@]}"; do
      ip_address=$(getent hosts ${result[0]} | awk '{ print $1 }')
      echo "sudo tc filter add dev $device protocol ip parent 1:0 prio 1 u32 match ip dst $ip_address match ip dport  ${result[1]} 0xffff flowid 2:1"
      sudo tc filter add dev $device protocol ip parent 1:0 prio 1 u32 match ip dst $ip_address match ip dport ${result[1]} 0xffff flowid 2:1
    done
  fi
done

sudo iptables -L --line-numbers

sleep $duration_of_fault_in_sec

sudo iptables -F OUTPUT
echo "Deleted all iptable rules"
sudo iptables -L --line-numbers

for device in "${interfaces[@]}"; do
  sudo tc qdisc del dev $device root
  echo "Deleted prio qdisc on $device"
done
