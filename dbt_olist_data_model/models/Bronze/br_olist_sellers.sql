{{
    config(
        materialized='incremental',
        unique_key='seller_id'
    )
}}

select
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state,
    _ingested_at::timestamp_ntz as ingested_at
from {{ source('raw_olist', 'raw_olist_sellers') }}

{% if is_incremental() %}
where _ingested_at::timestamp_ntz > (select max(ingested_at) from {{ this }})
{% endif %}