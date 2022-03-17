#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

export DEBEZIUM_VERSION=1.8
export RESOURCE_GROUP="dm-debezium"
export EVENTHUB_NAME="dm-debezium"
export CONTAINER_NAME="dm-debezium"

echo "deploying resource group"
az group create -n $RESOURCE_GROUP -l WestUS2

echo "deploying eventhubs namespace"
az eventhubs namespace create -g $RESOURCE_GROUP -n $EVENTHUB_NAME --enable-kafka=true -l WestUS2

echo "gathering eventhubs info"
export EH_NAME=`az eventhubs namespace list -g $EVENTHUB_NAME --query '[].name' -o tsv`
export EH_CONNECTION_STRING=`az eventhubs namespace authorization-rule keys list -g $CONTAINER_NAME -n RootManageSharedAccessKey --namespace-name $EVENTHUB_NAME -o tsv --query 'primaryConnectionString'`

echo "deploying debezium container"
az container create -g $RESOURCE_GROUP -n $CONTAINER_NAME \
	--image debezium/connect:${DEBEZIUM_VERSION} \
	--ports 8083 --ip-address Public \
	--os-type Linux --cpu 2 --memory 4 \
	--environment-variables \
		BOOTSTRAP_SERVERS=${EH_NAME}.servicebus.windows.net:9093 \
		GROUP_ID=1 \
		CONFIG_STORAGE_TOPIC=debezium_configs \
		OFFSET_STORAGE_TOPIC=debezium_offsets \
		STATUS_STORAGE_TOPIC=debezium_statuses \
		CONNECT_KEY_CONVERTER_SCHEMAS_ENABLE=false \
		CONNECT_VALUE_CONVERTER_SCHEMAS_ENABLE=true \
		CONNECT_REQUEST_TIMEOUT_MS=60000 \
		CONNECT_SECURITY_PROTOCOL=SASL_SSL \
		CONNECT_SASL_MECHANISM=PLAIN \
		CONNECT_SASL_JAAS_CONFIG="org.apache.kafka.common.security.plain.PlainLoginModule required username=\"\$ConnectionString\" password=\"${EH_CONNECTION_STRING}\";" \
		CONNECT_PRODUCER_SECURITY_PROTOCOL=SASL_SSL \
		CONNECT_PRODUCER_SASL_MECHANISM=PLAIN \
		CONNECT_PRODUCER_SASL_JAAS_CONFIG="org.apache.kafka.common.security.plain.PlainLoginModule required username=\"\$ConnectionString\" password=\"${EH_CONNECTION_STRING}\";" \
		CONNECT_CONSUMER_SECURITY_PROTOCOL=SASL_SSL \
		CONNECT_CONSUMER_SASL_MECHANISM=PLAIN \
		CONNECT_CONSUMER_SASL_JAAS_CONFIG="org.apache.kafka.common.security.plain.PlainLoginModule required username=\"\$ConnectionString\" password=\"${EH_CONNECTION_STRING}\";"
 
echo "eventhub connection string"
echo $EH_CONNECTION_STRING