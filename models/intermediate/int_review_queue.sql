{{ config(materialized='table') }}

-- Candidates for a human to look at: records in different systems that
-- share a normalized phone number and country but did NOT clear tier 1 or
-- tier 2 (different match_key), so they were kept as separate identities.
-- A shared phone can mean the same person, or a spouse/relative sharing a
-- household line — a person should decide, not the pipeline.

with a as (select * from {{ ref('int_party_matched') }}),
     b as (select * from {{ ref('int_party_matched') }})

select distinct
    a.source_system as system_a, a.source_id as source_id_a, a.match_key as match_key_a,
    b.source_system as system_b, b.source_id as source_id_b, b.match_key as match_key_b,
    a.phone_key, a.country
from a
join b
    on a.phone_key = b.phone_key
    and a.country = b.country
    and a.source_system != b.source_system
    and a.match_key != b.match_key
where a.phone_key is not null
