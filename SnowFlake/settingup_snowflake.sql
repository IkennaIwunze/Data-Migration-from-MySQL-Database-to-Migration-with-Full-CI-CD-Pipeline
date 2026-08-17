--Creating database and raw schema
CREATE DATABASE olist_dw;
CREATE SCHEMA olist_dw.raw;

--Creating the storage integragion to s3
CREATE STORAGE INTEGRATION s3_olist_integration
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'S3'
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::769488154012:role/s3-to-snowflake-connect'
  STORAGE_ALLOWED_LOCATIONS = ('s3://olist-raw-datasets/ecommerce-dataset/');

--Retrieving Snowflake AWS identity
DESC STORAGE INTEGRATION s3_olist_integration;

--Creating JSON file format
CREATE FILE FORMAT olist_dw.raw.json_format
  TYPE = 'JSON'
  STRIP_OUTER_ARRAY = TRUE;

  --Creating external stage
  CREATE STAGE olist_dw.raw.olist_raw_stage
  URL = 's3://olist-raw-datasets/ecommerce-dataset/'
  STORAGE_INTEGRATION = s3_olist_integration
  FILE_FORMAT = olist_dw.raw.json_format;
  --confirming stage creation
  LIST @olist_dw.raw.olist_raw_stage;

  --Creating the raw tables
  CREATE TABLE olist_dw.raw.raw_olist_customers (
    customer_id STRING,
    customer_unique_id STRING,
    customer_zip_code_prefix STRING,
    customer_city STRING,
    customer_state STRING,
    _ingested_at TIMESTAMP_NTZ
);

CREATE TABLE olist_dw.raw.raw_olist_geolocation (
    geolocation_id NUMBER,
    geolocation_zip_code_prefix STRING,
    geolocation_lat STRING,
    geolocation_lng STRING,
    geolocation_city STRING,
    geolocation_state STRING,
    _ingested_at TIMESTAMP_NTZ
);

CREATE TABLE olist_dw.raw.raw_olist_sellers (
    seller_id STRING,
    seller_zip_code_prefix STRING,
    seller_city STRING,
    seller_state STRING,
    _ingested_at TIMESTAMP_NTZ
);

CREATE TABLE olist_dw.raw.raw_olist_product_category_translation (
    product_category_id NUMBER,
    product_category_name STRING,
    product_category_name_english STRING,
    _ingested_at TIMESTAMP_NTZ
);

CREATE TABLE olist_dw.raw.raw_olist_products (
    product_id STRING,
    product_category_name STRING,
    product_name_lenght STRING,
    product_description_lenght STRING,
    product_photos_qty STRING,
    product_weight_g STRING,
    product_length_cm STRING,
    product_height_cm STRING,
    product_width_cm STRING,
    _ingested_at TIMESTAMP_NTZ
);

CREATE TABLE olist_dw.raw.raw_olist_orders (
    order_id STRING,
    customer_id STRING,
    order_status STRING,
    order_purchase_timestamp STRING,
    order_approved_at STRING,
    order_delivered_carrier_date STRING,
    order_delivered_customer_date STRING,
    order_estimated_delivery_date STRING,
    _ingested_at TIMESTAMP_NTZ
);

CREATE TABLE olist_dw.raw.raw_olist_order_items (
    order_id STRING,
    order_item_id STRING,
    product_id STRING,
    seller_id STRING,
    shipping_limit_date STRING,
    price STRING,
    freight_value STRING,
    _ingested_at TIMESTAMP_NTZ
);

CREATE TABLE olist_dw.raw.raw_olist_order_payments (
    payment_id NUMBER,
    order_id STRING,
    payment_sequential STRING,
    payment_type STRING,
    payment_installments STRING,
    payment_value STRING,
    _ingested_at TIMESTAMP_NTZ
);

CREATE TABLE olist_dw.raw.raw_olist_order_reviews (
    review_pk_id NUMBER,
    review_id STRING,
    order_id STRING,
    review_score STRING,
    review_comment_title STRING,
    review_comment_message STRING,
    review_creation_date STRING,
    review_answer_timestamp STRING,
    _ingested_at TIMESTAMP_NTZ
);

--Loading the raw table from the external stage
-- 1. Customers
COPY INTO olist_dw.raw.raw_olist_customers
  (customer_id, customer_unique_id, customer_zip_code_prefix, customer_city, customer_state, _ingested_at)
