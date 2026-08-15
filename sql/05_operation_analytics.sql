========================
-- Part.1 Delivery Operations
========================

-- Q1. How well is Olist performing on delivery?

-- 1. Customer delivery time i.e time from purchase to delivery

WITH delivery_time AS(
    SELECT 
        order_id,
        EXTRACT (
          EPOCH FROM (order_delivered_customer_date - order_purchase_timestamp)
          ) / 86400 AS delivery_days
    FROM orders
    WHERE order_status = 'delivered'
        AND order_delivered_customer_date IS NOT NULL
)

SELECT 
    ROUND(AVG(delivery_days)::numeric,2) AS avg_delivery_days,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY delivery_days)::numeric
    ,2) AS median_delivery_days
FROM delivery_time;

-- 2. Order approval and post-approval delivery time
WITH approval AS(
    SELECT 
        order_id,
        EXTRACT(
          EPOCH FROM (order_approved_at - order_purchase_timestamp)
          ) / 60 AS approval_time,
        EXTRACT(
          EPOCH FROM (order_delivered_customer_date - order_approved_at)
          ) / 86400 AS delivery_days
FROM orders
WHERE order_approved_at IS NOT NULL
    AND order_delivered_customer_date IS NOT NULL
    AND order_approved_at >= order_purchase_timestamp)

SELECT
    count(*) AS order_count,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY approval_time)::numeric,2) 
    AS median_approval_time_min,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY delivery_days)::numeric,2)
    AS median_delovery_days
FROM approval;

-- 3. Did Olist deliver orders by the date it promised
SELECT 
    ROUND(100.0 * 
    SUM(CASE 
        WHEN order_delivered_customer_date <= order_estimated_delivery_date THEN 1
        ELSE 0
    END) / COUNT(*),2) AS on_time_rate
FROM orders
WHERE order_status = 'delivered'
        AND order_delivered_customer_date IS NOT NULL
        AND order_estimated_delivery_date IS NOT NULL;

/*Insights:
- Delivery time: Orders were delivered in a median of 10.22 days, while the average was 12.56 days
 suggesting a some orders experienced significantly longer delivery times.
- Delivery reliability: Olist achieved an overall 91% on-time delivery rate,
 indicating generally strong performance for promised delivery dates.
- Order processing: Median approval time was only 20.60 minutes which is good enough,
 suggesting approval time doesn't have significant effect on delivery time.
 */ 
-------------------------------------------------------------------------------------------------------

-- Q2. Which Brazilian states have the worst delivery performance?

-- 1. BY Median days
WITH cte AS(
    SELECT 
        o.order_id,
        EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_purchase_timestamp)
        ) / 86400 as delivery_days,
        c.customer_state
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id
WHERE order_status = 'delivered'
        AND order_delivered_customer_date IS NOT NULL)

SELECT
    customer_state,
    COUNT(*) AS order_count,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP(order by delivery_days)::numeric,2)
    AS median_delivery_time
FROM cte
GROUP BY customer_state
ORDER BY median_delivery_time DESC,
    order_count DESC
LIMIT 10 ;

-- 2. By Rate of On-time delivery
SELECT 
    COUNT(*) AS order_count,
    ROUND(SUM(CASE
        WHEN o.order_estimated_delivery_date >= o.order_delivered_customer_date THEN 1
        ELSE 0 END )*100.0/COUNT(*),2) AS On_time_Rate,
    c.customer_state
FROM orders o 
LEFT JOIN customers c ON o.customer_id = c.customer_id
WHERE order_status = 'delivered'
        AND order_delivered_customer_date IS NOT NULL
        AND order_estimated_delivery_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY On_time_Rate ,COUNT(*) DESC
LIMIT 20
;
/* Observations:
- Median delivery time: The slowest states were AM (25.88 days), RR (25.01 days), 
 and AP (24.35 days), significantly above Olist's overall median of 10.22 days.
- On-time delivery: AL had the lowest on-time rate (76.07%), followed by MA (80.33%) and PI (84.03%).
- States with the longest delivery times were not always the states with the lowest on-time rates,
 showing that delivery speed and delivery reliability measure different aspects of performance.
-Some high-volume states also show weaker reliability: RJ (12,350 orders) had on-time rate of 86.53%,
 while BA (3,256 orders) had 85.96%.
*/
--------------------------------------------------------------------------------------------------------

-- Q3. Which sellers have the worst delivery performance?

WITH seller_orders AS(
    SELECT DISTINCT
    o.order_id,
    oi.seller_id,
    CASE
        WHEN o.order_estimated_delivery_date >= o.order_delivered_customer_date THEN 1
        ELSE 0 
    END AS On_time
FROM orders o LEFT JOIN order_items oi 
ON o.order_id = oi.order_id
WHERE order_status = 'delivered'
        AND order_delivered_customer_date IS NOT NULL
        AND order_estimated_delivery_date IS NOT NULL
)

