select
    *
from {{ ref('fact_order_items') }}
where amount != quantity * sale_price