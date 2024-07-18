#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

RESOURCE_GROUP="dbzrg"
EVENTHUB_NAMESPACE="dbzeventhub"

echo "deleting debezium-created eventhubs"
ehs=("debezium_configs" "debezium_offsets" "debezium_statuses" "dbzschemahistory")
for e in "${ehs[@]}"; do
    echo "deleting $e..."
    az eventhubs eventhub delete \
        --resource-group $RESOURCE_GROUP \
        --namespace-name $EVENTHUB_NAMESPACE \
        --name $e
done

echo "done"
