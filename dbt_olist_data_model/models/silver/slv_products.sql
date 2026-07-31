{{
    config(
        materialized='incremental',
        unique_key='product_id'
    )
}}

with products as (
    select * from {{ ref('br_olist_products') }}
    {% if is_incremental() %}
    where ingested_at > (select max(ingested_at) from {{ this }})
    {% endif %}
),

category_translation as (
    select * from {{ ref('br_olist_product_category_translation') }}
)

select
    p.product_id,

    case
        when p.product_category_name is null then 'Unknown'
        when p.product_category_name regexp '^[0-9].*' then 'Unknown'
        else initcap(p.product_category_name)
    end as product_category_name,

    case
        when c.product_category_name_english is null then 'Unknown'
        when c.product_category_name_english regexp '^[0-9].*' then 'Unknown'
        else initcap(c.product_category_name_english)
    end as product_category_name_english,

    p.product_name_length,
    p.product_description_length,
    p.product_photos_qty,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm,
    p.ingested_at
from products p
left join category_translation c
    on p.product_category_name = c.product_category_name