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

commit_date_dim as (
  select
    date_key as commit_date_key,
    year as commit_year,
    quarter as commit_quarter,
    month as commit_month,
    month_name as commit_month_name,
    quarter_name as commit_quarter_name,
    day_type as commit_day_type,
    season as commit_season
  from {{ ref('dim_date') }}
),

receipt_date_dim as (
  select
    date_key as receipt_date_key,
    year as receipt_year,
    quarter as receipt_quarter,
    month as receipt_month,
    month_name as receipt_month_name,
    quarter_name as receipt_quarter_name,
    day_type as receipt_day_type,
    season as receipt_season
  from {{ ref('dim_date') }}
),

order_line_analysis as (
  select
    oli.order_key,
    oli.line_number,
    oli.part_key,
    oli.supplier_key,
    oi.customer_key,
    oli.quantity,
    oli.extended_price,
    oli.discount,
    oli.tax,
    oli.return_flag,
    oli.line_status,
    oli.ship_date,
    oli.commit_date,
    oli.receipt_date,
    oli.ship_instruct,
    oli.ship_mode,
    oi.order_date,
    oi.order_status,
    oi.order_priority,
    oi.clerk,
    oi.ship_priority,
    -- Calculated metrics
    oli.extended_price * oli.discount as discount_amount,
    oli.extended_price * (1 - oli.discount) as net_revenue,
    oli.extended_price * (1 - oli.discount) * oli.tax as tax_amount,
    -- Time calculations
    datediff('day', oi.order_date, oli.ship_date) as order_to_ship_days,
    datediff('day', oi.order_date, oli.commit_date) as order_to_commit_days,
    datediff('day', oi.order_date, oli.receipt_date) as order_to_receipt_days,
    datediff('day', oli.commit_date, oli.ship_date) as commit_to_ship_days,
    datediff('day', oli.ship_date, oli.receipt_date) as ship_to_receipt_days
  from order_line_items oli
  left join order_info oi on oli.order_key = oi.order_key
)

