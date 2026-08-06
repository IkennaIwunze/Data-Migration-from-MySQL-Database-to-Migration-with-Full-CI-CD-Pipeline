-- back compat for old kwarg name
  
  begin;
    
        
            
            
            
            
        
    

    

    merge into OLIST_DW.bronze.br_olist_customers as DBT_INTERNAL_DEST
        using OLIST_DW.bronze.br_olist_customers__dbt_tmp as DBT_INTERNAL_SOURCE
        on ((DBT_INTERNAL_SOURCE.customer_id = DBT_INTERNAL_DEST.customer_id))

    
    when matched then update set
        "CUSTOMER_ID" = DBT_INTERNAL_SOURCE."CUSTOMER_ID","CUSTOMER_UNIQUE_ID" = DBT_INTERNAL_SOURCE."CUSTOMER_UNIQUE_ID","CUSTOMER_ZIP_CODE_PREFIX" = DBT_INTERNAL_SOURCE."CUSTOMER_ZIP_CODE_PREFIX","CUSTOMER_CITY" = DBT_INTERNAL_SOURCE."CUSTOMER_CITY","CUSTOMER_STATE" = DBT_INTERNAL_SOURCE."CUSTOMER_STATE","INGESTED_AT" = DBT_INTERNAL_SOURCE."INGESTED_AT"
    

    when not matched then insert
        ("CUSTOMER_ID", "CUSTOMER_UNIQUE_ID", "CUSTOMER_ZIP_CODE_PREFIX", "CUSTOMER_CITY", "CUSTOMER_STATE", "INGESTED_AT")
    values
        ("CUSTOMER_ID", "CUSTOMER_UNIQUE_ID", "CUSTOMER_ZIP_CODE_PREFIX", "CUSTOMER_CITY", "CUSTOMER_STATE", "INGESTED_AT")

;
    commit;