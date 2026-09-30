{{ config(materialized='view') }}

-- Exposes scripts/dq1_preflight.py's log (one row per file, per run) as a
-- table, so DQ1 leaves a record reviewers can query as well as read as CSV.
select *
from read_csv_auto('dq_logs/dq1_results.csv', header = true)
