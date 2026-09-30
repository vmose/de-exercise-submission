{{ config(materialized='table') }}

select
    txn_id,
    loan_id,
    currency,
    all_reasons as quarantine_reasons,
    current_timestamp as quarantined_at
from {{ ref('stg_cbs_repayments__checked') }}
where is_quarantined
