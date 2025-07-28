-- Trigger PR validation - testing CI/CD pipeline

with source as (
    select 
        o_orderkey,
        o_custkey,
        o_orderstatus,
        o_totalprice,
        o_orderdate,
        o_orderpriority,
        o_clerk,
        o_shippriority,
        o_comment
    from {{ source('tpch', 'orders') }}
),

transformed_orders as (
    select
        o_orderkey as order_key,
        o_custkey as customer_key,
        o_orderstatus as order_status,
        o_totalprice as total_price,
        o_orderdate as order_date,
        o_orderpriority as order_priority,
        o_clerk as clerk,
        o_shippriority as ship_priority,
        o_comment as order_comment
    from source
)

select
    order_key,
    customer_key,
    order_status,
    total_price,
    order_date,
    order_priority,
    clerk,
    ship_priority,
    order_comment
from transformed_orders 