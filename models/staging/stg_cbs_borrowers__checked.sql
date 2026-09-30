{{ config(materialized='ephemeral') }}

with source as (
    select * from {{ ref('raw_cbs_borrowers') }}
),

typed as (
    select
        trim(borrower_id) as borrower_id,
        nullif(trim(full_name), '') as full_name,
        case lower(trim(gender))
            when 'm' then 'male' when 'male' then 'male'
            when 'f' then 'female' when 'female' then 'female'
            else null
        end as gender,
        trim(date_of_birth) as date_of_birth_raw,
        try_strptime(trim(date_of_birth), '%Y-%m-%d')::date as date_of_birth,
        nullif(regexp_replace(coalesce(mobile_no, ''), '[^0-9+]', '', 'g'), '') as mobile_no,
        nullif(trim(id_type), '') as id_type,
        nullif(upper(regexp_replace(coalesce(id_number, ''), '[^A-Za-z0-9]', '', 'g')), '') as id_number_norm,
        upper(trim(country)) as country,
        nullif(trim(branch), '') as branch,
        nullif(trim(office_id), '') as office_id,
        try_cast(created_on as date) as created_on
    from source
),

flagged as (
    select
        *,
        row_number() over (partition by borrower_id order by created_on desc nulls last) as _dedup_rank,
        list_filter([
            case when borrower_id is null or borrower_id = '' then 'missing borrower_id' end,
            case when full_name is null then 'missing full_name' end,
            case when country not in ('ET','KE','RW','SS','TD') then 'unrecognized country code: ' || country end,
            case when date_of_birth_raw is not null and date_of_birth_raw != '' and date_of_birth is null
                 then 'date_of_birth unparseable: ' || date_of_birth_raw end
        ], x -> x is not null) as validation_errors
    from typed
)

select
    *,
    (_dedup_rank > 1) as is_duplicate_key,
    len(validation_errors) > 0 or _dedup_rank > 1 as is_quarantined,
    list_concat(
        validation_errors,
        case when _dedup_rank > 1 then ['duplicate borrower_id, kept most recently created record'] else [] end
    ) as all_reasons
from flagged
