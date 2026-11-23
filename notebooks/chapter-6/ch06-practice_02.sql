--Bước 1: Chọn 3 sản phẩm đã đổi giá gốc hoặc category
 -- 1. Kiểm tra các sản phẩm có nhiều hơn 1 phiên bản lịch sử trong bảng SCD Type 2
SELECT
  product_id,
  COUNT(*) AS version_count
FROM `cedar-turbine-511010-d3.stylehub_silver.dim_products_t2`
GROUP BY product_id
HAVING COUNT(*) > 1
ORDER BY product_id
LIMIT 20;

-- 2. Đối chiếu dữ liệu của sản phẩm có product_id = 1 trên 3 bảng SCD (Type 0, Type 1, Type 2)
SELECT product_id, category, cost, retail_price
FROM `cedar-turbine-511010-d3.stylehub_silver.dim_products_t0`
WHERE product_id = 1;

SELECT product_id, category, cost, retail_price
FROM `cedar-turbine-511010-d3.stylehub_silver.dim_products_t1`
WHERE product_id = 1;

SELECT product_id, category, cost, retail_price, valid_from, valid_to, is_current
FROM `cedar-turbine-511010-d3.stylehub_silver.dim_products_t2`
WHERE product_id = 1
ORDER BY valid_from;

--Bước 2a: dim_products_t0
SELECT
    p.category,
    SUM(f.amount) AS revenue,
    SUM(f.amount) - SUM(p.retail_price * f.quantity) AS profit
FROM `cedar-turbine-511010-d3.stylehub_silver.fact_order_items` AS f
JOIN `cedar-turbine-511010-d3.stylehub_silver.dim_products_t0` AS p
ON f.product_id = p.product_id
WHERE f.status != 'Cancelled'
    AND f.order_date >= DATE '2026-09-01'
    AND f.order_date < DATE '2026-12-01'
GROUP BY p.category
ORDER BY p.category;

--Bước 2b: dim_products_t1
SELECT
    p.category,
    SUM(f.amount) AS revenue,
    SUM(f.amount) - SUM(p.retail_price * f.quantity) AS profit
FROM `cedar-turbine-511010-d3.stylehub_silver.fact_order_items` AS f
JOIN `cedar-turbine-511010-d3.stylehub_silver.dim_products_t1` AS p
ON f.product_id = p.product_id
WHERE f.status != 'Cancelled'
    AND f.order_date >= DATE '2026-09-01'
    AND f.order_date < DATE '2026-12-01'
GROUP BY p.category
ORDER BY p.category;

--Bước 2c: dim_products_t2
SELECT
    p.category,
    SUM(f.amount) AS revenue,
    SUM(f.amount) - SUM(p.retail_price * f.quantity) AS profit
FROM `cedar-turbine-511010-d3.stylehub_silver.fact_order_items` AS f
JOIN `cedar-turbine-511010-d3.stylehub_silver.dim_products_t2` AS p
ON f.product_id = p.product_id
    AND p.is_current
    AND TIMESTAMP(f.order_date) >= p.valid_from
    AND ( p.valid_to IS NULL OR TIMESTAMP(f.order_date) < p.valid_from )
WHERE f.status != 'Cancelled'
    AND f.order_date >= DATE '2026-09-01'
    AND f.order_date < DATE '2026-12-01'
GROUP BY p.category
ORDER BY p.category;
