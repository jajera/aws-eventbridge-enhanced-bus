"""IoT → enhanced EventBridge adapter (lab).

AWS IoT topic-rule actions cannot call ``eventsv2 PutEvents`` onto an enhanced
bus (``event-busv2/...``) with ``SystemMetadata.EventGroupId``. This Lambda is
the required hop:

  IoT rules ``iot_talk_*`` (devices/fleet · events + telemetry)
    → ``eb-bridge``
    → ``eventsv2 PutEvents`` on ``lab-events``

Every entry is stamped with ``Source`` (env ``SOURCE``, default ``iot.lab``)
so the **dev** Subscriber DATA filter can match. ``EventGroupId`` is
``device_id`` for FIFO ordering. Camera payloads are rejected.

The existing ``iot-talk-ingest`` action on each wired rule stays; this path does
not touch talk DynamoDB / dashboard tables.
"""

from __future__ import annotations

import json
import logging
import os
from typing import Any

# Lambda's bundled botocore does not yet include eventbridgev2. Load the
# vendored service model under bridge/data/ (same shape as AWS CLI ≥ 2.37.3).
_DATA_DIR = os.path.join(os.path.dirname(__file__), "data")
_existing = os.environ.get("AWS_DATA_PATH", "")
os.environ["AWS_DATA_PATH"] = (
    _DATA_DIR if not _existing else f"{_DATA_DIR}{os.pathsep}{_existing}"
)

import boto3  # noqa: E402  — after AWS_DATA_PATH

logger = logging.getLogger()
logger.setLevel(logging.INFO)

EVENT_BUS_ARN = os.environ["EVENT_BUS_ARN"]
SOURCE = os.environ.get("SOURCE", "iot.lab")

# Do not put camera blobs on the bus.
_STRIP_KEYS = frozenset({"jpeg_b64", "data_b64", "image_b64"})

_client = None


def _events_v2():
    global _client
    if _client is None:
        _client = boto3.client("eventbridgev2")
    return _client


def _normalize(event: Any) -> dict:
    """Flatten IoT rule / direct-invoke payloads to a device dict."""
    if isinstance(event, (bytes, bytearray)):
        event = event.decode("utf-8")
    if isinstance(event, str):
        event = json.loads(event)

    if not isinstance(event, dict):
        raise ValueError(f"Unsupported event type: {type(event).__name__}")

    if "body" in event and isinstance(event["body"], str):
        event = json.loads(event["body"])
        if not isinstance(event, dict):
            raise ValueError("body must decode to an object")

    if "device_id" in event:
        return event

    for key in ("payload", "detail", "data"):
        nested = event.get(key)
        if isinstance(nested, str):
            nested = json.loads(nested)
        if isinstance(nested, dict) and "device_id" in nested:
            return nested

    raise ValueError(
        "device_id required (expected IoT SELECT * device JSON or nested payload)"
    )


def _detail_for_bus(payload: dict) -> dict:
    """Copy payload without bulky / non-event fields."""
    out = {k: v for k, v in payload.items() if k not in _STRIP_KEYS}
    kind = str(out.get("type", "")).strip()
    if kind == "camera":
        raise ValueError("camera payloads are not published to the enhanced bus")
    return out


def handler(event, context):
    payload = _normalize(event)
    device_id = str(payload.get("device_id", "")).strip()
    if not device_id:
        raise ValueError("device_id must be non-empty")

    detail_obj = _detail_for_bus(payload)
    detail_type = str(detail_obj.get("type", "connectivity")).strip() or "connectivity"
    detail = json.dumps(detail_obj, separators=(",", ":"))

    system_metadata: dict[str, str] = {"EventGroupId": device_id}
    try:
        ts = int(detail_obj.get("ts", 0))
    except (TypeError, ValueError):
        ts = 0
    if ts > 0:
        # Stable within the device+ts+type window; helps FIFO subscribers.
        system_metadata["DeduplicationId"] = f"{device_id}:{ts}:{detail_type}"[:128]

    resp = _events_v2().put_events(
        EventBusArn=EVENT_BUS_ARN,
        Entries=[
            {
                "Source": SOURCE,
                "DetailType": detail_type,
                "Detail": detail,
                "SystemMetadata": system_metadata,
            }
        ],
    )
    failed = int(resp.get("FailedEntryCount", 0) or 0)
    if failed:
        logger.error("put_events failed: %s", json.dumps(resp, default=str))
        raise RuntimeError(f"put_events failed: {json.dumps(resp, default=str)}")

    entry = (resp.get("Entries") or [{}])[0]
    logger.info(
        "published source=%s detail_type=%s device_id=%s event_id=%s",
        SOURCE,
        detail_type,
        device_id,
        entry.get("EventId"),
    )
    return {
        "ok": True,
        "source": SOURCE,
        "device_id": device_id,
        "detail_type": detail_type,
        "event_id": entry.get("EventId"),
        "entries": resp.get("Entries", []),
    }
