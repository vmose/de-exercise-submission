{{ config(materialized='table') }}

select
    *,
    current_timestamp as _loaded_at
from read_csv_auto(
    '{{ var("validated_dir") }}/cbs_control_totals.csv',
    all_varchar = true,
    header = true
)
