{{ config(materialized='table') }}

-- DQ3, after identity resolution (A2): matched / unmatched / review-queue
-- counts, and any enterprise_client_id whose linked records disagree on a
-- core attribute (country or date_of_birth) despite being merged — this can
-- happen on a tier-1 (ID number) match where the two systems recorded a
-- different DOB or country for the same physical ID, and is worth a human's
-- attention even though the merge itself is high-confidence.

with per_ecid as (
    select
        enterprise_client_id,
        count(*) as record_count,
        count(distinct source_system) as system_count,
        count(*) filter (where source_system = 'ims') as ims_record_count,
        count(*) filter (where source_system = 'cbs') as cbs_record_count,
        count(distinct country) as distinct_country_count,
        count(distinct date_of_birth) as distinct_dob_count,
        min(match_tier) as match_tier
    from {{ ref('int_client_crosswalk') }}
    group by 1
),

summary as (
    select
        count(*) as total_enterprise_clients,
        count(*) filter (where system_count = 2) as matched_across_systems,
        count(*) filter (where system_count = 1 and ims_record_count > 0 and cbs_record_count = 0) as ims_only_unmatched,
        count(*) filter (where system_count = 1 and cbs_record_count > 0 and ims_record_count = 0) as cbs_only_unmatched,
        count(*) filter (where match_tier = 'id_number') as matched_via_id_number,
        count(*) filter (where match_tier = 'name_dob_country') as matched_via_name_dob_country,
        count(*) filter (where distinct_country_count > 1 or distinct_dob_count > 1) as conflicting_attribute_ecids,
        (select count(*) from {{ ref('int_review_queue') }}) as review_queue_pairs
    from per_ecid
)

select * from summary
