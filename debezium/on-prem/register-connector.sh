#!/bin/sh

curl -i -X POST \
    -H "Accept:application/json" \
    -H "Content-Type:application/json" \
    http://localhost:8083/connectors/ \
    -d @../sqlserver-connector-config.json \
    -w "\n"
