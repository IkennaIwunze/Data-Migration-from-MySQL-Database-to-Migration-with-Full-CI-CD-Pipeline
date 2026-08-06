
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select review_pk_id
from OLIST_DW.silver.slv_order_reviews
where review_pk_id is null



  
  
      
    ) dbt_internal_test