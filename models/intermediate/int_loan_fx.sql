{{ config(materialized='table') }}

-- B1: which exchange rate, and why.
--
-- We use fx_rates.csv's 'official' rate as of the loan's disbursement date
-- (the most recent official rate on or before disbursed_at), not:
--   - cbs_loans.cbs_fx_rate / principal_usd_cbs: CBS's own embedded
--     conversion is simply missing for every KES-denominated loan (a bug in
--     the source system, see DATA_QUALITY.md) so it cannot be relied on
--     uniformly across countries.
--   - the 'parallel' rate: not the rate a bank or donor would expect for
--     official reporting.
--   - the latest/current rate: would misstate the USD value of loans
--     disbursed months ago as currencies move.
--
-- A loan disbursed before the first published official rate for its
-- currency falls back to the earliest available official rate and is
-- flagged `fx_rate_is_estimated` so it can be told apart in the mart.

with loans as (
    select loan_id, currency, disbursed_at from {{ ref('stg_cbs_loans') }}
),

official_rates as (
    select currency, rate_date, units_per_usd
    from {{ ref('stg_fx_rates') }}
    where rate_type = 'official'
),

as_of_match as (
    select
        l.loan_id,
        f.units_per_usd,
        f.rate_date,
        false as fx_rate_is_estimated,
        row_number() over (partition by l.loan_id order by f.rate_date desc) as rn
    from loans l
    join official_rates f
        on f.currency = l.currency
        and f.rate_date <= cast(l.disbursed_at as date)
),

fallback_match as (
    select
        l.loan_id,
        f.units_per_usd,
        f.rate_date,
        true as fx_rate_is_estimated,
        row_number() over (partition by l.loan_id order by f.rate_date asc) as rn
    from loans l
    join official_rates f on f.currency = l.currency
    where l.loan_id not in (select loan_id from as_of_match where rn = 1)
)

select loan_id, units_per_usd, rate_date, fx_rate_is_estimated from as_of_match where rn = 1
union all
select loan_id, units_per_usd, rate_date, fx_rate_is_estimated from fallback_match where rn = 1
