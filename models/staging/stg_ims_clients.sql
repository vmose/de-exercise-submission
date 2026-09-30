{{ config(materialized='table') }}

select
    ims_client_id,
    first_name,
    middle_name,
    last_name,
    sex,
    date_of_birth,
    phone_1_norm as phone_1,
    phone_2_norm as phone_2,
    country,
    location,
    household_id,
    relationship_to_head,
    id_document_type,
    id_document_number_norm as id_document_number,
    registration_date,
    business_sector,
    registered_by,
    source_form,
    updated_at,
    notes,
    (date_diff('year', date_of_birth, cast('{{ var("as_of_date") }}' as date))
        - case when date_add(date_of_birth, interval (date_diff('year', date_of_birth, cast('{{ var("as_of_date") }}' as date))) year)
                    > cast('{{ var("as_of_date") }}' as date)
               then 1 else 0 end) < 18 as is_minor
from {{ ref('stg_ims_clients__checked') }}
where not is_quarantined
