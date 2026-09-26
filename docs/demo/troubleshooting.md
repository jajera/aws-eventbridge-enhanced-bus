# Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `invalid choice 'eventsv2'` / `eventbridgev2` | CLI &lt; 2.37.3 (or still on 2.36.x) | Upgrade AWS CLI to **≥ 2.37.3**; confirm `aws eventsv2 help` |
| `Refusing to mutate AWS` | Gate unset | `export EB_ENHANCED_ALLOW_AWS=1` |
| RAM `OperationNotPermittedException` | Org-wide RAM sharing not enabled | One-time on the **management** account (out of lab scope): `aws ram enable-sharing-with-aws-organization` — then recreate the lab→dev share |
| Subscriber created but verify get-item empty | Filter mismatch, share not visible, or eval crashing | Confirm bus ARN via `list-event-buses` in **both** profiles; check `health-eval` logs; republish |
| Bus missing from `list-event-buses` in dev | RAM share not associated | Check `ram get-resource-share-associations` (lab) and `ram list-resources --resource-owner OTHER-ACCOUNTS` (dev) |
| CloudWatch `Datapoints: []` on EventsV2 | Lag, wrong dim, or empty window | Wait; confirm `BUS_DIM` / `SUB_DIM` are name/id suffixes; widen `--start-time` |
| Verify fails DLQ not empty | Target invoke / handler errors | Inspect `health-alerts-dlq` and `/aws/lambda/health-eval` |
| `put-events` PUBLISHED but no Dynamo row | Subscriber after events / LATEST | Create Subscriber first; republish |
| Stale alert wins | Ordering / ts | Ensure `EventGroupId` set; check `source_event_ts` no-op path in logs |
| Bridge invoke fails | Missing `eventbridgev2` model / IAM | Zip must include `bridge/data/` (see Deploy lab); check PutEvents on bus ARN and `/aws/lambda/eb-bridge` |
| Device event never hits bus | Rule not wired / filter mismatch | Check **telemetry** first (`iot_talk_telemetry` / `iot_talk_fleet_telemetry`) — that is the busy path; each must list `eb-bridge`; Subscriber filter `source=iot.lab` |
| IoT rule broken after teardown | Bridge deleted before rules restored | Re-run `teardown-lab.sh` (restores ingest-only) or set each events/telemetry rule action to `iot-talk-ingest` only |
| Bus delete fails | Subscriber still attached | Tear down **dev** first; wait until Subscriber is gone |

Related: [Prerequisites](prerequisites.md) · [Verify](verify.md) · [Tear down](teardown.md).
