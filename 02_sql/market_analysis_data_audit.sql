-- Instacart Market Analysis: data audit (MySQL 8 / standard SQL)

-- A1. Row count of every table
SELECT 'aisles' AS table_name, COUNT(*) AS row_count FROM aisles
UNION ALL SELECT 'departments', COUNT(*) FROM departments
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_products_train', COUNT(*) FROM order_products_train;

-- A2. Duplicate keys
SELECT 'duplicate order_id in orders' AS check_name, COUNT(*) - COUNT(DISTINCT order_id) AS issues FROM orders
UNION ALL SELECT 'duplicate product_id in products', COUNT(*) - COUNT(DISTINCT product_id) FROM products
UNION ALL SELECT 'duplicate aisle_id in aisles', COUNT(*) - COUNT(DISTINCT aisle_id) FROM aisles
UNION ALL SELECT 'duplicate department_id in departments', COUNT(*) - COUNT(DISTINCT department_id) FROM departments
UNION ALL SELECT 'duplicate (order_id, product_id) lines', COUNT(*) FROM (
    SELECT order_id, product_id FROM order_products_train
    GROUP BY order_id, product_id HAVING COUNT(*) > 1) t;

-- A3. Missing values in orders
-- days_since_prior_order is stored as text, with an empty string (not NULL) on a customer's first order,
-- so the blank count and the first-order count should match.
SELECT SUM(CASE WHEN days_since_prior_order IS NULL OR days_since_prior_order = '' THEN 1 ELSE 0 END) AS blank_days_since_prior,
       SUM(CASE WHEN order_number = 1 THEN 1 ELSE 0 END) AS first_orders,
       SUM(CASE WHEN user_id IS NULL OR order_dow IS NULL OR order_hour_of_day IS NULL THEN 1 ELSE 0 END) AS rows_missing_key_fields
FROM orders;

-- A4. Rows that do not link between tables (orphans)
SELECT 'line items whose order is not in orders' AS check_name, COUNT(*) AS rows_affected
FROM order_products_train
WHERE order_id NOT IN (SELECT order_id FROM orders WHERE order_id IS NOT NULL);

SELECT 'distinct orders behind those line items' AS check_name, COUNT(*) AS rows_affected
FROM (SELECT DISTINCT order_id FROM order_products_train) x
WHERE x.order_id NOT IN (SELECT order_id FROM orders WHERE order_id IS NOT NULL);

SELECT 'line items whose product is not in products' AS check_name, COUNT(*) AS rows_affected
FROM order_products_train
WHERE product_id NOT IN (SELECT product_id FROM products WHERE product_id IS NOT NULL);

SELECT 'products with an unknown aisle or department' AS check_name, COUNT(*) AS rows_affected
FROM products
WHERE aisle_id NOT IN (SELECT aisle_id FROM aisles WHERE aisle_id IS NOT NULL)
   OR department_id NOT IN (SELECT department_id FROM departments WHERE department_id IS NOT NULL);

SELECT 'orders that have line items' AS check_name, COUNT(*) AS rows_affected
FROM orders
WHERE order_id IN (SELECT order_id FROM order_products_train);

SELECT 'orders with no line items' AS check_name, COUNT(*) AS rows_affected
FROM orders
WHERE order_id NOT IN (SELECT order_id FROM order_products_train WHERE order_id IS NOT NULL);

-- A5. Which customers and orders are in the data
SELECT MIN(user_id) AS first_user, MAX(user_id) AS last_user, COUNT(DISTINCT user_id) AS customers FROM orders;

SELECT COUNT(*) AS customers,
       SUM(CASE WHEN n = last_no THEN 1 ELSE 0 END) AS customers_with_complete_history
FROM (SELECT user_id, COUNT(*) AS n, MAX(order_number) AS last_no FROM orders GROUP BY user_id) t;

SELECT eval_set, COUNT(*) AS orders FROM orders GROUP BY eval_set;

SELECT eval_set, COUNT(*) AS orders_with_line_items
FROM orders
WHERE order_id IN (SELECT order_id FROM order_products_train)
GROUP BY eval_set;

-- A6. Value ranges and caps
SELECT MIN(order_dow) AS min_dow, MAX(order_dow) AS max_dow,
       MIN(order_hour_of_day) AS min_hour, MAX(order_hour_of_day) AS max_hour,
       MIN(CAST(NULLIF(days_since_prior_order, '') AS DECIMAL(5,1))) AS min_gap,
       MAX(CAST(NULLIF(days_since_prior_order, '') AS DECIMAL(5,1))) AS max_gap,
       SUM(CASE WHEN CAST(NULLIF(days_since_prior_order, '') AS DECIMAL(5,1)) = 30 THEN 1 ELSE 0 END) AS orders_at_30_day_cap
FROM orders;

SELECT MAX(n) AS max_orders_per_customer,
       SUM(CASE WHEN n = 100 THEN 1 ELSE 0 END) AS customers_at_100
FROM (SELECT user_id, COUNT(*) AS n FROM orders GROUP BY user_id) t;

-- A7. Placeholder values
SELECT 'products in the missing aisle' AS check_name, COUNT(*) AS products
FROM products p JOIN aisles a ON a.aisle_id = p.aisle_id WHERE a.aisle = 'missing'
UNION ALL
SELECT 'products in the missing department', COUNT(*)
FROM products p JOIN departments d ON d.department_id = p.department_id WHERE d.department = 'missing'
UNION ALL
SELECT 'products with a corrupted name (#NAME?)', COUNT(*)
FROM products WHERE product_name IN ('#NAME?', 'Unknown product');
