with base_nation as (
  select
    nation_key,
    nation_name,
    region_key,
    nation_comment
  from {{ ref('stg_nation') }}
),

base_region as (
  select
    region_key,
    region_name,
    region_comment
  from {{ ref('stg_region') }}
)

select
  n.nation_key,
  n.nation_name,
  n.nation_comment,
  r.region_key,
  r.region_name,
  r.region_comment
from base_nation n
left join base_region r on n.region_key = r.region_key 