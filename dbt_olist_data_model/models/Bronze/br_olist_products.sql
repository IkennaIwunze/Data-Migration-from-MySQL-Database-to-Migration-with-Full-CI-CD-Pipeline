{{
    config(
        materialized='incremental',
        unique_key='product_id'
    )
}}

select
    product_id,
    product_category_name,
    product_name_lenght::number as product_name_length,
    product_description_lenght::number as product_description_length,
    product_photos_qty::number as product_photos_qty,
    product_weight_g::number as product_weight_g,
    product_length_cm::number as product_length_cm,
    product_height_cm::number as product_height_cm,
    product_width_cm::number as product_width_cm,
    _ingested_at::timestamp_ntz as ingested_at
from {{ source('raw_olist', 'raw_olist_products') }}

{% if is_incremental() %}
where _ingested_at::timestamp_ntz > (select max(ingested_at) from {{ this }})
{% endif %}