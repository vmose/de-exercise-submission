{{ config(materialized='table') }}

-- A3: reconcile our own totals, computed straight from the validated,
-- DQ2-passed cbs_loans / cbs_repayments records, against the totals CBS
-- itself published in cbs_control_totals.csv. This checks our load, not
-- CBS's numbers — we treat cbs_control_totals as the ground truth to match,
-- per the task ("reconcile ... against cbs_control_totals.csv").
--
-- Grain: country x month x currency, for two figures: loans disbursed and
-- repayments received. Repayments don't carry country directly, so we join
-- to the loan for country; a repayment whose loan was quarantined already
-- dropped out in staging (DQ2), which is itself a reason a total might not
-- tie out — see DATA_QUALITY.md.
--
-- Tolerance: see DECISIONS.md for why we chose
-- {{ var('reconciliation_tolerance_pct') * 100 }}% of the control-total
-- figure (not a fixed currency amount), applied on both count and amount.

with computed_loans as (
    select
        country,
        strftime(disbursed_at, '%Y-%m') as month,
        currency,
        count(*) as loans_disbursed_count,
        sum(principal) as loans_disbursed_amount
    from {{ ref('stg_cbs_loans') }}
    group by 1, 2, 3
),

computed_repayments as (
    select
        l.country,
        strftime(r.paid_at, '%Y-%m') as month,
        r.currency,
        count(*) as repayments_count,
        sum(r.amount) as repayments_amount
    from {{ ref('stg_cbs_repayments') }} r
    join {{ ref('stg_cbs_loans') }} l on r.loan_id = l.loan_id
    group by 1, 2, 3
),

-- control totals use full country names; map to the same iso2 code used everywhere else
control as (
    select * from {{ ref('stg_cbs_control_totals') }}
),

joined as (
    select
        coalesce(control.country, cl.country, cr.country) as country,
        coalesce(control.month, cl.month, cr.month) as month,
        coalesce(control.currency, cl.currency, cr.currency) as currency,
        control.loans_disbursed_count as control_loans_count,
        control.loans_disbursed_amount as control_loans_amount,
        control.repayments_count as control_repayments_count,
        control.repayments_amount as control_repayments_amount,
        cl.loans_disbursed_count as computed_loans_count,
        cl.loans_disbursed_amount as computed_loans_amount,
        cr.repayments_count as computed_repayments_count,
        cr.repayments_amount as computed_repayments_amount
    from control
    full outer join computed_loans cl
        on control.country = cl.country and control.month = cl.month and control.currency = cl.currency
    full outer join computed_repayments cr
        on coalesce(control.country, cl.country) = cr.country
        and coalesce(control.month, cl.month) = cr.month
        and coalesce(control.currency, cl.currency) = cr.currency
),

evaluated as (
    select
        *,
        coalesce(computed_loans_count, 0) - coalesce(control_loans_count, 0) as loans_count_diff,
        coalesce(computed_loans_amount, 0) - coalesce(control_loans_amount, 0) as loans_amount_diff,
        coalesce(computed_repayments_count, 0) - coalesce(control_repayments_count, 0) as repayments_count_diff,
        coalesce(computed_repayments_amount, 0) - coalesce(control_repayments_amount, 0) as repayments_amount_diff
    from joined
)

select
    *,
    abs(loans_count_diff) <= greatest(1, control_loans_count * {{ var('reconciliation_tolerance_pct') }})
        as loans_count_pass,
    abs(loans_amount_diff) <= greatest(1, abs(control_loans_amount) * {{ var('reconciliation_tolerance_pct') }})
        as loans_amount_pass,
    abs(repayments_count_diff) <= greatest(1, control_repayments_count * {{ var('reconciliation_tolerance_pct') }})
        as repayments_count_pass,
    abs(repayments_amount_diff) <= greatest(1, abs(control_repayments_amount) * {{ var('reconciliation_tolerance_pct') }})
        as repayments_amount_pass
from evaluated
order by country, month, currency
