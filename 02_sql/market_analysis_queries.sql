-- Instacart Market Analysis: answers to the 20 business questions (MySQL 8 / standard SQL)
-- Database: project_orders. Tables: aisles, departments, orders, order_products_train, products.

-- Q1. Top 10 aisles with the highest number of products
-- 'missing' is a placeholder aisle for 1,254 unassigned products, so it is excluded to show real aisles.
SELECT a.aisle, COUNT(*) AS product_count
FROM products p
JOIN aisles a ON a.aisle_id = p.aisle_id
WHERE a.aisle <> 'missing'
GROUP BY a.aisle
ORDER BY product_count DESC
LIMIT 10;

-- Q2. How many unique departments are there?
SELECT COUNT(*) AS departments_in_table,
       SUM(CASE WHEN department <> 'missing' THEN 1 ELSE 0 END) AS real_departments
FROM departments;

-- Q3. Distribution of products across departments
SELECT d.department,
       COUNT(*) AS product_count,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM products), 1) AS pct_of_products
FROM products p
JOIN departments d ON d.department_id = p.department_id
GROUP BY d.department
ORDER BY product_count DESC;

-- Q4. Top 10 products with the highest reorder rates
SELECT p.product_name,
       COUNT(*) AS times_ordered,
       ROUND(100.0 * AVG(op.reordered), 2) AS reorder_rate_pct	
FROM order_products_train op
JOIN products p ON p.product_id = op.product_id
GROUP BY p.product_id, p.product_name
HAVING COUNT(*) > 1000
ORDER BY reorder_rate_pct DESC
LIMIT 10;

-- Q5. How many unique users have placed orders?
SELECT COUNT(DISTINCT user_id) AS unique_users FROM orders;

-- Q6. Average number of days between orders for each user
SELECT user_id, ROUND(AVG(CAST(days_since_prior_order AS DECIMAL(5,1))), 2) AS avg_days_between_orders
FROM orders
WHERE order_number > 1
GROUP BY user_id
ORDER BY user_id
LIMIT 20;

SELECT ROUND(AVG(CAST(days_since_prior_order AS DECIMAL(5,1))), 2) AS overall_avg_days
FROM orders
WHERE order_number > 1;

-- Q7. Peak hours of order placement
-- Top 5 hours by order count.
SELECT order_hour_of_day, COUNT(*) AS orders
FROM orders
GROUP BY order_hour_of_day
ORDER BY orders DESC
LIMIT 5;

-- Q8. Order volume by day of the week
SELECT order_dow, COUNT(*) AS orders
FROM orders
GROUP BY order_dow
ORDER BY order_dow;

-- Q9. Top 10 most ordered products
SELECT p.product_name, COUNT(*) AS times_ordered
FROM order_products_train op
JOIN products p ON p.product_id = op.product_id
GROUP BY p.product_id, p.product_name
ORDER BY times_ordered DESC
LIMIT 10;

-- Q10. How many users have placed orders in each department
SELECT d.department, COUNT(DISTINCT o.user_id) AS users
FROM order_products_train op
JOIN (SELECT order_id, user_id FROM orders
      WHERE order_id IN (SELECT order_id FROM order_products_train)) o ON o.order_id = op.order_id
JOIN products p ON p.product_id = op.product_id
JOIN departments d ON d.department_id = p.department_id
GROUP BY d.department
ORDER BY users DESC;

-- Q11. Average number of products per order
SELECT ROUND(1.0 * COUNT(*) / COUNT(DISTINCT order_id), 2) AS avg_products_per_order
FROM order_products_train;

-- Q12. Most reordered products in each department (top 3)
SELECT department,
       SUBSTRING_INDEX(
           GROUP_CONCAT(CONCAT(product_name, ' (', reorders, ' reorders)') ORDER BY reorders DESC SEPARATOR ' | '),
           ' | ', 3) AS top_3_reordered_products
FROM (
    SELECT d.department, p.product_id, p.product_name, SUM(op.reordered) AS reorders
    FROM order_products_train op
    JOIN products p ON p.product_id = op.product_id
    JOIN departments d ON d.department_id = p.department_id
    GROUP BY d.department, p.product_id, p.product_name
) t
GROUP BY department
ORDER BY department;

-- Q13. How many products have been reordered more than once
SELECT COUNT(*) AS products_reordered_more_than_once
FROM (
    SELECT product_id
    FROM order_products_train
    GROUP BY product_id
    HAVING SUM(reordered) > 1
) t;

-- Q14. Average number of products added to the cart per order
SELECT ROUND(AVG(cart_size), 2) AS avg_cart_size
FROM (
    SELECT order_id, MAX(CAST(add_to_cart_order AS UNSIGNED)) AS cart_size
    FROM order_products_train
    GROUP BY order_id
) t;

