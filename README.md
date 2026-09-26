# aws-eventbridge-enhanced-bus

Cross account ordered alerts on an enhanced EventBridge custom event bus

Docs: [aws-eventbridge-enhanced-bus.johna.kiwi](https://aws-eventbridge-enhanced-bus.johna.kiwi/)

## Docs locally

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/zensical serve
```

Open the URL printed by the server (usually `http://127.0.0.1:8000`).

## Deploy (operator)

AWS CLI **≥ 2.37.3** (`aws eventsv2`). Walkthroughs author every command:

```bash
export AWS_REGION=ap-southeast-2

AWS_PROFILE=lab ./scripts/capture-accounts.sh lab
AWS_PROFILE=dev ./scripts/capture-accounts.sh dev
```

Then follow the Demo pages in order:

1. [docs/demo/lab.md](docs/demo/lab.md) — bus, `eb-bridge`, IoT rules wire, RAM share
2. [docs/demo/dev.md](docs/demo/dev.md) — table, Subscriber + filter, eval  
3. [docs/demo/verify.md](docs/demo/verify.md) — put-events + DynamoDB + meters  

Tear down (scripts still): `teardown-dev.sh` then `teardown-lab.sh`
(with `EB_ENHANCED_ALLOW_AWS=1`).

## Layout

| Path | Purpose |
| --- | --- |
| `docs/` | Zensical site |
| `bridge/` | lab Lambda `eb-bridge` (IoT → enhanced bus) + vendored `eventbridgev2` model |
| `consumer/` | dev Lambda `health-eval` |
| `scripts/` | capture-accounts / teardown |
| `out/` | gitignored ARNs |

See [AGENTS.md](AGENTS.md) for agent rules.
