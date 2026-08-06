

with items_agg as (
    select
        order_id,
        count(*) as item_count,
        sum(price) as total_price,
        sum(freight_value) as total_freight
    from OLIST_DW.silver.slv_order_items
    group by order_id
),

payments_agg as (
    select
        order_id,
        sum(payment_value) as total_payment_value,
        count(*) as installment_count
    from OLIST_DW.silver.slv_order_payments
    group by order_id
),

reviews_agg as (
    select
        order_id,
        avg(review_score) as avg_review_score,
        max(has_comment::int)::boolean as has_any_comment
    from OLIST_DW.silver.slv_order_reviews
    group by order_id
)

select
    o.order_id,
    md5(o.customer_id) as customer_sk,

    o.is_delivered,
    o.is_late,
    o.delivery_days,

    ia.item_count,
    ia.total_price,
    ia.total_freight,

    pa.total_payment_value,
    pa.installment_count,

    ra.avg_review_score,
    ra.has_any_comment,

    o.ingested_at
from OLIST_DW.silver.slv_orders o
left join items_agg ia on o.order_id = ia.order_id
left join payments_agg pa on o.order_id = pa.order_id
left join reviews_agg ra on o.order_id = ra.order_id


where o.ingested_at > (select max(ingested_at) from OLIST_DW.gold.fct_orders)
