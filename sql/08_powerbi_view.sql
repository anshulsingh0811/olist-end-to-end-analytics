--1. Delivery Pefromance
 
CREATE VIEW vw_delivery_performance AS
WITH delivery_data AS (
    SELECT
        o.order_id,
        o.order_purchase_timestamp::date AS purchase_date,
        o.order_delivered_customer_date::date AS delivered_date,
        o.order_estimated_delivery_date::date AS estimated_delivery_date,
        c.customer_state,
        DATE_TRUNC('month', o.order_purchase_timestamp)::date AS month_start,
        EXTRACT(
            DAY FROM 
            o.order_delivered_customer_date 
            - o.order_purchase_timestamp
        ) AS delivery_days,
        CASE
            WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date THEN 1
            ELSE 0
        END AS on_time_flag
    FROM orders o
    LEFT JOIN customers c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
)
SELECT
    order_id,
    purchase_date,
    estimated_delivery_date,
    delivered_date,
    customer_state,
    month_start,
    delivery_days,
    on_time_flag,
    CASE
        WHEN delivery_days > 30 THEN 1
        ELSE 0
    END AS slow_delivery_flag
FROM delivery_data;


-- 2 Freight & Logistics

  CREATE OR REPLACE VIEW vw_freight_analysis AS
SELECT
    oi.order_id,
    oi.product_id,
    oi.price,
    oi.freight_value,
    p.product_category_name,
    pct.product_category_name_english,
    ROUND(
        (oi.freight_value / oi.price) * 100,2
    ) AS freight_burden,
    p.product_weight_g,
    ROUND(
        (p.product_length_cm * p.product_height_cm * p.product_width_cm)::numeric,2
    ) AS volume_cm3
FROM order_items oi
JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN product_category_translation pct
    ON p.product_category_name = pct.product_category_name
WHERE oi.price > 0
  AND oi.freight_value IS NOT NULL
  AND pct.product_category_name_english IS NOT NULL;


--3. Customer Retention

CREATE VIEW vw_customer_retention AS
SELECT
    c.customer_unique_id,
    COUNT(DISTINCT o.order_id) AS total_orders,
    MIN(o.order_purchase_timestamp) AS first_order_date,
    CASE
        WHEN COUNT(DISTINCT o.order_id) = 1 THEN 'One-time'
        ELSE 'Repeat' END AS customer_type,
    SUM(oi.price) AS total_spend
FROM customers c
JOIN orders o
    ON c.customer_id = o.customer_id
LEFT JOIN order_items oi
    ON o.order_id = oi.order_id
GROUP BY
    c.customer_unique_id;

--4. Customer behaviour

CREATE OR REPLACE VIEW vw_customer_activity AS
WITH customer_orders AS (
    SELECT
        o.order_id,
        c.customer_unique_id,
        o.order_purchase_timestamp,
        DATE_TRUNC('month',o.order_purchase_timestamp)::date AS purchase_month,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp, o.order_id
        ) AS order_sequence
    FROM orders o
    JOIN customers c
        ON o.customer_id = c.customer_id
)
SELECT
    co.order_id,
    co.customer_unique_id,
    co.order_purchase_timestamp,
    co.purchase_month,
    co.order_sequence,
    CASE
        WHEN co.order_sequence = 1 THEN 'New'
        ELSE 'Returning' END AS customer_status,
    r.review_score,
    r.review_comment_message,
    r.review_creation_date::DATE
FROM customer_orders co
LEFT JOIN reviews r
    ON co.order_id = r.order_id;


--5. Category repeat 

CREATE VIEW vw_category_repeat_rate AS
WITH customer_type AS (
    SELECT
        c.customer_unique_id,
        CASE
            WHEN COUNT(DISTINCT o.order_id) = 1 THEN 'One-time'
            ELSE 'Repeat' END AS customer_type
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
)

SELECT DISTINCT
    ct.customer_unique_id,
    ct.customer_type,
    pct.product_category_name_english AS category
FROM customer_type ct
JOIN customers c
    ON ct.customer_unique_id = c.customer_unique_id
JOIN orders o
    ON c.customer_id = o.customer_id
JOIN order_items oi
    ON o.order_id = oi.order_id
JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN product_category_translation pct
    ON p.product_category_name = pct.product_category_name
WHERE pct.product_category_name_english IS NOT NULL;


--6 Payment method

CREATE VIEW vw_payment_method AS
SELECT
    op.payment_type,
    COUNT(DISTINCT op.order_id) AS total_orders,
    SUM(op.payment_value) AS total_payment_value,
    AVG(op.payment_value) AS avg_payment_value
FROM order_payments op
JOIN orders o
    ON op.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY op.payment_type;


--7.
CREATE VIEW vw_revenue_overview AS
SELECT
    o.order_id,
    o.order_purchase_timestamp::date AS purchase_date,
    DATE_TRUNC('month', o.order_purchase_timestamp)::date AS month_start,
    oi.price,
    oi.freight_value,
    oi.price + oi.freight_value AS order_item_value
FROM orders o
LEFT JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered';
SELECT
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(SUM(price), 2) AS total_revenue,
    ROUND(SUM(price + freight_value), 2) AS total_order_value
FROM vw_revenue_overview;
SELECT
    ROUND(SUM(price), 2) AS total_revenue
FROM vw_revenue_overview;

--8

CREATE OR REPLACE VIEW vw_category_revenue AS
SELECT
    COALESCE(
        pct.product_category_name_english,
        'Other'
    ) AS category,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    SUM(oi.price) AS product_revenue
FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id
LEFT JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN product_category_translation pct
    ON p.product_category_name = pct.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY
    COALESCE(
        pct.product_category_name_english,
        'Other'
        );


--9.Delivery status review

CREATE VIEW vw_delivery_review AS
SELECT
    CASE
        WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date
            THEN 'On-Time'
        ELSE 'Late'
        END AS delivery_status,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(AVG(r.review_score),2) AS avg_review_score
FROM orders o
JOIN reviews r
    ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
  AND r.review_score IS NOT NULL
GROUP BY
    CASE
        WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date
            THEN 'On-Time' ELSE 'Late'
    END;