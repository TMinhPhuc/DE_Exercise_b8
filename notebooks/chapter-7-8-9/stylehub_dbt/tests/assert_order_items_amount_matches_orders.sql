WITH order_items AS (
    SELECT
        order_id,
        SUM(amount) AS calculated_amount
    FROM {{ ref('fact_order_items') }}
    GROUP BY order_id
)
SELECT
    o.order_id,
    o.total_amount,
    i.calculated_amount
FROM {{ ref('fact_orders') }} AS o
JOIN order_items AS i
ON o.order_id = i.order_id
WHERE o.total_amount != coalesce(i.calculated_amount, 0)
