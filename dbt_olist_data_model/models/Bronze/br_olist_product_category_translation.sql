{{
    config(
        materialized='incremental',
        unique_key='product_category_id'
    )
}}

select
    product_category_id::number as product_category_id,
    product_category_name,
    product_category_name_english,
    _ingested_at::timestamp_ntz as ingested_at
from {{ source('raw_olist', 'raw_olist_product_category_translation') }}

{% if is_incremental() %}
where _ingested_at::timestamp_ntz > (select max(ingested_at) from {{ this }})
{% endif %}