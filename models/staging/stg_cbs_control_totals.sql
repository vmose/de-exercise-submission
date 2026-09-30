{{ config(materialized='table') }}

select
    country,
    month,
    currency,
    loans_disbursed_count,
    loans_disbursed_amount,
    repayments_count,
    repayments_amount
from {{ ref('stg_cbs_control_totals__checked') }}
where not is_quarantined
