with line_pricing as (
  select
    order_key,
    line_number,
    part_key,
    supplier_key,
    customer_key,
    order_date,
    ship_date,
    quantity,
    gross_revenue,
    net_revenue,
    supplier_cost,
    margin
  from {{ ref('int_line_pricing_calcs') }}
),

customer_geo as (
  select
    customer_key,
    nation_key as customer_nation_key,
    nation_name as customer_nation_name,
    region_key as customer_region_key,
    region_name as customer_region_name,
    segment_code
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

product_info as (
  select
    part_key,
    part_name,
    manufacturer,
    brand,
    part_type
  from {{ ref('dim_product') }}
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

ship_date_dim as (
  select
    date_key as ship_date_key,
    year as ship_year,
    quarter as ship_quarter,
    month as ship_month,
    month_name as ship_month_name,
    quarter_name as ship_quarter_name
  from {{ ref('dim_date') }}
)

select
  -- Fact table surrogate key
  row_number() over (order by lp.order_key, lp.line_number) as order_fact_key,
  
  -- Foreign keys to dimensions
  lp.order_key,
  lp.line_number,
  lp.part_key,
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
  
  -- Customer attributes
  cg.segment_code as customer_segment,
  
  -- Product attributes
  p.part_name,
  p.manufacturer,
  p.brand,
  p.part_type,
  
  -- Time attributes
  od.order_year,
  od.order_quarter,
  od.order_month,
  od.order_month_name,
  od.order_quarter_name,
  sd.ship_year,
  sd.ship_quarter,
  sd.ship_month,
  sd.ship_month_name,
  sd.ship_quarter_name,
  
  -- Core measures
  lp.quantity,
  lp.gross_revenue,
  lp.net_revenue,
  lp.supplier_cost,
  lp.margin,
  
  -- Calculated measures
  case when lp.quantity > 0 then lp.gross_revenue / lp.quantity else null end as unit_price,
  case when lp.quantity > 0 then lp.net_revenue / lp.quantity else null end as net_unit_price,
  case when lp.quantity > 0 then lp.supplier_cost / lp.quantity else null end as unit_cost,
  case when lp.quantity > 0 then lp.margin / lp.quantity else null end as margin_per_unit,
  
  -- Order size categories
  case 
    when lp.quantity > 100 then 'Large Order'
    when lp.quantity > 50 then 'Medium Order'
    else 'Small Order'
  end as order_size_category

from line_pricing lp
left join customer_geo cg on lp.customer_key = cg.customer_key
left join supplier_geo sg on lp.supplier_key = sg.supplier_key
left join product_info p on lp.part_key = p.part_key
left join order_date_dim od on lp.order_date = od.order_date_key
left join ship_date_dim sd on lp.ship_date = sd.ship_date_key 