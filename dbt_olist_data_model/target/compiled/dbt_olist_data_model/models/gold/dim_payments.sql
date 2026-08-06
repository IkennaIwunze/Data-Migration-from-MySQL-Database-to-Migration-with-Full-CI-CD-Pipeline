

select
    md5(payment_id::string) as payment_sk,
    payment_id,
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    ingested_at
from OLIST_DW.silver.slv_order_payments


where ingested_at > (select max(ingested_at) from OLIST_DW.gold.dim_payments)
