# Agent notes

Zensical + AWS CLI lab for the **enhanced EventBridge custom event bus**: lab publishes,
dev consumes via a FIFO Subscriber and writes `health-alerts`.

## Accounts

| Profile | Role |
| --- | --- |
| `lab` | Same account as sandbox — bus owner, `eb-bridge` (IoT→bus), RAM share |
| `dev` | FIFO Subscriber, `health-eval`, DynamoDB `health-alerts` |

Region: `ap-southeast-2`. Tag: `Project=eb-enhanced-bus`.

## Commands

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/zensical serve

# Capture account IDs (read-only):
AWS_PROFILE=lab ./scripts/capture-accounts.sh lab
AWS_PROFILE=dev ./scripts/capture-accounts.sh dev

# Deploy / verify: AWS CLI walkthroughs in docs/demo/{lab,dev,verify}.md
# (no deploy-lab.sh / deploy-dev.sh)

# Teardown still scripted:
AWS_PROFILE=dev EB_ENHANCED_ALLOW_AWS=1 ./scripts/teardown-dev.sh
AWS_PROFILE=lab EB_ENHANCED_ALLOW_AWS=1 ./scripts/teardown-lab.sh
```

Requires AWS CLI **2.37.3+** (`aws eventsv2`; briefly `eventbridgev2` in 2.37.2).

## Docs

Reading order: Overview → Patterns → Design → Demo → References (`zensical.toml` nav).

### Diagrams and icons

- AWS service icons — official AWS Architecture Icons, stored under `docs/assets/icons/`
  (sourced via the [`aws-icons`](https://github.com/MKAbuMattar/aws-icons) mirror on jsdelivr /
  `@aws-icons/svg`). Overview strip uses `eventbridge`, `ram`, `sqs`, `lambda`, `dynamodb`.
  Demo ownership diagram also uses `iot-core` and `iam` (inlined into the SVG).

## Non-negotiables

1. Do not invent bus ARNs — capture `EventBusArn` from create into `out/lab/bus-arn.txt`.
2. Do not mutate AWS without an explicit operator intent (teardown scripts require `EB_ENHANCED_ALLOW_AWS=1`).
3. Management account is out of scope (share is lab → dev).
4. Existing `iot-talk-*` stack is feed only; this repo owns the bridge + EventBridge path.
   Allowed IoT mutation: add/remove the `eb-bridge` Lambda action on events +
   telemetry rules (keep `iot-talk-ingest`; skip camera). Teardown restores ingest-only.
