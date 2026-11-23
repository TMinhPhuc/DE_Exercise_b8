-- fact_shipments
CREATE OR REPLACE TABLE `cedar-turbine-511010-d3.stylehub_silver.fact_shipments` AS
WITH shipments_ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER(
            PARTITION BY id
            ORDER BY updated_at DESC, _airbyte_extracted_at DESC
        ) AS rn
    FROM `cedar-turbine-511010-d3.stylehub_ab_bronze.shipments`
),
shipments_latest AS (
    SELECT * FROM shipments_ranked WHERE rn = 1
)
SELECT
    s.id AS shipment_id,
    s.order_id,
    f.user_id,
    s.shipped_at,
    s.returned_at,
    s.delivered_at,
    DATE_DIFF(DATE(s.delivered_at), DATE(s.shipped_at), DAY) AS ship_days
FROM shipments_latest AS s
LEFT JOIN `cedar-turbine-511010-d3.stylehub_silver.fact_orders` AS f
ON s.order_id = f.order_id;

--Kiểm tra grain
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT shipment_id) AS distinct_rows
FROM `cedar-turbine-511010-d3.stylehub_silver.fact_shipments`;