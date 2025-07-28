<<<<<<< HEAD

=======
-- FORCE TRIGGER: Testing GitHub Actions workflow
>>>>>>> e26799d (testing cicd)
-- Trigger PR validation - testing CI/CD pipeline
-- Test comment to trigger GitHub Actions


with source as (
    select 
        c_custkey,
        c_name,
        c_address,
        c_nationkey,
        c_phone,
        c_acctbal,
        c_mktsegment,
        c_comment
    from {{ source('tpch', 'customer') }}
),

transformed_customers as (
    select
        c_custkey as customer_key,
        c_name as customer_name,
        c_address as customer_address,
        c_nationkey as nation_key,
        c_phone as customer_phone,
        c_acctbal as account_balance,
        c_mktsegment as market_segment,
        c_comment as customer_comment
    from source
)

select
    customer_key,
    customer_name,
    customer_address,
    nation_key,
    customer_phone,
    account_balance,
    market_segment,
    customer_comment
from transformed_customers
