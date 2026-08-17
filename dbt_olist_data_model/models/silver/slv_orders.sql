{{
    config(
        materialized='incremental',
        unique_key='order_id'
    )
}}

select
    order_id,
    customer_id,

    case
        when order_status is null then 'Unknown'
        when order_status regexp '^[0-9].*' then 'Unknown'
        else initcap(trim(order_status))
    end as order_status,

    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date,

    case
        when order_delivered_customer_date is not null then true
        else false
    end as is_delivered,

    case
        when order_delivered_customer_date is not null
             and order_delivered_customer_date > order_estimated_delivery_date
        then true
        else false
    end as is_late,

    datediff('day', order_purchase_timestamp, order_delivered_customer_date) as delivery_days,
    
    ingested_at
from {{ ref('br_olist_orders') }}

{% if is_incremental() %}
where ingested_at > (select max(ingested_at) from {{ this }})
{% endif %}