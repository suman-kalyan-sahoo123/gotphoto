with source as (
    select 
        r_regionkey,
        r_name,
        r_comment
    from {{ source('tpch', 'region') }}
),

transformed_region as (
    select
        r_regionkey as region_key,
        r_name as region_name,
        r_comment as region_comment
    from source
)

select
    region_key,
    region_name,
    region_comment
from transformed_region 