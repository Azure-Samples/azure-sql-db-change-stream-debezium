USE WideWorldImporters
GO

-- Issue a new random order

DECLARE @personId INT
SELECT TOP(1) @personId = PersonID FROM [Application].People WHERE IsEmployee <> 0 ORDER BY NEWID();

DECLARE @orders AS [Website].[OrderList]
INSERT INTO @orders 
SELECT TOP(1) 1 AS OrderReference, c.CustomerID, c.PrimaryContactPersonID AS ContactPersonID, CAST(DATEADD(day, 1, SYSDATETIME()) AS date) AS ExpectedDeliveryDate, CAST(FLOOR(RAND() * 10000) + 1 AS nvarchar(20)) AS CustomerPurchaseOrderNumber, CAST(0 AS bit) AS IsUndersupplyBackordered, N'Auto-generated' AS Comments, c.DeliveryAddressLine1 + N', ' + c.DeliveryAddressLine2 AS DeliveryInstructions FROM Sales.Customers AS c ORDER BY NEWID();

DECLARE @r INT = CAST(RAND() * 100 AS INT)
DECLARE @orderlinelist AS [Website].[OrderLineList]
INSERT INTO @orderlinelist
SELECT TOP(7) 1 AS OrderReference, si.StockItemID, si.StockItemName AS [Description], FLOOR(RAND() * 10) + 1 AS Quantity FROM Warehouse.StockItems AS si WHERE IsChillerStock = 0 ORDER BY NEWID()
INSERT INTO @orderlinelist
SELECT TOP(1) 1 AS OrderReference, si.StockItemID, si.StockItemName AS [Description], FLOOR(RAND() * 10) + 1 AS Quantity FROM Warehouse.StockItems AS si WHERE IsChillerStock <> 0 AND @r < 4 ORDER BY NEWID()

EXEC Website.InsertCustomerOrders @orders, @orderlinelist, @personId, @personId
GO

-- View inserted order header
SELECT TOP (1) * FROM Sales.Orders ORDER BY OrderID DESC