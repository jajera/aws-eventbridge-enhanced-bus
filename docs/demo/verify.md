# Verify

Prove the shared enhanced bus with **AWS CLI** only: visible in both accounts,
FIFO Subscriber running, ordered delivery into `health-alerts`, retention, and
ingress/egress meters. Run after [Deploy lab](lab.md) and [Deploy dev](dev.md).

CLI `put-events` below smokes the **same envelope** `eb-bridge` stamps
(`Source=iot.lab`, `EventGroupId`). Live devices reach the bus via the IoT
events/telemetry rules → bridge wire on [Deploy lab](lab.md).

No mutation gate — these calls are PutEvents / read APIs.

## Load ARNs

<div class="run" markdown>

```bash
export AWS_REGION=ap-southeast-2
BUS_ARN="$(cat out/lab/bus-arn.txt)"
SHARE_ARN="$(cat out/lab/share-arn.txt)"
SUB_ARN="$(cat out/dev/subscriber-arn.txt)"
echo "$BUS_ARN"
```

```text {.no-copy}
arn:aws:events:ap-southeast-2:111122223333:event-busv2/lab-events/6yfjf3x6kbnmeebj112dpxahu
```

</div>

## Bus visible in lab (owner)

<div class="run" markdown>

```bash
aws eventsv2 list-event-buses --profile lab \
  --query "EventBuses[?EventBusArn=='$BUS_ARN']" --output json
```

```text {.no-copy}
[
    {
        "Name": "lab-events",
        "EventBusArn": "arn:aws:events:ap-southeast-2:111122223333:event-busv2/lab-events/6yfjf3x6kbnmeebj112dpxahu",
        "State": "ACTIVE",
        "EventBusAccountId": "111122223333"
    }
]
```

</div>

<div class="run" markdown>

```bash
aws eventsv2 describe-event-bus --profile lab \
  --event-bus-arn "$BUS_ARN" \
  --query '{Arn:EventBusArn,Name:Name,State:State,RetentionDays:StorageConfiguration.RetentionPeriodInDays}' \
  --output json
```

```text {.no-copy}
{
    "Arn": "arn:aws:events:ap-southeast-2:111122223333:event-busv2/lab-events/6yfjf3x6kbnmeebj112dpxahu",
    "Name": "lab-events",
    "State": "ACTIVE",
    "RetentionDays": 7
}
```

</div>

<div class="expect" markdown="0"><span class="pill">State = ACTIVE</span><span class="pill">Name = lab-events</span><span class="pill">RetentionDays = 7</span></div>

## Bus visible in dev (shared via RAM)

`list-event-buses` returns owned **and** RAM-shared buses. Shared rows only
carry identity fields (`Name`, `EventBusArn`, `EventBusAccountId`).

<div class="run" markdown>

```bash
aws eventsv2 list-event-buses --profile dev \
  --query "EventBuses[?EventBusArn=='$BUS_ARN']" --output json
```

```text {.no-copy}
[
    {
        "Name": "lab-events",
        "EventBusArn": "arn:aws:events:ap-southeast-2:111122223333:event-busv2/lab-events/6yfjf3x6kbnmeebj112dpxahu",
        "EventBusAccountId": "111122223333"
    }
]
```

</div>

`EventBusAccountId` must be the **lab** account — not dev.

<div class="expect" markdown="0"><span class="pill">EventBusAccountId = lab (111122223333)</span></div>

<div class="run" markdown>

```bash
aws eventsv2 describe-event-bus --profile dev \
  --event-bus-arn "$BUS_ARN" \
  --query '{Arn:EventBusArn,Name:Name,State:State}' --output json
```

```text {.no-copy}
{
    "Arn": "arn:aws:events:ap-southeast-2:111122223333:event-busv2/lab-events/6yfjf3x6kbnmeebj112dpxahu",
    "Name": "lab-events",
    "State": "ACTIVE"
}
```

</div>

<div class="run" markdown>

```bash
aws ram get-resource-share-associations --profile lab \
  --association-type PRINCIPAL \
  --resource-share-arns "$SHARE_ARN" \
  --query 'resourceShareAssociations[0].{Principal:associatedEntity,Status:status}' \
  --output json
```

