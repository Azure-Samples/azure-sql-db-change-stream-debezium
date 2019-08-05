# SQL Server Change Stream with Debezium

SQL Server Change Stream sample using [Debezium](https://debezium.io/)

## Step by Step Guide

This step by step guide uses Wide World Importers sample database from here:

https://github.com/Microsoft/sql-server-samples/releases/tag/wide-world-importers-v1.0

Make sure you download the OLTP database if you want to follow this guide without having to change a thing.

### Create Debezium User

Debezium needs to query the database so a dedicated user is used throught the sample. User has db_owner acces to make the script simpler. In real world you may want to tighten security a bit more.

To create the login and user run the script `/sql/00-setup-database-user.sql` on the server where you have restored Wide World Importers database.

### Enable Change Data Capture

Debezium uses [Change Data Capture](https://docs.microsoft.com/en-us/sql/relational-databases/track-changes/about-change-data-capture-sql-server?view=sql-server-2017) to capture all the changes done to selected tables.

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

#### Configuring Environment

Docker Compose will use `.env` to get the enviroment variables values used in the `.yaml` configuration file. The provided `.env` file look like the followin:

```bash
DEBEZIUM_VERSION=0.10
EH_NAME=debezium
EH_CONNECTION_STRING=
```

Leave the version set to 0.10. Change the `EH_NAME` to the EventHubs name you created before. Also set `EH_CONNECTION_STRING` to hold the EventHubs connection string you got before. Make sure not to use any additional quotes or double quotes.

#### Start Debezium

Debezium can now be started. If you're using the Docker Images you can just do this by running `debezium/start-debezium.ps1` (or the `.sh` file if you're on Linux/WSL)