-- Q15. Number of orders by hour of the day
SELECT order_hour_of_day, COUNT(*) AS orders
FROM orders
GROUP BY order_hour_of_day
ORDER BY order_hour_of_day;

-- Q16. Distribution of order sizes (products per order)
SELECT items_in_order, COUNT(*) AS orders
FROM (
    SELECT order_id, COUNT(*) AS items_in_order
    FROM order_products_train
    GROUP BY order_id
) t
GROUP BY items_in_order
ORDER BY items_in_order;

-- Q17. Average reorder rate for products in each aisle
SELECT a.aisle, ROUND(100.0 * AVG(op.reordered), 2) AS reorder_rate_pct, COUNT(*) AS line_items
FROM order_products_train op
JOIN products p ON p.product_id = op.product_id
JOIN aisles a ON a.aisle_id = p.aisle_id
GROUP BY a.aisle
ORDER BY reorder_rate_pct DESC;

-- Q18. Average order size by day of the week
SELECT o.order_dow,
       ROUND(1.0 * COUNT(*) / COUNT(DISTINCT op.order_id), 2) AS avg_order_size
FROM order_products_train op
JOIN (SELECT order_id, order_dow FROM orders
      WHERE order_id IN (SELECT order_id FROM order_products_train)) o ON o.order_id = op.order_id
GROUP BY o.order_dow
ORDER BY o.order_dow;

-- Q19. Top 10 users with the highest number of orders
SELECT user_id, COUNT(*) AS orders
FROM orders
GROUP BY user_id
ORDER BY orders DESC, user_id
LIMIT 10;

-- Q20. How many products belong to each aisle and department
SELECT a.aisle, d.department, COUNT(*) AS product_count
FROM products p
JOIN aisles a ON a.aisle_id = p.aisle_id
JOIN departments d ON d.department_id = p.department_id
GROUP BY a.aisle, d.department
ORDER BY product_count DESC
LIMIT 20;

-- BONUS 1. Customer loyalty groups: share of customers vs share of orders
SELECT order_group,
       COUNT(*) AS customers,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(DISTINCT user_id) FROM orders), 1) AS pct_of_customers,
       ROUND(100.0 * SUM(orders) / (SELECT COUNT(*) FROM orders), 1) AS pct_of_orders
FROM (
    SELECT user_id,
           COUNT(*) AS orders,
           CASE WHEN COUNT(*) <= 10 THEN '1-10'
                WHEN COUNT(*) <= 20 THEN '11-20'
                WHEN COUNT(*) <= 40 THEN '21-40'
                ELSE '41+' END AS order_group
    FROM orders
    GROUP BY user_id
) t
GROUP BY order_group
ORDER BY MIN(orders);

-- BONUS 2. Reorder reminder timing: how long customers wait between orders
SELECT CASE WHEN CAST(days_since_prior_order AS DECIMAL(5,1)) <= 7 THEN '0-7 days'
            WHEN CAST(days_since_prior_order AS DECIMAL(5,1)) <= 14 THEN '8-14 days'
            WHEN CAST(days_since_prior_order AS DECIMAL(5,1)) <= 29 THEN '15-29 days'
            ELSE '30+ days' END AS gap,
       COUNT(*) AS orders,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM orders WHERE order_number > 1), 1) AS pct_of_orders
FROM orders
WHERE order_number > 1
GROUP BY 1
ORDER BY MIN(CAST(days_since_prior_order AS DECIMAL(5,1)));

-- BONUS 3. Frequently bought together: top product pairs
SELECT p.product_name AS bought_with_banana,
       COUNT(*) AS orders_together,
       ROUND(100.0 * COUNT(*) / anchor.n, 1) AS pct_of_banana_orders,
       ROUND(1.0 * COUNT(*) * tot.n / (anchor.n * item.n), 2) AS lift
FROM order_products_train op
JOIN (SELECT order_id FROM order_products_train
      WHERE product_id = (SELECT product_id FROM products WHERE product_name = 'Banana')) b
  ON b.order_id = op.order_id
JOIN products p ON p.product_id = op.product_id
JOIN (SELECT product_id, COUNT(*) AS n FROM order_products_train GROUP BY product_id) item
  ON item.product_id = op.product_id
CROSS JOIN (SELECT COUNT(DISTINCT order_id) AS n FROM order_products_train) tot
CROSS JOIN (SELECT COUNT(*) AS n FROM order_products_train
            WHERE product_id = (SELECT product_id FROM products WHERE product_name = 'Banana')) anchor
WHERE p.product_name <> 'Banana'
GROUP BY p.product_id, p.product_name, anchor.n, tot.n, item.n
ORDER BY orders_together DESC
LIMIT 10;