FROM (
  SELECT
    $1:customer_id::STRING,
    $1:customer_unique_id::STRING,
    $1:customer_zip_code_prefix::STRING,
    $1:customer_city::STRING,
    $1:customer_state::STRING,
    $1:_ingested_at::TIMESTAMP_NTZ
  FROM @olist_dw.raw.olist_raw_stage/raw_olist_customers/
)
FILE_FORMAT = (FORMAT_NAME = olist_dw.raw.json_format)
ON_ERROR = 'CONTINUE';

-- 2. Geolocation
COPY INTO olist_dw.raw.raw_olist_geolocation
  (geolocation_id, geolocation_zip_code_prefix, geolocation_lat, geolocation_lng, geolocation_city, geolocation_state, _ingested_at)
FROM (
  SELECT
    $1:geolocation_id::NUMBER,
    $1:geolocation_zip_code_prefix::STRING,
    $1:geolocation_lat::STRING,
    $1:geolocation_lng::STRING,
    $1:geolocation_city::STRING,
    $1:geolocation_state::STRING,
    $1:_ingested_at::TIMESTAMP_NTZ
  FROM @olist_dw.raw.olist_raw_stage/raw_olist_geolocation/
)
FILE_FORMAT = (FORMAT_NAME = olist_dw.raw.json_format)
ON_ERROR = 'CONTINUE';

-- 3. Sellers
COPY INTO olist_dw.raw.raw_olist_sellers
  (seller_id, seller_zip_code_prefix, seller_city, seller_state, _ingested_at)
FROM (
  SELECT
    $1:seller_id::STRING,
    $1:seller_zip_code_prefix::STRING,
    $1:seller_city::STRING,
    $1:seller_state::STRING,
    $1:_ingested_at::TIMESTAMP_NTZ
  FROM @olist_dw.raw.olist_raw_stage/raw_olist_sellers/
)
FILE_FORMAT = (FORMAT_NAME = olist_dw.raw.json_format)
ON_ERROR = 'CONTINUE';

-- 4. Product Category Translation
COPY INTO olist_dw.raw.raw_olist_product_category_translation
  (product_category_id, product_category_name, product_category_name_english, _ingested_at)
FROM (
  SELECT
    $1:product_category_id::NUMBER,
    $1:product_category_name::STRING,
    $1:product_category_name_english::STRING,
    $1:_ingested_at::TIMESTAMP_NTZ
  FROM @olist_dw.raw.olist_raw_stage/raw_olist_product_category_translation/
)
FILE_FORMAT = (FORMAT_NAME = olist_dw.raw.json_format)
ON_ERROR = 'CONTINUE';

-- 5. Products
COPY INTO olist_dw.raw.raw_olist_products
  (product_id, product_category_name, product_name_lenght, product_description_lenght,
   product_photos_qty, product_weight_g, product_length_cm, product_height_cm, product_width_cm, _ingested_at)
FROM (
  SELECT
    $1:product_id::STRING,
    $1:product_category_name::STRING,
    $1:product_name_lenght::STRING,
    $1:product_description_lenght::STRING,
    $1:product_photos_qty::STRING,
    $1:product_weight_g::STRING,
    $1:product_length_cm::STRING,
    $1:product_height_cm::STRING,
    $1:product_width_cm::STRING,
    $1:_ingested_at::TIMESTAMP_NTZ
  FROM @olist_dw.raw.olist_raw_stage/raw_olist_products/
)
FILE_FORMAT = (FORMAT_NAME = olist_dw.raw.json_format)
ON_ERROR = 'CONTINUE';

-- 6. Orders
COPY INTO olist_dw.raw.raw_olist_orders
  (order_id, customer_id, order_status, order_purchase_timestamp, order_approved_at,
   order_delivered_carrier_date, order_delivered_customer_date, order_estimated_delivery_date, _ingested_at)
FROM (
  SELECT
    $1:order_id::STRING,
    $1:customer_id::STRING,
    $1:order_status::STRING,
    $1:order_purchase_timestamp::STRING,
    $1:order_approved_at::STRING,
    $1:order_delivered_carrier_date::STRING,
    $1:order_delivered_customer_date::STRING,
    $1:order_estimated_delivery_date::STRING,
    $1:_ingested_at::TIMESTAMP_NTZ
  FROM @olist_dw.raw.olist_raw_stage/raw_olist_orders/
)
FILE_FORMAT = (FORMAT_NAME = olist_dw.raw.json_format)
ON_ERROR = 'CONTINUE';

-- 7. Order Items
COPY INTO olist_dw.raw.raw_olist_order_items
  (order_id, order_item_id, product_id, seller_id, shipping_limit_date, price, freight_value, _ingested_at)
