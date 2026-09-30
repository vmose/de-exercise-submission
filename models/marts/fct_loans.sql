{{ config(materialized='table') }}

select
    l.loan_id,
    xw.enterprise_client_id,
    l.borrower_id,
    l.country,
    l.branch,
    l.product,
    l.currency,
    l.principal as principal_local,
    fx.units_per_usd as fx_rate_used,
    fx.rate_date as fx_rate_date,
    fx.fx_rate_is_estimated,
    round(l.principal / fx.units_per_usd, 2) as principal_usd,
    l.disbursed_at,
    l.term_months,
    l.interest_rate_pct,
    l.status,
    l.loan_officer,
    coalesce(xw.is_minor, false) as borrower_linked_to_minor_record  -- safeguarding flag, see DECISIONS.md; not for external sharing
from {{ ref('stg_cbs_loans') }} l
left join {{ ref('int_client_crosswalk') }} xw
    on xw.source_system = 'cbs' and xw.source_id = l.borrower_id
left join {{ ref('int_loan_fx') }} fx
    on fx.loan_id = l.loan_id
