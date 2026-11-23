--Bước 1: Bronze products đã sync những lần nào
SELECT
    TIMESTAMP_TRUNC(_airbyte_extracted_at, MINUTE) AS sync_minute,
    COUNT(*) AS ROW_COUNT
FROM `cedar-turbine-511010-d3.stylehub_ab_bronze.products`
GROUP BY sync_minute;

--Bước 2: id nào có từ 2 phiên bản trở lên
SELECT
    id,
    COUNT(*) AS ROW_COUNT,
    COUNT(DISTINCT TO_HEX(MD5(TO_JSON_STRING(STRUCT(name, brand, category, department, cost, retail_price, sku))))) AS version_count
FROM `cedar-turbine-511010-d3.stylehub_ab_bronze.products`
GROUP BY id
HAVING COUNT(DISTINCT TO_HEX(MD5(TO_JSON_STRING(STRUCT(name, brand, category, department, cost, retail_price, sku))))) >= 2;

--Bước 3: Xem phiên bản của một sản phẩm
SELECT id, name, category, cost, retail_price, updated_at, _airbyte_extracted_at
FROM `cedar-turbine-511010-d3.stylehub_ab_bronze.products`
WHERE id = 1
ORDER BY _airbyte_extracted_at;

--Bước 4: Nếu chỉ lấy bản mới nhất, đơn cũ tính theo gì
WITH products_ranked AS (
    SElECT
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
    p.category AS latest_category,
    p.cost AS latest_cost,
    COUNT(f.order_item_id) AS old_item_count,
    SUM(f.amount) AS old_revenue
FROM products_latest AS p
JOIN `cedar-turbine-511010-d3.stylehub_silver.fact_order_items` AS f
ON p.id = f.product_id
GROUP BY p.category, p.cost;