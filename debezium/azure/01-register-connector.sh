#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

echo "finding debezium ip"
export DEBEZIUM_IP=`az container show -g debezium -n debezium -o tsv --query "ipAddress.ip"`

echo "registering connector"
curl -i -X POST \
    -H "Accept:application/json" -H  "Content-Type:application/json" \
    http://${DEBEZIUM_IP}:8083/connectors/ \
    -d @../register-sqlserver-eh.json
