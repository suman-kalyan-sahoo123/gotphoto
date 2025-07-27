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
    ship_date
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

customer_order_aggregations as (
  select
    co.customer_key,
    count(distinct co.order_key) as total_orders,
    count(oli.line_number) as total_line_items,
    sum(oli.quantity) as total_quantity_ordered,
    sum(oli.extended_price) as total_gross_revenue,
    sum(oli.extended_price * oli.discount) as total_discount_amount,
    sum(oli.extended_price * (1 - oli.discount)) as total_net_revenue,
    sum(oli.extended_price * (1 - oli.discount) * oli.tax) as total_tax_amount,
    count(distinct oli.part_key) as unique_products_ordered,
    count(distinct oli.supplier_key) as unique_suppliers_used,
    sum(case when oli.return_flag = 'R' then 1 else 0 end) as total_returned_lines,
    sum(case when oli.line_status = 'F' then 1 else 0 end) as total_filled_lines,
    min(co.order_date) as first_order_date,
    max(co.order_date) as last_order_date,
    avg(oli.quantity) as avg_quantity_per_line,
    avg(oli.extended_price) as avg_revenue_per_line,
    count(distinct extract(year from co.order_date)) as years_active,
    count(distinct extract(month from co.order_date)) as months_active
  from customer_orders co
  left join order_line_items oli on co.order_key = oli.order_key
  group by co.customer_key
)

select
  -- Fact table surrogate key
  row_number() over (order by csa.customer_key) as customer_summary_fact_key,
  
  -- Foreign keys
  csa.customer_key,
  cg.nation_key,
  cg.region_key,
  od_first.order_date_key as first_order_date_key,
  od_last.order_date_key as last_order_date_key,
  
  -- Customer attributes
  cg.customer_name,
  cg.customer_address,
  cg.customer_phone,
  cg.account_balance,
  cg.segment_code as customer_segment,
  cg.nation_name as customer_nation,
  cg.region_name as customer_region,
  
  -- Customer lifetime metrics
  csa.total_orders,
  csa.total_line_items,
  csa.total_quantity_ordered,
  csa.total_gross_revenue,
  csa.total_discount_amount,
  csa.total_net_revenue,
  csa.total_tax_amount,
  csa.unique_products_ordered,
  csa.unique_suppliers_used,
  csa.total_returned_lines,
  csa.total_filled_lines,
  csa.first_order_date,
  csa.last_order_date,
  csa.avg_quantity_per_line,
  csa.avg_revenue_per_line,
  csa.years_active,
  csa.months_active,
  
  -- Calculated customer metrics
  case when csa.total_orders > 0 then csa.total_gross_revenue / csa.total_orders else null end as avg_order_value,
  case when csa.total_orders > 0 then csa.total_quantity_ordered / csa.total_orders else null end as avg_order_quantity,
  case when csa.total_line_items > 0 then csa.total_quantity_ordered / csa.total_line_items else null end as avg_quantity_per_line_item,
  case when csa.total_line_items > 0 then csa.total_gross_revenue / csa.total_line_items else null end as avg_revenue_per_line_item,
  case when csa.total_gross_revenue > 0 then csa.total_discount_amount / csa.total_gross_revenue else null end as customer_discount_rate,
  case when csa.total_line_items > 0 then csa.total_returned_lines / csa.total_line_items else null end as customer_return_rate,
  case when csa.total_line_items > 0 then csa.total_filled_lines / csa.total_line_items else null end as customer_fill_rate,
  case when csa.years_active > 0 then csa.total_orders / csa.years_active else null end as orders_per_year,
  case when csa.years_active > 0 then csa.total_gross_revenue / csa.years_active else null end as revenue_per_year,
  
  -- Customer value categories
  case 
    when csa.total_gross_revenue > 500000 then 'Platinum Customer'
    when csa.total_gross_revenue > 200000 then 'Gold Customer'
    when csa.total_gross_revenue > 100000 then 'Silver Customer'
    when csa.total_gross_revenue > 50000 then 'Bronze Customer'
    else 'Standard Customer'
  end as customer_tier,
  
  case 
    when csa.total_quantity_ordered > 1000 then 'High Volume'
    when csa.total_quantity_ordered > 500 then 'Medium Volume'
    when csa.total_quantity_ordered > 100 then 'Low Volume'
    else 'Minimal Volume'
  end as volume_tier,
  
  case 
    when csa.total_orders > 20 then 'Frequent Buyer'
    when csa.total_orders > 10 then 'Regular Buyer'
    when csa.total_orders > 5 then 'Occasional Buyer'
    else 'Infrequent Buyer'
  end as frequency_tier,
  
  case 
    when csa.unique_products_ordered > 20 then 'Diverse Portfolio'
    when csa.unique_products_ordered > 10 then 'Varied Portfolio'
    when csa.unique_products_ordered > 5 then 'Moderate Portfolio'
    else 'Limited Portfolio'
  end as portfolio_tier,
  
  -- Business logic flags
  case 
    when csa.total_quantity_ordered > 300 then true
    else false
  end as is_large_volume_customer,
  
  case 
    when csa.total_gross_revenue > 100000 then true
    else false
  end as is_high_value_customer,
  
  case 
    when (case when csa.total_line_items > 0 then csa.total_returned_lines / csa.total_line_items else null end) > 0.1 then true
    else false
  end as has_high_return_rate,
  
  case 
    when (case when csa.total_line_items > 0 then csa.total_filled_lines / csa.total_line_items else null end) < 0.8 then true
    else false
  end as has_low_fill_rate,
  
  case 
    when csa.years_active > 2 then true
    else false
  end as is_long_term_customer

from customer_order_aggregations csa
left join customer_geo cg on csa.customer_key = cg.customer_key
left join order_date_dim od_first on csa.first_order_date = od_first.order_date_key
left join order_date_dim od_last on csa.last_order_date = od_last.order_date_key 