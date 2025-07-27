with base_supplier as (
  select
    supplier_key,
    supplier_name,
    supplier_address,
    nation_key,
    supplier_phone,
    account_balance,
    supplier_comment
  from {{ ref('stg_supplier') }}
),

base_nation as (
  select
    nation_key,
    nation_name,
    region_key
  from {{ ref('stg_nation') }}
),

base_region as (
  select
    region_key,
    region_name
  from {{ ref('stg_region') }}
)

select
  s.supplier_key,
  s.supplier_name,
  s.supplier_address,
  s.supplier_phone,
  s.account_balance,
  s.supplier_comment,
  n.nation_key,
  n.nation_name,
  r.region_key,
  r.region_name
from base_supplier s
left join base_nation n on s.nation_key = n.nation_key
left join base_region r on n.region_key = r.region_key 