-- fact_orders
CREATE OR REPLACE TABLE `cedar-turbine-511010-d3.stylehub_silver.fact_orders` AS
WITH orders_ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER(
            PARTITION BY id
            ORDER BY updated_at DESC, _airbyte_extracted_at DESC
        ) AS rn
    FROM `cedar-turbine-511010-d3.stylehub_ab_bronze.orders`
),
orders_latest AS (
    SELECT
        *
    FROM orders_ranked
    WHERE rn = 1
)
SELECT
    id AS order_id,
    user_id,
    status,
    total_amount,
    DATE(created_at) AS order_date,
    IF(status = 'Returned', 1, 0) AS is_returned
FROM orders_latest;

--dim_users
CREATE OR REPLACE TABLE `cedar-turbine-511010-d3.stylehub_silver.dim_users` AS
WITH users_ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER(
            PARTITION BY id
            ORDER BY updated_at DESC, _airbyte_extracted_at DESC
        ) AS rn
    FROM `cedar-turbine-511010-d3.stylehub_ab_bronze.users`
)
users_latest AS (
    SELECT * FROM users_ranked WHERE rn = 1
)
SELECT
    id AS user_id,
    first_name,
    last_name,
    age,
    gender,
    email,
    street_address,
    city,
    state,
    country,
    latitude,
    longitude,
    traffic_source,
    postal_code,
    traffic_source
FROM users_latest;

--Kiểm tra khóa nối
SELECT COUNT(*) AS missing_users
FROM `cedar-turbine-511010-d3.stylehub_silver.fact_orders` f
LEFT JOIN `cedar-turbine-511010-d3.stylehub_silver.dim_users` d
ON f.user_id = d.user_id
WHERE d.user_id IS NULL;