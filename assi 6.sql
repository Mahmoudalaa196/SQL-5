use StoreDB
go
-----------Customer Spending Analysis
DECLARE @customer_id INT = 1;
DECLARE @total_spent DECIMAL(10,2);
SELECT @total_spent = SUM(oi.quantity * oi.list_price * (1 - oi.discount))
FROM sales.orders o
JOIN sales.order_items oi ON o.order_id = oi.order_id
WHERE o.customer_id = @customer_id;
IF @total_spent IS NULL
    PRINT 'Customer not found or no spending.';
ELSE IF @total_spent > 5000
    PRINT 'Customer is a VIP. Total Spent: $' + CAST(@total_spent AS VARCHAR);
ELSE
    PRINT 'Customer is Regular. Total Spent: $' + CAST(@total_spent AS VARCHAR);
GO

------------ Product Price Threshold Report
DECLARE @threshold DECIMAL(10,2) = 1500;
DECLARE @count INT;
SELECT @count = COUNT(*) 
FROM production.products 
WHERE list_price > @threshold;
PRINT 'Threshold Price: $' + CAST(@threshold AS VARCHAR);
PRINT 'Number of products above threshold: ' + CAST(@count AS VARCHAR);
GO

---------------Staff Performance Calculator
DECLARE @staff_id INT = 2;
DECLARE @year INT = 2017;
DECLARE @total_sales DECIMAL(10,2);
SELECT @total_sales = SUM(oi.quantity * oi.list_price * (1 - oi.discount))
FROM sales.orders o
JOIN sales.order_items oi ON o.order_id = oi.order_id
WHERE o.staff_id = @staff_id AND YEAR(o.order_date) = @year;
PRINT 'Staff ID: ' + CAST(@staff_id AS VARCHAR);
PRINT 'Year: ' + CAST(@year AS VARCHAR);
PRINT 'Total Sales: $' + ISNULL(CAST(@total_sales AS VARCHAR), '0.00');
GO

------------ Global Variables Information
SELECT 
    @@SERVERNAME AS server_name,
    @@VERSION AS sql_version,
    @@ROWCOUNT AS last_rows_affected;
GO

------------Inventory Stock Level Check
DECLARE @product_id INT = 1;
DECLARE @store_id INT = 1;
DECLARE @quantity INT;
SELECT @quantity = quantity
FROM production.stocks
WHERE product_id = @product_id AND store_id = @store_id;
IF @quantity IS NULL
    PRINT 'Product not found in this store.';
ELSE IF @quantity > 20
    PRINT 'Well stocked';
ELSE IF @quantity BETWEEN 10 AND 20
    PRINT 'Moderate stock';
ELSE
    PRINT 'Low stock - reorder needed';
GO

------------ WHILE loop to restock low-stock items
DECLARE @counter INT = 0;
DECLARE @batch_size INT = 3;
WHILE EXISTS (SELECT 1 FROM production.stocks WHERE quantity < 5)
BEGIN
    UPDATE TOP (@batch_size) production.stocks
    SET quantity = quantity + 10
    WHERE quantity < 5;
    SET @counter += 1;
    PRINT 'Batch ' + CAST(@counter AS VARCHAR) + ' processed: 3 items updated.';
END
PRINT 'Restocking completed.';
GO

---------- Product Price Categorization
SELECT  product_id,  product_name, list_price,
    CASE 
        WHEN list_price < 300 THEN 'Budget'
        WHEN list_price BETWEEN 300 AND 800 THEN 'Mid-Range'
        WHEN list_price BETWEEN 801 AND 2000 THEN 'Premium'
        ELSE 'Luxury'
    END AS price_category
FROM production.products;
GO



----- Scalar Function: CalculateShipping
CREATE FUNCTION dbo.CalculateShipping(@order_total DECIMAL(10,2))
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @shipping_cost DECIMAL(10,2);
    IF @order_total > 100
        SET @shipping_cost = 0.00;
    ELSE IF @order_total >= 50
        SET @shipping_cost = 5.99;
    ELSE
        SET @shipping_cost = 12.99;
    RETURN @shipping_cost;
END;
GO

