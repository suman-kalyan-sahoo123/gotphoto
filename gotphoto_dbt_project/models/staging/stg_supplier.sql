with source as (
    select 
        s_suppkey,
        s_name,
        s_address,
        s_nationkey,
        s_phone,
        s_acctbal,
        s_comment
    from {{ source('tpch', 'supplier') }}
),

transformed_supplier as (
    select
        s_suppkey as supplier_key,
        s_name as supplier_name,
        s_address as supplier_address,
        s_nationkey as nation_key,
        s_phone as supplier_phone,
        s_acctbal as account_balance,
        s_comment as supplier_comment
    from source
)

select
    supplier_key,
    supplier_name,
    supplier_address,
    nation_key,
    supplier_phone,
    account_balance,
    supplier_comment
from transformed_supplier 