{{ config(materialized='table') }}

-- B2: aggregated only — no client identifiers, names, phones, IDs or
-- locations, per Rule 4 (this is shared with an external donor). Every
-- column here is either a code (country), a calendar period, or a count/sum.

select
    country,
    strftime(disbursed_at, '%Y-%m') as month,
    currency,
    count(*) as loans_disbursed_count,
    round(sum(principal_local), 2) as loans_disbursed_local,
    round(sum(principal_usd), 2) as loans_disbursed_usd,
    round(avg(principal_usd), 2) as avg_loan_size_usd,
    count(*) filter (where status = 'active') as active_loans_count,
    count(*) filter (where status = 'closed') as closed_loans_count,
    count(distinct enterprise_client_id) as distinct_clients_count
from {{ ref('fct_loans') }}
group by 1, 2, 3
order by 1, 2, 3
