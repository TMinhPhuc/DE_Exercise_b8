SELECT
    TIMESTAMP_TRUNC(_airbyte_extracted_at, MINUTE) AS sync_minute,
    COUNT(*) AS row_count
FROM `cedar-turbine-511010-d3.stylehub_ab_bronze.products`
GROUP BY _airbyte_extracted_at;

--Bước 1a: Tạo dim_products_t1 từ các mốc cũ
CREATE OR REPLACE TABLE `cedar-turbine-511010-d3.stylehub_silver.dim_products_t1` AS
WITH products_ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER(
            PARTITION BY id
            ORDER BY updated_at DESC, _airbyte_extracted_at DESC
        ) AS rn
    FROM `cedar-turbine-511010-d3.stylehub_ab_bronze.products`
    WHERE _airbyte_extracted_at <= TIMESTAMP '2026-11-19 16:31:00 UTC'
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

--Bước 1b: Sao chép ra dim_products_t0
CREATE OR REPLACE TABLE `cedar-turbine-511010-d3.stylehub_silver.dim_products_t0` AS
SELECT * FROM `cedar-turbine-511010-d3.stylehub_silver.dim_products_t1`;

--Bước 1c: Sao chép ra dim_products_t2 và thêm cột lịch sử
CREATE OR REPLACE TABLE `cedar-turbine-511010-d3.stylehub_silver.dim_products_t2` AS
WITH date_start AS (
    SELECT
        MIN(created_at) AS start_at
    FROM `cedar-turbine-511010-d3.stylehub_ab_bronze.products`
)
SELECT
    GENERATE_UUID() AS product_key,
    t.product_id,
    t.name,
    t.brand,
    t.category,
    t.sku,
    t.department,
    t.cost,
    t.retail_price,
    t.created_at,
    t.updated_at,
    t.row_hash,
    TIMESTAMP(d.start_at) AS valid_from,
    CAST(NULL AS TIMESTAMP) AS valid_to,
    TRUE AS is_current
FROM `cedar-turbine-511010-d3.stylehub_silver.dim_products_t1` AS t
CROSS JOIN date_start AS d;

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

--Bước 3a: Chỉ thêm id mới, id cũ bỏ qua
INSERT INTO `cedar-turbine-511010-d3.stylehub_silver.dim_products_t0`
    (product_id, name, category, brand, sku, department, cost, retail_price, created_at, updated_at, row_hash)
SELECT s.product_id, s.name, s.category, s.brand, s.sku, s.department, s.cost, s.retail_price, s.created_at, s.updated_at, s.row_hash
FROM `cedar-turbine-511010-d3.stylehub_silver.stg_products` AS s
LEFT JOIN `cedar-turbine-511010-d3.stylehub_silver.dim_products_t0` AS d
ON s.product_id = d.product_id
WHERE d.product_id IS NULL;


--Bước 3b: Type 1 ghi đè dòng có hash khác rồi thêm type mới
UPDATE `cedar-turbine-511010-d3.stylehub_silver.dim_products_t1` AS d
SET
    name = s.name,
    brand = s.brand,
    category = s.category,
    sku = s.sku,
    department = s.department,
    cost = s.cost,
    retail_price = s.retail_price,
    updated_at = s.updated_at,
    row_hash = s.row_hash
FROM `cedar-turbine-511010-d3.stylehub_silver.stg_products` AS s
WHERE d.product_id = s.product_id AND d.row_hash != s.row_hash;

INSERT INTO `cedar-turbine-511010-d3.stylehub_silver.dim_products_t1`
    (product_id, name, category, brand, sku, department, cost, retail_price, created_at, updated_at, row_hash)
SELECT s.product_id, s.name, s.category, s.brand, s.sku, s.department, s.cost, s.retail_price, s.created_at, s.updated_at, s.row_hash
FROM `cedar-turbine-511010-d3.stylehub_silver.stg_products` AS s
LEFT JOIN `cedar-turbine-511010-d3.stylehub_silver.dim_products_t1` AS d
ON s.product_id = d.product_id
WHERE d.product_id IS NULL;

--Bước 3c: Type 2 đóng dòng cũ, thêm dòng mới
UPDATE `cedar-turbine-511010-d3.stylehub_silver.dim_products_t2` AS d
SET
    d.valid_to = TIMESTAMP(s.updated_at),
    is_current = FALSE
FROM `cedar-turbine-511010-d3.stylehub_silver.stg_products` AS s
WHERE d.product_id = s.product_id AND is_current AND d.row_hash != s.row_hash;

INSERT INTO `cedar-turbine-511010-d3.stylehub_silver.dim_products_t2`
    (product_key, product_id, name, category, brand, sku, department, cost,
    retail_price, created_at, updated_at, row_hash, valid_from, valid_to, is_current)
SELECT
    GENERATE_UUID(),
    s.product_id,
    s.name ,
    s.brand,
    s.category,
    s.sku,
    s.department,
    s.cost,
    s.retail_price,
    s.created_at,
    s.updated_at,
    s.row_hash,
    TIMESTAMP(s.updated_at),
    CAST(NULL AS TIMESTAMP),
    TRUE
FROM `cedar-turbine-511010-d3.stylehub_silver.stg_products` AS s
LEFT JOIN `cedar-turbine-511010-d3.stylehub_silver.dim_products_t2` AS d
ON s.product_id = d.product_id AND d.is_current
WHERE d.product_id IS NULL;