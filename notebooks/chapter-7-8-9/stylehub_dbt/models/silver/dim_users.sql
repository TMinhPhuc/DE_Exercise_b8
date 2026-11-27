with ranked as (
    select
        *,
        {{ latest_rank() }} as rn
    from {{ source('stylehub_bronze', 'users') }}
)

select
    id as user_id,
    first_name,
    last_name,
    email,
    age,
    gender,
    street_address,
    city,
    state,
    postal_code,
    country,
    latitude,
    longitude,
    traffic_source,
    created_at,
    updated_at
from ranked
where rn = 1