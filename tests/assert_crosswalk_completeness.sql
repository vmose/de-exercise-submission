-- Every valid (DQ2-passed) ims_client and cbs_borrower record must appear in
-- the crosswalk exactly once. This fails (returns rows) if A2 silently
-- dropped or duplicated a valid source record.
with expected as (
    select 'ims' as source_system, ims_client_id as source_id from {{ ref('stg_ims_clients') }}
    union all
    select 'cbs' as source_system, borrower_id as source_id from {{ ref('stg_cbs_borrowers') }}
),
actual as (
    select source_system, source_id, count(*) as n
    from {{ ref('int_client_crosswalk') }}
    group by 1, 2
)
select e.source_system, e.source_id, coalesce(a.n, 0) as times_in_crosswalk
from expected e
left join actual a using (source_system, source_id)
where coalesce(a.n, 0) != 1
