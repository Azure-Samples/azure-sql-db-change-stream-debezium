# SQL Server Change Stream with Debezium

SQL Server Change Stream sample using [Debezium](https://debezium.io/). A change feed or change stream allow applications to access real-time data changes, using standard technologies and well-known API, to create modern applications using the full power of database like SQL Server.

Debezium make use of [Change Data Capture](https://docs.microsoft.com/en-us/sql/relational-databases/track-changes/about-change-data-capture-sql-server?view=sql-server-2017), so it can be used with On-Premises SQL Servers, SQL Servers running on VMs in any cloud, and [Azure SQL MI](https://docs.microsoft.com/en-us/azure/sql-database/sql-database-managed-instance-index).

With Debezium and SQL Server you can not only create more modern and reactive applications that handles data changes in near real time with a minium impact on the database, but you can also use it to implement your Hybrid IT strategy, still using On-Prem SQL Server but relying on Azure for all your computing needs, taking advantage of PaaS offerings like EventHubs and Azure Functions. This sample will show how to do that.

![SQL Server Change Stream](./documentation/sql-server-change-stream.gif)

## Step by Step Guide

This step by step guide uses Wide World Importers sample database from here:

https://github.com/Microsoft/sql-server-samples/releases/tag/wide-world-importers-v1.0

Make sure you download the OLTP database if you want to follow this guide without having to change a thing.

### Create Debezium User

Debezium needs to query the database so a dedicated user is used throught the sample. User has db_owner acces to make the script simpler. In real world you may want to tighten security a bit more.

To create the login and user run the script `/sql/00-setup-database-user.sql` on the server where you have restored Wide World Importers database.

### Enable Change Data Capture

Debezium uses Change Data Capture to capture all the changes done to selected tables.

In this samples only two tables are monitored:

- Sales.Orders
- Warehouse.StockItems

The script `/sql/01-enable-cdc.sql` enable Change Data Capture on the aforementioned tables.

### Create an Azure Event Hubs

All data gathered by Change Tracking will be send to Event Hubs, so create an Azure Event Hubs in your Azure Subscription. Using the [Azure Cloud Shell](https://shell.azure.com/) Bash:

```bash
# create group
az group create -n debezium -l eastus

# create eventhuvbs with kafka enabled
az eventhubs namespace create -n debezium -g debezium -l eastus --enable-kafka
```

Later in the configuration process you'll need the EventHubs connection string, so grab it and store it somewhere:

```bash
az eventhubs namespace authorization-rule keys list -g debezium --namespace-name debezium -n RootManageSharedAccessKey --query "primaryConnectionString" -o tsv
 ```

### Run Debezium

#### Pre-Requisites

In order to run Debezium you have to install and configure Apache Kafka, Apache Zookeper and Kafka Connect. If you already know how to do that, or your already have a testing or development environment, well, perfect. Go and install Debezium SQL Server Connector: [Installing a Debezium Connector](https://debezium.io/docs/install/stable/#installing_a_debezium_connector).

If prefer a more lean and quick easy to start using Debezium, you can just use the [Debezium Docker Image](https://github.com/debezium/docker-images), that provide anything you need to run a test instance of Debezium.
Event simpler than that, just make sure you have [Docker](https://docs.docker.com/install/) and [Docker Compose](https://docs.docker.com/compose) installed.

#### Configure Environment

Docker Compose will use `.env` to get the enviroment variables values used in the `.yaml` configuration file. The provided `.env.template` file look like the followin:

```bash
DEBEZIUM_VERSION=0.10
EH_NAME=debezium
EH_CONNECTION_STRING=
```

Copy it and create a new `.env` file. Leave the version set to 0.10. Change the `EH_NAME` to the EventHubs name you created before. Also set `EH_CONNECTION_STRING` to hold the EventHubs connection string you got before. Make sure not to use any additional quotes or double quotes.

#### The .yaml file

If you are just interested in testing Debezium you can safely skip this section and move to the next one to start Debezium. If you want to understand how to make Debzium work with Evenhubs, read on.

Debezium needs Apache Kafka to run, NOT EventHubs. Luckly for us, EventHubs exposes a Kafka-Compatible endpoint, so we can still enjoy Kafka with all the comfort of a PaaS offering. There are a few tweeks needed in order to make Debezium working with EventHubs.

First of all EventHubs requires authentication. This part is taken care from the configuration settings that looks like the followin:

```yaml
- *_SECURITY_PROTOCOL=SASL_SSL
- *_SASL_MECHANISM=PLAIN
- *_SASL_JAAS_CONFIG=[...]
```

Documentation on EventHubs Kafka Authentication and Kafka Connect is available here:

[Integrate Apache Kafka Connect support on Azure Event Hubs](https://docs.microsoft.com/en-us/azure/event-hubs/event-hubs-kafka-connect-tutorial)

Since we're running a Docker Image, we cannot really change the configuration file, but Debezium allows pass-through configurations:

[Debezium Connect-Base](https://github.com/debezium/docker-images/tree/master/connect-base/0.10#others)

There is additional caveat to keep in mind. EventHubs security uses the string `$ConnectionString` as username. In order to avoid to have Docker Compose to treat it as a variable instead, a double dollar sign `$$` needs to be used:

[Docker Compose Config File Variable Substitution](https://docs.docker.com/compose/compose-file/#variable-substitution)

Two other options useful for running Debezium on EventHubs are the following:

```yaml
- CONNECT_KEY_CONVERTER_SCHEMAS_ENABLE=false
- CONNECT_VALUE_CONVERTER_SCHEMAS_ENABLE=true
```

They control if the schema is sent with the data or not. Since the EventHub only support values, as opposed to Apache Kafka, which everything is actually a key-value pair, the schema generation for the key section can be safely turned off. While this can also be done for the value part, it is not recommended as some data type are serialized in a Kafka-Way and you need to know their "sematic" type in order to recreate the correct value.

[Debezium SQL Server Connector Data Types](https://debezium.io/docs/connectors/sqlserver/#data-types)

Here's a sample of a schema for a "create" (INSERT) event:

[Debezium SQL Server Connector Create Event Sample](https://debezium.io/docs/connectors/sqlserver/#create-events)

#### Start Debezium

Debezium can now be started. If you're using the Docker Images you can just do this by running `debezium/start-debezium.ps1` (or the `.sh` file if you're on Linux/WSL)

Once the startup has finished, you'll see something like

```text
[Worker clientId=connect-1, groupId=1] Finished starting connectors and tasks   [org.apache.kafka.connect.runtime.distributed.DistributedHerder]
```

you will see three topics (or eventhub to use the Azure EventHubs nomenclature):

```bash
az eventhubs eventhub list -g debezium --namespace debezium -o table
```

and the result will show:

- debezium_configs
- debezium_offsets
- debezium_statuses

to explore EventHubs is strongly suggest to download and use [Service Bus Explorer](https://github.com/paolosalvatori/ServiceBusExplorer)

#### Register SQL Server Connector

Now that Debezium is running, the SQL Server Connector can be registered. Before doing that, make sure to specify the correct connection for your SQL Server instance in the `debezium/register-sqlserver-eh.json` file.

If you are using the Wide World Importer database, the only values you have to change are:

```json
"database.hostname" : "192.168.0.80",
"database.port" : "1433",
```

If you are followin the step-by-step guide using a database of yours, make sure to also correctly set values for

```json
"database.user" : "debezium-wwi",
"database.password" : "debezium-WWI-P@ssw0rd!",
"database.dbname" : "WideWorldImporters",
```

All the other values used are explained in detail here:

[SQL Server Connector Configuration Values](./documentation/SQL-Server-Connector-Configuration-Value..md)

Once the configuration file is set, just register that using `debezium/register-connector.ps1`.

Depending on how big your tables are, it make take a while (more on this later). Once you see the following message:

```text
Snapshot step 8 - Finalizing   [io.debezium.relational.HistorizedRelationalSnapshotChangeEventSource]
```

and no other errors or exception before that, you'll know that the SQL Server Connector is correctly running.

### Make sample changes

Now that Debezium is running and fully configured, you can generate a new Sales Order and insert, update and delete some data in the Stock table. You can use the following scripts:

```bash
./sql/02-create-new-sales-order.sql
./sql/03-modify-warehouse-stock.sql
```

After running the script you can use Service Bus Explorer or VS Code Event Hub Explorer to consume the stream of changes sent to EventHubs. You'll notice a new topic named `wwi`. That's where we instructed Debezium to send all the changes detected to the monitored tables.

### Consume Change Stream using an Azure Functions

One way to quickly react to the Change Stream data coming from Debezium is to use Azure Functions. A sample is available in folder `azure-function`. The easiest way to run the sample is to open it from VS Code. It will automatically recognize it as an Azure Function and download everything needed to run it.

Make sure you have a `local.setting.json` that looks like the provided template. Copy the EventHubs connection string you got at the beginning into the `Debezium` configuration option.

Start the function. As soon as the Azure Function runtime is running, the code will start to process the changes already available in EventHubs and you'll see something like this:

```text
Event from Change Feed received:
- Object: Sales.Orders
- Operation: Insert
- Captured At: 2019-08-04T22:35:59.0100000Z
> OrderID = 73625
> CustomerID = 941
> SalespersonPersonID = 3
> PickedByPersonID =
> ContactPersonID = 3141
> BackorderOrderID =
> OrderDate = 8/4/2019 12:00:00 AM
> ExpectedDeliveryDate = 8/5/2019 12:00:00 AM
> CustomerPurchaseOrderNumber = 4923
> IsUndersupplyBackordered = False
> Comments = Auto-generated
> DeliveryInstructions = Unit 17, 1466 Deilami Road
> InternalComments =
> PickingCompletedWhen =
> LastEditedBy = 3
> LastEditedWhen = 8/4/2019 10:35:58 PM
Executed 'ProcessDebeziumPayload' (Succeeded, Id=ee9d1080-64ff-4039-83af-69c4b12fa85f)
```

### Done

Congratulations, you now have a working Change Stream from SQL Server. This opens up a whole new set of possibilities! Have fun!
