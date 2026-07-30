{{
    config(
        materialized='incremental',
        unique_key='order_id'
    )
}}

select
    order_id,
    customer_id,
    order_status,
    try_to_timestamp_ntz(order_purchase_timestamp) as order_purchase_timestamp,
    try_to_timestamp_ntz(order_approved_at) as order_approved_at,
    try_to_timestamp_ntz(order_delivered_carrier_date) as order_delivered_carrier_date,
    try_to_timestamp_ntz(order_delivered_customer_date) as order_delivered_customer_date,
    try_to_timestamp_ntz(order_estimated_delivery_date) as order_estimated_delivery_date,
    _ingested_at::timestamp_ntz as ingested_at
from {{ source('raw_olist', 'raw_olist_orders') }}

{% if is_incremental() %}
where _ingested_at::timestamp_ntz > (select max(ingested_at) from {{ this }})
{% endif %}