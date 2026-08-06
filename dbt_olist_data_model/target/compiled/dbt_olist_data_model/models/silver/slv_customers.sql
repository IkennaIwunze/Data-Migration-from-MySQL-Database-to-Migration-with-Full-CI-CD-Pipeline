

select
    customer_id,
    customer_unique_id,

    case
        when customer_zip_code_prefix is null then 'Unknown'
        else customer_zip_code_prefix
    end as customer_zip_code_prefix,

    case
        when customer_city is null then 'Unknown'
        when customer_city regexp '^[0-9].*' then 'Unknown'
        else initcap(trim(customer_city))
    end as customer_city,

    case
        when customer_state is null then 'Unknown'
        when customer_state regexp '^[0-9].*' then 'Unknown'
        else upper(trim(customer_state))
    end as customer_state,

    ingested_at
from OLIST_DW.bronze.br_olist_customers


where ingested_at > (select max(ingested_at) from OLIST_DW.silver.slv_customers)
