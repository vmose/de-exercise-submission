{{ config(materialized='ephemeral') }}

with source as (
    select * from {{ ref('raw_cbs_control_totals') }}
),

typed as (
    select
        trim(source.country) as country_raw,
        cl.country_iso2 as country,
        trim(month) as month,
        case when upper(trim(currency)) in ('KSH') then 'KES' else upper(trim(currency)) end as currency,
        try_cast(loans_disbursed_count as integer) as loans_disbursed_count,
        {{ parse_number('loans_disbursed_amount') }} as loans_disbursed_amount,
        try_cast(repayments_count as integer) as repayments_count,
        {{ parse_number('repayments_amount') }} as repayments_amount
    from source
    left join {{ ref('country_lookup') }} cl on lower(trim(source.country)) = cl.lower_value
),

flagged as (
    select
        *,
        row_number() over (partition by country, month, currency order by 1) as _dedup_rank,
        list_filter([
            case when country_raw is not null and country is null then 'unrecognized country: ' || country_raw end,
            case when month !~ '^[0-9]{4}-[0-9]{2}$' then 'month not in YYYY-MM format: ' || month end,
            case when currency not in ('ETB','KES','RWF','SSP','XAF') then 'unrecognized currency: ' || currency end,
            case when loans_disbursed_count is null or loans_disbursed_count < 0 then 'invalid loans_disbursed_count' end,
            case when loans_disbursed_amount is null or loans_disbursed_amount < 0 then 'invalid loans_disbursed_amount' end,
            case when repayments_count is null or repayments_count < 0 then 'invalid repayments_count' end,
            case when repayments_amount is null or repayments_amount < 0 then 'invalid repayments_amount' end
        ], x -> x is not null) as validation_errors
    from typed
)

select
    *,
    (_dedup_rank > 1) as is_duplicate_key,
    len(validation_errors) > 0 or _dedup_rank > 1 as is_quarantined,
    list_concat(
        validation_errors,
        case when _dedup_rank > 1 then ['duplicate (country, month, currency)'] else [] end
    ) as all_reasons
from flagged