```text {.no-copy}
{
    "Principal": "444455556666",
    "Status": "ASSOCIATED"
}
```

</div>

<div class="expect" markdown="0"><span class="pill">Principal = dev (444455556666)</span><span class="pill">Status = ASSOCIATED</span></div>

<div class="run" markdown>

```bash
aws ram list-resources --profile dev \
  --resource-owner OTHER-ACCOUNTS \
  --query "resources[?arn=='$BUS_ARN'].{Arn:arn,Status:status}" --output json
```

```text {.no-copy}
[
    {
        "Arn": "arn:aws:events:ap-southeast-2:111122223333:event-busv2/lab-events/6yfjf3x6kbnmeebj112dpxahu",
        "Status": "AVAILABLE"
    }
]
```

</div>

## Subscriber on the shared bus

<div class="run" markdown>

```bash
aws eventsv2 describe-subscriber --profile dev \
  --subscriber-arn "$SUB_ARN" \
  --query '{State:State,Type:Type,EventBusArn:EventBusArn}' --output json
```

```text {.no-copy}
{
    "State": "RUNNING",
    "Type": "FIFO",
    "EventBusArn": "arn:aws:events:ap-southeast-2:111122223333:event-busv2/lab-events/6yfjf3x6kbnmeebj112dpxahu"
}
```

</div>

`EventBusArn` must match `BUS_ARN`. `Type` is `FIFO`.

<div class="expect" markdown="0"><span class="pill">State = RUNNING</span><span class="pill">Type = FIFO</span><span class="pill">EventBusArn = BUS_ARN</span></div>

## Ordered delivery (one entity)

