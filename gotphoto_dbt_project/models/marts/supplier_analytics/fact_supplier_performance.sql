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
    o.order_status,
    o.order_priority
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

supplier_order_aggregations as (
  select
    so.supplier_key,
    so.order_key,
    so.line_number,
    so.part_key,
    so.quantity,
    so.extended_price,
    so.discount,
    so.tax,
    so.return_flag,
    so.line_status,
    so.ship_date,
    so.order_date,
    so.order_status,
    so.order_priority,
    ps.available_quantity,
    ps.supply_cost,
    -- Calculated metrics
    so.extended_price * so.discount as discount_amount,
    so.extended_price * (1 - so.discount) as net_revenue,
    so.extended_price * (1 - so.discount) * so.tax as tax_amount,
    ps.supply_cost * so.quantity as total_supplier_cost,
    (so.extended_price * (1 - so.discount)) - (ps.supply_cost * so.quantity) as margin,
    case when so.extended_price * (1 - so.discount) = 0 then null
         else ((so.extended_price * (1 - so.discount)) - (ps.supply_cost * so.quantity)) / (so.extended_price * (1 - so.discount))
    end as margin_pct
  from supplier_orders so
  left join partsupp_info ps on so.part_key = ps.part_key and so.supplier_key = ps.supplier_key
)

select
  -- Fact table surrogate key
  row_number() over (order by spa.supplier_key, spa.order_key, spa.line_number) as supplier_performance_fact_key,
  
  -- Foreign keys
  spa.supplier_key,
  spa.order_key,
  spa.line_number,
  spa.part_key,
  od.order_date_key,
  sd.ship_date_key,
  sg.nation_key,
  sg.region_key,
  
  -- Supplier attributes
  sg.supplier_name,
  sg.supplier_address,
  sg.supplier_phone,
  sg.account_balance,
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
  spa.order_status,
  spa.order_priority,
  
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
  
  -- Core metrics
  spa.quantity,
  spa.extended_price as gross_revenue,
  spa.discount_amount,
  spa.net_revenue,
  spa.tax_amount,
  spa.available_quantity,
  spa.supply_cost,
  spa.total_supplier_cost,
  spa.margin,
  spa.margin_pct,
  
  -- Calculated supplier metrics
  case when spa.quantity > 0 then spa.extended_price / spa.quantity else null end as unit_price,
  case when spa.quantity > 0 then spa.net_revenue / spa.quantity else null end as net_unit_price,
  case when spa.quantity > 0 then spa.total_supplier_cost / spa.quantity else null end as unit_cost,
  case when spa.quantity > 0 then spa.margin / spa.quantity else null end as margin_per_unit,
  case when spa.supply_cost > 0 then spa.extended_price / spa.supply_cost else null end as markup_ratio,
  case when spa.available_quantity > 0 then spa.quantity / spa.available_quantity else null end as utilization_rate,
  
  -- Performance flags
  case 
    when spa.return_flag = 'R' then true
    else false
  end as is_returned,
  
  case 
    when spa.line_status = 'F' then true
    else false
  end as is_filled,
  
  case 
    when spa.margin_pct > 0.3 then 'High Margin'
    when spa.margin_pct > 0.15 then 'Medium Margin'
    else 'Low Margin'
  end as margin_category,
  
  case 
    when spa.quantity > 100 then 'Large Order'
    when spa.quantity > 50 then 'Medium Order'
    else 'Small Order'
  end as order_size_category,
  
  case 
    when spa.supply_cost < spa.extended_price * 0.5 then 'High Markup'
    when spa.supply_cost < spa.extended_price * 0.7 then 'Medium Markup'
    else 'Low Markup'
  end as markup_category,
  
  case 
    when spa.available_quantity > spa.quantity * 2 then 'High Availability'
    when spa.available_quantity > spa.quantity then 'Medium Availability'
    else 'Low Availability'
  end as availability_category

from supplier_order_aggregations spa
left join supplier_geo sg on spa.supplier_key = sg.supplier_key
left join product_info p on spa.part_key = p.part_key
left join order_date_dim od on spa.order_date = od.order_date_key
left join ship_date_dim sd on spa.ship_date = sd.ship_date_key 