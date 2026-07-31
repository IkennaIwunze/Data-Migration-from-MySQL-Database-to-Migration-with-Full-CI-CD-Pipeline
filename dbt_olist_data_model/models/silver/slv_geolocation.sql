{{
    config(
        materialized='incremental',
        unique_key='geolocation_id'
    )
}}

select
    geolocation_id,

    case
        when geolocation_zip_code_prefix is null then 'Unknown'
        else geolocation_zip_code_prefix
    end as geolocation_zip_code_prefix,

    geolocation_lat,
    geolocation_lng,

    case
        when geolocation_city is null then 'Unknown'
        when geolocation_city regexp '^[0-9].*' then 'Unknown'
        else initcap(trim(geolocation_city))
    end as geolocation_city,

    case
        when geolocation_state is null then 'Unknown'
        when geolocation_state regexp '^[0-9].*' then 'Unknown'
        else upper(trim(geolocation_state))
    end as geolocation_state,

    ingested_at
from {{ ref('br_olist_geolocation') }}

{% if is_incremental() %}
where ingested_at > (select max(ingested_at) from {{ this }})
{% endif %}