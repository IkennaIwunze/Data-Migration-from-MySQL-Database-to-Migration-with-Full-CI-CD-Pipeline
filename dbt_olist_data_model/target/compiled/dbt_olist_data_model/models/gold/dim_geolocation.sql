

select
    md5(geolocation_id::string) as geolocation_sk,
    geolocation_id,
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state,
    ingested_at
from OLIST_DW.silver.slv_geolocation


where ingested_at > (select max(ingested_at) from OLIST_DW.gold.dim_geolocation)
