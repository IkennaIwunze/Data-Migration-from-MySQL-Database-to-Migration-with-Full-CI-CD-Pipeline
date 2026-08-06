# tests/test_mysql_connector.py
import json
import decimal
import datetime
import sys
from pathlib import Path
from unittest.mock import MagicMock, patch, call

import pytest
from botocore.exceptions import ClientError

# Make ingestion/ importable
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "ingestion"))

import MySQL_Connector as mc


# ---------------------------------------------------------------------------
# json_default
# ---------------------------------------------------------------------------

def test_json_default_date():
    d = datetime.date(2026, 8, 5)
    assert mc.json_default(d) == "2026-08-05"


def test_json_default_datetime():
    dt = datetime.datetime(2026, 8, 5, 12, 30, 0)
    assert mc.json_default(dt) == dt.isoformat()


def test_json_default_decimal():
    assert mc.json_default(decimal.Decimal("19.99")) == 19.99
    assert isinstance(mc.json_default(decimal.Decimal("19.99")), float)


def test_json_default_bytes():
    assert mc.json_default(b"hello") == "hello"


def test_json_default_unsupported_type_raises():
    with pytest.raises(TypeError):
        mc.json_default(object())


# ---------------------------------------------------------------------------
# load_watermarks / save_watermarks (now backed by S3, not local disk)
# ---------------------------------------------------------------------------

def test_load_watermarks_missing_key_returns_empty_dict():
    mock_s3 = MagicMock()
    mock_s3.get_object.side_effect = ClientError(
        {"Error": {"Code": "NoSuchKey", "Message": "not found"}},
        "GetObject",
    )

    result = mc.load_watermarks(mock_s3)

    assert result == {}
    mock_s3.get_object.assert_called_once_with(
        Bucket=mc.S3_BUCKET, Key=mc.WATERMARK_S3_KEY
    )


def test_load_watermarks_other_client_error_raises():
    mock_s3 = MagicMock()
    mock_s3.get_object.side_effect = ClientError(
        {"Error": {"Code": "AccessDenied", "Message": "forbidden"}},
        "GetObject",
    )

    with pytest.raises(ClientError):
        mc.load_watermarks(mock_s3)


def test_load_watermarks_returns_parsed_json_when_key_exists():
    mock_s3 = MagicMock()
    state = {"raw_olist_customers": {"strategy": "keyset", "last_values": ["abc123"]}}
    body_bytes = json.dumps(state).encode("utf-8")

    mock_body = MagicMock()
    mock_body.read.return_value = body_bytes
    mock_s3.get_object.return_value = {"Body": mock_body}

    result = mc.load_watermarks(mock_s3)

    assert result == state


def test_save_watermarks_calls_put_object_with_correct_key_and_bucket():
    mock_s3 = MagicMock()
    state = {"raw_olist_customers": {"strategy": "keyset", "last_values": ["abc123"]}}

    mc.save_watermarks(mock_s3, state)

    mock_s3.put_object.assert_called_once()
    _, kwargs = mock_s3.put_object.call_args
    assert kwargs["Bucket"] == mc.S3_BUCKET
    assert kwargs["Key"] == mc.WATERMARK_S3_KEY

    body = json.loads(kwargs["Body"])
    assert body == state


def test_save_and_load_watermarks_roundtrip():
    """Simulate a save followed by a load against the same in-memory S3 mock,
    confirming the JSON written by save_watermarks is exactly what
    load_watermarks reads back."""
    mock_s3 = MagicMock()
    state = {"raw_olist_geolocation": {"strategy": "column", "last_value": 42}}

    mc.save_watermarks(mock_s3, state)
    written_body = mock_s3.put_object.call_args.kwargs["Body"]

    mock_body = MagicMock()
    mock_body.read.return_value = written_body
    mock_s3.get_object.return_value = {"Body": mock_body}

    loaded = mc.load_watermarks(mock_s3)

    assert loaded == state


# ---------------------------------------------------------------------------
# upload_batch
# ---------------------------------------------------------------------------

