{{ config(materialized='table') }}

-- A2: one row per source record (advisory or banking), normalized onto a
-- common shape so matching rules can treat both systems the same way.
-- name_key is order- and punctuation-invariant (sorted lowercase tokens) so
-- "ABDI HAWA" and "Hawa Abdi" compare equal, and so does extra whitespace or
-- a dropped middle name.

with ims as (
    select
        'ims' as source_system,
        ims_client_id as source_id,
        {{ name_key("coalesce(first_name, '') || ' ' || coalesce(last_name, '')") }} as name_key,
        date_of_birth,
        country,
        id_document_number as id_key,
        phone_1 as phone_key,
        sex as gender_norm,
        is_minor
    from {{ ref('stg_ims_clients') }}
),

cbs as (
    select
        'cbs' as source_system,
        borrower_id as source_id,
        {{ name_key('full_name') }} as name_key,
        date_of_birth,
        country,
        id_number as id_key,
        mobile_no as phone_key,
        gender as gender_norm,
        false as is_minor  -- cbs population is banking clients; minor flag only tracked from the advisory system
    from {{ ref('stg_cbs_borrowers') }}
)

select * from ims
union all
select * from cbs
