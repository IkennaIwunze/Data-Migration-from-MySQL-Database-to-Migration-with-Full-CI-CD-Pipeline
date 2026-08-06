

select
    review_pk_id::number as review_pk_id,
    review_id,
    order_id,
    review_score::number as review_score,
    review_comment_title,
    review_comment_message,
    try_to_timestamp_ntz(review_creation_date) as review_creation_date,
    try_to_timestamp_ntz(review_answer_timestamp) as review_answer_timestamp,
    _ingested_at::timestamp_ntz as ingested_at
from olist_dw.raw.raw_olist_order_reviews


where _ingested_at::timestamp_ntz > (select max(ingested_at) from OLIST_DW.bronze.br_olist_order_reviews)
