===========================================
-- Part 1 — Customer Behavior & Experience
===========================================

-- Q1. Which payment methods are most common, and how does payment value differ across them?

WITH payment_summary AS (
    SELECT
        order_id,
        COUNT(DISTINCT payment_type) AS payment_type_count,
        MAX(payment_type) AS payment_type,
        SUM(payment_value) AS total_payment
    FROM order_payments
    GROUP BY order_id
)
SELECT
    payment_type AS payment_method,
    COUNT(*) AS total_orders,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        2
    ) AS order_percentage,
    ROUND(AVG(total_payment), 2) AS avg_payment_value,
    ROUND(SUM(total_payment), 2) AS total_payment_value
FROM payment_summary
WHERE payment_type_count = 1
GROUP BY payment_type
ORDER BY total_orders DESC;
/* Observations:
- Credit card is the most common method, used for 76.4% of single-payment orders.
- Boleto accounts for another 20.36%, so these two methods cover almost the entire payment mix.
- Credit-card orders also have the highest average payment value at 166.95,
 compared with 145.03 for boleto and 114.39 for vouchers.
*/

-- Q2. Which product categories receive the lowest customer ratings?

SELECT
    pct.product_category_name_english,
    COUNT(r.review_id) AS review_count,
    ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM reviews r
INNER JOIN orders o
    ON r.order_id = o.order_id
INNER JOIN order_items oi
    ON o.order_id = oi.order_id
INNER JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN product_category_translation pct
    ON p.product_category_name = pct.product_category_name
WHERE r.review_score IS NOT NULL
    AND pct.product_category_name_english IS NOT NULL
GROUP BY pct.product_category_name_english
HAVING COUNT(r.review_id) >= 1000
ORDER BY avg_review_score,
    review_count DESC;
/* Observations:
- Office furniture had the lowest rating at 3.49, based on 1,687 reviews.
- Furniture decor and bed & bath table both scored 3.90. Their review counts are much higher,
  with 8,331 and 11,137 reviews respectively.
- Computers & accessories also had a relatively low rating of 3.93, with 7,849 reviews
*/

===============================
-- Part 2 — Customer Retention
===============================

-- Q1. How many customers make repeat purchases?

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS order_count
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
)
SELECT
    CASE
        WHEN order_count = 1 THEN 'One-time'
        ELSE 'Repeat'
    END AS customer_type,
    ROUND(COUNT(*) * 100.0
    /SUM(COUNT(*)) OVER (),2) AS customer_count
FROM customer_orders
GROUP BY customer_type
ORDER BY customer_count DESC;
/*Observations:
- Olist has low retention rate of customer as only 3.12% of customers repeat orders.
*/

-- Q2. Are repeat customers more valuable than one-time customers?

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS order_count,
        SUM(oi.price) AS total_spend
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    LEFT JOIN order_items oi
        ON o.order_id = oi.order_id
    GROUP BY c.customer_unique_id
)
SELECT
    CASE
        WHEN order_count = 1 THEN 'One-time'
        ELSE 'Repeat'
    END AS customer_type,
    COUNT(*) AS customer_count,
    ROUND(AVG(total_spend), 2) AS avg_customer_spend,
    ROUND(SUM(total_spend), 2) AS total_spend,
    ROUND(SUM(total_spend) * 100.0
        / SUM(SUM(total_spend)) OVER (),
        2) AS revenue_percentage
FROM customer_orders
GROUP BY customer_type
ORDER BY customer_type;
/*Observations:
- Repeat customers spend more on average, with 260.56 compared with 138.62 for one-time customers
- Repeat customers are only 3.1% of the customer base, but account for 5.73% of total spend
- This suggests that repeat customers are more valuable on an individual basis,
 even though most customers are still one-time buyers.
*/

-- Q3. What factors are associated with customers making repeat purchases?

-- 1.Average review score of repeat customers vs one-time customers
WITH customer_type AS (
    SELECT
        c.customer_unique_id,
        CASE
            WHEN COUNT(DISTINCT o.order_id) = 1 THEN 'One-time'
            ELSE 'Repeat'
        END AS customer_type
    FROM customers c
    INNER JOIN orders o
        ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
)
SELECT
    ct.customer_type,
    COUNT(r.review_id) AS review_count,
    ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM customer_type ct
INNER JOIN customers c
    ON ct.customer_unique_id = c.customer_unique_id
INNER JOIN orders o
    ON c.customer_id = o.customer_id
INNER JOIN reviews r
    ON o.order_id = r.order_id
WHERE r.review_score IS NOT NULL
GROUP BY ct.customer_type
ORDER BY avg_review_score DESC;
-- The average review score was almost the same for repeat and one-time customers,
-- so review score does not appear to be strongly associated with repeat purchasing


-- 2. Categories that attract more repeated customer
WITH customer_type AS (
    SELECT
        c.customer_unique_id,
        CASE
            WHEN COUNT(DISTINCT o.order_id) = 1 THEN 'One-time'
            ELSE 'Repeat'
        END AS customer_type
    FROM customers c
    INNER JOIN orders o
        ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
),
category_customers AS (
    SELECT DISTINCT
        ct.customer_unique_id,
        ct.customer_type,
        pct.product_category_name_english
    FROM customer_type ct
    INNER JOIN customers c
        ON ct.customer_unique_id = c.customer_unique_id
    INNER JOIN orders o
        ON c.customer_id = o.customer_id
    INNER JOIN order_items oi
        ON o.order_id = oi.order_id
    LEFT JOIN products p
        ON oi.product_id = p.product_id
    LEFT JOIN product_category_translation pct
        ON p.product_category_name = pct.product_category_name
    WHERE pct.product_category_name_english IS NOT NULL
)
SELECT
    product_category_name_english,
    COUNT(*) FILTER (WHERE customer_type = 'Repeat') AS repeat_customers,
    COUNT(*) AS total_customers,
    ROUND(
        COUNT(*) FILTER (WHERE customer_type = 'Repeat') * 100.0
        / COUNT(*), 2
    ) AS repeat_customer_rate
FROM category_customers
GROUP BY product_category_name_english
HAVING COUNT(*) >= 100
ORDER BY repeat_customer_rate DESC;
/*Observations:
- Home appliances had the highest repeat-customer rate at 10.95%, followed by fashion bags & accessories at 9.12%.
- Furniture decor and bed & bath table had relatively high repeat rates of 7.36% and 6.58%, with much larger customer bases.
- Some categories had very low repeat rates, such as books_technical (1.54%) and computers (2.23%).
/*
