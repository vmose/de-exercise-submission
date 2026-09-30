{{ config(materialized='table') }}

select
    loan_id,
    borrower_id,
    country,
    currency,
    all_reasons as quarantine_reasons,
    current_timestamp as quarantined_at
from {{ ref('stg_cbs_loans__checked') }}
where is_quarantined
