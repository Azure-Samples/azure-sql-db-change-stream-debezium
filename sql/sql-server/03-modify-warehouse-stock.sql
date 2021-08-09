USE WideWorldImporters
GO

/*
	Update some stock items
*/
WITH cte AS 
(
	SELECT TOP (1) * FROM [Warehouse].[StockItems] ORDER BY NEWID() DESC
)
UPDATE 
	cte 
SET 
	InternalComments = 'Just some random thoughts...',
	Barcode = '123ABC123'
GO

WAITFOR DELAY '00:00:05'
GO

WITH cte AS 
(
	SELECT TOP (1) * FROM [Warehouse].[StockItems] ORDER BY NEWID() DESC
)
UPDATE 
	cte 
SET
	MarketingComments = 'Some important marketing message.',
	Barcode = '456QAZ567'
GO

WAITFOR DELAY '00:00:05'
GO

/*
	Insert a new dummy stock item
*/

INSERT INTO [Warehouse].[StockItems] 
	([StockItemID], [StockItemName], [SupplierID], [ColorID], [UnitPackageID], [OuterPackageID], [Brand], [Size], [LeadTimeDays], [QuantityPerOuter], [IsChillerStock], [Barcode], [TaxRate], [UnitPrice], [RecommendedRetailPrice], [TypicalWeightPerUnit], [MarketingComments], [InternalComments], [Photo], [CustomFields], [LastEditedBy])
VALUES
	(999, 'Dummy Stock', 1, NULL, 1, 6, NULL, NULL, 1, 1, 0, NULL, 0.0, 0.0, 0.0, 0.0, NULL, NULL, NULL, '{}', 1)
GO

SELECT * FROM [Warehouse].[StockItems] WHERE StockItemID = 999
GO

WAITFOR DELAY '00:00:05'
GO

/*
	Delete the inserted dummy item
*/
DELETE FROM [Warehouse].[StockItems] WHERE StockItemID = 999
GO
