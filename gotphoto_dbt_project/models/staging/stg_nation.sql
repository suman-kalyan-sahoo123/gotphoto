with source as (
    select 
        n_nationkey,
        n_name,
        n_regionkey,
        n_comment
    from {{ source('tpch', 'nation') }}
),

transformed_nation as (
    select
        n_nationkey as nation_key,
        n_name as nation_name,
        n_regionkey as region_key,
        n_comment as nation_comment
    from source
)

select
    nation_key,
    nation_name,
    region_key,
    nation_comment
from transformed_nation 