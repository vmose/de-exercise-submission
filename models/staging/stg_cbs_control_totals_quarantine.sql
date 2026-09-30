{{ config(materialized='table') }}

select
    country_raw,
    month,
    currency,
    all_reasons as quarantine_reasons,
    current_timestamp as quarantined_at
from {{ ref('stg_cbs_control_totals__checked') }}
where is_quarantined
