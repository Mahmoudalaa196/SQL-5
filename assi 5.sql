
--1
SELECT 
 product_id,product_name,list_price,
CASE 
  WHEN list_price < 300 THEN 'Economy'
   WHEN list_price BETWEEN 300 AND 999 THEN 'Standard'
  WHEN list_price BETWEEN 1000 AND 2499 THEN 'Premium'
    ELSE 'Luxury'
END AS category
FROM production.products;


--2
SELECT order_id,order_date,order_status,
CASE order_status
 WHEN 1 THEN 'Order Received'
 WHEN 2 THEN 'In Preparation'
 WHEN 3 THEN 'Order Cancelled'
   WHEN 4 THEN 'Order Delivered'
END AS statu,
CASE 
 WHEN order_status = 1 AND DATEDIFF(DAY, order_date, GETDATE()) > 5 THEN 'URGENT'
  WHEN order_status = 2 AND DATEDIFF(DAY, order_date, GETDATE()) > 3 THEN 'HIGH'
ELSE 'NORMAL'
END AS level
FROM sales.orders;


--------------3
SELECT s.staff_id, s.first_name, s.last_name,
    COUNT(o.order_id) AS order_count,
    CASE 
        WHEN COUNT(o.order_id) = 0 THEN 'New Staff'
        WHEN COUNT(o.order_id) BETWEEN 1 AND 10 THEN 'Junior Staff'
        WHEN COUNT(o.order_id) BETWEEN 11 AND 25 THEN 'Senior Staff'
        ELSE 'Expert Staff'
    END AS staff_level
FROM sales.staffs s
LEFT JOIN sales.orders o ON s.staff_id = o.staff_id
GROUP BY s.staff_id, s.first_name, s.last_name;

----------4

SELECT 
    customer_id, first_name,email,
   
 ISNULL(phone, 'Phone not available') AS phone,
    
COALESCE(phone, email, 'No Contact') AS preferred_contact,
    street, city, state, zip_code
FROM sales.customers;


--------------5


SELECT 
               p.product_id,p.product_name,s.quantity,
ISNULL(NULLIF(s.quantity, 0), 0) AS safty,
ISNULL(p.list_price / NULLIF(s.quantity, 0), 0) AS priceaunit,
    CASE 
    WHEN s.quantity IS NULL THEN 'No Stock'
        WHEN s.quantity = 0 THEN 'Out of Stock'
     ELSE 'In Stock'
    END AS stock_status
FROM production.products p
LEFT JOIN production.stocks s 
    ON p.product_id = s.product_id AND s.store_id = 1;
-----------------6

	SELECT 
    customer_id ,  first_name,  last_name,
  COALESCE(street, '') AS street,
   COALESCE(city, '') AS city,
COALESCE(state, '') AS state,
    COALESCE(zip_code, '') AS zip,
   COALESCE(street, '') + ', ' + 
  COALESCE(city, '') + ', ' +
    COALESCE(state, '') + ' ' +
    ISNULL(zip_code, 'No ZIP') AS formatted_address
FROM sales.customers;


---7 
WITH customer_spending AS (
    SELECT 
        o.customer_id,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_spent
    FROM sales.orders o
    JOIN sales.order_items oi ON o.order_id = oi.order_id
    GROUP BY o.customer_id
)
SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    cs.total_spent
FROM customer_spending cs
JOIN sales.customers c ON cs.customer_id = c.customer_id
WHERE cs.total_spent > 1500
ORDER BY cs.total_spent DESC;

SELECT *
FROM (
    SELECT 
        p.product_id,
        p.product_name,
        c.category_name,
        p.list_price,
        ROW_NUMBER() OVER (PARTITION BY p.category_id ORDER BY p.list_price DESC) AS row_num,
        RANK() OVER (PARTITION BY p.category_id ORDER BY p.list_price DESC) AS price_rank,
        DENSE_RANK() OVER (PARTITION BY p.category_id ORDER BY p.list_price DESC) AS dense_rank
    FROM production.products p
    JOIN production.categories c ON p.category_id = c.category_id
) AS ranked
WHERE row_num <= 3;









