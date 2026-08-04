{{
    config(
        materialized='incremental',
        unique_key='geolocation_id',
        incremental_strategy='merge'
    )
}}

select
    md5(geolocation_id::string) as geolocation_sk,
    geolocation_id,
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state,
    ingested_at
from {{ ref('slv_geolocation') }}

{% if is_incremental() %}
where ingested_at > (select max(ingested_at) from {{ this }})
{% endif %}