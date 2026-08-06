-- back compat for old kwarg name
  
  begin;
    
        
            
                
                
            
                
                
            
        
    

    

    merge into OLIST_DW.bronze.br_olist_order_items as DBT_INTERNAL_DEST
        using OLIST_DW.bronze.br_olist_order_items__dbt_tmp as DBT_INTERNAL_SOURCE
        on (
                    DBT_INTERNAL_SOURCE.order_id = DBT_INTERNAL_DEST.order_id
                ) and (
                    DBT_INTERNAL_SOURCE.order_item_id = DBT_INTERNAL_DEST.order_item_id
                )

    
    when matched then update set
        "ORDER_ID" = DBT_INTERNAL_SOURCE."ORDER_ID","ORDER_ITEM_ID" = DBT_INTERNAL_SOURCE."ORDER_ITEM_ID","PRODUCT_ID" = DBT_INTERNAL_SOURCE."PRODUCT_ID","SELLER_ID" = DBT_INTERNAL_SOURCE."SELLER_ID","SHIPPING_LIMIT_DATE" = DBT_INTERNAL_SOURCE."SHIPPING_LIMIT_DATE","PRICE" = DBT_INTERNAL_SOURCE."PRICE","FREIGHT_VALUE" = DBT_INTERNAL_SOURCE."FREIGHT_VALUE","INGESTED_AT" = DBT_INTERNAL_SOURCE."INGESTED_AT"
    

    when not matched then insert
        ("ORDER_ID", "ORDER_ITEM_ID", "PRODUCT_ID", "SELLER_ID", "SHIPPING_LIMIT_DATE", "PRICE", "FREIGHT_VALUE", "INGESTED_AT")
    values
        ("ORDER_ID", "ORDER_ITEM_ID", "PRODUCT_ID", "SELLER_ID", "SHIPPING_LIMIT_DATE", "PRICE", "FREIGHT_VALUE", "INGESTED_AT")

;
    commit;