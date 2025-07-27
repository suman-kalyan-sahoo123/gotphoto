with base_lineitem as (
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
    receipt_date,
    ship_instruct,
    ship_mode
  from {{ ref('stg_lineitem') }}
),

base_orders as (
  select
    order_key,
    customer_key as order_customer_key,
    order_date,
    order_status,
    order_priority,
    clerk,
    ship_priority
  from {{ ref('stg_orders') }}
)

select
  li.order_key,
  li.line_number,
  li.part_key,
  li.supplier_key,
  ord.order_customer_key as customer_key,
  ord.order_date,
  ord.order_status,
  ord.order_priority,
  ord.clerk,
  ord.ship_priority,
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

from base_lineitem li
join base_orders ord
  on li.order_key = ord.order_key 