#!/bin/bash

# Script to configure the kafka cluster after the deployment has finished
# Check if openstack API are available
function zookeeper_config {
  local id=$1
  shift
  local zookeeper_ips=($@)
  echo clientPort=2181
  echo dataDir=/tmp/zookeeper
  echo initLimit=5
  echo syncLimit=2
  for i in ${!zookeeper_ips[@]}; do
    echo server.$((i+1))=${zookeeper_ips[$i]}:2888:3888
  done
}

function kafka_config {
  local id=$1
  shift
  local zookeeper_ips=$@

  echo broker.id=$id
  echo port=9092
  echo listeners=PLAINTEXT://:9092
  echo -n "zookeeper.connect="
  for zoo_ip in ${zookeeper_ips[@]}; do
    echo -n "$zoo_ip:2181,"
  done
  echo ""
}

function hosts_update {
  local hosts_ips=$@
  local id=0
  for ip in ${hosts_ips[@]}; do
    echo "$ip kafka-$id.novalocal kafka-$id"
    id=$((id+1))
  done
}
PREFIX="\033[1m> kafka cluster > \033[0m"

heat stack-list 1> /dev/null
if [ $? -ne 0 ]; then
  echo "Heat API is not available. Are the credentials in the env? OS_{USERNAME, PASSWORD, TENANT_ID, AUTH_URL}?"
  exit -1
fi
STACK_NAME=${1:?"Name of the kafka stack to configure"}
echo -e "$PREFIX Configure cluster $STACK_NAME"
KAFKA_LIST_FLOATING=`heat output-show $STACK_NAME kafka_list_floating | python -c "import sys,json ;data=json.load(sys.stdin);print ' '.join(data)"`
KAFKA_LIST_FLOATING=($KAFKA_LIST_FLOATING)
KAFKA_LIST=`heat output-show $STACK_NAME kafka_list | python -c "import sys,json ;data=json.load(sys.stdin);print ' '.join(data)"`
KAFKA_LIST=($KAFKA_LIST)
echo -e "$PREFIX Kafka servers list: ${KAFKA_LIST[@]}"

ZOOKEEPER_LIST_FLOATING=`heat output-show $STACK_NAME zookeeper_list_floating | python -c "import sys,json ;data=json.load(sys.stdin);print ' '.join(data)"| xargs -n1`
ZOOKEEPER_LIST_FLOATING=($ZOOKEEPER_LIST_FLOATING)
ZOOKEEPER_LIST=`heat output-show $STACK_NAME zookeeper_list | python -c "import sys,json ;data=json.load(sys.stdin);print ' '.join(data)"| xargs -n1`
ZOOKEEPER_LIST=($ZOOKEEPER_LIST)
echo -e "$PREFIX Zookeeper servers list: ${ZOOKEEPER_LIST[@]}"

for i in ${!KAFKA_LIST[@]}; do
  echo -e "$PREFIX Generate kafka config file: $i.server.properties"
  kafka_config $i ${ZOOKEEPER_LIST[@]} > $i.server.properties
done

echo -e "$PREFIX Generate kafka config file: zookeeper.properties"
zookeeper_config $i ${ZOOKEEPER_LIST[@]} > zookeeper.properties

# TODO: Assume that 
echo -e "$PREFIX Generate update hosts file: /etc/hosts"
hosts_update ${KAFKA_LIST[@]} > hosts


#####################################################################
for i in ${!KAFKA_LIST_FLOATING[@]}; do
  kip=${KAFKA_LIST_FLOATING[$i]}
  echo fab -u ubuntu -H $kip kafka_conf:filename=$i.server.properties enable_kafka update_supervisor restart_service:svc_name="kafka"
  fab -u ubuntu -H $kip kafka_conf:filename=$i.server.properties enable_kafka update_supervisor restart_service:svc_name="kafka"
done

for i in ${!ZOOKEEPER_LIST_FLOATING[@]}; do
  kip=${ZOOKEEPER_LIST_FLOATING[$i]}
  echo fab -u ubuntu -H $kip update_hosts:hosts_file=hosts zookeeper_conf:identifier=$((i+1)),filename=zookeeper.properties enable_zookeeper update_supervisor restart_service:svc_name="zookeeper"
  fab -u ubuntu -H $kip update_hosts:hosts_file=hosts zookeeper_conf:identifier=$((i+1)),filename=zookeeper.properties enable_zookeeper update_supervisor restart_service:svc_name="zookeeper"
done
