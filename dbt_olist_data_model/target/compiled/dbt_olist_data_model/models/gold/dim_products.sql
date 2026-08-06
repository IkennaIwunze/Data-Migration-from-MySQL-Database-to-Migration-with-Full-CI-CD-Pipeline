

select
    md5(product_id) as product_sk,
    product_id,
    product_category_name,
    product_category_name_english,
    product_name_length,
    product_description_length,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm,
    ingested_at
from OLIST_DW.silver.slv_products


where ingested_at > (select max(ingested_at) from OLIST_DW.gold.dim_products)
