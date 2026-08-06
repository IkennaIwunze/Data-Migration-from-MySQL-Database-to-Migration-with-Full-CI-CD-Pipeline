

select
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state,
    _ingested_at::timestamp_ntz as ingested_at
from olist_dw.raw.raw_olist_customers


where _ingested_at::timestamp_ntz > (select max(ingested_at) from OLIST_DW.bronze.br_olist_customers)
