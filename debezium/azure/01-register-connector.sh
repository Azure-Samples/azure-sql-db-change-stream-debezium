#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

RESOURCE_GROUP="dbzrg"
CONTAINER_NAME="dbzcontainer"

echo "finding debezium ip"
DEBEZIUM_IP=`az container show --resource-group $RESOURCE_GROUP --name $CONTAINER_NAME --output tsv --query "ipAddress.ip"`

echo "registering connector"
curl -i -X POST \
    -H "Accept:application/json" -H  "Content-Type:application/json" \
    http://${DEBEZIUM_IP}:8083/connectors/ \
    -d @../sqlserver-connector-config.json
