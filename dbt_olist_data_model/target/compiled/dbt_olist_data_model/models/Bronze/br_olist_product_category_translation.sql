

select
    product_category_id::number as product_category_id,
    product_category_name,
    product_category_name_english,
    _ingested_at::timestamp_ntz as ingested_at
from olist_dw.raw.raw_olist_product_category_translation


where _ingested_at::timestamp_ntz > (select max(ingested_at) from OLIST_DW.bronze.br_olist_product_category_translation)
