{{
    config(
        materialized='incremental',
        unique_key='review_pk_id',
        incremental_strategy='merge'
    )
}}

select
    md5(review_pk_id::string) as review_sk,
    review_pk_id,
    review_id,
    order_id,
    has_comment,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp,
    ingested_at
from {{ ref('slv_order_reviews') }}

{% if is_incremental() %}
where ingested_at > (select max(ingested_at) from {{ this }})
{% endif %}