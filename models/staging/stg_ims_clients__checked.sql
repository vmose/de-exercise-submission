{{ config(materialized='ephemeral') }}

-- DQ2, per record, in staging: type/format/required-field/allowed-value/
-- duplicate checks. A record that fails any rule is quarantined with its
-- reason(s), never dropped. See stg_ims_clients (pass) and
-- stg_ims_clients_quarantine (fail) below, and DATA_QUALITY.md for the
-- issue list this uncovered.

with source as (
    select * from {{ ref('raw_ims_clients') }}
),

typed as (
    select
        trim(ims_client_id) as ims_client_id,
        nullif(trim(first_name), '') as first_name,
        nullif(trim(middle_name), '') as middle_name,
        nullif(trim(last_name), '') as last_name,
        lower(trim(sex)) as sex_raw,
        case lower(trim(sex))
            when 'male' then 'male'
            when 'm' then 'male'
            when 'female' then 'female'
            when 'f' then 'female'
            else null
        end as sex,
        trim(date_of_birth) as date_of_birth_raw,
        coalesce(
            try_strptime(trim(date_of_birth), '%Y-%m-%d'),
            try_strptime(trim(date_of_birth), '%d/%m/%Y')
        )::date as date_of_birth,
        nullif(regexp_replace(coalesce(phone_1, ''), '[^0-9+]', '', 'g'), '') as phone_1_norm,
        nullif(regexp_replace(coalesce(phone_2, ''), '[^0-9+]', '', 'g'), '') as phone_2_norm,
        trim(country) as country_raw,
        cl.country_iso2 as country,
        nullif(trim(location), '') as location,
        nullif(trim(household_id), '') as household_id,
        nullif(lower(trim(relationship_to_head)), '') as relationship_to_head,
        nullif(trim(id_document_type), '') as id_document_type,
        nullif(upper(regexp_replace(coalesce(id_document_number, ''), '[^A-Za-z0-9]', '', 'g')), '') as id_document_number_norm,
        try_strptime(trim(registration_date), '%Y-%m-%d')::date as registration_date,
        nullif(trim(business_sector), '') as business_sector,
        nullif(trim(registered_by), '') as registered_by,
        nullif(trim(source_form), '') as source_form,
        try_cast(updated_at as timestamp) as updated_at,
        nullif(trim(notes), '') as notes
    from source
    left join {{ ref('country_lookup') }} cl
        on lower(trim(source.country)) = cl.lower_value
),

flagged as (
    select
        *,
        row_number() over (
            partition by ims_client_id
            order by updated_at desc nulls last, registration_date desc nulls last
        ) as _dedup_rank,
        list_filter([
            case when ims_client_id is null or ims_client_id = '' then 'missing ims_client_id' end,
            case when first_name is null and last_name is null then 'missing both first_name and last_name' end,
            case when date_of_birth_raw is not null and date_of_birth_raw != '' and date_of_birth is null
                 then 'date_of_birth present but unparseable: ' || date_of_birth_raw end,
            case when date_of_birth is null then 'missing date_of_birth' end,
            case when country_raw is not null and country_raw != '' and country is null
                 then 'unrecognized country value: ' || country_raw end,
            case when country_raw is null or country_raw = '' then 'missing country' end
        ], x -> x is not null) as validation_errors
    from typed
)

select
    *,
    (_dedup_rank > 1) as is_duplicate_key,
    len(validation_errors) > 0 or _dedup_rank > 1 as is_quarantined,
    list_concat(
        validation_errors,
        case when _dedup_rank > 1 then ['duplicate ims_client_id, kept most recently updated record'] else [] end
    ) as all_reasons
from flagged
