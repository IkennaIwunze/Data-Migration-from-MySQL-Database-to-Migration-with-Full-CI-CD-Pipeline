
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select geolocation_id
from OLIST_DW.silver.slv_geolocation
where geolocation_id is null



  
  
      
    ) dbt_internal_test