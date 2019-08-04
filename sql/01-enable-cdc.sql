USE [WideWorldImporters]
GO

/*
	Enable CDC on database (make sure SQL Server Agent is running!)
*/
EXEC sys.sp_cdc_enable_db
GO

/*
	Enable CDC on selected tables
*/
EXEC sys.sp_cdc_enable_table N'Sales', N'Orders', @role_name=null, @supports_net_changes=0
EXEC sys.sp_cdc_enable_table N'Warehouse', N'StockItems', @role_name=null, @supports_net_changes=0
GO

/*
	Verify the CDC has been enabled for the selected tables
*/
EXEC sys.sp_cdc_help_change_data_capture
GO