{{ config(materialized='table') }}

select
    currency,
    rate_date,
    rate_type,
    all_reasons as quarantine_reasons,
    current_timestamp as quarantined_at
from {{ ref('stg_fx_rates__checked') }}
where is_quarantined
