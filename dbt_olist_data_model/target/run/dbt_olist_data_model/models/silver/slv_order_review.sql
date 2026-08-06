
  
    

create or replace transient table OLIST_DW.silver.slv_order_review
    
    
    
    
    

    as (

select
    review_pk_id,

    case
        when review_id is null then 'unknown'
        else review_id
    end as review_id,

    case
        when order_id is null then 'unknown'
        else order_id
    end as order_id,

    review_score,

    case
        when review_comment_title is null then 'unknown'
        else review_comment_title
    end as review_comment_title,

    case
        when review_comment_message is null then 'unknown'
        else review_comment_message
    end as review_comment_message,

    review_creation_date,
    review_answer_timestamp,
    ingested_at
from OLIST_DW.bronze.br_olist_order_reviews


    )
;


  