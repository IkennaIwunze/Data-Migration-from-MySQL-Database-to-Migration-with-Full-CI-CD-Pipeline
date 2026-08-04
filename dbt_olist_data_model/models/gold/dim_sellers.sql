{{
    config(
        materialized='incremental',
        unique_key='seller_id',
        incremental_strategy='merge'
    )
}}

select
    md5(seller_id) as seller_sk,
    seller_id,
    seller_city,
    seller_state,
    seller_zip_code_prefix,
    ingested_at
from {{ ref('slv_sellers') }}

{% if is_incremental() %}
where ingested_at > (select max(ingested_at) from {{ this }})
{% endif %}