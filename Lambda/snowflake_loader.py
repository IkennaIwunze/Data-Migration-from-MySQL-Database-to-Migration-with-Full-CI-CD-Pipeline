import json
import os
import snowflake.connector
import boto3

secrets_client = boto3.client("secretsmanager")
SNOWFLAKE_SECRET_ARN = os.environ["SNOWFLAKE_SECRET_ARN"]


def get_snowflake_credentials():
    response = secrets_client.get_secret_value(SecretId=SNOWFLAKE_SECRET_ARN)
    return json.loads(response["SecretString"])


def lambda_handler(event, context):
    creds = get_snowflake_credentials()

    conn = snowflake.connector.connect(
        account=creds["SNOWFLAKE_ACCOUNT"],
        user=creds["SNOWFLAKE_USER"],
        password=creds["SNOWFLAKE_PASSWORD"],
        role=creds["SNOWFLAKE_ROLE"],
        database=creds["SNOWFLAKE_DATABASE"],
        warehouse=creds["SNOWFLAKE_WAREHOUSE"],
        schema="raw",
    )

    try:
        cursor = conn.cursor()
        cursor.execute("CALL olist_dw.raw.load_all_tables()")
        result = cursor.fetchone()[0]
        return {"status": "success", "result": result}
    finally:
        conn.close()