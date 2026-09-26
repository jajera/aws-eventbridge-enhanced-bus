# Lab safety

- Profiles: **`lab`**, **`dev`** (same accounts as existing `sandbox` / `dev`)
- Region: **`ap-southeast-2`**
- Mutation gate: **`EB_ENHANCED_ALLOW_AWS=1`**
- Tag: **`Project=eb-enhanced-bus`**
- Teardown order: Subscriber → eval Lambda → roles → DLQ → table; then RAM share → bridge → bus
- Do not mutate the existing `iot-talk-*` stack except the documented
  events + telemetry rule → `eb-bridge` Lambda actions (keep ingest; skip camera;
  teardown restores ingest-only)
- Scripts write under `out/` (gitignored); never commit ARNs with secrets
