--Dataset Silver và Gold
CREATE SCHEMA IF NOT EXISTS `cedar-turbine-511010-d3.stylehub_silver` OPTIONS (location = 'asia-southeast1');
CREATE SCHEMA IF NOT EXISTS `cedar-turbine-511010-d3.stylehub_golden` OPTIONS (location = 'asia-southeast1');

--dim_products
CREATE OR REPLACE TABLE `cedar-turbine-511010-d3.stylehub_silver.dim_products` AS
WITH RANKED AS (
    SElECT
        *,
        ROW_NUMBER() OVER(
          PARTITION BY id
          ORDER BY updated_at DESC, _airbyte_extracted_at DESC
        ) AS rn
    FROM `cedar-turbine-511010-d3.stylehub_ab_bronze.products`
)
SELECT
    id AS product_id,
    name AS product_name,
    brand,
    category,
    sku,
    cost
FROM RANKED
WHERE rn = 1;

--fact_order_items
CREATE OR REPLACE TABLE `cedar-turbine-511010-d3.stylehub_silver.fact_order_items` AS
WITH orders_ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER(
          PARTITION BY id
          ORDER BY updated_at DESC, _airbyte_extracted_at DESC
        ) as rn
    FROM `cedar-turbine-511010-d3.stylehub_ab_bronze.orders`
),
orders_latest AS (
    SELECT * FROM orders_ranked WHERE rn = 1
),
order_items_ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER(
          PARTITION BY id
          ORDER BY updated_at DESC, _airbyte_extracted_at DESC
        ) AS rn
    FROM `cedar-turbine-511010-d3.stylehub_ab_bronze.order_items`
),
order_items_latest AS (
    SELECT * FROM order_items_ranked WHERE rn = 1
)
SELECT
    i.id AS order_item_id,
    i.order_id,
    i.product_id,
    o.user_id,
    o.status,
    DATE(o.created_at) AS order_date,
    i.amount,
    i.sale_price,
    i.quantity,
    p.cost * i.quantity AS total_cost
FROM order_items_latest i
JOIN orders_latest o
ON i.order_id = o.id
LEFT JOIN `cedar-turbine-511010-d3.stylehub_silver.dim_products` p
ON i.product_id = p.product_id;

--Kiểm tra gain
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT order_item_id) AS distinct_row
FROM `cedar-turbine-511010-d3.stylehub_silver.fact_order_items`;