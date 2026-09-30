{{ config(materialized='table') }}

-- Raw layer only ever reads from validated/, never from source/ directly.
-- DQ1 (scripts/dq1_preflight.py) is what populates validated/, having already
-- dropped `excluded`-classified columns and rejected any file whose shape
-- doesn't match contracts/source_schemas.yml. Everything lands as VARCHAR
-- here; typing and validation happen in staging (DQ2), never before, so a
-- bad value quarantines a record instead of crashing the raw load.
select
    *,
    current_timestamp as _loaded_at
from read_csv_auto(
    '{{ var("validated_dir") }}/ims_clients.csv',
    all_varchar = true,
    header = true
)