def test_upload_batch_stamps_ingested_at_and_calls_put_object():
    mock_s3 = MagicMock()
    rows = [{"customer_id": "c1"}, {"customer_id": "c2"}]

    mc.upload_batch(mock_s3, "raw_olist_customers", 1, rows)

    assert mock_s3.put_object.called
    _, kwargs = mock_s3.put_object.call_args
    assert kwargs["Bucket"] == mc.S3_BUCKET

    key = kwargs["Key"]
    assert key.startswith(f"{mc.S3_PREFIX}/raw_olist_customers/")
    assert "raw_olist_customers_batch00001_" in key

    body = json.loads(kwargs["Body"])
    assert len(body) == 2
    assert all("_ingested_at" in row for row in body)


def test_upload_batch_skips_empty_rows():
    mock_s3 = MagicMock()
    mc.upload_batch(mock_s3, "raw_olist_customers", 1, [])
    mock_s3.put_object.assert_not_called()


# ---------------------------------------------------------------------------
# ingest_column_strategy
# ---------------------------------------------------------------------------

def test_ingest_column_strategy_paginates_and_stops_on_short_batch(monkeypatch):
    mock_conn = MagicMock()
    mock_cursor = MagicMock()
    mock_conn.cursor.return_value = mock_cursor

    full_batch = [{"geolocation_id": i} for i in range(mc.BATCH_SIZE)]
    partial_batch = [{"geolocation_id": mc.BATCH_SIZE}, {"geolocation_id": mc.BATCH_SIZE + 1}]
    mock_cursor.fetchall.side_effect = [full_batch, partial_batch]

    mock_s3 = MagicMock()
    watermarks = {}
    table_cfg = {
        "table": "raw_olist_geolocation",
        "strategy": "column",
        "watermark_column": "geolocation_id",
    }

    mc.ingest_column_strategy(mock_conn, mock_s3, table_cfg, watermarks)

    assert mock_cursor.execute.call_count == 2
    # Each batch now triggers one upload_batch put_object plus one
    # save_watermarks put_object, so 2 batches -> 4 total put_object calls.
    assert mock_s3.put_object.call_count == 4
    assert watermarks["raw_olist_geolocation"]["last_value"] == mc.BATCH_SIZE + 1
    assert watermarks["raw_olist_geolocation"]["batch_number"] == 2


def test_ingest_column_strategy_no_rows_does_nothing(monkeypatch):
    mock_conn = MagicMock()
    mock_cursor = MagicMock()
    mock_conn.cursor.return_value = mock_cursor
    mock_cursor.fetchall.return_value = []

    mock_s3 = MagicMock()
    watermarks = {}
    table_cfg = {
        "table": "raw_olist_geolocation",
        "strategy": "column",
        "watermark_column": "geolocation_id",
    }

    mc.ingest_column_strategy(mock_conn, mock_s3, table_cfg, watermarks)

    mock_s3.put_object.assert_not_called()
    assert "raw_olist_geolocation" not in watermarks


# ---------------------------------------------------------------------------
# ingest_keyset_strategy
# ---------------------------------------------------------------------------

def test_ingest_keyset_strategy_paginates_on_composite_key(monkeypatch):
    mock_conn = MagicMock()
    mock_cursor = MagicMock()
    mock_conn.cursor.return_value = mock_cursor

    full_batch = [
        {"order_id": f"o{i}", "order_item_id": 1} for i in range(mc.BATCH_SIZE)
    ]
    partial_batch = [{"order_id": "o_last", "order_item_id": 1}]
    mock_cursor.fetchall.side_effect = [full_batch, partial_batch]

    mock_s3 = MagicMock()
    watermarks = {}
    table_cfg = {
        "table": "raw_olist_order_items",
        "strategy": "keyset",
        "keyset_columns": ["order_id", "order_item_id"],
    }

    mc.ingest_keyset_strategy(mock_conn, mock_s3, table_cfg, watermarks)

    assert mock_cursor.execute.call_count == 2
    assert watermarks["raw_olist_order_items"]["last_values"] == ["o_last", 1]
    assert watermarks["raw_olist_order_items"]["batch_number"] == 2