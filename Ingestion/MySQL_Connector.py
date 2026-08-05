import json
import decimal
import datetime
import os
from pathlib import Path
import boto3
import mysql.connector
from botocore.exceptions import ClientError
from dotenv import load_dotenv

PROJECT_ROOT = Path(__file__).resolve().parent.parent
ENV_PATH = PROJECT_ROOT / ".env"

# Load explicitly from the project root
load_dotenv(dotenv_path=ENV_PATH)

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

MYSQL_CONFIG = {
    "host": os.environ.get("MYSQL_HOST", ""),
    "port": 18091,
    "user": os.environ.get("MYSQL_USER", ""),
    "password": os.environ.get("MYSQL_PASSWORD", ""),
    "database": os.environ.get("MYSQL_DATABASE", ""),
    "ssl_disabled": False,
}

S3_BUCKET = os.environ.get("S3_BUCKET_NAME", "")
S3_PREFIX = "ecommerce-dataset"  # top-level folder in the bucket

WATERMARK_S3_KEY = "pipeline-state/watermark_state.json"
BATCH_SIZE = 5000

TABLES = [
    {
        "table": "raw_olist_customers",
        "strategy": "keyset",
        "keyset_columns": ["customer_id"],
    },
    {
        "table": "raw_olist_geolocation",
        "strategy": "column",
        "watermark_column": "geolocation_id",
    },
    {
        "table": "raw_olist_sellers",
        "strategy": "keyset",
        "keyset_columns": ["seller_id"],
    },
    {
        "table": "raw_olist_product_category_translation",
        "strategy": "column",
        "watermark_column": "product_category_id",
    },
    {
        "table": "raw_olist_products",
        "strategy": "keyset",
        "keyset_columns": ["product_id"],
    },
    {
        "table": "raw_olist_orders",
        "strategy": "keyset",
        "keyset_columns": ["order_id"],
    },
    {
        "table": "raw_olist_order_items",
        "strategy": "keyset",
        "keyset_columns": ["order_id", "order_item_id"],
    },
    {
        "table": "raw_olist_order_payments",
        "strategy": "column",
        "watermark_column": "payment_id",
    },
    {
        "table": "raw_olist_order_reviews",
        "strategy": "column",
        "watermark_column": "review_pk_id",
    },
]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def json_default(obj):
    """Handle types that json.dumps can't serialize natively."""
    if isinstance(obj, (datetime.date, datetime.datetime)):
        return obj.isoformat()
    if isinstance(obj, decimal.Decimal):
        return float(obj)
    if isinstance(obj, (bytes, bytearray)):
        return obj.decode("utf-8", errors="replace")
    raise TypeError(f"Type {type(obj)} not serializable")


def load_watermarks(s3):
    """Read watermark_state.json from S3. Returns {} if it doesn't exist yet
    (e.g. first-ever run)."""
    try:
        response = s3.get_object(Bucket=S3_BUCKET, Key=WATERMARK_S3_KEY)
        return json.loads(response["Body"].read().decode("utf-8"))
    except ClientError as e:
        if e.response["Error"]["Code"] in ("NoSuchKey", "404"):
            return {}
        raise


def save_watermarks(s3, state):
    """Write watermark_state.json to S3, overwriting the previous version."""
    body = json.dumps(state, indent=2, default=str)
    s3.put_object(Bucket=S3_BUCKET, Key=WATERMARK_S3_KEY, Body=body.encode("utf-8"))


def get_s3_client():
    return boto3.client("s3")


def upload_batch(s3, table_name, batch_number, rows):
    """Write a batch of rows as JSON into a date-partitioned S3 path,
    stamping each row with the ingestion timestamp."""
    if not rows:
        return

    now = datetime.datetime.utcnow()
    ingestion_ts = now.isoformat()

    year = now.strftime("%Y")
    month = now.strftime("%m")
    day = now.strftime("%d")
    timestamp = now.strftime("%Y%m%dT%H%M%S")

    for row in rows:
        row["_ingested_at"] = ingestion_ts

    key = (
        f"{S3_PREFIX}/{table_name}/{year}/{month}/{day}/"
        f"{table_name}_batch{batch_number:05d}_{timestamp}.json"
    )

    body = json.dumps(rows, default=json_default)
    s3.put_object(Bucket=S3_BUCKET, Key=key, Body=body.encode("utf-8"))

    print(f"  -> uploaded {len(rows)} rows to s3://{S3_BUCKET}/{key}")


