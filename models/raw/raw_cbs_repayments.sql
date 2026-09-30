{{ config(materialized='incremental', unique_key='txn_id', incremental_strategy='merge') }}

-- Repayments arrive as one file per day (validated/cbs_repayments/*.csv:
-- only files that passed DQ1 land here — cbs_repayments_day2.csv did not,
-- see contracts/source_schemas.yml and dq_logs/dq1_results.csv). Merging on
-- txn_id means: re-running the pipeline on the same file is a no-op (A1,
-- idempotent), and a later day's file that introduces a new txn_id is added
-- without duplicating anything already loaded. A day's file that repeats a
-- txn_id (e.g. a corrected re-extract) replaces that row rather than
-- duplicating it.
select
    txn_id,
    loan_id,
    paid_at,
    amount,
    currency,
    channel,
    reversal_of,
    filename as _source_file,
    current_timestamp as _loaded_at
from read_csv_auto(
    '{{ var("validated_dir") }}/cbs_repayments/*.csv',
    all_varchar = true,
    header = true,
    filename = true
)