Use a fresh entity id and set `SystemMetadata.EventGroupId` to that id.
**`Source` must be `iot.lab`** — that is what the [dev Subscriber filter](dev.md#the-filter) matches.

<div class="run" markdown>

```bash
ENTITY="verify-$(date -u +%Y%m%d%H%M%S)"
TS="$(date +%s)"
echo "$ENTITY"
```

```text {.no-copy}
verify-20260926044300
```

</div>

### OPEN — weak rssi

<div class="run" markdown>

```bash
aws eventsv2 put-events --profile lab \
  --event-bus-arn "$BUS_ARN" \
  --entries "[
    {
      \"Source\": \"iot.lab\",
      \"DetailType\": \"connectivity\",
      \"Detail\": \"{\\\"type\\\":\\\"connectivity\\\",\\\"rssi\\\":-85,\\\"chip_temp_c\\\":40,\\\"heap_free\\\":200000,\\\"ts\\\":${TS},\\\"device_id\\\":\\\"${ENTITY}\\\"}\",
      \"SystemMetadata\": {\"EventGroupId\": \"${ENTITY}\"}
    }
  ]"
```

```text {.no-copy}
{
    "FailedEntryCount": 0,
    "Entries": [
        {
            "EventId": "d2f552ac-d0f2-4491-8de5-707730744f9c",
            "SequenceNumber": "10000000000000015000",
            "SuccessCode": "PUBLISHED"
        }
    ]
}
```

</div>

Expect `FailedEntryCount` 0 and `SuccessCode` `PUBLISHED`.

<div class="expect" markdown="0"><span class="pill--warn pill">FailedEntryCount 0</span><span class="pill">SuccessCode = PUBLISHED</span></div>

<div class="run" markdown>

```bash
sleep 5
aws dynamodb get-item --profile dev \
  --table-name health-alerts \
  --key "{\"entity_id\":{\"S\":\"${ENTITY}\"}}" \
  --query 'Item.{status:status.S,reason:reason.S,rssi:metrics.M.rssi.N,ts:source_event_ts.N}' \
  --output json
```

```text {.no-copy}
{
    "status": "OPEN",
    "reason": "weak_rssi",
    "rssi": "-85",
    "ts": "1790397835"
}
```

</div>

<div class="expect" markdown="0"><span class="pill">status = OPEN</span><span class="pill">reason = weak_rssi</span><span class="sep">rssi −85 &lt; −80 threshold</span></div>

### CLEAR — healthy

<div class="run" markdown>

```bash
TS=$((TS + 1))
aws eventsv2 put-events --profile lab \
  --event-bus-arn "$BUS_ARN" \
  --entries "[
    {
      \"Source\": \"iot.lab\",
      \"DetailType\": \"connectivity\",
      \"Detail\": \"{\\\"type\\\":\\\"connectivity\\\",\\\"rssi\\\":-50,\\\"chip_temp_c\\\":40,\\\"heap_free\\\":200000,\\\"ts\\\":${TS},\\\"device_id\\\":\\\"${ENTITY}\\\"}\",
      \"SystemMetadata\": {\"EventGroupId\": \"${ENTITY}\"}
    }
  ]"
```

```text {.no-copy}
{
    "FailedEntryCount": 0,
    "Entries": [
        {
            "EventId": "3fafde24-9673-418c-9c12-40893d1e7bca",
            "SequenceNumber": "10000000000000016000",
            "SuccessCode": "PUBLISHED"
        }
    ]
}
```

</div>

<div class="run" markdown>

```bash
sleep 5
aws dynamodb get-item --profile dev \
  --table-name health-alerts \
  --key "{\"entity_id\":{\"S\":\"${ENTITY}\"}}" \
  --query 'Item.{status:status.S,reason:reason.S,rssi:metrics.M.rssi.N,ts:source_event_ts.N}' \
  --output json
```

```text {.no-copy}
{
    "status": "CLEAR",
    "reason": "healthy",
    "rssi": "-50",
    "ts": "1790397836"
}
```

</div>

`ts` must advance with the new publish.

<div class="expect" markdown="0"><span class="pill">status = CLEAR</span><span class="pill">reason = healthy</span><span class="sep">ts &gt; previous</span></div>

### OPEN — button

<div class="run" markdown>

```bash
TS=$((TS + 1))
aws eventsv2 put-events --profile lab \
  --event-bus-arn "$BUS_ARN" \
  --entries "[
    {
      \"Source\": \"iot.lab\",
      \"DetailType\": \"button\",
      \"Detail\": \"{\\\"type\\\":\\\"button\\\",\\\"event\\\":\\\"press\\\",\\\"ts\\\":${TS},\\\"device_id\\\":\\\"${ENTITY}\\\"}\",
      \"SystemMetadata\": {\"EventGroupId\": \"${ENTITY}\"}
    }
  ]"
```

```text {.no-copy}
{
    "FailedEntryCount": 0,
    "Entries": [
        {
            "EventId": "…",
            "SequenceNumber": "…",
            "SuccessCode": "PUBLISHED"
        }
    ]
}
```

</div>

<div class="run" markdown>

```bash
sleep 5
aws dynamodb get-item --profile dev \
  --table-name health-alerts \
  --key "{\"entity_id\":{\"S\":\"${ENTITY}\"}}" \
  --query 'Item.{status:status.S,reason:reason.S,detail_type:detail_type.S}' \
  --output json
```

```text {.no-copy}
{
    "status": "OPEN",
    "reason": "attention_button",
    "detail_type": "button"
}
```

</div>

<div class="expect" markdown="0"><span class="pill">status = OPEN</span><span class="pill">reason = attention_button</span><span class="pill">detail_type = button</span></div>

## Independent EventGroupId lane

Same batch, two entities — B opens while A stays on its own timeline.

<div class="run" markdown>

```bash
ENTITY_B="${ENTITY}-b"
TS_B=$((TS + 1))
aws eventsv2 put-events --profile lab \
  --event-bus-arn "$BUS_ARN" \
  --entries "[
    {
      \"Source\": \"iot.lab\",
      \"DetailType\": \"connectivity\",
      \"Detail\": \"{\\\"type\\\":\\\"connectivity\\\",\\\"rssi\\\":-90,\\\"chip_temp_c\\\":40,\\\"heap_free\\\":200000,\\\"ts\\\":${TS_B},\\\"device_id\\\":\\\"${ENTITY_B}\\\"}\",
      \"SystemMetadata\": {\"EventGroupId\": \"${ENTITY_B}\"}
    },
    {
      \"Source\": \"iot.lab\",
      \"DetailType\": \"connectivity\",
      \"Detail\": \"{\\\"type\\\":\\\"connectivity\\\",\\\"rssi\\\":-45,\\\"chip_temp_c\\\":40,\\\"heap_free\\\":200000,\\\"ts\\\":$((TS_B + 1)),\\\"device_id\\\":\\\"${ENTITY}\\\"}\",
      \"SystemMetadata\": {\"EventGroupId\": \"${ENTITY}\"}
    }
  ]"
```

```text {.no-copy}
{
    "FailedEntryCount": 0,
    "Entries": [
        {"EventId": "…", "SequenceNumber": "…", "SuccessCode": "PUBLISHED"},
        {"EventId": "…", "SequenceNumber": "…", "SuccessCode": "PUBLISHED"}
    ]
}
```

</div>

<div class="run" markdown>

```bash
sleep 5
aws dynamodb get-item --profile dev \
  --table-name health-alerts \
  --key "{\"entity_id\":{\"S\":\"${ENTITY_B}\"}}" \
  --query 'Item.{status:status.S,reason:reason.S,rssi:metrics.M.rssi.N}' \
  --output json
```

```text {.no-copy}
{
    "status": "OPEN",
    "reason": "weak_rssi",
    "rssi": "-90"
}
```

</div>

<div class="expect" markdown="0"><span class="sep">entity B</span><span class="pill">status = OPEN</span><span class="pill">rssi = −90</span></div>

<div class="run" markdown>

```bash
aws dynamodb get-item --profile dev \
  --table-name health-alerts \
  --key "{\"entity_id\":{\"S\":\"${ENTITY}\"}}" \
  --query 'Item.{status:status.S,reason:reason.S,rssi:metrics.M.rssi.N}' \
  --output json
```

```text {.no-copy}
{
    "status": "CLEAR",
    "reason": "healthy",
    "rssi": "-45"
}
```

</div>

<div class="expect" markdown="0"><span class="sep">entity A</span><span class="pill">status = CLEAR</span><span class="pill">rssi = −45</span><span class="sep">B did not disturb A's lane</span></div>

## DLQ empty

<div class="run" markdown>

```bash
aws sqs get-queue-attributes --profile dev \
  --queue-url "$(cat out/dev/dlq-url.txt)" \
  --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible \
  --output json
```

```text {.no-copy}
{
    "Attributes": {
        "ApproximateNumberOfMessages": "0",
        "ApproximateNumberOfMessagesNotVisible": "0"
    }
}
```

</div>

<div class="expect" markdown="0"><span class="pill--warn pill">ApproximateNumberOfMessages 0</span><span class="pill--warn pill">NotVisible 0</span><span class="sep">no failed deliveries</span></div>

## Meters (ingress / egress)

CloudWatch namespace `AWS/EventsV2` — the same meters as [Cost](../cost.md).
Dimension values are the bus and subscriber name/id suffixes (not full ARNs).
Metrics can lag a few minutes after publish.

<div class="run" markdown>

```bash
BUS_DIM="${BUS_ARN##*event-busv2/}"
SUB_DIM="${SUB_ARN##*subscriber/}"
echo "BUS_DIM=$BUS_DIM"
echo "SUB_DIM=$SUB_DIM"
```

```text {.no-copy}
BUS_DIM=lab-events/6yfjf3x6kbnmeebj112dpxahu
SUB_DIM=health-fifo/abq086i14frab44aykzxxqhgk
```

</div>

### Lab — publish ingress

<div class="run" markdown>

```bash
aws cloudwatch get-metric-statistics --profile lab \
  --namespace AWS/EventsV2 \
  --metric-name PublishEventsEntryCount \
  --dimensions Name=EventBus,Value="$BUS_DIM" \
  --start-time "$(date -u -d '6 hours ago' +%Y-%m-%dT%H:%M:%SZ)" \
  --end-time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --period 3600 --statistics Sum --output json
```

```text {.no-copy}
{
    "Label": "PublishEventsEntryCount",
    "Datapoints": [
        {
            "Timestamp": "2026-09-26T16:09:00+12:00",
            "Sum": 12.0,
            "Unit": "Count"
        }
    ]
}
```

</div>

<div class="expect" markdown="0"><span class="pill">Sum &gt; 0</span><span class="sep">publishes landed on the bus</span></div>

<div class="run" markdown>

```bash
aws cloudwatch get-metric-statistics --profile lab \
  --namespace AWS/EventsV2 \
  --metric-name PublishEventsIngressBytes \
  --dimensions Name=EventBus,Value="$BUS_DIM" \
  --start-time "$(date -u -d '6 hours ago' +%Y-%m-%dT%H:%M:%SZ)" \
  --end-time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --period 3600 --statistics Sum --output json
```

```text {.no-copy}
{
    "Label": "PublishEventsIngressBytes",
    "Datapoints": [
        {
            "Timestamp": "2026-09-26T16:09:00+12:00",
            "Sum": 14206.0,
            "Unit": "Bytes"
        }
    ]
}
```

</div>

<div class="expect" markdown="0"><span class="pill">Sum &gt; 0</span><span class="sep">ingress bytes (lab / publisher side of the bill)</span></div>

### Dev — filter match and egress

<div class="run" markdown>

```bash
aws cloudwatch get-metric-statistics --profile dev \
  --namespace AWS/EventsV2 \
  --metric-name FilterMatched \
  --dimensions Name=Subscriber,Value="$SUB_DIM" Name=EventBus,Value="$BUS_DIM" \
  --start-time "$(date -u -d '6 hours ago' +%Y-%m-%dT%H:%M:%SZ)" \
  --end-time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --period 3600 --statistics Sum --output json
```

```text {.no-copy}
{
    "Label": "FilterMatched",
    "Datapoints": [
        {
            "Timestamp": "2026-09-26T16:09:00+12:00",
            "Sum": 12.0,
            "Unit": "Count"
        }
    ]
}
```

</div>

<div class="expect" markdown="0"><span class="pill">Sum &gt; 0</span><span class="sep">DATA filter selected events</span></div>

<div class="run" markdown>

```bash
aws cloudwatch get-metric-statistics --profile dev \
  --namespace AWS/EventsV2 \
  --metric-name EventsDelivered \
  --dimensions Name=Subscriber,Value="$SUB_DIM" Name=EventBus,Value="$BUS_DIM" \
  --start-time "$(date -u -d '6 hours ago' +%Y-%m-%dT%H:%M:%SZ)" \
  --end-time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --period 3600 --statistics Sum --output json
```

```text {.no-copy}
{
    "Label": "EventsDelivered",
    "Datapoints": [
        {
            "Timestamp": "2026-09-26T16:09:00+12:00",
            "Sum": 12.0,
            "Unit": "Count"
        }
    ]
}
```

</div>

<div class="expect" markdown="0"><span class="pill">Sum &gt; 0</span><span class="sep">delivered to the Subscriber</span></div>

<div class="run" markdown>

```bash
aws cloudwatch get-metric-statistics --profile dev \
  --namespace AWS/EventsV2 \
  --metric-name EgressBytes \
  --dimensions Name=Subscriber,Value="$SUB_DIM" Name=EventBus,Value="$BUS_DIM" \
  --start-time "$(date -u -d '6 hours ago' +%Y-%m-%dT%H:%M:%SZ)" \
  --end-time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --period 3600 --statistics Sum --output json
```

```text {.no-copy}
{
    "Label": "EgressBytes",
    "Datapoints": [
        {
            "Timestamp": "2026-09-26T16:09:00+12:00",
            "Sum": 8674.0,
            "Unit": "Bytes"
        }
    ]
}
```

</div>

<div class="expect" markdown="0"><span class="pill">Sum &gt; 0</span><span class="sep">egress bytes (dev / consumer side of the bill)</span></div>

!!! note "Empty Datapoints?"
    Wait a few minutes and re-run, or widen `--start-time`. Empty usually means
    lag, wrong `BUS_DIM` / `SUB_DIM`, or no publishes in the window yet.

If a get-item is empty, wait a few more seconds and re-run that command. Stuck?
[Troubleshooting](troubleshooting.md). Clean up: [Tear down](teardown.md).
