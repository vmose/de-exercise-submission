{{ config(materialized='table') }}

select
    loan_id,
    borrower_id,
    country,
    branch,
    product,
    currency,
    principal,
    disbursed_at,
    term_months,
    interest_rate_pct,
    status,
    cbs_fx_rate,
    principal_usd_cbs,
    loan_officer
from {{ ref('stg_cbs_loans__checked') }}
where not is_quarantined
