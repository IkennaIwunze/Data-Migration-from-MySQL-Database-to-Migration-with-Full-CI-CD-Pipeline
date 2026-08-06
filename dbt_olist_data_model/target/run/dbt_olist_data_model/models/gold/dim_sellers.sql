-- back compat for old kwarg name
  
  begin;
    
        
            
            
            
            
        
    

    

    merge into OLIST_DW.gold.dim_sellers as DBT_INTERNAL_DEST
        using OLIST_DW.gold.dim_sellers__dbt_tmp as DBT_INTERNAL_SOURCE
        on ((DBT_INTERNAL_SOURCE.seller_id = DBT_INTERNAL_DEST.seller_id))

    
    when matched then update set
        "SELLER_SK" = DBT_INTERNAL_SOURCE."SELLER_SK","SELLER_ID" = DBT_INTERNAL_SOURCE."SELLER_ID","SELLER_CITY" = DBT_INTERNAL_SOURCE."SELLER_CITY","SELLER_STATE" = DBT_INTERNAL_SOURCE."SELLER_STATE","SELLER_ZIP_CODE_PREFIX" = DBT_INTERNAL_SOURCE."SELLER_ZIP_CODE_PREFIX","INGESTED_AT" = DBT_INTERNAL_SOURCE."INGESTED_AT"
    

    when not matched then insert
        ("SELLER_SK", "SELLER_ID", "SELLER_CITY", "SELLER_STATE", "SELLER_ZIP_CODE_PREFIX", "INGESTED_AT")
    values
        ("SELLER_SK", "SELLER_ID", "SELLER_CITY", "SELLER_STATE", "SELLER_ZIP_CODE_PREFIX", "INGESTED_AT")

;
    commit;