

select
    payment_id,

    case
        when order_id is null then 'Unknown'
        else order_id
    end as order_id,

    payment_sequential,

    case
        when payment_type is null then 'Unknown'
        when payment_type regexp '^[0-9].*' then 'Unknown'
        else payment_type
    end as payment_type,

    payment_installments,
    payment_value,
    ingested_at
from OLIST_DW.bronze.br_olist_order_payments


where ingested_at > (select max(ingested_at) from OLIST_DW.silver.slv_order_payments)
