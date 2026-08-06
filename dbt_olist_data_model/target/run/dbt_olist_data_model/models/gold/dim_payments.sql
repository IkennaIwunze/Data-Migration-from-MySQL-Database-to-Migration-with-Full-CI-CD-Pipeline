-- back compat for old kwarg name
  
  begin;
    
        
            
            
            
            
        
    

    

    merge into OLIST_DW.gold.dim_payments as DBT_INTERNAL_DEST
        using OLIST_DW.gold.dim_payments__dbt_tmp as DBT_INTERNAL_SOURCE
        on ((DBT_INTERNAL_SOURCE.payment_id = DBT_INTERNAL_DEST.payment_id))

    
    when matched then update set
        "PAYMENT_SK" = DBT_INTERNAL_SOURCE."PAYMENT_SK","PAYMENT_ID" = DBT_INTERNAL_SOURCE."PAYMENT_ID","ORDER_ID" = DBT_INTERNAL_SOURCE."ORDER_ID","PAYMENT_SEQUENTIAL" = DBT_INTERNAL_SOURCE."PAYMENT_SEQUENTIAL","PAYMENT_TYPE" = DBT_INTERNAL_SOURCE."PAYMENT_TYPE","PAYMENT_INSTALLMENTS" = DBT_INTERNAL_SOURCE."PAYMENT_INSTALLMENTS","INGESTED_AT" = DBT_INTERNAL_SOURCE."INGESTED_AT"
    

    when not matched then insert
        ("PAYMENT_SK", "PAYMENT_ID", "ORDER_ID", "PAYMENT_SEQUENTIAL", "PAYMENT_TYPE", "PAYMENT_INSTALLMENTS", "INGESTED_AT")
    values
        ("PAYMENT_SK", "PAYMENT_ID", "ORDER_ID", "PAYMENT_SEQUENTIAL", "PAYMENT_TYPE", "PAYMENT_INSTALLMENTS", "INGESTED_AT")

;
    commit;