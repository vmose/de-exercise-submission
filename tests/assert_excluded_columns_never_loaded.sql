-- Rule 2: columns classified `excluded` must never be loaded anywhere,
-- including raw. fingerprint_template_ref (cbs_borrowers) is the one
-- example in this data set. This fails if it's ever found in the raw table.
select column_name
from information_schema.columns
where table_schema = 'main_raw'
  and table_name = 'raw_cbs_borrowers'
  and column_name = 'fingerprint_template_ref'
