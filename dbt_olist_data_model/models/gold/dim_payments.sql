{{
    config(
        materialized='incremental',
        unique_key='payment_id',
        incremental_strategy='merge'
    )
}}

select
    md5(payment_id::string) as payment_sk,
    payment_id,
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    ingested_at
from {{ ref('slv_order_payments') }}

{% if is_incremental() %}
where ingested_at > (select max(ingested_at) from {{ this }})
{% endif %}