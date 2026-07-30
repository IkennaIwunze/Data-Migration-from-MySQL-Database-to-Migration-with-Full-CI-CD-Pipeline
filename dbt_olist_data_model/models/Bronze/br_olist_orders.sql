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
    order_purchase_timestamp::timestamp_ntz as order_purchase_timestamp,
    order_approved_at::timestamp_ntz as order_approved_at,
    order_delivered_carrier_date::timestamp_ntz as order_delivered_carrier_date,
    order_delivered_customer_date::timestamp_ntz as order_delivered_customer_date,
    order_estimated_delivery_date::timestamp_ntz as order_estimated_delivery_date,
    _ingested_at::timestamp_ntz as ingested_at
from {{ source('raw_olist', 'raw_olist_orders') }}

{% if is_incremental() %}
where _ingested_at::timestamp_ntz > (select max(ingested_at) from {{ this }})
{% endif %}