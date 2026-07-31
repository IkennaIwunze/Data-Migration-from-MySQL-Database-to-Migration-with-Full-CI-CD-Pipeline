{{
    config(
        materialized='incremental',
        unique_key='seller_id'
    )
}}

select
    seller_id,

    case
        when seller_zip_code_prefix is null then 'Unknown'
        else seller_zip_code_prefix
    end as seller_zip_code_prefix,

    case
        when seller_city is null then 'Unknown'
        when seller_city regexp '^[0-9].*' then 'Unknown'
        else initcap(trim(seller_city))
    end as seller_city,

    case
        when seller_state is null then 'Unknown'
        when seller_state regexp '^[0-9].*' then 'Unknown'
        else upper(trim(seller_state))
    end as seller_state,

    ingested_at
from {{ ref('br_olist_sellers') }}

{% if is_incremental() %}
where ingested_at > (select max(ingested_at) from {{ this }})
{% endif %}