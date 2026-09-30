{{ config(materialized='table') }}

-- Loaded so DQ1/DQ2 cover it like every other source, but not used by any
-- mart or the identity crosswalk: no task requires it, and it carries
-- `sensitive`-classified screening decisions we have no declared need for
-- downstream. See DECISIONS.md.
select
    *,
    current_timestamp as _loaded_at
from read_csv_auto(
    '{{ var("validated_dir") }}/investment_screening.csv',
    all_varchar = true,
    header = true
)
