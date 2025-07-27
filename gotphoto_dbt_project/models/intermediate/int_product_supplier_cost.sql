with base_part as (
  select
    part_key,
    part_name,
    manufacturer,
    brand,
    part_type,
    part_size,
    container,
    retail_price
  from {{ ref('stg_part') }}
),

base_partsupp as (
  select
    part_key,
    supplier_key,
    available_quantity,
    supply_cost
  from {{ ref('stg_partsupp') }}
),

base_supplier as (
  select
    supplier_key,
    supplier_name,
    nation_key,
    supplier_phone,
    account_balance as supplier_acctbal
  from {{ ref('stg_supplier') }}
)

select
  p.part_key,
  ps.supplier_key,
  p.part_name,
  p.manufacturer,
  p.brand,
  p.part_type,
  p.part_size,
  p.container,
  p.retail_price,
  ps.supply_cost,
  ps.available_quantity,
  s.supplier_name,
  s.nation_key,
  s.supplier_phone,
  s.supplier_acctbal
from base_part p
join base_partsupp ps
  on p.part_key = ps.part_key
join base_supplier s
  on ps.supplier_key = s.supplier_key 