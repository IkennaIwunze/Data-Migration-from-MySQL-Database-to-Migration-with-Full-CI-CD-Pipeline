
    
    

select
    review_pk_id as unique_field,
    count(*) as n_records

from OLIST_DW.silver.slv_order_reviews
where review_pk_id is not null
group by review_pk_id
having count(*) > 1


