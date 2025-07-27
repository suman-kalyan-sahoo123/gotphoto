with customer_orders as (
  select
    order_key,
    customer_key,
    order_date,
    order_status,
    order_priority,
    clerk,
    ship_priority
  from {{ ref('stg_orders') }}
),

order_line_items as (
  select
    order_key,
    line_number,
    part_key,
    supplier_key,
    quantity,
    extended_price,
    discount,
    tax,
    return_flag,
    line_status,
    ship_date,
    commit_date,
    receipt_date
  from {{ ref('stg_lineitem') }}
),

customer_geo as (
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
),

product_info as (
  select
    part_key,
    part_name,
    manufacturer,
    brand,
    part_type,
    part_size,
    container,
    retail_price
  from {{ ref('dim_product') }}
),

order_date_dim as (
  select
    date_key as order_date_key,
    year as order_year,
    quarter as order_quarter,
    month as order_month,
    month_name as order_month_name,
    quarter_name as order_quarter_name,
    day_type as order_day_type,
    season as order_season
  from {{ ref('dim_date') }}
),

ship_date_dim as (
  select
    date_key as ship_date_key,
    year as ship_year,
    quarter as ship_quarter,
    month as ship_month,
    month_name as ship_month_name,
    quarter_name as ship_quarter_name,
    day_type as ship_day_type,
    season as ship_season
  from {{ ref('dim_date') }}
),

order_aggregations as (
  select
    co.order_key,
    co.customer_key,
    co.order_date,
    co.order_status,
    co.order_priority,
    co.clerk,
    co.ship_priority,
    count(oli.line_number) as line_item_count,
    sum(oli.quantity) as total_quantity,
    sum(oli.extended_price) as total_gross_revenue,
    sum(oli.extended_price * oli.discount) as total_discount_amount,
    sum(oli.extended_price * (1 - oli.discount)) as total_net_revenue,
    sum(oli.extended_price * (1 - oli.discount) * oli.tax) as total_tax_amount,
    avg(oli.quantity) as avg_line_quantity,
    avg(oli.extended_price) as avg_line_revenue,
    min(oli.ship_date) as earliest_ship_date,
    max(oli.ship_date) as latest_ship_date,
    count(distinct oli.part_key) as unique_products,
    count(distinct oli.supplier_key) as unique_suppliers,
    sum(case when oli.return_flag = 'R' then 1 else 0 end) as returned_lines,
    sum(case when oli.line_status = 'F' then 1 else 0 end) as filled_lines
  from customer_orders co
  left join order_line_items oli on co.order_key = oli.order_key
  group by 
    co.order_key,
    co.customer_key,
    co.order_date,
    co.order_status,
    co.order_priority,
    co.clerk,
    co.ship_priority
)

select
  -- Fact table surrogate key
  row_number() over (order by oa.order_key) as customer_order_fact_key,
  
  -- Foreign keys
  oa.order_key,
  oa.customer_key,
  od.order_date_key,
  sd.ship_date_key,
  cg.nation_key,
  cg.region_key,
  
  -- Customer attributes
  cg.customer_name,
  cg.customer_address,
  cg.customer_phone,
  cg.account_balance,
  cg.segment_code as customer_segment,
  cg.nation_name as customer_nation,
  cg.region_name as customer_region,
  
  -- Order attributes
  oa.order_status,
  oa.order_priority,
  oa.clerk,
  oa.ship_priority,
  
  -- Time attributes
  od.order_year,
  od.order_quarter,
  od.order_month,
  od.order_month_name,
  od.order_quarter_name,
  od.order_day_type,
  od.order_season,
  sd.ship_year,
  sd.ship_quarter,
  sd.ship_month,
  sd.ship_month_name,
  sd.ship_quarter_name,
  sd.ship_day_type,
  sd.ship_season,
  
  -- Order metrics
  oa.line_item_count,
  oa.total_quantity,
  oa.total_gross_revenue,
  oa.total_discount_amount,
  oa.total_net_revenue,
  oa.total_tax_amount,
  oa.avg_line_quantity,
  oa.avg_line_revenue,
  oa.unique_products,
  oa.unique_suppliers,
  oa.returned_lines,
  oa.filled_lines,
  
  -- Calculated metrics
  case when oa.total_gross_revenue > 0 then oa.total_discount_amount / oa.total_gross_revenue else null end as order_discount_rate,
  case when oa.line_item_count > 0 then oa.total_quantity / oa.line_item_count else null end as avg_quantity_per_line,
  case when oa.line_item_count > 0 then oa.total_gross_revenue / oa.line_item_count else null end as avg_revenue_per_line,
  case when oa.line_item_count > 0 then oa.returned_lines / oa.line_item_count else null end as return_rate,
  case when oa.line_item_count > 0 then oa.filled_lines / oa.line_item_count else null end as fill_rate,
  
  -- Customer analysis flags
  case 
    when oa.total_quantity > 300 then 'Large Volume Customer'
    when oa.total_quantity > 100 then 'Medium Volume Customer'
    else 'Small Volume Customer'
  end as volume_category,
  
  case 
    when oa.total_gross_revenue > 100000 then 'High Value Customer'
    when oa.total_gross_revenue > 50000 then 'Medium Value Customer'
    else 'Low Value Customer'
  end as value_category,
  
  case 
    when oa.line_item_count > 10 then 'Complex Order'
    when oa.line_item_count > 5 then 'Standard Order'
    else 'Simple Order'
  end as order_complexity,
  
  case 
    when oa.unique_products > 5 then 'Multi-Product'
    when oa.unique_products > 1 then 'Multi-Product'
    else 'Single Product'
  end as product_diversity,
  
  case 
    when oa.unique_suppliers > 3 then 'Multi-Supplier'
    when oa.unique_suppliers > 1 then 'Multi-Supplier'
    else 'Single Supplier'
  end as supplier_diversity,
  
  -- Business logic flags
  case 
    when oa.total_quantity > 300 then true
    else false
  end as is_large_volume_order,
  
  case 
    when (case when oa.line_item_count > 0 then oa.returned_lines / oa.line_item_count else null end) > 0.1 then true
    else false
  end as has_high_returns,
  
  case 
    when (case when oa.line_item_count > 0 then oa.filled_lines / oa.line_item_count else null end) < 0.8 then true
    else false
  end as has_low_fill_rate

from order_aggregations oa
left join customer_geo cg on oa.customer_key = cg.customer_key
left join order_date_dim od on oa.order_date = od.order_date_key
left join ship_date_dim sd on oa.earliest_ship_date = sd.ship_date_key 