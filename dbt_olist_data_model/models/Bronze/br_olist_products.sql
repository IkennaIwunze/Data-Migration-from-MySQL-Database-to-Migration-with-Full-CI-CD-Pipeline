{{
    config(
        materialized='incremental',
        unique_key='product_id'
    )
}}

select
    product_id,
    product_category_name,
    try_to_number(product_name_lenght) as product_name_length,
    try_to_number(product_description_lenght) as product_description_length,
    try_to_number(product_photos_qty) as product_photos_qty,
    try_to_number(product_weight_g) as product_weight_g,
    try_to_number(product_length_cm) as product_length_cm,
    try_to_number(product_height_cm) as product_height_cm,
    try_to_number(product_width_cm) as product_width_cm,
    _ingested_at::timestamp_ntz as ingested_at
from {{ source('raw_olist', 'raw_olist_products') }}

{% if is_incremental() %}
where _ingested_at::timestamp_ntz > (select max(ingested_at) from {{ this }})
{% endif %}