{{
    config(
        materialized='incremental',
        unique_key=['order_id', 'order_item_id']
    )
}}

select
    oi.order_id,
    oi.order_item_id,
    md5(o.customer_id) as customer_sk,
    md5(oi.product_id) as product_sk,
    md5(oi.seller_id) as seller_sk,
    oi.price,
    oi.freight_value,
    oi.ingested_at
from {{ ref('slv_order_items') }} oi
left join {{ ref('slv_orders') }} o on oi.order_id = o.order_id

{% if is_incremental() %}
where oi.ingested_at > (select max(ingested_at) from {{ this }})
{% endif %}