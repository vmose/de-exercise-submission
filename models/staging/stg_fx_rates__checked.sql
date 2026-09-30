{{ config(materialized='ephemeral') }}

with source as (
    select * from {{ ref('raw_fx_rates') }}
),

typed as (
    select
        case when upper(trim(currency)) in ('KSH') then 'KES' else upper(trim(currency)) end as currency,
        try_cast(rate_date as date) as rate_date,
        lower(trim(rate_type)) as rate_type,
        {{ parse_number('units_per_usd') }} as units_per_usd,
        nullif(trim(source), '') as source,
        try_cast(published_at as timestamp) as published_at
    from source
),

flagged as (
    select
        *,
        row_number() over (
            partition by currency, rate_date, rate_type
            order by published_at desc nulls last
        ) as _dedup_rank,
        list_filter([
            case when currency not in ('ETB','KES','RWF','SSP','XAF') then 'unrecognized currency: ' || currency end,
            case when rate_date is null then 'rate_date missing or unparseable' end,
            case when rate_type not in ('official', 'parallel') then 'unrecognized rate_type: ' || rate_type end,
            case when units_per_usd is null or units_per_usd <= 0 then 'units_per_usd missing or not positive' end
        ], x -> x is not null) as validation_errors
    from typed
)

select
    *,
    (_dedup_rank > 1) as is_duplicate_key,
    len(validation_errors) > 0 or _dedup_rank > 1 as is_quarantined,
    list_concat(
        validation_errors,
        case when _dedup_rank > 1 then ['duplicate (currency, rate_date, rate_type), kept latest published_at'] else [] end
    ) as all_reasons
from flagged
