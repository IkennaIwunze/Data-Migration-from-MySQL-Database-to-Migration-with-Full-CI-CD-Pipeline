{{
    config(
        materialized='incremental',
        unique_key='review_pk_id'
    )
}}

select
    review_pk_id::number as review_pk_id,
    review_id,
    order_id,
    review_score::number as review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date::timestamp_ntz as review_creation_date,
    review_answer_timestamp::timestamp_ntz as review_answer_timestamp,
    _ingested_at::timestamp_ntz as ingested_at
from {{ source('raw_olist', 'raw_olist_order_reviews') }}

{% if is_incremental() %}
where _ingested_at::timestamp_ntz > (select max(ingested_at) from {{ this }})
{% endif %}