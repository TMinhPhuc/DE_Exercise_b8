SELECT
    DATE_TRUNC(DATE (o.order_date), MONTH) AS order_month,
    category,
    COUNT(DISTINCT i.order_id) AS total_orders,
    SUM(i.amount) AS revenue,
    SUM(i.amount - i.total_cost) AS profit
FROM {{ ref('fact_order_items') }} AS i
LEFT JOIN {{ ref('dim_products') }} AS p
ON i.product_id = p.product_id
LEFT JOIN {{ ref('fact_orders') }} AS o
ON i.order_id = o.order_id
WHERE p.product_id IS NOT NULL
    AND o.order_status NOT IN ('Cancelled', 'Returned')
    AND o.order_id IS NOT NULL
GROUP BY DATE_TRUNC(DATE (o.order_date), MONTH), category
ORDER BY DATE_TRUNC(DATE (o.order_date), MONTH), category