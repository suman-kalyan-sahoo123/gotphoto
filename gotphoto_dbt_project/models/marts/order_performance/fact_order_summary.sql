with order_line_items as (
  select
    li.order_key,
    li.line_number,
    li.part_key,
    li.supplier_key,
    li.quantity,
    li.extended_price,
    li.discount,
    li.tax,
    li.return_flag,
    li.line_status,
    li.ship_date,
    li.commit_date,
    li.receipt_date,
    li.ship_instruct,
    li.ship_mode
  from {{ ref('stg_lineitem') }} li
),

order_info as (
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
    quarter_name as order_quarter_name,
    day_type as order_day_type,
    season as order_season
  from {{ ref('dim_date') }}
),

order_aggregations as (
  select
    oi.order_key,
    oi.customer_key,
    oi.order_date,
    oi.order_status,
    oi.order_priority,
    oi.clerk,
    oi.ship_priority,
    count(oli.line_number) as line_item_count,
    sum(oli.quantity) as total_quantity,
    sum(oli.extended_price) as total_gross_revenue,
    sum(oli.extended_price * oli.discount) as total_discount_amount,
    sum(oli.extended_price * (1 - oli.discount)) as total_net_revenue,
    sum(oli.extended_price * (1 - oli.discount) * oli.tax) as total_tax_amount,
    count(distinct oli.part_key) as unique_products,
    count(distinct oli.supplier_key) as unique_suppliers,
    sum(case when oli.return_flag = 'R' then 1 else 0 end) as returned_lines,
    sum(case when oli.line_status = 'F' then 1 else 0 end) as filled_lines,
    min(oli.ship_date) as earliest_ship_date,
    max(oli.ship_date) as latest_ship_date,
    min(oli.commit_date) as earliest_commit_date,
    max(oli.commit_date) as latest_commit_date,
    min(oli.receipt_date) as earliest_receipt_date,
    max(oli.receipt_date) as latest_receipt_date,
    avg(oli.quantity) as avg_line_quantity,
    avg(oli.extended_price) as avg_line_revenue,
    count(distinct oli.ship_mode) as shipping_methods_used,
    count(distinct oli.ship_instruct) as shipping_instructions_used
  from order_info oi
  left join order_line_items oli on oi.order_key = oli.order_key
  group by
    oi.order_key,
    oi.customer_key,
    oi.order_date,
    oi.order_status,
    oi.order_priority,
    oi.clerk,
    oi.ship_priority
),

order_time_analysis as (
  select
    oa.order_key,
    oa.earliest_ship_date,
    oa.latest_ship_date,
    oa.earliest_commit_date,
    oa.latest_commit_date,
    oa.earliest_receipt_date,
    oa.latest_receipt_date,
    -- Time calculations
    datediff('day', oa.order_date, oa.earliest_ship_date) as order_to_first_ship_days,
    datediff('day', oa.order_date, oa.latest_ship_date) as order_to_last_ship_days,
    datediff('day', oa.order_date, oa.earliest_commit_date) as order_to_first_commit_days,
    datediff('day', oa.order_date, oa.latest_commit_date) as order_to_last_commit_days,
    datediff('day', oa.order_date, oa.earliest_receipt_date) as order_to_first_receipt_days,
    datediff('day', oa.order_date, oa.latest_receipt_date) as order_to_last_receipt_days,
    datediff('day', oa.earliest_commit_date, oa.earliest_ship_date) as first_commit_to_ship_days,
    datediff('day', oa.earliest_ship_date, oa.earliest_receipt_date) as first_ship_to_receipt_days,
    datediff('day', oa.latest_ship_date, oa.latest_receipt_date) as last_ship_to_receipt_days
  from order_aggregations oa
)

