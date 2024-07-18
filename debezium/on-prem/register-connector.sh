#!/bin/sh

RESOURCE_GROUP="dbzrg"
EVENTHUB_NAMESPACE="dbzeventhub"

echo "generating Debezium SQL Server connector configuration JSON file"
EH_CONNECTION_STRING=`az eventhubs namespace authorization-rule keys list --resource-group $RESOURCE_GROUP --name RootManageSharedAccessKey --namespace-name $EVENTHUB_NAMESPACE --output tsv --query 'primaryConnectionString'`
cat > ../sqlserver-connector-config.json << EOF
{
  "name": "wwi",
  "config": {
    "snapshot.mode": "schema_only",
    "connector.class": "io.debezium.connector.sqlserver.SqlServerConnector",
    "database.hostname": "dmmssqlsrv.database.windows.net",
    "database.port": "1433",
    "database.user": "debezium-wwi",
    "database.password": "Abcd1234!",
    "database.names": "WideWorldImportersStandardCDC",
    "driver.encrypt": "false",
    "driver.trustServerCertificate": "true",
    "schema.history.internal.kafka.bootstrap.servers": "${EVENTHUB_NAMESPACE}.servicebus.windows.net:9093",
    "schema.history.internal.kafka.topic": "dbzschemahistory",
    "schema.history.internal.consumer.security.protocol": "SASL_SSL",
    "schema.history.internal.consumer.sasl.mechanism": "PLAIN",
    "schema.history.internal.consumer.sasl.jaas.config": "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"\$ConnectionString\" password=\"${EH_CONNECTION_STRING}\";",
    "schema.history.internal.producer.security.protocol": "SASL_SSL",
    "schema.history.internal.producer.sasl.mechanism": "PLAIN",
    "schema.history.internal.producer.sasl.jaas.config": "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"\$ConnectionString\" password=\"${EH_CONNECTION_STRING}\";",
    "table.include.list": "Sales.Orders,Warehouse.StockItems",
    "tombstones.on.delete": false,
    "topic.prefix": "SQLAzure",
    "transforms": "Reroute",
    "transforms.Reroute.type": "io.debezium.transforms.ByLogicalTableRouter",
    "transforms.Reroute.topic.regex": "(.*)",
    "transforms.Reroute.topic.replacement": "wwi"
  }
}
EOF
echo "done"

curl -i -X POST \
    -H "Accept:application/json" \
    -H "Content-Type:application/json" \
    http://localhost:8083/connectors/ \
    -d @../sqlserver-connector-config.json \
    -w "\n"
