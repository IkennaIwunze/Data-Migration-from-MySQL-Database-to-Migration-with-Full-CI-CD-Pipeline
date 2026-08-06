

select
    order_id,
    order_item_id,

    case
        when product_id is null then 'Unknown'
        else product_id
    end as product_id,

    case
        when seller_id is null then 'Unknown'
        else seller_id
    end as seller_id,

    shipping_limit_date,
    price,
    freight_value,
    ingested_at
from OLIST_DW.bronze.br_olist_order_items


where ingested_at > (select max(ingested_at) from OLIST_DW.silver.slv_order_items)
