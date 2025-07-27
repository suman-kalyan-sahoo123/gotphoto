with supplier_orders as (
  select
    li.supplier_key,
    li.order_key,
    li.line_number,
    li.part_key,
    li.quantity,
    li.extended_price,
    li.discount,
    li.tax,
    li.return_flag,
    li.line_status,
    li.ship_date,
    o.order_date,
    o.customer_key
  from {{ ref('stg_lineitem') }} li
  left join {{ ref('stg_orders') }} o on li.order_key = o.order_key
),

supplier_geo as (
  select
    supplier_key,
    supplier_name,
    supplier_address,
    supplier_phone,
    account_balance,
    nation_key,
    nation_name,
    region_key,
    region_name
  from {{ ref('dim_supplier') }}
),

partsupp_info as (
  select
    part_key,
    supplier_key,
    available_quantity,
    supply_cost
  from {{ ref('stg_partsupp') }}
),

order_date_dim as (
  select
    date_key as order_date_key,
    year as order_year,
    quarter as order_quarter,
    month as order_month,
    month_name as order_month_name,
    quarter_name as order_quarter_name
  from {{ ref('dim_date') }}
),

supplier_aggregations as (
  select
    so.supplier_key,
    count(distinct so.order_key) as total_orders,
    count(so.line_number) as total_line_items,
    sum(so.quantity) as total_quantity_supplied,
    sum(so.extended_price) as total_gross_revenue,
    sum(so.extended_price * so.discount) as total_discount_amount,
    sum(so.extended_price * (1 - so.discount)) as total_net_revenue,
    sum(so.extended_price * (1 - so.discount) * so.tax) as total_tax_amount,
    count(distinct so.part_key) as unique_products_supplied,
    count(distinct so.customer_key) as unique_customers_served,
    sum(case when so.return_flag = 'R' then 1 else 0 end) as total_returned_lines,
    sum(case when so.line_status = 'F' then 1 else 0 end) as total_filled_lines,
    min(so.order_date) as first_order_date,
    max(so.order_date) as last_order_date,
    avg(so.quantity) as avg_quantity_per_line,
    avg(so.extended_price) as avg_revenue_per_line,
    count(distinct extract(year from so.order_date)) as years_active,
    count(distinct extract(month from so.order_date)) as months_active
  from supplier_orders so
  group by so.supplier_key
),

supplier_cost_analysis as (
  select
    ps.supplier_key,
    count(distinct ps.part_key) as total_products_available,
    sum(ps.available_quantity) as total_available_quantity,
    avg(ps.supply_cost) as avg_supply_cost,
    min(ps.supply_cost) as min_supply_cost,
    max(ps.supply_cost) as max_supply_cost,
    sum(ps.available_quantity * ps.supply_cost) as total_inventory_value
  from partsupp_info ps
  group by ps.supplier_key
)

