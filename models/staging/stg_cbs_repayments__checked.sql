{{ config(materialized='ephemeral') }}

with source as (
    select * from {{ ref('raw_cbs_repayments') }}
),

typed as (
    select
        trim(txn_id) as txn_id,
        trim(loan_id) as loan_id,
        try_cast(paid_at as timestamp) as paid_at,
        {{ parse_number('amount') }} as amount,
        case
            when upper(trim(currency)) in ('KSH') then 'KES'
            else upper(trim(currency))
        end as currency,
        nullif(trim(channel), '') as channel,
        nullif(trim(reversal_of), '') as reversal_of
    from source
),

flagged as (
    select
        t.*,
        l.loan_id is not null as loan_found,
        row_number() over (partition by t.txn_id order by t.paid_at desc nulls last) as _dedup_rank,
        list_filter([
            case when t.txn_id is null or t.txn_id = '' then 'missing txn_id' end,
            case when t.loan_id is null or t.loan_id = '' then 'missing loan_id' end,
            case when t.loan_id is not null and l.loan_id is null
                 then 'loan_id not found in valid cbs_loans (missing or quarantined upstream): ' || t.loan_id end,
            case when t.paid_at is null then 'paid_at missing or unparseable' end,
            case when t.amount is null then 'amount missing or unparseable' end,
            case when t.currency not in ('ETB','KES','RWF','SSP','XAF') then 'unrecognized currency: ' || t.currency end,
            case when t.amount is not null and t.amount < 0 and t.reversal_of is null
                 then 'negative amount without a reversal_of reference' end,
            case when t.amount is not null and t.amount = 0 then 'zero amount transaction' end
        ], x -> x is not null) as validation_errors
    from typed t
    left join {{ ref('stg_cbs_loans') }} l on t.loan_id = l.loan_id
)

select
    *,
    (_dedup_rank > 1) as is_duplicate_key,
    len(validation_errors) > 0 or _dedup_rank > 1 as is_quarantined,
    list_concat(
        validation_errors,
        case when _dedup_rank > 1 then ['duplicate txn_id'] else [] end
    ) as all_reasons
from flagged
