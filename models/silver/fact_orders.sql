with ranked as (
    select
        *,
        row_number() over (
            partition by id
            order by updated_at desc, _airbyte_extracted_at desc
        ) as rn
    from {{ source('stylehub_bronze', 'orders') }}
)
select
    *
from ranked