select
  -- Fact table surrogate key
  row_number() over (order by sa.supplier_key) as supplier_summary_fact_key,
  
  -- Foreign keys
  sa.supplier_key,
  sg.nation_key,
  sg.region_key,
  od_first.order_date_key as first_order_date_key,
  od_last.order_date_key as last_order_date_key,
  
  -- Supplier attributes
  sg.supplier_name,
  sg.supplier_address,
  sg.supplier_phone,
  sg.account_balance,
  sg.nation_name as supplier_nation,
  sg.region_name as supplier_region,
  
  -- Supplier performance metrics
  sa.total_orders,
  sa.total_line_items,
  sa.total_quantity_supplied,
  sa.total_gross_revenue,
  sa.total_discount_amount,
  sa.total_net_revenue,
  sa.total_tax_amount,
  sa.unique_products_supplied,
  sa.unique_customers_served,
  sa.total_returned_lines,
  sa.total_filled_lines,
  sa.first_order_date,
  sa.last_order_date,
  sa.avg_quantity_per_line,
  sa.avg_revenue_per_line,
  sa.years_active,
  sa.months_active,
  
  -- Supplier cost metrics
  sca.total_products_available,
  sca.total_available_quantity,
  sca.avg_supply_cost,
  sca.min_supply_cost,
  sca.max_supply_cost,
  sca.total_inventory_value,
  
  -- Calculated supplier metrics
  case when sa.total_orders > 0 then sa.total_gross_revenue / sa.total_orders else null end as avg_order_value,
  case when sa.total_orders > 0 then sa.total_quantity_supplied / sa.total_orders else null end as avg_order_quantity,
  case when sa.total_line_items > 0 then sa.total_quantity_supplied / sa.total_line_items else null end as avg_quantity_per_line_item,
  case when sa.total_line_items > 0 then sa.total_gross_revenue / sa.total_line_items else null end as avg_revenue_per_line_item,
  case when sa.total_gross_revenue > 0 then sa.total_discount_amount / sa.total_gross_revenue else null end as supplier_discount_rate,
  case when sa.total_line_items > 0 then sa.total_returned_lines / sa.total_line_items else null end as supplier_return_rate,
  case when sa.total_line_items > 0 then sa.total_filled_lines / sa.total_line_items else null end as supplier_fill_rate,
  case when sa.years_active > 0 then sa.total_orders / sa.years_active else null end as orders_per_year,
  case when sa.years_active > 0 then sa.total_gross_revenue / sa.years_active else null end as revenue_per_year,
  case when sca.total_products_available > 0 then sa.unique_products_supplied / sca.total_products_available else null end as product_utilization_rate,
  
  -- Supplier value categories
  case 
    when sa.total_gross_revenue > 1000000 then 'Platinum Supplier'
    when sa.total_gross_revenue > 500000 then 'Gold Supplier'
    when sa.total_gross_revenue > 200000 then 'Silver Supplier'
    when sa.total_gross_revenue > 100000 then 'Bronze Supplier'
    else 'Standard Supplier'
  end as supplier_tier,
  
  case 
    when sa.total_quantity_supplied > 5000 then 'High Volume'
    when sa.total_quantity_supplied > 2000 then 'Medium Volume'
    when sa.total_quantity_supplied > 500 then 'Low Volume'
    else 'Minimal Volume'
  end as volume_tier,
  
  case 
    when sa.total_orders > 50 then 'Frequent Supplier'
    when sa.total_orders > 20 then 'Regular Supplier'
    when sa.total_orders > 10 then 'Occasional Supplier'
    else 'Infrequent Supplier'
  end as frequency_tier,
  
  case 
    when sa.unique_products_supplied > 20 then 'Diverse Portfolio'
    when sa.unique_products_supplied > 10 then 'Varied Portfolio'
    when sa.unique_products_supplied > 5 then 'Moderate Portfolio'
    else 'Limited Portfolio'
  end as portfolio_tier,
  
  case 
    when sa.unique_customers_served > 20 then 'Wide Customer Base'
    when sa.unique_customers_served > 10 then 'Moderate Customer Base'
    when sa.unique_customers_served > 5 then 'Limited Customer Base'
    else 'Narrow Customer Base'
  end as customer_reach_tier,
  
  -- Business logic flags
  case 
    when sa.total_quantity_supplied > 1000 then true
    else false
  end as is_high_volume_supplier,
  
  case 
    when sa.total_gross_revenue > 500000 then true
    else false
  end as is_high_value_supplier,
  
  case 
    when (case when sa.total_line_items > 0 then sa.total_returned_lines / sa.total_line_items else null end) > 0.1 then true
    else false
  end as has_high_return_rate,
  
  case 
    when (case when sa.total_line_items > 0 then sa.total_filled_lines / sa.total_line_items else null end) < 0.8 then true
    else false
  end as has_low_fill_rate,
  
  case 
    when sa.years_active > 2 then true
    else false
  end as is_long_term_supplier,
  
  case 
    when sa.unique_customers_served > 10 then true
    else false
  end as has_broad_customer_base

from supplier_aggregations sa
left join supplier_geo sg on sa.supplier_key = sg.supplier_key
left join supplier_cost_analysis sca on sa.supplier_key = sca.supplier_key
left join order_date_dim od_first on sa.first_order_date = od_first.order_date_key
left join order_date_dim od_last on sa.last_order_date = od_last.order_date_key 