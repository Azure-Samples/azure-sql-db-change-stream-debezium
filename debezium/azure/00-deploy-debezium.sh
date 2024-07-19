#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

DEBEZIUM_VERSION=2.7
RESOURCE_GROUP="debezium"
EVENTHUB_NAMESPACE="debezium"
EVENTHUB_SCHEMA_HISTORY="schemahistory"
CONTAINER_NAME="debezium"
LOCATION="WestUS2"

echo "deploying resource group"
az group create \
	--name $RESOURCE_GROUP \
	--location $LOCATION

echo "deploying eventhubs namespace"
az eventhubs namespace create \
	--resource-group $RESOURCE_GROUP \
	--location $LOCATION \
	--name $EVENTHUB_NAMESPACE \
	--enable-kafka=true

echo "deploying schema history event hub"
az eventhubs eventhub create \
    --resource-group $RESOURCE_GROUP \
    --namespace-name $EVENTHUB_NAMESPACE \
    --name $EVENTHUB_SCHEMA_HISTORY \
    --partition-count 1 \
    --cleanup-policy Delete \
    --retention-time-in-hours 168 \
    --output none

echo "gathering eventhubs connection string"
EVENTHUB_CONNECTION_STRING=`az eventhubs namespace authorization-rule keys list --resource-group $RESOURCE_GROUP --name RootManageSharedAccessKey --namespace-name $EVENTHUB_NAMESPACE --output tsv --query 'primaryConnectionString'`

echo "deploying debezium container"
az container create \
	--resource-group $RESOURCE_GROUP \
	--location $LOCATION \
	--name $CONTAINER_NAME \
	--image debezium/connect:${DEBEZIUM_VERSION} \
	--ports 8083 \
	--ip-address Public \
	--os-type Linux \
	--cpu 2 \
	--memory 4 \
	--environment-variables \
		BOOTSTRAP_SERVERS=${EVENTHUB_NAMESPACE}.servicebus.windows.net:9093 \
		GROUP_ID=1 \
		CONFIG_STORAGE_TOPIC=debezium_configs \
		OFFSET_STORAGE_TOPIC=debezium_offsets \
		STATUS_STORAGE_TOPIC=debezium_statuses \
		CONNECT_KEY_CONVERTER_SCHEMAS_ENABLE=false \
		CONNECT_VALUE_CONVERTER_SCHEMAS_ENABLE=true \
		CONNECT_REQUEST_TIMEOUT_MS=60000 \
		CONNECT_SECURITY_PROTOCOL=SASL_SSL \
		CONNECT_SASL_MECHANISM=PLAIN \
		CONNECT_SASL_JAAS_CONFIG="org.apache.kafka.common.security.plain.PlainLoginModule required username=\"\$ConnectionString\" password=\"${EVENTHUB_CONNECTION_STRING}\";" \
		CONNECT_PRODUCER_SECURITY_PROTOCOL=SASL_SSL \
		CONNECT_PRODUCER_SASL_MECHANISM=PLAIN \
		CONNECT_PRODUCER_SASL_JAAS_CONFIG="org.apache.kafka.common.security.plain.PlainLoginModule required username=\"\$ConnectionString\" password=\"${EVENTHUB_CONNECTION_STRING}\";" \
		CONNECT_CONSUMER_SECURITY_PROTOCOL=SASL_SSL \
		CONNECT_CONSUMER_SASL_MECHANISM=PLAIN \
		CONNECT_CONSUMER_SASL_JAAS_CONFIG="org.apache.kafka.common.security.plain.PlainLoginModule required username=\"\$ConnectionString\" password=\"${EVENTHUB_CONNECTION_STRING}\";"
 
echo "eventhub connection string"
echo $EVENTHUB_CONNECTION_STRING