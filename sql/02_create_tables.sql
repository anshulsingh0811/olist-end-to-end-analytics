-- 1_Create customers table with  customer_id as primary key

CREATE TABLE customers (
    customer_id TEXT PRIMARY KEY,
    customer_unique_id TEXT,
    customer_zip_code_prefix INT,
    customer_city TEXT,
    customer_state CHAR(2)
);

-- 2_Create sellers table with seller_id as primary key

CREATE TABLE sellers (
    seller_id TEXT PRIMARY KEY,
    seller_zip_code_prefix INT,
    seller_city TEXT,
    seller_state CHAR(2)
);

-- 3_Create product_category_name_translation table 

CREATE TABLE product_category_translation (
    product_category_name TEXT PRIMARY KEY,
    product_category_name_english TEXT
);

-- 4_Create products table with product_id as primary key

CREATE TABLE products (
    product_id TEXT PRIMARY KEY,
    product_category_name TEXT,
    product_name_length INT,
    product_description_length INT,
    product_photos_qty INT,
    product_weight_g INT,
    product_length_cm INT,
    product_height_cm INT,
    product_width_cm INT,
    FOREIGN KEY (product_category_name) REFERENCES product_category_translation(product_category_name)
);

-- 5_Create order table with order_id as primary key

CREATE TABLE orders (
    order_id TEXT PRIMARY KEY,
    customer_id TEXT,
    order_status TEXT,
    order_purchase_timestamp TIMESTAMP,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- 6_Create order_items table 

CREATE TABLE order_items (
    order_id TEXT,
    order_item_id INT,
    product_id TEXT,
    seller_id TEXT,
    shipping_limit_date TIMESTAMP,
    price NUMERIC(10,2),
    freight_value NUMERIC(10,2),
    PRIMARY KEY (order_id, order_item_id),
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    FOREIGN KEY (seller_id) REFERENCES sellers(seller_id)
); 

-- 7. Create reviews table
-- Note: review_id is not unique in the raw dataset.
-- Composite key (review_id, order_id) uniquely identifies review records.

CREATE TABLE reviews (
    review_id TEXT,
    order_id TEXT,
    review_score INT,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date TIMESTAMP,
    review_answer_timestamp TIMESTAMP,
    PRIMARY KEY (review_id, order_id),
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

-- 8_Create order_payments table

CREATE TABLE order_payments (
    order_id Text,
    payment_sequential INT,
    payment_type TEXT,
    payment_installments INT,
    payment_value NUMERIC(10,2),
    PRIMARY KEY(order_id,payment_sequential),
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
);


--Droping Foreign key from products table  
ALTER TABLE products
DROP CONSTRAINT products_product_category_name_fkey;

