with customer_geo as (
  select
    customer_key,
    customer_name,
    customer_address,
    customer_phone,
    account_balance,
    segment_code,
    nation_key,
    nation_name,
    region_key,
    region_name
  from {{ ref('int_customer_geo') }}
)

select
  customer_key,
  customer_name,
  customer_address,
  customer_phone,
  account_balance,
  segment_code as market_segment,
  nation_key,
  nation_name,
  region_key,
  region_name
from customer_geo 