FROM (
  SELECT
    $1:order_id::STRING,
    $1:order_item_id::STRING,
    $1:product_id::STRING,
    $1:seller_id::STRING,
    $1:shipping_limit_date::STRING,
    $1:price::STRING,
    $1:freight_value::STRING,
    $1:_ingested_at::TIMESTAMP_NTZ
  FROM @olist_dw.raw.olist_raw_stage/raw_olist_order_items/
)
FILE_FORMAT = (FORMAT_NAME = olist_dw.raw.json_format)
ON_ERROR = 'CONTINUE';

-- 8. Order Payments
COPY INTO olist_dw.raw.raw_olist_order_payments
  (payment_id, order_id, payment_sequential, payment_type, payment_installments, payment_value, _ingested_at)
FROM (
  SELECT
    $1:payment_id::NUMBER,
    $1:order_id::STRING,
    $1:payment_sequential::STRING,
    $1:payment_type::STRING,
    $1:payment_installments::STRING,
    $1:payment_value::STRING,
    $1:_ingested_at::TIMESTAMP_NTZ
  FROM @olist_dw.raw.olist_raw_stage/raw_olist_order_payments/
)
FILE_FORMAT = (FORMAT_NAME = olist_dw.raw.json_format)
ON_ERROR = 'CONTINUE';

-- 9. Order Reviews
COPY INTO olist_dw.raw.raw_olist_order_reviews
  (review_pk_id, review_id, order_id, review_score, review_comment_title, review_comment_message,
   review_creation_date, review_answer_timestamp, _ingested_at)
FROM (
  SELECT
    $1:review_pk_id::NUMBER,
    $1:review_id::STRING,
    $1:order_id::STRING,
    $1:review_score::STRING,
    $1:review_comment_title::STRING,
    $1:review_comment_message::STRING,
    $1:review_creation_date::STRING,
    $1:review_answer_timestamp::STRING,
    $1:_ingested_at::TIMESTAMP_NTZ
  FROM @olist_dw.raw.olist_raw_stage/raw_olist_order_reviews/
)
FILE_FORMAT = (FORMAT_NAME = olist_dw.raw.json_format)
ON_ERROR = 'CONTINUE';





--Stored procedure to load tables
CREATE OR REPLACE PROCEDURE olist_dw.raw.load_today(target_table STRING)
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
  today_date DATE DEFAULT CURRENT_DATE();
  s3_path STRING;
  copy_sql STRING;
  select_cols STRING;
  target_cols STRING;
