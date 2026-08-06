

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
from OLIST_DW.silver.slv_order_reviews


where ingested_at > (select max(ingested_at) from OLIST_DW.gold.dim_reviews)
