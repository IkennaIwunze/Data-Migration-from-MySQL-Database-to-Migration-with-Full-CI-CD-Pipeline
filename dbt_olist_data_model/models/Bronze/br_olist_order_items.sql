{{
    config(
        materialized='incremental',
        unique_key=['order_id', 'order_item_id']
    )
}}

select
    order_id,
    order_item_id::number as order_item_id,
    product_id,
    seller_id,
    shipping_limit_date::timestamp_ntz as shipping_limit_date,
    price::number(10,2) as price,
    freight_value::number(10,2) as freight_value,
    _ingested_at::timestamp_ntz as ingested_at
from {{ source('raw_olist', 'raw_olist_order_items') }}

{% if is_incremental() %}
where _ingested_at::timestamp_ntz > (select max(ingested_at) from {{ this }})
{% endif %}