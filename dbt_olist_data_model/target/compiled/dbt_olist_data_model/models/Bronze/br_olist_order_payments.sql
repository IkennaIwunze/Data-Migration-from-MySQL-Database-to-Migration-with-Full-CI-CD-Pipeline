
select
    payment_id::number as payment_id,
    order_id,
    payment_sequential::number as payment_sequential,
    payment_type,
    payment_installments::number as payment_installments,
    payment_value::number(10,2) as payment_value,
    _ingested_at::timestamp_ntz as ingested_at
from olist_dw.raw.raw_olist_order_payments


where _ingested_at::timestamp_ntz > (select max(ingested_at) from OLIST_DW.bronze.br_olist_order_payments)
