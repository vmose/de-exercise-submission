{{ config(materialized='table') }}

select
    txn_id,
    loan_id,
    paid_at,
    amount,
    currency,
    channel,
    reversal_of
from {{ ref('stg_cbs_repayments__checked') }}
where not is_quarantined
