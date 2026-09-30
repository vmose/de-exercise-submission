{{ config(materialized='table') }}

select
    ims_client_id,
    first_name,
    last_name,
    date_of_birth_raw,
    country_raw,
    all_reasons as quarantine_reasons,
    current_timestamp as quarantined_at
from {{ ref('stg_ims_clients__checked') }}
where is_quarantined
