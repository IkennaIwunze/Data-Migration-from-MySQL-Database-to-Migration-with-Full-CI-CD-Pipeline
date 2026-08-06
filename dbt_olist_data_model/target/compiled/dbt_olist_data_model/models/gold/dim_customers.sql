

select
    md5(customer_id) as customer_sk,
    customer_id,
    customer_unique_id,
    customer_city,
    customer_state,
    customer_zip_code_prefix,
    ingested_at
from OLIST_DW.silver.slv_customers


where ingested_at > (select max(ingested_at) from OLIST_DW.gold.dim_customers)
