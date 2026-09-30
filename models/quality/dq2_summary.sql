{{ config(materialized='table') }}

select 'ims_clients' as source_name,
    (select count(*) from {{ ref('raw_ims_clients') }}) as raw_count,
    (select count(*) from {{ ref('stg_ims_clients') }}) as passed_count,
    (select count(*) from {{ ref('stg_ims_clients_quarantine') }}) as quarantined_count
union all
select 'cbs_borrowers',
    (select count(*) from {{ ref('raw_cbs_borrowers') }}),
    (select count(*) from {{ ref('stg_cbs_borrowers') }}),
    (select count(*) from {{ ref('stg_cbs_borrowers_quarantine') }})
union all
select 'cbs_loans',
    (select count(*) from {{ ref('raw_cbs_loans') }}),
    (select count(*) from {{ ref('stg_cbs_loans') }}),
    (select count(*) from {{ ref('stg_cbs_loans_quarantine') }})
union all
select 'cbs_repayments',
    (select count(*) from {{ ref('raw_cbs_repayments') }}),
    (select count(*) from {{ ref('stg_cbs_repayments') }}),
    (select count(*) from {{ ref('stg_cbs_repayments_quarantine') }})
union all
select 'fx_rates',
    (select count(*) from {{ ref('raw_fx_rates') }}),
    (select count(*) from {{ ref('stg_fx_rates') }}),
    (select count(*) from {{ ref('stg_fx_rates_quarantine') }})
union all
select 'cbs_control_totals',
    (select count(*) from {{ ref('raw_cbs_control_totals') }}),
    (select count(*) from {{ ref('stg_cbs_control_totals') }}),
    (select count(*) from {{ ref('stg_cbs_control_totals_quarantine') }})
