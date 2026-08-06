

select
    md5(seller_id) as seller_sk,
    seller_id,
    seller_city,
    seller_state,
    seller_zip_code_prefix,
    ingested_at
from OLIST_DW.silver.slv_sellers


where ingested_at > (select max(ingested_at) from OLIST_DW.gold.dim_sellers)
