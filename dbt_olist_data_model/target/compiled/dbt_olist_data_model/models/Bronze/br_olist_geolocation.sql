

select
    geolocation_id::number as geolocation_id,
    geolocation_zip_code_prefix,
    geolocation_lat::float as geolocation_lat,
    geolocation_lng::float as geolocation_lng,
    geolocation_city,
    geolocation_state,
    _ingested_at::timestamp_ntz as ingested_at
from olist_dw.raw.raw_olist_geolocation


where _ingested_at::timestamp_ntz > (select max(ingested_at) from OLIST_DW.bronze.br_olist_geolocation)