BEGIN
  s3_path := '@olist_dw.raw.olist_raw_stage/' || :target_table || '/' ||
             TO_CHAR(:today_date, 'YYYY') || '/' ||
             TO_CHAR(:today_date, 'MM') || '/' ||
             TO_CHAR(:today_date, 'DD') || '/';

  CASE (:target_table)
    WHEN 'raw_olist_customers' THEN
      target_cols := 'customer_id, customer_unique_id, customer_zip_code_prefix, customer_city, customer_state, _ingested_at';
      select_cols := '$1:customer_id::STRING, $1:customer_unique_id::STRING, $1:customer_zip_code_prefix::STRING, $1:customer_city::STRING, $1:customer_state::STRING, $1:_ingested_at::TIMESTAMP_NTZ';

    WHEN 'raw_olist_geolocation' THEN
      target_cols := 'geolocation_id, geolocation_zip_code_prefix, geolocation_lat, geolocation_lng, geolocation_city, geolocation_state, _ingested_at';
      select_cols := '$1:geolocation_id::NUMBER, $1:geolocation_zip_code_prefix::STRING, $1:geolocation_lat::STRING, $1:geolocation_lng::STRING, $1:geolocation_city::STRING, $1:geolocation_state::STRING, $1:_ingested_at::TIMESTAMP_NTZ';

    WHEN 'raw_olist_sellers' THEN
      target_cols := 'seller_id, seller_zip_code_prefix, seller_city, seller_state, _ingested_at';
      select_cols := '$1:seller_id::STRING, $1:seller_zip_code_prefix::STRING, $1:seller_city::STRING, $1:seller_state::STRING, $1:_ingested_at::TIMESTAMP_NTZ';

    WHEN 'raw_olist_product_category_translation' THEN
      target_cols := 'product_category_id, product_category_name, product_category_name_english, _ingested_at';
      select_cols := '$1:product_category_id::NUMBER, $1:product_category_name::STRING, $1:product_category_name_english::STRING, $1:_ingested_at::TIMESTAMP_NTZ';

    WHEN 'raw_olist_products' THEN
      target_cols := 'product_id, product_category_name, product_name_lenght, product_description_lenght, product_photos_qty, product_weight_g, product_length_cm, product_height_cm, product_width_cm, _ingested_at';
      select_cols := '$1:product_id::STRING, $1:product_category_name::STRING, $1:product_name_lenght::STRING, $1:product_description_lenght::STRING, $1:product_photos_qty::STRING, $1:product_weight_g::STRING, $1:product_length_cm::STRING, $1:product_height_cm::STRING, $1:product_width_cm::STRING, $1:_ingested_at::TIMESTAMP_NTZ';

    WHEN 'raw_olist_orders' THEN
      target_cols := 'order_id, customer_id, order_status, order_purchase_timestamp, order_approved_at, order_delivered_carrier_date, order_delivered_customer_date, order_estimated_delivery_date, _ingested_at';
      select_cols := '$1:order_id::STRING, $1:customer_id::STRING, $1:order_status::STRING, $1:order_purchase_timestamp::STRING, $1:order_approved_at::STRING, $1:order_delivered_carrier_date::STRING, $1:order_delivered_customer_date::STRING, $1:order_estimated_delivery_date::STRING, $1:_ingested_at::TIMESTAMP_NTZ';

    WHEN 'raw_olist_order_items' THEN
      target_cols := 'order_id, order_item_id, product_id, seller_id, shipping_limit_date, price, freight_value, _ingested_at';
      select_cols := '$1:order_id::STRING, $1:order_item_id::STRING, $1:product_id::STRING, $1:seller_id::STRING, $1:shipping_limit_date::STRING, $1:price::STRING, $1:freight_value::STRING, $1:_ingested_at::TIMESTAMP_NTZ';

    WHEN 'raw_olist_order_payments' THEN
      target_cols := 'payment_id, order_id, payment_sequential, payment_type, payment_installments, payment_value, _ingested_at';
      select_cols := '$1:payment_id::NUMBER, $1:order_id::STRING, $1:payment_sequential::STRING, $1:payment_type::STRING, $1:payment_installments::STRING, $1:payment_value::STRING, $1:_ingested_at::TIMESTAMP_NTZ';

    WHEN 'raw_olist_order_reviews' THEN
      target_cols := 'review_pk_id, review_id, order_id, review_score, review_comment_title, review_comment_message, review_creation_date, review_answer_timestamp, _ingested_at';
      select_cols := '$1:review_pk_id::NUMBER, $1:review_id::STRING, $1:order_id::STRING, $1:review_score::STRING, $1:review_comment_title::STRING, $1:review_comment_message::STRING, $1:review_creation_date::STRING, $1:review_answer_timestamp::STRING, $1:_ingested_at::TIMESTAMP_NTZ';

    ELSE
      RETURN 'Unknown table: ' || :target_table;
  END CASE;

  copy_sql := 'COPY INTO olist_dw.raw.' || :target_table || ' (' || :target_cols || ') ' ||
              'FROM (SELECT ' || :select_cols || ' FROM ' || :s3_path || ') ' ||
              'FILE_FORMAT = (FORMAT_NAME = olist_dw.raw.json_format) ' ||
              'ON_ERROR = ''CONTINUE''';

  EXECUTE IMMEDIATE :copy_sql;

  RETURN 'Loaded ' || :target_table || ' for date ' || :today_date;
END;
$$;
--Stored Procedure to load all 9 tables
CREATE OR REPLACE PROCEDURE olist_dw.raw.load_all_tables()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
  result STRING DEFAULT '';
  tables ARRAY DEFAULT ARRAY_CONSTRUCT(
    'raw_olist_customers',
    'raw_olist_geolocation',
    'raw_olist_sellers',
    'raw_olist_product_category_translation',
    'raw_olist_products',
    'raw_olist_orders',
    'raw_olist_order_items',
    'raw_olist_order_payments',
    'raw_olist_order_reviews'
  );
  tbl STRING;
  i INT DEFAULT 0;
BEGIN
  FOR i IN 0 TO ARRAY_SIZE(:tables) - 1 DO
    tbl := GET(:tables, :i)::STRING;
    CALL olist_dw.raw.load_today(:tbl) INTO :result;
    result := result || ' | ' || tbl || ': done';
  END FOR;

  RETURN result;
END;
$$;

--Task for loading all 9 tables
CREATE TASK olist_dw.raw.daily_load_all
  WAREHOUSE = olist_wh
  SCHEDULE = 'USING CRON 0 6 * * * UTC'
AS
CALL olist_dw.raw.load_all_tables();
