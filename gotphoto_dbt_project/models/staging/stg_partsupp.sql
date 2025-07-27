with source as (
    select 
        ps_partkey,
        ps_suppkey,
        ps_availqty,
        ps_supplycost,
        ps_comment
    from {{ source('tpch', 'partsupp') }}
),

transformed_partsupp as (
    select
        ps_partkey as part_key,
        ps_suppkey as supplier_key,
        ps_availqty as available_quantity,
        ps_supplycost as supply_cost,
        ps_comment as partsupp_comment
    from source
)

select
    part_key,
    supplier_key,
    available_quantity,
    supply_cost,
    partsupp_comment
from transformed_partsupp 