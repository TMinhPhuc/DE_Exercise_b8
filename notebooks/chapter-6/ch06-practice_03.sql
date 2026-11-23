SELECT
    TIMESTAMP_TRUNC(_airbyte_extracted_at, MINUTE) AS sync_minute,
    COUNT(*) AS row_count
FROM `cedar-turbine-511010-d3.stylehub_ab_bronze.products`
GROUP BY _airbyte_extracted_at;

--Bước 1: Tạo bảng dim_products_t3 từ mốc cũ
CREATE OR REPLACE TABLE `cedar-turbine-511010-d3.stylehub_silver.dim_products_t3` AS
WITH ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER(
            PARTITION BY id
            ORDER BY updated_at DESC, _airbyte_extracted_at DESC
        ) AS rn
    FROM `cedar-turbine-511010-d3.stylehub_ab_bronze.products`
    WHERE _airbyte_extracted_at <=  TIMESTAMP '2026-11-19 16:31:00 UTC'
)
SELECT
    id AS product_id,
    name AS product_name,
    category,
    brand,
    sku,
    department,
    cost,
    retail_price,
    created_at,
    updated_at,
    CAST(NULL AS FLOAT64) AS previus_retail_retail_price
FROM ranked
WHERE rn = 1;

--Bước 2: Áp dụng stg_products
UPDATE `cedar-turbine-511010-d3.stylehub_silver.dim_products_t3` AS d
SET
    retail_price = s.retail_price,
    previus_retail_price = d.retail_price,
    updated_at = s.updated_at
FROM `cedar-turbine-511010-d3.stylehub_silver.stg_products` AS s
WHERE d.product_id = s.product_id
    AND d.retail_price IS DISTINCT FROM s.retail_price;

INSERT INTO `cedar-turbine-511010-d3.stylehub_silver.dim_products_t3`
    (product_id, name, category, brand, sku, department, cost, retail_price, created_at, updated_at, previus_retail_price)
SELECT
    s.product_id,
    s.name AS product_name,
    s.brand,
    s.category,
    s.sku,
    s.department,
    s.cost,
    s.retail_price,
    s.created_at,
    s.updated_at,
    CAST(NULL AS FLOAT64)
FROM `cedar-turbine-511010-d3.stylehub_silver.stg_products` AS s
LEFT JOIN `cedar-turbine-511010-d3.stylehub_silver.dim_products_t3` AS d
ON s.product_id = d.product_id
WHERE d.product_id IS NULL;

--Bước 3: Chạy lại stg_products
CREATE OR REPLACE TABLE `cedar-turbine-511010-d3.stylehub_silver.stg_products` AS
WITH products_ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER(
            PARTITION BY id
            ORDER BY updated_at DESC, _airbyte_extracted_at DESC
        ) AS rn
    FROM `cedar-turbine-511010-d3.stylehub_ab_bronze.products`
),
products_latest AS (
    SELECT * FROM products_ranked WHERE rn = 1
)
SELECT
    id as product_id,
    name,
    brand,
    category,
    sku,
    department,
    cost,
    retail_price,
    created_at,
    updated_at,
    TO_HEX(MD5(TO_JSON_STRING(STRUCT(cost, category, name, brand, retail_price, department, sku)))) AS row_hash
FROM products_latest;

