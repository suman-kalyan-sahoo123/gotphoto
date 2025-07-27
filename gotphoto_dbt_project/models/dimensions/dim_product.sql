with base_part as (
  select
    part_key,
    part_name,
    manufacturer,
    brand,
    part_type,
    part_size,
    container,
    retail_price,
    part_comment
  from {{ ref('stg_part') }}
)

select
  part_key,
  part_name,
  manufacturer,
  brand,
  part_type,
  part_size,
  container,
  retail_price,
  part_comment
from base_part 