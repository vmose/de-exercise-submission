{{ config(materialized='table') }}

select
    borrower_id,
    full_name,
    country,
    all_reasons as quarantine_reasons,
    current_timestamp as quarantined_at
from {{ ref('stg_cbs_borrowers__checked') }}
where is_quarantined