# ---------------------------------------------------------------------------
# Ingestion strategies
# ---------------------------------------------------------------------------

def ingest_column_strategy(conn, s3, table_cfg, watermarks):
    """Page through rows using WHERE watermark_column > last_value ORDER BY it."""
    table = table_cfg["table"]
    col = table_cfg["watermark_column"]
    last_value = watermarks.get(table, {}).get("last_value")

    cursor = conn.cursor(dictionary=True)
    batch_number = watermarks.get(table, {}).get("batch_number", 0)

    while True:
        if last_value is None:
            query = f"SELECT * FROM {table} ORDER BY {col} LIMIT %s"
            params = (BATCH_SIZE,)
        else:
            query = f"SELECT * FROM {table} WHERE {col} > %s ORDER BY {col} LIMIT %s"
            params = (last_value, BATCH_SIZE)

        cursor.execute(query, params)
        rows = cursor.fetchall()

        if not rows:
            break

        batch_number += 1
        upload_batch(s3, table, batch_number, rows)

        last_value = rows[-1][col]
        watermarks[table] = {
            "strategy": "column",
            "last_value": last_value,
            "batch_number": batch_number,
            "updated_at": datetime.datetime.utcnow().isoformat(),
        }
        save_watermarks(s3, watermarks)

        if len(rows) < BATCH_SIZE:
            break

    cursor.close()


def ingest_keyset_strategy(conn, s3, table_cfg, watermarks):
    """Page through rows using keyset pagination on the primary key column(s)."""
    table = table_cfg["table"]
    key_cols = table_cfg["keyset_columns"]
    last_values = watermarks.get(table, {}).get("last_values")

    cursor = conn.cursor(dictionary=True)
    batch_number = watermarks.get(table, {}).get("batch_number", 0)
    order_clause = ", ".join(key_cols)

    while True:
        if last_values is None:
            query = f"SELECT * FROM {table} ORDER BY {order_clause} LIMIT %s"
            params = (BATCH_SIZE,)
        else:
            placeholders = ", ".join(["%s"] * len(key_cols))
            cols_tuple = ", ".join(key_cols)
            query = (
                f"SELECT * FROM {table} "
                f"WHERE ({cols_tuple}) > ({placeholders}) "
                f"ORDER BY {order_clause} LIMIT %s"
            )
            params = tuple(last_values) + (BATCH_SIZE,)

        cursor.execute(query, params)
        rows = cursor.fetchall()

        if not rows:
            break

        batch_number += 1
        upload_batch(s3, table, batch_number, rows)

        last_row = rows[-1]
        last_values = [last_row[c] for c in key_cols]
        watermarks[table] = {
            "strategy": "keyset",
            "last_values": last_values,
            "batch_number": batch_number,
            "updated_at": datetime.datetime.utcnow().isoformat(),
        }
        save_watermarks(s3, watermarks)

        if len(rows) < BATCH_SIZE:
            break

    cursor.close()


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    s3 = get_s3_client()
    watermarks = load_watermarks(s3)
    conn = mysql.connector.connect(**MYSQL_CONFIG)

    try:
        for table_cfg in TABLES:
            table = table_cfg["table"]
            print(f"Ingesting {table} (strategy: {table_cfg['strategy']})...")

            if table_cfg["strategy"] == "column":
                ingest_column_strategy(conn, s3, table_cfg, watermarks)
            elif table_cfg["strategy"] == "keyset":
                ingest_keyset_strategy(conn, s3, table_cfg, watermarks)
            else:
                raise ValueError(f"Unknown strategy for {table}")

            print(f"Done with {table}.\n")
    finally:
        conn.close()

    print("All tables ingested.")


if __name__ == "__main__":
    main()