

select
    oi.order_id,
    oi.order_item_id,
    md5(o.customer_id) as customer_sk,
    md5(oi.product_id) as product_sk,
    md5(oi.seller_id) as seller_sk,
    oi.price,
    oi.freight_value,
    oi.ingested_at
from OLIST_DW.silver.slv_order_items oi
left join OLIST_DW.silver.slv_orders o on oi.order_id = o.order_id


where oi.ingested_at > (select max(ingested_at) from OLIST_DW.gold.fct_order_items)
