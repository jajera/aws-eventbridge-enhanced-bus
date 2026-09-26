"""Evaluate feed events and open/clear rows in health-alerts (dev account)."""

from __future__ import annotations

import json
import os
import time
from decimal import Decimal
from typing import Any

import boto3

TABLE_NAME = os.environ.get("HEALTH_ALERTS_TABLE", "health-alerts")

RSSI_WEAK = int(os.environ.get("RSSI_WEAK", "-80"))
TEMP_HIGH = float(os.environ.get("TEMP_HIGH", "55"))
HEAP_LOW = int(os.environ.get("HEAP_LOW", "100000"))

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(TABLE_NAME)


def _to_decimal(value: Any) -> Any:
    if isinstance(value, float):
        return Decimal(str(value))
    if isinstance(value, dict):
        return {k: _to_decimal(v) for k, v in value.items()}
    if isinstance(value, list):
        return [_to_decimal(v) for v in value]
    return value


def _unwrap(event: dict) -> tuple[str, dict, str | None]:
    """Return (detail_type, payload, event_group_id)."""
    # Classic-style envelope from put-events without WITH_METADATA
    if "detail-type" in event and "detail" in event:
        detail = event["detail"]
        if isinstance(detail, str):
            detail = json.loads(detail)
        return str(event.get("detail-type", "")), detail, None

    # WITH_METADATA / raw delivery shape
    data = event.get("Data", event)
    if isinstance(data, str):
        data = json.loads(data)
    if isinstance(data, dict) and "detail" in data:
        detail = data["detail"]
        if isinstance(detail, str):
            detail = json.loads(detail)
        detail_type = str(data.get("detail-type") or event.get("detail-type") or "")
        group = None
        meta = event.get("SystemMetadata") or {}
        if isinstance(meta, dict):
            group = meta.get("EventGroupId")
        return detail_type, detail if isinstance(detail, dict) else {}, group

    if "device_id" in event:
        return str(event.get("type", "connectivity")), event, event.get("device_id")

    raise ValueError(f"Unrecognized event shape: {list(event.keys())}")


def _evaluate(detail_type: str, payload: dict) -> tuple[str, str]:
    if detail_type == "button" or payload.get("type") == "button":
        return "OPEN", "attention_button"

    rssi = payload.get("rssi")
    temp = payload.get("chip_temp_c")
    heap = payload.get("heap_free")

    if rssi is not None and int(rssi) < RSSI_WEAK:
        return "OPEN", "weak_rssi"
    if temp is not None and float(temp) > TEMP_HIGH:
        return "OPEN", "high_temp"
    if heap is not None and int(heap) < HEAP_LOW:
        return "OPEN", "low_heap"
    return "CLEAR", "healthy"


def _source_ts(payload: dict) -> int:
    try:
        ts = int(payload.get("ts", 0))
    except (TypeError, ValueError):
        ts = 0
    return ts if ts > 0 else int(time.time())


def handler(event, context):
    # FIFO Subscriber may deliver a bare list (batch) or a single object.
    if isinstance(event, list):
        return {"ok": True, "results": [_process_one(_coerce_record(item)) for item in event]}

    if isinstance(event, dict):
        records = event.get("Records")
        if isinstance(records, list):
            return {
                "ok": True,
                "results": [_process_one(_coerce_record(record)) for record in records],
            }
        return _process_one(event)

    if isinstance(event, (str, bytes, bytearray)):
        return _process_one(json.loads(event))

    raise TypeError(f"Unsupported event type: {type(event).__name__}")


def _coerce_record(record: Any) -> dict:
    if isinstance(record, dict):
        body = record.get("body", record)
        if isinstance(body, str):
            body = json.loads(body)
        if isinstance(body, dict):
            return body
        raise TypeError(f"Unsupported record body type: {type(body).__name__}")
    if isinstance(record, (str, bytes, bytearray)):
        parsed = json.loads(record)
        if isinstance(parsed, dict):
            return parsed
        raise TypeError(f"Unsupported parsed record type: {type(parsed).__name__}")
    raise TypeError(f"Unsupported record type: {type(record).__name__}")


def _process_one(event: dict) -> dict:
    detail_type, payload, group = _unwrap(event)
    entity_id = str(
        group
        or payload.get("device_id")
        or (event.get("SystemMetadata") or {}).get("EventGroupId")
        or ""
    ).strip()
    if not entity_id:
        raise ValueError("entity_id / device_id required")

    source_ts = _source_ts(payload)
    status, reason = _evaluate(detail_type or str(payload.get("type", "")), payload)

    existing = table.get_item(Key={"entity_id": entity_id}).get("Item")
    if existing:
        prev_ts = int(existing.get("source_event_ts", 0))
        if source_ts < prev_ts:
            return {
                "ok": True,
                "noop": True,
                "entity_id": entity_id,
                "reason": "stale_event",
            }

    metrics = {
        k: payload[k]
        for k in ("rssi", "chip_temp_c", "heap_free", "uptime_s")
        if k in payload
    }
    item = {
        "entity_id": entity_id,
        "status": status,
        "reason": reason,
        "metrics": _to_decimal(metrics),
        "updated_ts": int(time.time()),
        "source_event_ts": source_ts,
        "detail_type": detail_type or str(payload.get("type", "")),
    }
    table.put_item(Item=item)
    return {"ok": True, "entity_id": entity_id, "status": status, "reason": reason}
