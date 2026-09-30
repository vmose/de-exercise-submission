{{ config(materialized='table') }}

with matched as (
    select * from {{ ref('int_party_matched') }}
),

enterprise_ids as (
    select
        match_key,
        'ECID-' || upper(substr(md5(match_key), 1, 10)) as enterprise_client_id
    from matched
    group by 1
)

select
    e.enterprise_client_id,
    m.source_system,
    m.source_id,
    m.match_tier,
    m.name_key,
    m.date_of_birth,
    m.country,
    m.id_key,
    m.phone_key,
    m.gender_norm,
    m.is_minor
from matched m
join enterprise_ids e on m.match_key = e.match_key
