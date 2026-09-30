{{ config(materialized='view') }}

select *
from read_csv_auto('dq_logs/dq4_results.csv', header = true)
