

select
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state,
    _ingested_at::timestamp_ntz as ingested_at
from olist_dw.raw.raw_olist_sellers


where _ingested_at::timestamp_ntz > (select max(ingested_at) from OLIST_DW.bronze.br_olist_sellers)
