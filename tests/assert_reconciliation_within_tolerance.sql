-- Fails (returns rows) if any country/month/currency reconciliation figure
-- is outside tolerance. This is the test DQ4 checks before publishing B1/B2.
select *
from {{ ref('int_reconciliation') }}
where not (loans_count_pass and loans_amount_pass and repayments_count_pass and repayments_amount_pass)