WITH customer_spending AS (
    SELECT 
        o.customer_id,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_spent
    FROM sales.orders o
    JOIN sales.order_items oi ON o.order_id = oi.order_id
    GROUP BY o.customer_id
)
SELECT 
    c.customer_id, c.first_name,  c.last_name, cs.total_spent,
    RANK() OVER (ORDER BY cs.total_spent DESC) AS spending_rank,
    NTILE(5) OVER (ORDER BY cs.total_spent DESC) AS spending_group,
    CASE NTILE(5) OVER (ORDER BY cs.total_spent DESC)
  WHEN 1 THEN 'VIP'
    WHEN 2 THEN 'Gold'
    WHEN 3 THEN 'Silver'
	WHEN 4 THEN 'Bronze'
	ELSE 'Standard'
    END AS tier
FROM customer_spending cs
JOIN sales.customers c ON cs.customer_id = c.customer_id;



WITH revenue_per_store AS (
    SELECT 
        o.store_id,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_revenue,
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM sales.orders o
    JOIN sales.order_items oi ON o.order_id = oi.order_id
    GROUP BY o.store_id
)
SELECT 
    s.store_name, r.total_revenue,  r.total_orders,
    RANK() OVER (ORDER BY r.total_revenue DESC) AS revenue_rank,
    RANK() OVER (ORDER BY r.total_orders DESC) AS orders_rank,
    PERCENT_RANK() OVER (ORDER BY r.total_revenue) AS revenue_percentile
FROM revenue_per_store r
JOIN sales.stores s ON r.store_id = s.store_id;








--------------14

SELECT *
FROM (
    SELECT 
        s.store_name,
        DATENAME(MONTH, o.order_date) AS order_month,
        oi.quantity * oi.list_price * (1 - oi.discount) AS revenue
    FROM sales.orders o
    JOIN sales.order_items oi ON o.order_id = oi.order_id
    JOIN sales.stores s ON o.store_id = s.store_id
) AS source
PIVOT (
    SUM(revenue)
    FOR order_month IN ([January], [February], [March], [April], [May], [June],
                        [July], [August], [September], [October], [November], [December])
) AS pivot_months;


----------15

SELECT *
FROM (
    SELECT 
        s.store_name,
        CASE o.order_status
            WHEN 1 THEN 'Pending'
            WHEN 2 THEN 'Processing'
            WHEN 3 THEN 'Rejected'
            WHEN 4 THEN 'Completed'
        END AS status
    FROM sales.orders o
    JOIN sales.stores s ON o.store_id = s.store_id
) AS source
PIVOT (
    COUNT(status)
    FOR status IN ([Pending], [Processing], [Rejected], [Completed])
) AS pivot_status;
-------------16
WITH brand_sales AS (
    SELECT 
        b.brand_name, p.model_year,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_revenue
    FROM sales.order_items oi
    JOIN production.products p ON oi.product_id = p.product_id
    JOIN production.brands b ON p.brand_id = b.brand_id
    GROUP BY b.brand_name, p.model_year
)
SELECT *
FROM brand_sales
PIVOT (
    SUM(total_revenue)
    FOR model_year IN ([2022], [2023], [2024])
) AS pivot_years;

-----------18


-- in 2023
SELECT DISTINCT customer_id
FROM sales.orders
WHERE YEAR(order_date) = 2023

INTERSECT

-- in 2024
SELECT DISTINCT customer_id
FROM sales.orders
WHERE YEAR(order_date) = 2024;


------20

SELECT DISTINCT customer_id, '2022 Only' AS retention_status
FROM sales.orders
WHERE YEAR(order_date) = 2022
EXCEPT
SELECT DISTINCT customer_id, '2022 Only'
FROM sales.orders
WHERE YEAR(order_date) = 2023

UNION ALL

SELECT DISTINCT customer_id, 'New in 2023'
FROM sales.orders
WHERE YEAR(order_date) = 2023
EXCEPT
SELECT DISTINCT customer_id, 'New in 2023'
FROM sales.orders
WHERE YEAR(order_date) = 2022

UNION ALL


SELECT DISTINCT customer_id, 'Retained'
FROM sales.orders
WHERE YEAR(order_date) = 2022
INTERSECT
SELECT DISTINCT customer_id, 'Retained'
FROM sales.orders
WHERE YEAR(order_date) = 2023;