select
  -- Fact table surrogate key
  row_number() over (order by oa.order_key) as order_summary_fact_key,
  
  -- Foreign keys
  oa.order_key,
  oa.customer_key,
  od.order_date_key,
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
  
  -- Order metrics
  oa.line_item_count,
  oa.total_quantity,
  oa.total_gross_revenue,
  oa.total_discount_amount,
  oa.total_net_revenue,
  oa.total_tax_amount,
  oa.unique_products,
  oa.unique_suppliers,
  oa.returned_lines,
  oa.filled_lines,
  oa.avg_line_quantity,
  oa.avg_line_revenue,
  oa.shipping_methods_used,
  oa.shipping_instructions_used,
  
  -- Time-based metrics
  ota.order_to_first_ship_days,
  ota.order_to_last_ship_days,
  ota.order_to_first_commit_days,
  ota.order_to_last_commit_days,
  ota.order_to_first_receipt_days,
  ota.order_to_last_receipt_days,
  ota.first_commit_to_ship_days,
  ota.first_ship_to_receipt_days,
  ota.last_ship_to_receipt_days,
  
  -- Calculated efficiency metrics
  case when oa.line_item_count > 0 then oa.total_quantity / oa.line_item_count else null end as avg_quantity_per_line,
  case when oa.line_item_count > 0 then oa.total_gross_revenue / oa.line_item_count else null end as avg_revenue_per_line,
  case when oa.total_gross_revenue > 0 then oa.total_discount_amount / oa.total_gross_revenue else null end as order_discount_rate,
  case when oa.line_item_count > 0 then oa.returned_lines / oa.line_item_count else null end as order_return_rate,
  case when oa.line_item_count > 0 then oa.filled_lines / oa.line_item_count else null end as order_fill_rate,
  
  -- Order fulfillment categories
  case when ota.order_to_first_ship_days <= 7 then 'Fast Fulfillment'
       when ota.order_to_first_ship_days <= 14 then 'Standard Fulfillment'
       when ota.order_to_first_ship_days <= 30 then 'Slow Fulfillment'
       else 'Delayed Fulfillment'
  end as fulfillment_speed_category,
  
  case when ota.first_commit_to_ship_days <= 3 then 'On Time'
       when ota.first_commit_to_ship_days <= 7 then 'Slightly Delayed'
       when ota.first_commit_to_ship_days <= 14 then 'Delayed'
       else 'Significantly Delayed'
  end as commitment_accuracy_category,
  
  case when ota.first_ship_to_receipt_days <= 3 then 'Fast Delivery'
       when ota.first_ship_to_receipt_days <= 7 then 'Standard Delivery'
       when ota.first_ship_to_receipt_days <= 14 then 'Slow Delivery'
       else 'Very Slow Delivery'
  end as delivery_speed_category,
  
  -- Order complexity categories
  case 
    when oa.total_quantity > 300 then 'Large Volume Order'
    when oa.total_quantity > 100 then 'Medium Volume Order'
    else 'Small Volume Order'
  end as volume_category,
  
  case 
    when oa.total_gross_revenue > 100000 then 'High Value Order'
    when oa.total_gross_revenue > 50000 then 'Medium Value Order'
    else 'Low Value Order'
  end as value_category,
  
  case 
    when oa.line_item_count > 10 then 'Complex Order'
    when oa.line_item_count > 5 then 'Standard Order'
    else 'Simple Order'
  end as complexity_category,
  
  case 
    when oa.unique_products > 5 then 'Multi-Product'
    when oa.unique_products > 1 then 'Multi-Product'
    else 'Single Product'
  end as product_diversity_category,
  
  case 
    when oa.unique_suppliers > 3 then 'Multi-Supplier'
    when oa.unique_suppliers > 1 then 'Multi-Supplier'
    else 'Single Supplier'
  end as supplier_diversity_category,
  
  case 
    when oa.order_priority = '1-URGENT' then 'High Priority'
    when oa.order_priority = '2-HIGH' then 'High Priority'
    when oa.order_priority = '3-MEDIUM' then 'Medium Priority'
    else 'Low Priority'
  end as priority_category,
  
  -- Performance flags
  case 
    when ota.order_to_first_ship_days <= 7 then true
    else false
  end as is_fast_fulfillment,
  
  case 
    when ota.first_commit_to_ship_days <= 3 then true
    else false
  end as is_on_time_commitment,
  
  case 
    when ota.first_ship_to_receipt_days <= 3 then true
    else false
  end as is_fast_delivery,
  
  case 
    when ota.order_to_first_ship_days > 30 then true
    else false
  end as is_delayed_fulfillment,
  
  case 
    when ota.first_commit_to_ship_days > 14 then true
    else false
  end as is_late_commitment,
  
  case 
    when ota.first_ship_to_receipt_days > 14 then true
    else false
  end as is_slow_delivery,
  
  case 
    when oa.returned_lines > 0 then true
    else false
  end as has_returns,
  
  case 
    when (case when oa.line_item_count > 0 then oa.returned_lines / oa.line_item_count else null end) > 0.1 then true
    else false
  end as has_high_return_rate,
  
  case 
    when (case when oa.line_item_count > 0 then oa.filled_lines / oa.line_item_count else null end) < 0.8 then true
    else false
  end as has_low_fill_rate,
  
  case 
    when oa.unique_suppliers > 1 then true
    else false
  end as is_multi_supplier_order,
  
  case 
    when oa.unique_products > 1 then true
    else false
  end as is_multi_product_order

from order_aggregations oa
left join order_time_analysis ota on oa.order_key = ota.order_key
left join customer_geo cg on oa.customer_key = cg.customer_key
left join order_date_dim od on oa.order_date = od.order_date_key 