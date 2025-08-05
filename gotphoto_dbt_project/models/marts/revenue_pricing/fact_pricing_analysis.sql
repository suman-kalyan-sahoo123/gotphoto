with line_pricing as (
  select
    order_key,
    line_number,
    part_key,
    customer_key,
    quantity,
    gross_revenue,
    discount_amount,
    net_revenue,
    tax_amount,
    average_selling_point
  from {{ ref('fact_line_pricing_analysis') }}
),

product_info as (
  select
    part_key,
    part_name,
    manufacturer,
    brand,
    part_type,
    retail_price
  from {{ ref('dim_product') }}
),

customer_geo as (
  select
    customer_key,
    segment_code
  from {{ ref('int_customer_geo') }}
)

select
  -- Fact table surrogate key
  row_number() over (order by lp.order_key, lp.line_number) as pricing_fact_key,
  
  -- Foreign keys
  lp.order_key,
  lp.line_number,
  lp.part_key,
  lp.customer_key,
  
  -- Product attributes
  p.part_name,
  p.manufacturer,
  p.brand,
  p.part_type,
  p.retail_price as list_price,
  
  -- Customer attributes
  cg.segment_code as customer_segment,
  
  -- Core pricing measures
  lp.quantity,
  lp.gross_revenue,
  lp.discount_amount,
  lp.net_revenue,
  lp.tax_amount,
  lp.average_selling_point,
  
  -- Calculated pricing metrics
  case when lp.gross_revenue > 0 then lp.discount_amount / lp.gross_revenue else null end as discount_rate,
  case when lp.quantity > 0 then lp.discount_amount / lp.quantity else null end as discount_per_unit,
  case when lp.quantity > 0 then lp.gross_revenue / lp.quantity else null end as unit_price,
  case when lp.quantity > 0 then lp.net_revenue / lp.quantity else null end as net_unit_price,
  case when p.retail_price > 0 then (lp.gross_revenue / lp.quantity) / p.retail_price else null end as price_to_list_ratio,
  
  -- Revenue with tax
  lp.gross_revenue + lp.tax_amount as gross_revenue_with_tax,
  lp.net_revenue + lp.tax_amount as net_revenue_with_tax,
  
  -- Pricing categories
  case 
    when (case when lp.gross_revenue > 0 then lp.discount_amount / lp.gross_revenue else null end) > 0.1 then 'High Discount'
    when (case when lp.gross_revenue > 0 then lp.discount_amount / lp.gross_revenue else null end) > 0.05 then 'Medium Discount'
    else 'Low Discount'
  end as discount_category,
  
  case 
    when p.retail_price > 0 and (lp.gross_revenue / lp.quantity) / p.retail_price > 1.2 then 'Premium Pricing'
    when p.retail_price > 0 and (lp.gross_revenue / lp.quantity) / p.retail_price < 0.8 then 'Discount Pricing'
    else 'Standard Pricing'
  end as pricing_strategy

from line_pricing lp
left join product_info p on lp.part_key = p.part_key
left join customer_geo cg on lp.customer_key = cg.customer_key 