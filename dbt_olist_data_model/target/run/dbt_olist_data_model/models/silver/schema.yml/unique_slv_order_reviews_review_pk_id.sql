
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

select
    review_pk_id as unique_field,
    count(*) as n_records

from OLIST_DW.silver.slv_order_reviews
where review_pk_id is not null
group by review_pk_id
having count(*) > 1



  
  
      
    ) dbt_internal_test