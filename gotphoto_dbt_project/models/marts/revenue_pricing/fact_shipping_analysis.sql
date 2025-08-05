with line_pricing as (
  select
    order_key,
    line_number,
    supplier_key,
    customer_key,
    order_date,
    ship_date,
    quantity,
    gross_revenue,
    net_revenue,
    margin
  from {{ ref('fact_line_pricing_analysis') }}
),

customer_geo as (
  select
    customer_key,
    nation_key as customer_nation_key,
    nation_name as customer_nation_name,
    region_key as customer_region_key,
    region_name as customer_region_name
  from {{ ref('int_customer_geo') }}
),

supplier_geo as (
  select
    supplier_key,
    nation_key as supplier_nation_key,
    nation_name as supplier_nation_name,
    region_key as supplier_region_key,
    region_name as supplier_region_name
  from {{ ref('dim_supplier') }}
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
)

select
  -- Fact table surrogate key
  row_number() over (order by lp.order_key, lp.line_number) as shipping_fact_key,
  
  -- Foreign keys
  lp.order_key,
  lp.line_number,
  lp.supplier_key,
  lp.customer_key,
  od.order_date_key,
  sd.ship_date_key,
  cg.customer_nation_key,
  sg.supplier_nation_key,
  
  -- Geographic attributes
  cg.customer_nation_name,
  cg.customer_region_name,
  sg.supplier_nation_name,
  sg.supplier_region_name,
  
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
  
  -- Core measures
  lp.quantity,
  lp.gross_revenue,
  lp.net_revenue,
  lp.margin,
  
  -- Geographic analysis flags
  case 
    when cg.customer_nation_name != sg.supplier_nation_name then true
    else false
  end as is_international_shipment,
  
  case 
    when cg.customer_region_name != sg.supplier_region_name then true
    else false
  end as is_interregional_shipment,
  
  case 
    when cg.customer_nation_name = sg.supplier_nation_name then 'Domestic'
    when cg.customer_region_name = sg.supplier_region_name then 'Intra-Regional'
    else 'Inter-Regional'
  end as shipment_type,
  
  -- Time analysis flags
  case 
    when sd.ship_year in (1995, 1996) then true
    else false
  end as is_target_period,
  
  case 
    when od.order_season = sd.ship_season then 'Same Season'
    else 'Cross Season'
  end as order_to_ship_season,
  
  -- Shipping performance metrics
  case 
    when lp.quantity > 100 then 'Large Shipment'
    when lp.quantity > 50 then 'Medium Shipment'
    else 'Small Shipment'
  end as shipment_size_category,
  
  case 
    when lp.margin > 0 then 'Profitable'
    else 'Loss Making'
  end as profitability_flag

from line_pricing lp
left join customer_geo cg on lp.customer_key = cg.customer_key
left join supplier_geo sg on lp.supplier_key = sg.supplier_key
left join order_date_dim od on lp.order_date = od.order_date_key
left join ship_date_dim sd on lp.ship_date = sd.ship_date_key 