SELECT
    seller_id,
    COUNT(*) AS total_order,
    ROUND(SUM(on_time) * 100.0 / COUNT(*),2) AS on_time_rate
FROM seller_orders
GROUP BY seller_id
HAVING COUNT(*)>=50
ORDER BY on_time_rate
LIMIT 20;
/* Observations:
- Seller reliability varies significantly: The lowest on-time rate was 69.86%.
- Several sellers performed below 80% on-time delivery.
Some high-volume sellers also underperformed like One seller with 389 orders had only 76.86% on-time rate.
*/
-----------------------------------------------------------------------------------------------------------

-- Q4. Are late deliveries associated with lower customer review scores?

WITH order_reviews AS(
    SELECT 
        order_id,
        AVG (review_score) AS avg_review_score
    FROM reviews
    WHERE review_score IS NOT NULL
    GROUP BY order_id
),
order_performance AS(
    SELECT 
        o.order_id,
        CASE
            WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date
            THEN 1 ELSE 0
        END AS on_time,
        avg_review_score
    FROM orders o INNER JOIN order_reviews o_r
    ON o.order_id = o_r.order_id
    WHERE o.order_status = 'delivered'
    AND o.order_delivered_customer_date IS NOT NULL
    AND o.order_estimated_delivery_date IS NOT NULL
)
SELECT 
    ROUND(AVG(avg_review_score)FILTER (WHERE on_time = 1)
    ,2) AS on_time_avg_review,
    ROUND(AVG(avg_review_score)FILTER (WHERE on_time = 0)
    ,2) AS late_avg_review
FROM order_performance;
/*Observations:
- On-time orders had an average review score of 4.29, while late orders scored 2.57.
- That is a 1.72-point difference, showing that late delivery is linked with much lower review scores.
*/
---------------------------------------------------------------------------------------------------------

=========================
-- Part.2 Freight & Logistics 
=========================

-- Q5. Which product categories contribute most to freight costs,
   & which have the highest freight costs per item?

SELECT 
    p.product_category_name,
    pct.product_category_name_english,
    COUNT(*) AS order_item_count,
    SUM(oi.freight_value) AS total_freight,
    ROUND(AVG(oi.freight_value),2) AS avg_freight_cost,
    RANK() OVER (ORDER BY SUM(oi.freight_value) DESC
    ) AS total_freight_rank,
    RANK() OVER (ORDER BY AVG(oi.freight_value) DESC
    ) AS avg_freight_rank
FROM order_items oi LEFT JOIN products p
    ON oi.product_id = p.product_id
    LEFT JOIN product_category_translation pct
    ON p.product_category_name = pct.product_category_name
WHERE freight_value IS NOT NULL
GROUP BY p.product_category_name,
         pct.product_category_name_english
ORDER BY count(*) DESC;
/*Observations:
- Bed & bath table had the highest total freight cost (204.7K), mainly because 
 it had the highest number of order items (11,115).
- Computers had the highest freight cost per item (48.45), with only 203 order items.
- High total freight and high freight per item are not always found in the same categories.
*/
----------------------------------------------------------------------------------------------------------------------------------

-- Q6. How are product weight and volume associated with avg. freight cost?

SELECT
    p.product_category_name,
    pct.product_category_name_english,
    COUNT(*) AS order_item_count,
    ROUND(AVG(oi.freight_value), 2) AS avg_freight_per_item,
    ROUND(AVG(p.product_weight_g) / 1000.0, 2) AS avg_weight_kg,
    ROUND(AVG(p.product_length_cm
            * p.product_height_cm
            * p.product_width_cm),2) AS avg_volume_cm3,
    RANK() OVER (ORDER BY AVG(oi.freight_value) DESC) AS freight_rank,
    RANK() OVER (ORDER BY AVG(p.product_weight_g) DESC) AS weight_rank,
    RANK() OVER (ORDER BY AVG(
            p.product_length_cm
            * p.product_height_cm
            * p.product_width_cm) DESC) AS volume_rank
FROM order_items oi
LEFT JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN product_category_translation pct
    ON p.product_category_name = pct.product_category_name
WHERE oi.freight_value IS NOT NULL
  AND p.product_weight_g IS NOT NULL
  AND p.product_length_cm IS NOT NULL
  AND p.product_height_cm IS NOT NULL
  AND p.product_width_cm IS NOT NULL
GROUP BY
    p.product_category_name,
    pct.product_category_name_english
ORDER BY avg_freight_per_item DESC;
/*Observations:
- Higher freight costs are generally seen in heavier and larger products. Office furniture
 ranked 1st in both weight and volume, and also had the 6th-highest freight cost per item.
- The pattern is not the same for every category. Computers had the highest freight cost per item,
 but ranked only 7th in weight and 8th in volume.
*/
