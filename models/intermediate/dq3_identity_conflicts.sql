{{ config(materialized='table') }}

select
    enterprise_client_id,
    system_count,
    ims_record_count,
    cbs_record_count,
    distinct_country_count,
    distinct_dob_count
from (
    select
        enterprise_client_id,
        count(distinct source_system) as system_count,
        count(*) filter (where source_system = 'ims') as ims_record_count,
        count(*) filter (where source_system = 'cbs') as cbs_record_count,
        count(distinct country) as distinct_country_count,
        count(distinct date_of_birth) as distinct_dob_count
    from {{ ref('int_client_crosswalk') }}
    group by 1
)
where distinct_country_count > 1 or distinct_dob_count > 1
