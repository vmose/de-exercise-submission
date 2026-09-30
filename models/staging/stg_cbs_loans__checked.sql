{{ config(materialized='ephemeral') }}

with source as (
    select * from {{ ref('raw_cbs_loans') }}
),

typed as (
    select
        trim(loan_id) as loan_id,
        trim(borrower_id) as borrower_id,
        upper(trim(country)) as country,
        nullif(trim(branch), '') as branch,
        nullif(trim(product), '') as product,
        case
            when upper(trim(currency)) in ('KSH') then 'KES'
            else upper(trim(currency))
        end as currency,
        {{ parse_number('principal') }} as principal,
        try_cast(disbursed_at as timestamp) as disbursed_at,
        try_cast(term_months as integer) as term_months,
        {{ parse_number('interest_rate_pct') }} as interest_rate_pct,
        case
            when lower(trim(status)) like 'active%' then 'active'
            when lower(trim(status)) like 'closed%' then 'closed'
            else null
        end as status,
        {{ parse_number('cbs_fx_rate') }} as cbs_fx_rate,
        {{ parse_number('principal_usd_cbs') }} as principal_usd_cbs,
        nullif(trim(loan_officer), '') as loan_officer
    from source
),

flagged as (
    select
        t.*,
        b.borrower_id is not null as borrower_found,
        row_number() over (partition by t.loan_id order by t.disbursed_at desc nulls last) as _dedup_rank,
        list_filter([
            case when t.loan_id is null or t.loan_id = '' then 'missing loan_id' end,
            case when t.borrower_id is null or t.borrower_id = '' then 'missing borrower_id' end,
            case when t.borrower_id is not null and b.borrower_id is null
                 then 'borrower_id not found in valid cbs_borrowers (missing or quarantined upstream): ' || t.borrower_id end,
            case when t.country not in ('ET','KE','RW','SS','TD') then 'unrecognized country code: ' || t.country end,
            case when t.currency not in ('ETB','KES','RWF','SSP','XAF') then 'unrecognized currency: ' || t.currency end,
            case when t.principal is null then 'principal missing or unparseable' end,
            case when t.principal is not null and t.principal <= 0 then 'principal not positive' end,
            case when t.disbursed_at is null then 'disbursed_at missing or unparseable' end,
            case when t.status is null then 'unrecognized loan status' end
        ], x -> x is not null) as validation_errors
    from typed t
    left join {{ ref('stg_cbs_borrowers') }} b on t.borrower_id = b.borrower_id
)

select
    *,
    (_dedup_rank > 1) as is_duplicate_key,
    len(validation_errors) > 0 or _dedup_rank > 1 as is_quarantined,
    list_concat(
        validation_errors,
        case when _dedup_rank > 1 then ['duplicate loan_id'] else [] end
    ) as all_reasons
from flagged
