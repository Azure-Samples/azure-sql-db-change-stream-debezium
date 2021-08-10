# Debezium SQL Server Connector Configuration Notes

In order to properly work with Azure EventHubs and somehow big databases, the Debezium SQL Server Connector needs to be configured with some specific options. Here's the details:

## Snapshot Mode

```json
"snapshot.mode": "schema_only",
```

As also explained in the README in more detail, this option is needed to make sure data already present in the table, when Debezium is firstly activated, is not sent into the Change Stream. Debezium default behavior is to read all the existing data, send it to the Change Stream, and the start to monitor the table for changes:

[Debezium Snapshots](https://debezium.io/documentation/reference/1.6/connectors/sqlserver.html#sqlserver-snapshots)

For this sample we don't need to have all existing data into the Change Stream, as we only need the changes from now on. So the option is set to `initial_schema_only`.

## Decimal Handling

``` json
"decimal.handling.mode": "string",
```

By default decimal values are sent as Base64 encoded byte arrays. It is much easier to just have it as a string instead, especially if you plan to use .NET to handle the Change Stream.

## Whitelist Tables

```json
"table.include.list": "Sales.Orders,Warehouse.StockItems",
```

If you don't specify which tables should be monitored by Debezium, it will try to analyze *all* tables, not only those who have Change Data Capture enabled. To avoid errors and excessive locking, manually specify the tables you want Debezium to monitor.

## Topic Routing

```json
"transforms": "Reroute",
"transforms.Reroute.type": "io.debezium.transforms.ByLogicalTableRouter",
"transforms.Reroute.topic.regex": "(.*)",
"transforms.Reroute.topic.replacement": "wwi",
```

This configuration section is really useful especially with EventHubs. By default Debezium will create one Topic for each table. With Apache Kafka this is pretty standard, as you can use wildcards to data coming from different topics. EventHubs doesn't have that option, so having all the event routed to one well-known topic is more convenient. The configuration shown above will take data from *any* table (`transforms.Reroute.topic.regex`) and will send it to just one topic (`transforms.Reroute.topic.replacement`). As you can guess from the support of Regular Expression, you can do quite complex re-routings. More info here:

[Topic Routing](https://debezium.io/documentation/reference/1.6/configuration/topic-routing.html)

## Tombstones

```json
"tombstones.on.delete": false,
```

Apache Kafka uses tombstones, completely empty messages, to know when it can delete data during log compaction. (More info on this process here: [Apache Kafka Log Compaction](http://cloudurable.com/blog/kafka-architecture-log-compaction/index.html)). Azure Event Hubs doesn't support Log Compaction at the moment, so we don't need tombstones.

## Database History

```json
"database.history":"io.debezium.relational.history.MemoryDatabaseHistory"
```

This is a trick configuration that *should not* be used, but it is unfortunately needed due to limited compatibility support that Azure Event Hubs offers for Kafka API. GitHub Issue here for those interested in the details:

[Error "The broker does not support DESCRIBE_CONFIGS](https://github.com/Azure/azure-event-hubs-for-kafka/issues/61)

In brief what this is what happens: Debezium will try to create a new topic to store all DDL changes done to the database, in order to keep schema history. Unfortunately it won'y be able to do so, due to the aforementioned issus. The specified configuration tells Debezium to store the schema changes in memory, without using a Kafka Topic. This is tricky since if you do *a lot* of schema changes than it may happen that the machine running Debezium could go out of memory. But schema changes are usually not that common, so you should be pretty safe, until Azure Event Hubs is 100% Kafka compatible.
