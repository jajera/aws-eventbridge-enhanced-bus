# Tech

- **Docs:** Zensical + Patina (`zensical.toml`, `docs/`)
- **IaC:** none — deploy/verify are AWS CLI walkthroughs in `docs/demo/`
- **Enhanced EventBridge:** `aws eventsv2` (AWS CLI **≥ 2.37.3**; 2.37.2 used `eventbridgev2`)
- **Also used:** `iam`, `lambda`, `dynamodb`, `ram`, `sqs`, `logs`, `sts`
- **Region:** `ap-southeast-2`
- **Profiles:** `lab` (bus + bridge), `dev` (Subscriber + alerts)
- **Runtimes:** Lambda `python3.14`
- **Tag:** `Project=eb-enhanced-bus`
- **Mutation gate (teardown scripts):** `EB_ENHANCED_ALLOW_AWS=1`

## Commands

```bash
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
.venv/bin/zensical build
.venv/bin/zensical serve

# Deploy / verify — follow docs/demo/lab.md, dev.md, verify.md
```

## CI

- `markdown-lint.yml` + `commitmsg-conform.yml` (actionsforge reusables)
- `docs.yml` → `zensical-pages-deploy`
- `auto-merge.yml` + Dependabot (github-actions, pip)
