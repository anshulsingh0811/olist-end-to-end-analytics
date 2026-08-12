-- 1. Row counts

SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL
SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL
SELECT 'product_category_translation', COUNT(*) FROM product_category_translation
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'reviews', COUNT(*) FROM reviews
UNION ALL
SELECT 'order_payments', COUNT(*) FROM order_payments;
---------------------------------------------------------------------------------------
-- 2. Missing Values : customers

SELECT
    COUNT(*) FILTER (WHERE customer_id IS NULL) AS customer_id_nulls,
    COUNT(*) FILTER (WHERE customer_unique_id IS NULL) AS customer_unique_id_nulls,
    COUNT(*) FILTER (WHERE customer_zip_code_prefix IS NULL) AS zip_code_nulls,
    COUNT(*) FILTER (WHERE customer_city IS NULL) AS city_nulls,
    COUNT(*) FILTER (WHERE customer_state IS NULL) AS state_nulls
FROM customers;       

-- Missing values: sellers

SELECT
    COUNT(*) FILTER (WHERE seller_id IS NULL) AS seller_id_nulls,
    COUNT(*) FILTER (WHERE seller_zip_code_prefix IS NULL) AS zip_code_nulls,
    COUNT(*) FILTER (WHERE seller_city IS NULL) AS city_nulls,
    COUNT(*) FILTER (WHERE seller_state IS NULL) AS state_nulls
FROM sellers;           

-- Missing values: product_category_translation

SELECT
    COUNT(*) FILTER (WHERE product_category_name IS NULL) AS category_name_nulls,
    COUNT(*) FILTER (WHERE product_category_name_english IS NULL) AS english_name_nulls
FROM product_category_translation;      

-- Missing values: products

SELECT
    COUNT(*) FILTER (WHERE product_id IS NULL) AS product_id_nulls,
    COUNT(*) FILTER (WHERE product_category_name IS NULL) AS category_nulls,
    COUNT(*) FILTER (WHERE product_name_length IS NULL) AS name_length_nulls,
    COUNT(*) FILTER (WHERE product_description_length IS NULL) AS description_length_nulls,
    COUNT(*) FILTER (WHERE product_photos_qty IS NULL) AS photos_qty_nulls,
    COUNT(*) FILTER (WHERE product_weight_g IS NULL) AS weight_nulls,
    COUNT(*) FILTER (WHERE product_length_cm IS NULL) AS length_nulls,
    COUNT(*) FILTER (WHERE product_height_cm IS NULL) AS height_nulls,
    COUNT(*) FILTER (WHERE product_width_cm IS NULL) AS width_nulls
FROM products;

-- Missing values : orders

SELECT
    COUNT(*) FILTER (WHERE order_id IS NULL) AS order_id_nulls,
    COUNT(*) FILTER (WHERE customer_id IS NULL) AS customer_id_nulls,
    COUNT(*) FILTER (WHERE order_status IS NULL) AS status_nulls,
    COUNT(*) FILTER (WHERE order_purchase_timestamp IS NULL) AS purchase_nulls,
    COUNT(*) FILTER (WHERE order_approved_at IS NULL) AS approved_nulls,
    COUNT(*) FILTER (WHERE order_delivered_carrier_date IS NULL) AS carrier_nulls,
    COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL) AS delivered_nulls,
    COUNT(*) FILTER (WHERE order_estimated_delivery_date IS NULL) AS estimated_delivery_nulls
FROM orders;
-- Analysing the null value  
SELECT
    order_status,
    COUNT(*) AS total_orders,
    COUNT(*) FILTER (WHERE order_approved_at IS NULL) AS approved_nulls,
    COUNT(*) FILTER (WHERE order_delivered_carrier_date IS NULL) AS carrier_nulls,
    COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL) AS delivered_nulls
FROM orders
GROUP BY order_status
ORDER BY total_orders DESC;

-- Missing values: order_items

SELECT
    COUNT(*) FILTER (WHERE order_id IS NULL) AS order_id_nulls,
    COUNT(*) FILTER (WHERE order_item_id IS NULL) AS order_item_id_nulls,
    COUNT(*) FILTER (WHERE product_id IS NULL) AS product_id_nulls,
    COUNT(*) FILTER (WHERE seller_id IS NULL) AS seller_id_nulls,
    COUNT(*) FILTER (WHERE shipping_limit_date IS NULL) AS shipping_limit_nulls,
    COUNT(*) FILTER (WHERE price IS NULL) AS price_nulls,
    COUNT(*) FILTER (WHERE freight_value IS NULL) AS freight_value_nulls
FROM order_items;  

-- Missing values: order_payments

SELECT
    COUNT(*) FILTER (WHERE order_id IS NULL) AS order_id_nulls,
    COUNT(*) FILTER (WHERE payment_sequential IS NULL) AS sequential_nulls,
    COUNT(*) FILTER (WHERE payment_type IS NULL) AS payment_type_nulls,
    COUNT(*) FILTER (WHERE payment_installments IS NULL) AS installments_nulls,
    COUNT(*) FILTER (WHERE payment_value IS NULL) AS payment_value_nulls
FROM order_payments;

-- Missing values: reviews

SELECT
    COUNT(*) FILTER (WHERE review_id IS NULL) AS review_id_nulls,
    COUNT(*) FILTER (WHERE order_id IS NULL) AS order_id_nulls,
    COUNT(*) FILTER (WHERE review_score IS NULL) AS score_nulls,
    COUNT(*) FILTER (WHERE review_comment_title IS NULL) AS title_nulls,
    COUNT(*) FILTER (WHERE review_comment_message IS NULL) AS message_nulls,
    COUNT(*) FILTER (WHERE review_creation_date IS NULL) AS creation_date_nulls,
    COUNT(*) FILTER (WHERE review_answer_timestamp IS NULL) AS answer_date_nulls
FROM reviews;

-- NULL profiling findings:
-- customers: no NULLs.
-- sellers: no NULLs.
-- product_category_translation: no NULLs.
-- products: 610 product missing category name; 2 products lack physical measurements.
-- orders: missing delivery timestamps are mainly associated with non-delivered orders.
-- order_items: no NULLs.
-- order_payments: no NULLs.
-- reviews: comment title,message NULLs exists and are expected because comments are optional.
------------------------------------------------------------------------------------------------

-- 3. Date range for orders purchase

SELECT
    MIN(order_purchase_timestamp) AS first_order,
    MAX(order_purchase_timestamp) AS last_order
FROM orders;
--  "first_order": "2016-09-04 21:15:19"
--  "last_order": "2018-10-17 17:30:18"
