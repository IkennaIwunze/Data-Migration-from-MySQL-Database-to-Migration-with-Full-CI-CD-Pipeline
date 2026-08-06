-- back compat for old kwarg name
  
  begin;
    
        
            
            
            
            
        
    

    

    merge into OLIST_DW.gold.dim_customers as DBT_INTERNAL_DEST
        using OLIST_DW.gold.dim_customers__dbt_tmp as DBT_INTERNAL_SOURCE
        on ((DBT_INTERNAL_SOURCE.customer_id = DBT_INTERNAL_DEST.customer_id))

    
    when matched then update set
        "CUSTOMER_SK" = DBT_INTERNAL_SOURCE."CUSTOMER_SK","CUSTOMER_ID" = DBT_INTERNAL_SOURCE."CUSTOMER_ID","CUSTOMER_UNIQUE_ID" = DBT_INTERNAL_SOURCE."CUSTOMER_UNIQUE_ID","CUSTOMER_CITY" = DBT_INTERNAL_SOURCE."CUSTOMER_CITY","CUSTOMER_STATE" = DBT_INTERNAL_SOURCE."CUSTOMER_STATE","CUSTOMER_ZIP_CODE_PREFIX" = DBT_INTERNAL_SOURCE."CUSTOMER_ZIP_CODE_PREFIX","INGESTED_AT" = DBT_INTERNAL_SOURCE."INGESTED_AT"
    

    when not matched then insert
        ("CUSTOMER_SK", "CUSTOMER_ID", "CUSTOMER_UNIQUE_ID", "CUSTOMER_CITY", "CUSTOMER_STATE", "CUSTOMER_ZIP_CODE_PREFIX", "INGESTED_AT")
    values
        ("CUSTOMER_SK", "CUSTOMER_ID", "CUSTOMER_UNIQUE_ID", "CUSTOMER_CITY", "CUSTOMER_STATE", "CUSTOMER_ZIP_CODE_PREFIX", "INGESTED_AT")

;
    commit;