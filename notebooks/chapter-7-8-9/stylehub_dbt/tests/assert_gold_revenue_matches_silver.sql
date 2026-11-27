WITH revenue_by_month_category AS (
    SELECT
        DATE_TRUNC(DATE (o.order_date), MONTH) AS order_month,
        category,
        SUM(i.amount) AS revenue
    FROM {{ ref('fact_order_items') }} AS i
    LEFT JOIN {{ ref('dim_products') }} AS p
    ON i.product_id = p.product_id
    LEFT JOIN {{ ref('fact_orders') }} AS o
    ON i.order_id = o.order_id
    WHERE o.order_status NOT IN ('Cancelled', 'Returned')
        AND o.order_id IS NOT NULL
    GROUP BY DATE_TRUNC(DATE (o.order_date), MONTH), category
    ORDER BY DATE_TRUNC(DATE (o.order_date), MONTH), category
)
SELECT
    g.order_month,
    g.category,
    g.revenue AS gold_revenue,
    s.revenue AS silver_revenue
FROM {{ ref('gold_revenue_by_month_category') }} AS g
JOIN revenue_by_month_category AS s
ON g.order_month = s.order_month AND g.category = s.category
WHERE g.revenue != COALESCE(s.revenue, 0)