--------- Inline Table-Valued Function: GetProductsByPriceRange
CREATE FUNCTION dbo.GetProductsByPriceRange
(
    @min_price DECIMAL(10,2),
    @max_price DECIMAL(10,2)
)
RETURNS TABLE
AS
RETURN
(
    SELECT    p.product_id,    p.product_name,     p.list_price,    b.brand_name, c.category_name
    FROM production.products p
    JOIN production.brands b ON p.brand_id = b.brand_id
    JOIN production.categories c ON p.category_id = c.category_id
    WHERE p.list_price BETWEEN @min_price AND @max_price
);
GO

-- ------------ Multi-Statement Function: Customer Yearly Summary
CREATE FUNCTION dbo.GetCustomerYearlySummary(@customer_id INT)
RETURNS @summary TABLE (
    order_year INT,
    total_orders INT,
    total_spent DECIMAL(10,2),
    average_order_value DECIMAL(10,2)
)
AS
BEGIN
    INSERT INTO @summary
    SELECT 
        YEAR(o.order_date),
        COUNT(DISTINCT o.order_id),
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)),
        AVG(oi.quantity * oi.list_price * (1 - oi.discount))
    FROM sales.orders o
    JOIN sales.order_items oi ON o.order_id = oi.order_id
    WHERE o.customer_id = @customer_id
    GROUP BY YEAR(o.order_date);
    RETURN;
END;
GO

----------Scalar Function: CalculateBulkDiscount
CREATE FUNCTION dbo.CalculateBulkDiscount(@quantity INT)
RETURNS DECIMAL(4,2)
AS
BEGIN
    RETURN 
        CASE 
            WHEN @quantity BETWEEN 1 AND 2 THEN 0.00
            WHEN @quantity BETWEEN 3 AND 5 THEN 0.05
            WHEN @quantity BETWEEN 6 AND 9 THEN 0.10
            ELSE 0.15
        END;
END;
GO

----------- Stored ProcedureCustomer Order History
CREATE PROCEDURE sp_GetCustomerOrderHistory
    @customer_id INT, @start_date DATE = NULL,   @end_date DATE = NULL
AS
BEGIN
    SELECT 
        o.order_id,   o.order_date,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS order_total
    FROM sales.orders o
    JOIN sales.order_items oi ON o.order_id = oi.order_id
    WHERE o.customer_id = @customer_id
    AND (@start_date IS NULL OR o.order_date >= @start_date)
    AND (@end_date IS NULL OR o.order_date <= @end_date)
    GROUP BY o.order_id, o.order_date;
END;
GO

-----Stored Procedure: Restock Product with Output
CREATE PROCEDURE sp_RestockProduct
    @store_id INT,  @product_id INT,   @restock_qty INT,   @old_qty INT OUTPUT,  @new_qty INT OUTPUT,   @success BIT OUTPUT
AS
BEGIN
    DECLARE @exists INT;
    SELECT @exists = COUNT(*) 
    FROM production.stocks 
    WHERE store_id = @store_id AND product_id = @product_id;

    IF @exists = 1
    BEGIN
        SELECT @old_qty = quantity 
        FROM production.stocks 
        WHERE store_id = @store_id AND product_id = @product_id;

        UPDATE production.stocks
        SET quantity = quantity + @restock_qty
        WHERE store_id = @store_id AND product_id = @product_id;

        SELECT @new_qty = quantity 
        FROM production.stocks 
        WHERE store_id = @store_id AND product_id = @product_id;

        SET @success = 1;
    END
    ELSE
        SET @success = 0;
END;
GO

-- 15. Stored Procedure: Process New Order with Transaction
CREATE PROCEDURE sp_ProcessNewOrder
    @customer_id INT,  @product_id INT ,  @quantity INT,   @store_id INT
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @staff_id INT = (
            SELECT TOP 1 staff_id FROM sales.staffs WHERE store_id = @store_id
        );

        DECLARE @order_id INT;

        INSERT INTO sales.orders (customer_id, order_status, order_date, required_date, store_id, staff_id)
        VALUES (@customer_id, 1, GETDATE(), DATEADD(DAY, 3, GETDATE()), @store_id, @staff_id);

        SET @order_id = SCOPE_IDENTITY();

        DECLARE @list_price DECIMAL(10,2) = (
            SELECT list_price FROM production.products WHERE product_id = @product_id
        );

        INSERT INTO sales.order_items (order_id, item_id, product_id, quantity, list_price, discount)
        VALUES (@order_id, 1, @product_id, @quantity, @list_price, 0);

        COMMIT;
        PRINT 'Order processed successfully.';
    END TRY
    BEGIN CATCH
        ROLLBACK;
        PRINT 'Error processing order: ' + ERROR_MESSAGE();
    END CATCH
