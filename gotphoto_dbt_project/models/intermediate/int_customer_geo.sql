with base_customer as (
  select
    customer_key,
    customer_name,
    customer_address,
    nation_key,
    customer_phone,
    account_balance,
    market_segment,
    customer_comment
  from {{ ref('stg_customers') }}
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
  c.customer_key,
  c.customer_name,
  c.customer_address,
  c.customer_phone,
  c.account_balance,
  lower(c.market_segment)            as segment_code,
  n.nation_key,
  n.nation_name,
  r.region_key,
  r.region_name
from base_customer c
left join base_nation n on c.nation_key = n.nation_key
left join base_region r on n.region_key = r.region_key 