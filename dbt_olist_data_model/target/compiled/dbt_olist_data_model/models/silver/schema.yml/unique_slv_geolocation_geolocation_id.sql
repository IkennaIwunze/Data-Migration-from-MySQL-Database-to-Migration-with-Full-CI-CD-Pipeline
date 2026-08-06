
    
    

select
    geolocation_id as unique_field,
    count(*) as n_records

from OLIST_DW.silver.slv_geolocation
where geolocation_id is not null
group by geolocation_id
having count(*) > 1


