{{
    config(
        materialized='incremental',
        unique_key='review_pk_id'
    )
}}

select
    review_pk_id,

    case
        when review_id is null then 'Unknown'
        else review_id
    end as review_id,

    case
        when order_id is null then 'Unknown'
        else order_id
    end as order_id,

    review_score,

    case
        when review_comment_title is null then 'Unknown'
        else review_comment_title
    end as review_comment_title,

    review_comment_message,

    case
        when review_comment_message is null then false
        when trim(review_comment_message) = '' then false
        else true
    end as has_comment,

    review_creation_date,
    review_answer_timestamp,
    ingested_at
from {{ ref('br_olist_order_reviews') }}

{% if is_incremental() %}
where ingested_at > (select max(ingested_at) from {{ this }})
{% endif %}