END;
GO

-- -----------Stored Procedure: Dynamic Product Search
CREATE PROCEDURE sp_SearchProducts
    @name NVARCHAR(100) = NULL,
    @category_id INT = NULL,
    @min_price DECIMAL(10,2) = NULL,
    @max_price DECIMAL(10,2) = NULL,
    @sort_column NVARCHAR(50) = NULL
AS
BEGIN
    DECLARE @sql NVARCHAR(MAX);
    SET @sql = '
    SELECT p.product_id, p.product_name, p.list_price, c.category_name
    FROM production.products p
    JOIN production.categories c ON p.category_id = c.category_id
    WHERE 1 = 1';

    IF @name IS NOT NULL
        SET @sql += ' AND p.product_name LIKE ''%' + @name + '%''';

    IF @category_id IS NOT NULL
        SET @sql += ' AND p.category_id = ' + CAST(@category_id AS NVARCHAR);

    IF @min_price IS NOT NULL
        SET @sql += ' AND p.list_price >= ' + CAST(@min_price AS NVARCHAR);

    IF @max_price IS NOT NULL
        SET @sql += ' AND p.list_price <= ' + CAST(@max_price AS NVARCHAR);

    IF @sort_column IS NOT NULL
        SET @sql += ' ORDER BY ' + QUOTENAME(@sort_column);

    EXEC sp_executesql @sql;
END;
GO

------------Staff Bonus Calculation
DECLARE @start_date DATE = '2024-01-01';
DECLARE @end_date DATE = '2024-03-31';
SELECT  s.staff_id, s.first_name,  s.last_name,
    SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_sales,
              CASE 
      WHEN SUM(oi.quantity * oi.list_price * (1 - oi.discount)) > 20000 THEN '10% Bonus'
      WHEN SUM(oi.quantity * oi.list_price * (1 - oi.discount)) > 10000 THEN '5% Bonus'
               ELSE 'No Bonus'
    END AS bonus_tier
FROM sales.orders o
JOIN sales.order_items oi ON o.order_id = oi.order_id
JOIN sales.staffs s ON o.staff_id = s.staff_id
WHERE o.order_date BETWEEN @start_date AND @end_date
GROUP BY s.staff_id, s.first_name, s.last_name;
GO

-----------------Smart Inventory Restocking Logic
SELECT   s.store_id,  s.product_id,  p.product_name,  p.category_id, s.quantity,
    CASE 
        WHEN s.quantity < 5 AND p.category_id = 1 THEN 'Reorder 30'
        WHEN s.quantity < 5 AND p.category_id = 2 THEN 'Reorder 20'
        WHEN s.quantity < 5 THEN 'Reorder 10'
        ELSE 'Stock OK'
    END AS restock_action
FROM production.stocks s
JOIN production.products p ON s.product_id = p.product_id;
GO

-------------Customer Loyalty Tier Assignment
WITH spending AS (
    SELECT   c.customer_id,    c.first_name,   c.last_name,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_spent
    FROM sales.customers c
    LEFT JOIN sales.orders o ON c.customer_id = o.customer_id
    LEFT JOIN sales.order_items oi ON o.order_id = oi.order_id
    GROUP BY c.customer_id, c.first_name, c.last_name
)
SELECT *,
    CASE 
        WHEN total_spent IS NULL THEN 'No Orders'
        WHEN total_spent >= 10000 THEN 'Platinum'
        WHEN total_spent >= 5000 THEN 'Gold'
        WHEN total_spent >= 2000 THEN 'Silver'
        ELSE 'Bronze'
    END AS loyalty_tier
FROM spending;
GO

-- ---Product Discontinuation Procedure
CREATE PROCEDURE sp_DiscontinueProduct
    @product_id INT
AS
BEGIN
    IF EXISTS (
        SELECT 1 FROM sales.order_items oi
        JOIN sales.orders o ON oi.order_id = o.order_id
        WHERE oi.product_id = @product_id AND o.order_status IN (1, 2)
    )
    BEGIN
        PRINT 'Cannot discontinue product: pending orders exist.';
        RETURN;
    END

    DELETE FROM production.stocks WHERE product_id = @product_id;
    DELETE FROM production.products WHERE product_id = @product_id;

    PRINT 'Product discontinued successfully. Inventory cleared.';
END;
GO