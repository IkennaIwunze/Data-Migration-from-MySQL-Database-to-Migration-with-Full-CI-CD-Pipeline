-- back compat for old kwarg name
  
  begin;
    
        
            
            
            
            
        
    

    

    merge into OLIST_DW.bronze.br_olist_product_category_translation as DBT_INTERNAL_DEST
        using OLIST_DW.bronze.br_olist_product_category_translation__dbt_tmp as DBT_INTERNAL_SOURCE
        on ((DBT_INTERNAL_SOURCE.product_category_id = DBT_INTERNAL_DEST.product_category_id))

    
    when matched then update set
        "PRODUCT_CATEGORY_ID" = DBT_INTERNAL_SOURCE."PRODUCT_CATEGORY_ID","PRODUCT_CATEGORY_NAME" = DBT_INTERNAL_SOURCE."PRODUCT_CATEGORY_NAME","PRODUCT_CATEGORY_NAME_ENGLISH" = DBT_INTERNAL_SOURCE."PRODUCT_CATEGORY_NAME_ENGLISH","INGESTED_AT" = DBT_INTERNAL_SOURCE."INGESTED_AT"
    

    when not matched then insert
        ("PRODUCT_CATEGORY_ID", "PRODUCT_CATEGORY_NAME", "PRODUCT_CATEGORY_NAME_ENGLISH", "INGESTED_AT")
    values
        ("PRODUCT_CATEGORY_ID", "PRODUCT_CATEGORY_NAME", "PRODUCT_CATEGORY_NAME_ENGLISH", "INGESTED_AT")

;
    commit;