select
  -- Fact table surrogate key
  row_number() over (order by ola.order_key, ola.line_number) as order_fulfillment_fact_key,
  
  -- Foreign keys
  ola.order_key,
  ola.line_number,
  ola.part_key,
  ola.supplier_key,
  ola.customer_key,
  od.order_date_key,
  sd.ship_date_key,
  cd.commit_date_key,
  rd.receipt_date_key,
  cg.nation_key as customer_nation_key,
  sg.nation_key as supplier_nation_key,
  
  -- Customer attributes
  cg.customer_name,
  cg.customer_address,
  cg.customer_phone,
  cg.account_balance,
  cg.segment_code as customer_segment,
  cg.nation_name as customer_nation,
  cg.region_name as customer_region,
  
  -- Supplier attributes
  sg.supplier_name,
  sg.supplier_address,
  sg.supplier_phone,
  sg.account_balance as supplier_account_balance,
  sg.nation_name as supplier_nation,
  sg.region_name as supplier_region,
  
  -- Product attributes
  p.part_name,
  p.manufacturer,
  p.brand,
  p.part_type,
  p.part_size,
  p.container,
  p.retail_price as list_price,
  
  -- Order attributes
  ola.order_status,
  ola.order_priority,
  ola.clerk,
  ola.ship_priority,
  ola.ship_instruct,
  ola.ship_mode,
  
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
  cd.commit_year,
  cd.commit_quarter,
  cd.commit_month,
  cd.commit_month_name,
  cd.commit_quarter_name,
  cd.commit_day_type,
  cd.commit_season,
  rd.receipt_year,
  rd.receipt_quarter,
  rd.receipt_month,
  rd.receipt_month_name,
  rd.receipt_quarter_name,
  rd.receipt_day_type,
  rd.receipt_season,
  
  -- Core metrics
  ola.quantity,
  ola.extended_price as gross_revenue,
  ola.discount_amount,
  ola.net_revenue,
  ola.tax_amount,
  
  -- Time-based metrics
  ola.order_to_ship_days,
  ola.order_to_commit_days,
  ola.order_to_receipt_days,
  ola.commit_to_ship_days,
  ola.ship_to_receipt_days,
  
  -- Calculated efficiency metrics
  case when ola.order_to_ship_days <= 7 then 'Fast Fulfillment'
       when ola.order_to_ship_days <= 14 then 'Standard Fulfillment'
       when ola.order_to_ship_days <= 30 then 'Slow Fulfillment'
       else 'Delayed Fulfillment'
  end as fulfillment_speed_category,
  
  case when ola.commit_to_ship_days <= 3 then 'On Time'
       when ola.commit_to_ship_days <= 7 then 'Slightly Delayed'
       when ola.commit_to_ship_days <= 14 then 'Delayed'
       else 'Significantly Delayed'
  end as commitment_accuracy_category,
  
  case when ola.ship_to_receipt_days <= 3 then 'Fast Delivery'
       when ola.ship_to_receipt_days <= 7 then 'Standard Delivery'
       when ola.ship_to_receipt_days <= 14 then 'Slow Delivery'
       else 'Very Slow Delivery'
  end as delivery_speed_category,
  
  -- Performance flags
  case 
    when ola.return_flag = 'R' then true
    else false
  end as is_returned,
  
  case 
    when ola.line_status = 'F' then true
    else false
  end as is_filled,
  
  case 
    when ola.order_to_ship_days <= 7 then true
    else false
  end as is_fast_fulfillment,
  
  case 
    when ola.commit_to_ship_days <= 3 then true
    else false
  end as is_on_time_commitment,
  
  case 
    when ola.ship_to_receipt_days <= 3 then true
    else false
  end as is_fast_delivery,
  
  case 
    when ola.order_to_ship_days > 30 then true
    else false
  end as is_delayed_fulfillment,
  
  case 
    when ola.commit_to_ship_days > 14 then true
    else false
  end as is_late_commitment,
  
  case 
    when ola.ship_to_receipt_days > 14 then true
    else false
  end as is_slow_delivery,
  
  -- Geographic analysis
  case
    when cg.nation_name != sg.nation_name then true
    else false
  end as is_international_order,
  
  case
    when cg.region_name != sg.region_name then true
    else false
  end as is_interregional_order,
  
  case
    when cg.nation_name = sg.nation_name then 'Domestic'
    when cg.region_name = sg.region_name then 'Intra-Regional'
    else 'Inter-Regional'
  end as order_geography_type,
  
  -- Order complexity
  case 
    when ola.quantity > 100 then 'Large Order'
    when ola.quantity > 50 then 'Medium Order'
    else 'Small Order'
  end as order_size_category,
  
  case 
    when ola.order_priority = '1-URGENT' then 'High Priority'
    when ola.order_priority = '2-HIGH' then 'High Priority'
    when ola.order_priority = '3-MEDIUM' then 'Medium Priority'
    else 'Low Priority'
  end as priority_category,
  
  case 
    when ola.ship_mode = 'AIR' then 'Air Freight'
    when ola.ship_mode = 'TRUCK' then 'Ground Transport'
    when ola.ship_mode = 'MAIL' then 'Mail Service'
    when ola.ship_mode = 'SHIP' then 'Sea Freight'
    else 'Other'
  end as shipping_method_category

from order_line_analysis ola
left join customer_geo cg on ola.customer_key = cg.customer_key
left join supplier_geo sg on ola.supplier_key = sg.supplier_key
left join product_info p on ola.part_key = p.part_key
left join order_date_dim od on ola.order_date = od.order_date_key
left join ship_date_dim sd on ola.ship_date = sd.ship_date_key
left join commit_date_dim cd on ola.commit_date = cd.commit_date_key
left join receipt_date_dim rd on ola.receipt_date = rd.receipt_date_key 