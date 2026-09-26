# Tear down

**Dev first**, then **lab** — Subscriber leaves before the shared bus and RAM
share. Scripts need `EB_ENHANCED_ALLOW_AWS=1`.

Does **not** delete the `iot-talk-*` stack. Lab teardown restores wired IoT
rules to **ingest-only**, then deletes this lab’s resources. Leaves
`out/*/account-id.txt` (and `region.txt`) for the next deploy.

## What is removed

| Side | Removed |
| --- | --- |
| **dev** | Subscriber `health-fifo`, `health-eval`, delivery + eval roles, DLQ, `health-alerts` |
| **lab** | Bridge action on events/telemetry rules → ingest-only; RAM share; `eb-bridge` + role; `lab-events` |

Camera rule is untouched (never wired).

## Destroy (dev)

<div class="run" markdown>

```bash
export AWS_PROFILE=dev AWS_REGION=ap-southeast-2 EB_ENHANCED_ALLOW_AWS=1
./scripts/teardown-dev.sh
```

```text {.no-copy}
==> Deleting Subscriber arn:aws:events:…:subscriber/health-fifo/…
==> Deleting Lambda health-eval
==> Deleting role eb-subscriber-delivery
==> Deleting role health-eval-role
==> Deleting DLQ https://sqs.…/health-alerts-dlq
==> Deleting table health-alerts
Dev teardown complete.
```

</div>

## Destroy (lab)

Run only after **dev** teardown (or the bus delete can fail while a Subscriber
still attaches).

<div class="run" markdown>

```bash
export AWS_PROFILE=lab AWS_REGION=ap-southeast-2 EB_ENHANCED_ALLOW_AWS=1
./scripts/teardown-lab.sh
```

```text {.no-copy}
==> Restoring IoT rule iot_talk_events to ingest-only
==> Restoring IoT rule iot_talk_telemetry to ingest-only
==> Restoring IoT rule iot_talk_fleet_events to ingest-only
==> Restoring IoT rule iot_talk_fleet_telemetry to ingest-only
==> Deleting RAM share arn:aws:ram:…:resource-share/…
==> Deleting Lambda eb-bridge
==> Deleting role eb-bridge-role
==> Deleting event bus arn:aws:events:…:event-busv2/lab-events/…
Lab teardown complete.
```

</div>

Scripts prefer ARNs under `out/{dev,lab}/` and fall back to resource **names**
when those files are missing.

Stuck resources: [Troubleshooting](troubleshooting.md).
