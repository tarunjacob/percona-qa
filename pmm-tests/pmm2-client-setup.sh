#!/bin/bash

function jsonval {
    temp=`echo $json | sed 's/\\\\\//\//g' | sed 's/[{}]//g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' | sed 's/\"\:\"/\|/g' | sed 's/[\,]/ /g' | sed 's/\"//g' | grep -w $prop`
    echo ${temp##*|}
}

version=$1
server_url=$2
mysql_user=$3
mysql_password=$4

rm -rf ~/$version/
mkdir ~/$version/
export PATH=$PATH:~/$version/
cd ~/$version
wget "https://github.com/Percona-Lab/pmm-submodules/releases/download/v${version}/pmm-client.tgz"
tar zxvf pmm-client.tgz
chmod +x *

node_name=node$((1 + RANDOM % 100))
json=`curl -d '{"address": "'$server_url'", "custom_labels": {"custom_label": "for_node"}, "node_name": "'$node_name'"}' http://${server_url}/v1/inventory/Nodes/AddGeneric`
prop='node_id'
node_id=`jsonval`

json=`curl -d '{"custom_labels": {"custom_label2": "for_pmm-agent"}, "node_id": "'$node_id'"}' http://${server_url}/v1/inventory/Agents/AddPMMAgent`
prop='agent_id'
agent_id=`jsonval`
echo $agent_id
echo $node_id

./pmm-agent --address=127.0.0.1:443 --insecure-tls --id=$agent_id & > /dev/null

sleep 10

service_name=mysql-$((1 + RANDOM % 100))
json=`curl -d '{"address": "'$server_url'", "port": 3306, "custom_labels": {"custom_label3": "for_service"}, "node_id": "'$node_id'", "service_name": "'$service_name'"}' \
 http://${server_url}/v1/inventory/Services/AddMySQL`
prop='service_id'
service_id=`jsonval`
echo $service_id

json=`curl -d '{"custom_labels": {"custom_label4": "for_exporter"}, "runs_on_node_id": "'$node_id'", "service_id": "'$service_id'", "username": "root", "'$mysql_user'": "'$mysql_password'"}' \
http://${server_url}/v1/inventory/Agents/AddMySQLdExporter`
prop='runs_on_node_id'
runs_on_node_id=`jsonval`
echo $runs_on_node_id