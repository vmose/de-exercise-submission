{{ config(materialized='table') }}

select
    borrower_id,
    full_name,
    gender,
    date_of_birth,
    mobile_no,
    id_type,
    id_number_norm as id_number,
    country,
    branch,
    office_id,
    created_on
from {{ ref('stg_cbs_borrowers__checked') }}
where not is_quarantined
