with enriched_lines as (
  select
    li.order_key,
    li.line_number,
    li.part_key,
    li.supplier_key,
    li.customer_key,
    li.order_date,
    li.ship_date,
    li.quantity,
    li.extended_price,
    li.discount,
    li.tax,
    ps.supply_cost,
    ps.available_quantity,
    ps.nation_key,
    ps.supplier_name
  from {{ ref('int_lineitem_orders') }} li
  join {{ ref('int_product_supplier_cost') }} ps
    on li.part_key = ps.part_key
   and li.supplier_key = ps.supplier_key
)

select
  order_key,
  line_number,
  part_key,
  supplier_key,
  customer_key,
  nation_key,
  order_date,
  ship_date,
  quantity,
  extended_price                       as gross_revenue,
  extended_price * discount            as discount_amount,
  extended_price * (1 - discount)      as net_revenue,
  (extended_price * (1 - discount)) * tax as tax_amount,
  supply_cost * quantity               as supplier_cost,
  (extended_price * (1 - discount)) - (supply_cost * quantity)        as margin,
  case when extended_price * (1 - discount) = 0 then null
       else ((extended_price * (1 - discount)) - (supply_cost * quantity)) / (extended_price * (1 - discount))
  end                                   as margin_pct,
  case when quantity = 0 then null
       else (extended_price * (1 - discount)) / quantity
  end                                   as average_selling_point
from enriched_lines 