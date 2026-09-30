{{ config(materialized='table') }}

select
    currency,
    rate_date,
    rate_type,
    units_per_usd,
    source,
    published_at
from {{ ref('stg_fx_rates__checked') }}
where not is_quarantined
