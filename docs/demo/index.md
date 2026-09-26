# Demo

Stand up an enhanced EventBridge bus in **lab**, wire IoT through `eb-bridge`,
share it to **dev** with RAM, attach a FIFO Subscriber, and prove ordered
delivery. You run every AWS CLI command; these pages only author them.

**Billable while applied** — smoke-level traffic (cents). Destroy when finished →
[Tear down](teardown.md) · [Cost](../cost.md).

## What you will build

A two-account lab that proves the **enhanced custom event bus** capabilities on
[Overview](../index.md#what-the-feature-adds): shared bus + RAM, Subscriber,
consumer filter, FIFO, retention.

![Lab: IoT to eb-bridge to lab-events to RAM; dev: FIFO Subscriber to health-eval to health-alerts](../assets/diagrams/ownership.svg)

<p class="diagram-caption">Lab shape is <strong>enhanced share</strong>: one bus, RAM to dev, FIFO Subscriber. Feed/proof (IoT, bridge, DynamoDB) are incidental. Detail: <a href="../design/">Design</a>.</p>

### Accounts

| Profile | Owns |
| --- | --- |
| `lab` | `lab-events`, `eb-bridge`, RAM share (principal = **dev**) |
| `dev` | `health-fifo`, delivery role, `health-eval`, `health-alerts`, DLQ |

Share is lab → dev only.

### Resources

| Side | Name | Role |
| --- | --- | --- |
| lab | `iot_talk_*` | IoT rules → `eb-bridge` (telemetry + events; ingest stays) |
| lab | `eb-bridge` | IoT → `PutEvents` + `EventGroupId` |
| lab | `lab-events` | Enhanced bus (7-day retention) |
| lab | `eb-enhanced-bus-share` | RAM share |
| dev | `health-fifo` | FIFO Subscriber · filter `source=iot.lab` |
| dev | `health-eval` | Target (OPEN / CLEAR) |
| dev | `health-alerts` | Proof store |
| dev | `health-alerts-dlq` | On-failure |

### What you will prove

Maps to [What the feature adds](../index.md#what-the-feature-adds):

1. **Shared bus (RAM)** — same `event-busv2` ARN visible in lab and in dev.
2. **Subscriber** — `health-fifo` owns filter, target, retry, and DLQ in **dev**.
3. **Consumer DATA filter** — only `source=iot.lab` reaches the target (egress follows the match).
4. **FIFO + `EventGroupId`** — per-entity order (OPEN → CLEAR → button) holds.
5. **Retention** — bus keeps events for the configured window (this lab: 7 days).

## Steps

| Step | Page |
| --- | --- |
| Before you start | [Prerequisites](prerequisites.md) |
| 0 · Profiles | [Check profiles](profiles.md) |
| 1 · Lab | [Deploy lab](lab.md) |
| 2 · Dev | [Deploy dev](dev.md) |
| 3 · Verify | [Verify](verify.md) |
| 4 · Clean up | [Tear down](teardown.md) |
| Stuck? | [Troubleshooting](troubleshooting.md) |
