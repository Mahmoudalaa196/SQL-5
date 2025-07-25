CREATE NONCLUSTERED INDEX customersEmail
ON sales.customers (email);


CREATE NONCLUSTERED INDEX productsCategory_brand
ON production.products (category_id, brand_id);



CREATE NONCLUSTERED INDEX ordersOrderdate
ON sales.orders (order_date)
INCLUDE (customer_id, store_id, order_status);



CREATE TABLE sales.customer_log (
    log_id INT IDENTITY(1,1) PRIMARY KEY,
    customer_id INT,
    action VARCHAR(50),
    log_date DATETIME DEFAULT GETDATE()
);



GO


CREATE TRIGGER trg_log_customer_insert
ON sales.customers
AFTER INSERT
AS
BEGIN
    INSERT INTO sales.customer_log (customer_id, action)
    SELECT customer_id, 'Added new customer'
    FROM inserted;
END;
GO

CREATE TABLE production.price_history (
    history_id INT IDENTITY(1,1) PRIMARY KEY,
    product_id INT,
    old_price DECIMAL(10,2),
    new_price DECIMAL(10,2),
    change_date DATETIME DEFAULT GETDATE(),
    changed_by VARCHAR(100)
); 



go



CREATE TRIGGER trg_track_price_change
ON production.products
AFTER UPDATE
AS
BEGIN
    INSERT INTO production.price_history (product_id, old_price, new_price, changed_by)
    SELECT 
        d.product_id,  d.list_price, i.list_price,
        SYSTEM_USER
    FROM deleted d
    JOIN inserted i ON d.product_id = i.product_id
    WHERE d.list_price <> i.list_price;
END;



go



CREATE TRIGGER trg_prevent_category_delete
ON production.categories
INSTEAD OF DELETE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM production.products p
        JOIN deleted d ON p.category_id = d.category_id
    )
    BEGIN
        RAISERROR('Cannot delete category', 16, 1);
        RETURN;
    END

    DELETE FROM production.categories
    WHERE category_id IN (SELECT category_id FROM deleted);
END;

GO

CREATE TRIGGER trg_reduce_stock_on_order
ON sales.order_items
AFTER INSERT
AS
BEGIN
    UPDATE s
    SET s.quantity = s.quantity - i.quantity
    FROM production.stocks s
    JOIN inserted i ON s.product_id = i.product_id
    WHERE s.store_id = (
        SELECT store_id FROM sales.orders WHERE order_id = i.order_id
    );
END;
