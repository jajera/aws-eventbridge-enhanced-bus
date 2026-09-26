# Product

Cross-account ordered alerts on an **enhanced EventBridge custom event bus**.

Lab owns the bus and publishes. Dev registers a FIFO Subscriber that evaluates health
thresholds and writes alert rows to DynamoDB. An existing lab event feed is only the
publisher — this repo does not own IoT product work.

## Scope

- Enhanced bus (`eventbridgev2`) + RAM share lab → dev
- Bridge Lambda in lab (PutEvents with EventGroupId)
- FIFO Subscriber + health-eval Lambda + health-alerts table in dev
- Zensical docs + CLI scripts

## Non-goals

- Terraform / CDK
- Firmware, Amplify, replacing the existing feed dashboard
- Management-account or platform-owned bus
- Fake high-volume load generators
- Content-based dedup / JSONata reshape as required demo path
